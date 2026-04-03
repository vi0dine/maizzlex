# Mailer Configuration Reference

`Maizzlex.Mailer` reads runtime config from:

```elixir
Application.get_env(:my_app, MyApp.Mailer, [])
```

## Full example

```elixir
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Brevo,
  api_key: System.fetch_env!("BREVO_API_KEY"),
  from: {"My App", "noreply@example.com"},
  anti_spam_headers: [
    {"X-Mailer", "My App Mailer"}
  ],
  transactional_headers: [
    {"X-Transactional", "true"},
    {"X-MyApp-Category", "transactional"}
  ],
  list_unsubscribe_email: "unsubscribe@example.com",
  list_unsubscribe_url: "https://example.com/unsubscribe",
  html2text_opts: [
    width: 80,
    ignore_images: true,
    ignore_links: false
  ],
  attachment_adapter: {MyApp.Mailers.S3AttachmentAdapter, bucket: "mail-assets"},
  email_store: {MyApp.Mailers.DatabaseEmailStore, repo: MyApp.Repo}
```

`api_client` is configured separately through Swoosh:

```elixir
config :swoosh, :api_client, Swoosh.ApiClient.Req
```

## Runtime keys

### `adapter`

Required. This is the Swoosh adapter used for delivery.

Typical values:

```elixir
adapter: Swoosh.Adapters.Local
adapter: Swoosh.Adapters.Test
adapter: Swoosh.Adapters.Brevo
```

Any additional keys required by the selected adapter are passed through unchanged to Swoosh.
Examples include `api_key`, `domain`, `relay`, `username`, `password`, `region`, and `base_url`.

### `from`

Required. Sender identity used by `base_email/0` and `transactional_email/0`.

Supported forms:

```elixir
from: {"My App", "noreply@example.com"}
from: "noreply@example.com"
```

### `anti_spam_headers`

Optional. Additional or overriding headers for `base_email/0`.

Defaults:

```elixir
[
  {"X-Mailer", "Maizzlex Mailer"},
  {"X-Priority", "3"},
  {"Importance", "Normal"}
]
```

Headers are merged by name. If you pass the same header key, your value wins.

### `transactional_headers`

Optional. Additional or overriding headers for `transactional_email/0`.

Defaults:

```elixir
[
  {"X-Transactional", "true"},
  {"Auto-Submitted", "auto-generated"},
  {"X-Auto-Response-Suppress", "All"}
]
```

### `list_unsubscribe_email`

Optional. Adds a `mailto:` entry to `List-Unsubscribe`.

### `list_unsubscribe_url`

Optional. Adds an HTTPS entry to `List-Unsubscribe`.

If `list_unsubscribe_url` is set, `Maizzlex` also adds:

```text
List-Unsubscribe-Post: List-Unsubscribe=One-Click
```

### `html2text_opts`

Optional. Options passed directly to `HTML2Text.convert/2`.

Defaults:

```elixir
[
  width: 72,
  ignore_images: true,
  ignore_links: false
]
```

### `attachment_adapter`

Optional unless you pass attachments to `send_email/2`.

Accepted forms:

```elixir
attachment_adapter: MyApp.Mailers.AttachmentAdapter
attachment_adapter: {MyApp.Mailers.AttachmentAdapter, some: :option}
```

If attachments are provided and no adapter is configured, `send_email/2` returns:

```elixir
{:error, :missing_attachment_adapter}
```

### `email_store`

Optional.

Accepted forms:

```elixir
email_store: MyApp.Mailers.EmailStore
email_store: {MyApp.Mailers.EmailStore, repo: MyApp.Repo}
```

The store runs only after successful delivery. Errors are logged and ignored.

## Global Swoosh config

### `api_client`

Optional for `Local` and `Test`. Required for HTTP-based Swoosh adapters.

Supported forms:

```elixir
config :swoosh, :api_client, false
config :swoosh, :api_client, Swoosh.ApiClient.Req
config :swoosh, :api_client, Swoosh.ApiClient.Hackney
config :swoosh, :api_client, Swoosh.ApiClient.Finch
```

`api_client` is not part of `config :my_app, MyApp.Mailer`. It must be configured under `:swoosh`.

## Build config

`mix maizzlex.emails.build` reads app-level settings from:

```elixir
config :my_app, :maizzlex,
  maizzle_dir: "maizzle",
  output_dir: "priv/emails",
  build_command: {"npm", ["run", "build"]},
  dev_command: {"npm", ["run", "dev"]}
```

### `maizzle_dir`

Defaults to `"maizzle"`.

### `build_command`

Defaults to:

```elixir
{"npm", ["run", "build"]}
```

For custom test or CI flows, you can also pass an MFA tuple:

```elixir
config :my_app, :maizzlex,
  build_command: {:mfa, {MyApp.MaizzleBuilder, :run, []}}
```

The MFA will receive:

```elixir
[maizzle_dir, config | extra_args]
```

### `output_dir`

Defaults to `Path.expand("../priv/emails", maizzle_dir)`.

Before each build, `Maizzlex.Builder` clears this directory so only freshly built email
templates remain in the output.

### `dev_command`

Defaults to:

```elixir
{"npm", ["run", "dev"]}
```

This command is used by `mix maizzlex.emails.dev`.

For tests or custom integrations you can also pass an MFA tuple:

```elixir
config :my_app, :maizzlex,
  dev_command: {:mfa, {MyApp.MaizzleDevServer, :run, []}}
```
