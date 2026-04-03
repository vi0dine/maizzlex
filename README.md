# Maizzlex

Reusable Maizzle + Swoosh email tooling for Elixir applications.

`Maizzlex` gives a Phoenix host app three things:

- a mailer runtime built on `Swoosh`
- a Maizzle scaffolding and build workflow
- clear extension points for attachments and email persistence

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Key Concepts](#key-concepts)

## Overview

`Maizzlex` is intentionally split between library code and host-app code.

The library owns:

- `use Maizzlex.Mailer`
- `mix maizzlex.emails.build`
- Igniter installers and generators
- theme generation from semantic base colors
- behavior contracts for custom attachment and email-store integrations

The host app owns:

- `MyApp.Mailer`
- `maizzle/**`
- `priv/emails/**`
- `lib/my_app/emails/**`
- all domain-specific assigns, subject lines, and delivery orchestration

## Quick Start

1. Add the dependency.
2. Define a host mailer.
3. Run the installer.
4. Install Maizzle JavaScript dependencies.
5. Generate your first email module and template.
6. Start Phoenix and the Maizzle dev server.
7. Build the production HTML output.

Define a host mailer:

```elixir
defmodule MyApp.Mailer do
  use Maizzlex.Mailer, otp_app: :my_app, template_root: "emails"
end
```

The installer will seed config entries in `config/config.exs`, `config/dev.exs`,
`config/test.exs`, `config/prod.exs`, and `config/runtime.exs`.

Minimal host config:

```elixir
config :my_app, MyApp.Mailer,
  from: {"My App", "noreply@example.com"}

config :my_app, :maizzlex,
  maizzle_dir: "maizzle",
  build_command: {"npm", ["run", "build"]}

config :swoosh, :api_client, false
```

Install host-side scaffolding:

```bash
mix igniter.install maizzlex
```

Generated config defaults after install:

- `config/config.exs`
  `config :my_app, MyApp.Mailer, from: {"My App", "noreply@example.com"}`
  `config :my_app, :maizzlex, maizzle_dir: "maizzle", build_command: {"npm", ["run", "build"]}`
  `config :swoosh, :api_client, false`
- `config/dev.exs`
  `config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Local`
- `config/test.exs`
  `config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Test`
- `config/prod.exs`
  `config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Local`
  `config :swoosh, :api_client, Swoosh.ApiClient.Req`
- `config/runtime.exs`
  `config :my_app, MyApp.Mailer, from: {System.get_env("MAILER_FROM_NAME") || "My App", System.get_env("MAILER_FROM_EMAIL") || "noreply@example.com"}`

The `prod.exs` and `runtime.exs` values are placeholders meant to keep a fresh host app bootable.
Replace the production adapter and credentials before deploying.

Then continue with the workflow:

```bash
cd maizzle && npm install
mix igniter maizzlex.gen.email welcome_message

# terminal 1
mix phx.server

# terminal 2
mix maizzlex.emails.dev

# optional production build
mix maizzlex.emails.build
```

Generated email modules keep the existing host-side API:

```elixir
def call(receiver, assigns, attachments \\ []) do
  html_body = MyApp.Mailer.render_template("welcome_message.html", assigns)

  MyApp.Mailer.transactional_email()
  |> to(receiver)
  |> subject(gettext("Emails.WelcomeMessageEmail.Subject"))
  |> html_body(html_body)
  |> MyApp.Mailer.send_email(attachments)
end
```

## Documentation

- [Installation and Host Setup](docs/installation.md)
- [Mailer Configuration Reference](docs/configuration.md)
- [Theming and Palette Generation](docs/theming.md)
- [Custom Attachment and Email Store Adapters](docs/custom_adapters.md)
- [Generators and Build Workflow](docs/workflow.md)

## Key Concepts

### Runtime config lives on the host mailer

`Maizzlex.Mailer` reads runtime settings from:

```elixir
Application.get_env(:my_app, MyApp.Mailer, [])
```

That config controls sender identity, adapter selection, headers, HTML-to-text conversion,
and optional Maizzlex-specific adapters.

### Mailer config reference

`config :my_app, MyApp.Mailer, ...` supports:

- Required: `adapter`
  This is the Swoosh adapter used for delivery. In practice it is usually environment-specific, for example `Swoosh.Adapters.Local` in `dev.exs`, `Swoosh.Adapters.Test` in `test.exs`, and a real delivery adapter in production.
- Required: `from`
  Sender identity used by `base_email/0` and `transactional_email/0`.
- Optional: adapter-specific Swoosh keys
  Any adapter-specific options such as `api_key`, `domain`, `relay`, `username`, `password`, `region`, or `base_url` are passed through unchanged to Swoosh.
- Optional: `anti_spam_headers`
  Additional or overriding headers for `base_email/0`.
- Optional: `transactional_headers`
  Additional or overriding headers for `transactional_email/0`.
- Optional: `list_unsubscribe_email`
  Adds a `mailto:` entry to `List-Unsubscribe`.
- Optional: `list_unsubscribe_url`
  Adds an HTTPS entry to `List-Unsubscribe` and enables one-click unsubscribe header support.
- Optional: `html2text_opts`
  Options forwarded to `HTML2Text.convert/2`.
- Optional unless you pass attachments to `send_email/2`: `attachment_adapter`
  Adds external attachments before delivery.
- Optional: `email_store`
  Persists a copy of successfully sent emails after delivery.

Full example:

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

`api_client` is a separate Swoosh config, not a `MyApp.Mailer` key:

```elixir
config :swoosh, :api_client, Swoosh.ApiClient.Req
```

Use `false` for adapters that do not perform HTTP requests, such as `Local` and `Test`:

```elixir
config :swoosh, :api_client, false
```

### Maizzle build and dev config is app-level

`mix maizzlex.emails.build` and `mix maizzlex.emails.dev` read app-level settings from:

```elixir
config :my_app, :maizzlex,
  maizzle_dir: "maizzle",
  build_command: {"npm", ["run", "build"]},
  dev_command: {"npm", ["run", "dev"]}
```

### Attachments are explicit

If you call `send_email(email, attachments)` with a non-empty list, `Maizzlex` expects an `attachment_adapter` to be configured. If no adapter is configured, the send fails with `{:error, :missing_attachment_adapter}`.

### Email storage is best effort

`email_store` is optional. If configured, it runs after successful delivery. Store failures are logged and do not fail the send.
