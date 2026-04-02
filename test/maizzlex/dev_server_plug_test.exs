defmodule Maizzlex.DevServerPlugTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  test "proxies html through the host path prefix" do
    conn =
      conn(:get, "/welcome")
      |> Map.put(:script_name, ["dev", "maizzle"])
      |> Maizzlex.DevServerPlug.call(
        request_fun: fn request ->
          assert request.url == "http://127.0.0.1:3000/welcome"

          {:ok,
           %{
             status: 200,
             headers: [{"content-type", "text/html; charset=utf-8"}],
             body: ~s(<html><head></head><body><script src="/hmr.js"></script></body></html>)
           }}
        end
      )

    assert conn.status == 200
    assert conn.resp_body =~ ~s(src="/dev/maizzle/hmr.js")

    [content_type] = get_resp_header(conn, "content-type")
    assert String.starts_with?(content_type, "text/html")
  end

  test "rewrites hmr client to use the forwarded websocket path" do
    conn =
      conn(:get, "/hmr.js")
      |> Map.put(:script_name, ["dev", "maizzle"])
      |> Maizzlex.DevServerPlug.call(
        request_fun: fn request ->
          assert request.url == "http://127.0.0.1:3000/hmr.js"

          {:ok,
           %{
             status: 200,
             headers: [{"content-type", "application/javascript"}],
             body: """
             const { hostname, port } = window.location
             const socket = new WebSocket(`ws://${hostname}:${port}`)
             """
           }}
        end
      )

    assert conn.status == 200

    assert conn.resp_body =~
             "const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws'"

    assert conn.resp_body =~ "/dev/maizzle/__ws"
  end

  test "delegates websocket upgrades to the websocket proxy" do
    conn =
      conn(:get, "/__ws")
      |> Map.put(:script_name, ["dev", "maizzle"])
      |> put_req_header("upgrade", "websocket")
      |> Maizzlex.DevServerPlug.call(
        websocket_proxy_fun: fn conn, websocket_opts ->
          assert websocket_opts[:upstream_uri] == "ws://127.0.0.1:3000"
          assert websocket_opts[:path] == "/__ws"
          send_resp(conn, 200, "websocket proxied")
        end
      )

    assert conn.status == 200
    assert conn.resp_body == "websocket proxied"
  end
end
