defmodule Maizzlex.Mailer do
  @moduledoc """
  Runtime for host mailers built on top of Swoosh.

  ## Example

      defmodule MyApp.Mailer do
        use Maizzlex.Mailer, otp_app: :my_app, template_root: "emails"
      end

  Host configuration is read from `Application.get_env(otp_app, mailer_module, [])`.
  """

  require Logger

  @default_anti_spam_headers [
    {"X-Mailer", "Maizzlex Mailer"},
    {"X-Priority", "3"},
    {"Importance", "Normal"}
  ]

  @default_transactional_headers [
    {"X-Transactional", "true"},
    {"Auto-Submitted", "auto-generated"},
    {"X-Auto-Response-Suppress", "All"}
  ]

  @default_html2text_opts [
    width: 72,
    ignore_images: true,
    ignore_links: false
  ]

  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    template_root = Keyword.get(opts, :template_root, "emails")

    quote bind_quoted: [otp_app: otp_app, template_root: template_root] do
      use Swoosh.Mailer, otp_app: otp_app

      @maizzlex_otp_app otp_app
      @maizzlex_template_root template_root

      def base_email do
        Maizzlex.Mailer.base_email(__MODULE__, @maizzlex_otp_app)
      end

      def transactional_email do
        Maizzlex.Mailer.transactional_email(__MODULE__, @maizzlex_otp_app)
      end

      def render_template(template_name, assigns \\ %{}) do
        Maizzlex.Mailer.render_template(
          @maizzlex_otp_app,
          @maizzlex_template_root,
          template_name,
          assigns
        )
      end

      def generate_template(template_name, assigns \\ %{}) do
        render_template(template_name, assigns)
      end

      def send_email(email, attachments \\ []) do
        Maizzlex.Mailer.send_email(__MODULE__, @maizzlex_otp_app, email, attachments)
      end

      def premail(email) do
        Maizzlex.Mailer.premail(email)
      end

      defoverridable base_email: 0,
                     generate_template: 2,
                     premail: 1,
                     render_template: 2,
                     send_email: 2,
                     transactional_email: 0
    end
  end

  def base_email(mailer_module, otp_app) do
    config = mailer_config(otp_app, mailer_module)
    from = fetch_from!(config)

    Swoosh.Email.new()
    |> add_headers(header_config(config, :anti_spam_headers, @default_anti_spam_headers))
    |> add_list_unsubscribe_headers(config)
    |> Swoosh.Email.from(from)
  end

  def transactional_email(mailer_module, otp_app) do
    config = mailer_config(otp_app, mailer_module)

    base_email(mailer_module, otp_app)
    |> add_headers(header_config(config, :transactional_headers, @default_transactional_headers))
  end

  def render_template(otp_app, template_root, template_name, assigns) do
    otp_app
    |> :code.priv_dir()
    |> Path.join(template_root)
    |> Path.join(template_name)
    |> EEx.eval_file(assigns: assigns)
  rescue
    error ->
      Logger.error(
        "Failed to render email template #{template_name}: #{Exception.message(error)}"
      )

      reraise(error, __STACKTRACE__)
  end

  def send_email(mailer_module, otp_app, email, attachments) do
    config = mailer_config(otp_app, mailer_module)

    with {:ok, email} <- maybe_add_attachments(email, attachments, config),
         {:ok, text_body} <- html_to_text(email.html_body, config),
         {:ok, final_email} <- deliver_email(mailer_module, email, text_body) do
      maybe_store_email(final_email, text_body, config)
      {:ok, final_email}
    end
  end

  def premail(email) do
    {_, delivered_email} = Swoosh.Adapters.Test.deliver(email, [])
    delivered_email
  end

  defp deliver_email(mailer_module, email, text_body) do
    final_email = Swoosh.Email.text_body(email, text_body)

    case mailer_module.deliver(final_email, []) do
      {:ok, _metadata} ->
        {:ok, final_email}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp html_to_text(nil, _config), do: {:ok, ""}

  defp html_to_text(html_body, config) do
    opts = Keyword.get(config, :html2text_opts, @default_html2text_opts)

    case HTML2Text.convert(html_body, opts) do
      {:ok, text_body} ->
        {:ok, text_body}

      {:error, reason} ->
        Logger.error("Failed to convert HTML to text: #{inspect(reason)}")
        {:ok, "HTML content converted to text"}
    end
  end

  defp maybe_add_attachments(email, [], _config), do: {:ok, email}

  defp maybe_add_attachments(email, attachments, config) do
    case Keyword.get(config, :attachment_adapter) do
      {module, adapter_opts} when is_atom(module) and is_list(adapter_opts) ->
        module.add_attachments(email, attachments, adapter_opts)

      module when is_atom(module) ->
        module.add_attachments(email, attachments, [])

      nil ->
        {:error, :missing_attachment_adapter}

      other ->
        {:error, {:invalid_attachment_adapter, other}}
    end
  end

  defp maybe_store_email(email, text_body, config) do
    sent_at = DateTime.utc_now()

    case Keyword.get(config, :email_store) do
      nil ->
        :ok

      {module, store_opts} when is_atom(module) and is_list(store_opts) ->
        do_store_email(module, email, %{text_body: text_body, sent_at: sent_at}, store_opts)

      module when is_atom(module) ->
        do_store_email(module, email, %{text_body: text_body, sent_at: sent_at}, [])

      other ->
        Logger.warning("Ignoring invalid email_store config: #{inspect(other)}")
        :ok
    end
  end

  defp do_store_email(module, email, metadata, opts) do
    case module.store(email, metadata, opts) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to persist sent email with #{inspect(module)}: #{inspect(reason)}")
        :ok
    end
  end

  defp add_list_unsubscribe_headers(email, config) do
    unsubscribe_email = Keyword.get(config, :list_unsubscribe_email)
    unsubscribe_url = Keyword.get(config, :list_unsubscribe_url)

    values =
      []
      |> maybe_add_unsubscribe_entry(unsubscribe_email, :email)
      |> maybe_add_unsubscribe_entry(unsubscribe_url, :url)

    case values do
      [] ->
        email

      _ ->
        email
        |> Swoosh.Email.header("List-Unsubscribe", Enum.join(values, ", "))
        |> maybe_add_list_unsubscribe_post(unsubscribe_url)
    end
  end

  defp maybe_add_list_unsubscribe_post(email, nil), do: email

  defp maybe_add_list_unsubscribe_post(email, _url) do
    Swoosh.Email.header(email, "List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
  end

  defp maybe_add_unsubscribe_entry(values, nil, _type), do: values
  defp maybe_add_unsubscribe_entry(values, value, :email), do: values ++ ["<mailto:#{value}>"]
  defp maybe_add_unsubscribe_entry(values, value, :url), do: values ++ ["<#{value}>"]

  defp add_headers(email, headers) do
    Enum.reduce(headers, email, fn {name, value}, acc ->
      Swoosh.Email.header(acc, name, value)
    end)
  end

  defp header_config(config, key, defaults) do
    defaults
    |> Enum.concat(normalize_headers(Keyword.get(config, key, [])))
    |> Enum.reduce(%{}, fn {name, value}, acc ->
      Map.put(acc, to_string(name), value)
    end)
    |> Map.to_list()
  end

  defp normalize_headers(nil), do: []
  defp normalize_headers(headers) when is_map(headers), do: Map.to_list(headers)
  defp normalize_headers(headers) when is_list(headers), do: headers

  defp normalize_headers(other),
    do:
      raise(ArgumentError, "expected headers to be a keyword list or map, got: #{inspect(other)}")

  defp fetch_from!(config) do
    case Keyword.get(config, :from) do
      {name, email} when is_binary(name) and is_binary(email) ->
        {name, email}

      email when is_binary(email) ->
        email

      nil ->
        raise ArgumentError, "expected :from to be configured for the host mailer"

      other ->
        raise ArgumentError,
              "expected :from to be a string or {name, email} tuple, got: #{inspect(other)}"
    end
  end

  defp mailer_config(otp_app, mailer_module) do
    Application.get_env(otp_app, mailer_module, [])
  end
end
