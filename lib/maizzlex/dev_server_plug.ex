defmodule Maizzlex.DevServerPlug do
  @moduledoc """
  Proxies the Maizzle development server through the host Phoenix app.
  """

  @behaviour Plug

  import Plug.Conn

  @default_dev_server_url "http://127.0.0.1:3000"
  @hmr_script_path "/hmr.js"
  @websocket_proxy_path "/__ws"

  @hop_by_hop_headers ~w(
    connection
    content-length
    host
    keep-alive
    proxy-authenticate
    proxy-authorization
    te
    trailers
    transfer-encoding
    upgrade
  )

  def init(opts), do: opts

  def call(conn, opts) do
    if websocket_upgrade?(conn) and request_path(conn) == @websocket_proxy_path do
      proxy_websocket(conn, opts)
    else
      proxy_http(conn, opts)
    end
  end

  @doc false
  def rewrite_html_body(body, route_prefix) do
    String.replace(body, ~s(src="/hmr.js"), ~s(src="#{route_prefix}/hmr.js"))
  end

  @doc false
  def rewrite_hmr_script(body, route_prefix) do
    websocket_path = route_prefix <> @websocket_proxy_path

    String.replace(
      body,
      ~S|const socket = new WebSocket(`ws://${hostname}:${port}`)|,
      """
      const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws'
      const socket = new WebSocket(`${protocol}://${hostname}:${port}#{websocket_path}`)
      """
    )
  end

  defp proxy_http(conn, opts) do
    route_prefix = route_prefix(conn)
    upstream_url = build_destination(http_upstream_url(opts), conn.path_info, conn.query_string)
    request_fun = Keyword.get(opts, :request_fun, &default_request/1)
    request = build_request(conn, upstream_url)

    case request_fun.(request) do
      {:ok, %{status: status, headers: headers, body: body}} ->
        content_type = header_value(headers, "content-type")
        body = rewrite_response_body(body, content_type, request.path, route_prefix)

        conn
        |> put_proxy_resp_headers(headers)
        |> send_resp(status, body)

      {:error, reason} ->
        send_resp(conn, 502, proxy_error_message(reason))
    end
  end

  defp proxy_websocket(conn, opts) do
    websocket_proxy_fun = Keyword.get(opts, :websocket_proxy_fun, &default_websocket_proxy/2)
    websocket_proxy_fun.(conn, websocket_proxy_opts(opts))
  end

  defp default_request(request) do
    req_opts = [
      method: request.method,
      url: request.url,
      headers: request.headers,
      body: request.body
    ]

    case Req.request(req_opts) do
      {:ok, response} ->
        {:ok, %{status: response.status, headers: response.headers, body: response.body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp default_websocket_proxy(conn, websocket_opts) do
    conn
    |> ReverseProxyPlugWebsocket.call(ReverseProxyPlugWebsocket.init(websocket_opts))
  end

  defp build_destination(base_url, path_info, query_string) do
    path =
      case path_info do
        [] -> ""
        _ -> "/" <> Enum.join(path_info, "/")
      end

    query =
      case query_string do
        nil -> ""
        "" -> ""
        query -> "?" <> query
      end

    String.trim_trailing(base_url, "/") <> path <> query
  end

  defp build_request(conn, upstream_url) do
    %{
      method: http_method(conn.method),
      url: upstream_url,
      headers: request_headers(conn.req_headers),
      body: request_body(conn),
      path: request_path(conn)
    }
  end

  defp put_proxy_resp_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {name, value}, acc ->
      if String.downcase(name) in @hop_by_hop_headers do
        acc
      else
        put_resp_header(acc, name, value)
      end
    end)
  end

  defp rewrite_response_body(body, content_type, path, route_prefix)
       when is_binary(body) and is_binary(content_type) do
    cond do
      String.starts_with?(content_type, "text/html") ->
        rewrite_html_body(body, route_prefix)

      path == @hmr_script_path and String.contains?(content_type, "javascript") ->
        rewrite_hmr_script(body, route_prefix)

      true ->
        body
    end
  end

  defp rewrite_response_body(body, _content_type, _path, _route_prefix), do: body

  defp request_headers(headers) do
    Enum.reject(headers, fn {name, _value} ->
      String.downcase(name) in @hop_by_hop_headers
    end)
  end

  defp request_body(%Plug.Conn{method: method}) when method in ["GET", "HEAD"], do: nil

  defp request_body(conn) do
    conn
    |> read_full_body([])
    |> IO.iodata_to_binary()
  end

  defp read_full_body(conn, chunks) do
    case read_body(conn) do
      {:ok, chunk, _conn} ->
        Enum.reverse([chunk | chunks])

      {:more, chunk, next_conn} ->
        read_full_body(next_conn, [chunk | chunks])
    end
  end

  defp request_path(conn) do
    case conn.path_info do
      [] -> "/"
      segments -> "/" <> Enum.join(segments, "/")
    end
  end

  defp route_prefix(conn) do
    "/" <> Enum.join(conn.script_name, "/")
  end

  defp http_upstream_url(opts) do
    Keyword.get(
      opts,
      :url,
      Application.get_env(:maizzlex, :dev_server_url, @default_dev_server_url)
    )
  end

  defp websocket_proxy_opts(opts) do
    [
      upstream_uri: websocket_upstream_url(opts),
      path: @websocket_proxy_path,
      adapter: ReverseProxyPlugWebsocket.Adapters.Gun
    ]
  end

  defp websocket_upstream_url(opts) do
    opts
    |> http_upstream_url()
    |> URI.parse()
    |> Map.update!(:scheme, fn
      "https" -> "wss"
      _ -> "ws"
    end)
    |> URI.to_string()
  end

  defp websocket_upgrade?(conn) do
    conn
    |> get_req_header("upgrade")
    |> Enum.any?(&(String.downcase(&1) == "websocket"))
  end

  defp header_value(headers, header_name) do
    header_name = String.downcase(header_name)

    headers
    |> Enum.find_value("", fn {name, value} ->
      if String.downcase(name) == header_name, do: value
    end)
  end

  defp http_method(method) do
    method
    |> String.downcase()
    |> String.to_existing_atom()
  rescue
    ArgumentError -> :get
  end

  defp proxy_error_message(reason) do
    "Failed to reach the Maizzle dev server: #{inspect(reason)}"
  end
end
