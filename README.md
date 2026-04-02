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

Add the dependency and define a host mailer:

```elixir
defmodule MyApp.Mailer do
  use Maizzlex.Mailer, otp_app: :my_app, template_root: "emails"
end
```

Minimal runtime config:

```elixir
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Test,
  from: {"My App", "noreply@example.com"}
```

Install host-side scaffolding:

```bash
mix igniter.install maizzlex
mix igniter maizzlex.gen.email welcome_message
cd maizzle && npm run dev
mix maizzlex.emails.build
```

The installer also wires a host-side preview route at `/dev/maizzle`, which reverse proxies
the Maizzle development server so the browser stays on the same host and port as the Phoenix app.

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

That config controls sender identity, headers, HTML-to-text conversion, and optional adapters.

### Maizzle build config is app-level

`mix maizzlex.emails.build` reads app-level build settings from:

```elixir
config :my_app, :maizzlex,
  maizzle_dir: "maizzle",
  build_command: {"npm", ["run", "build"]}
```

The dev preview proxy reads its upstream URL from:

```elixir
config :maizzlex,
  dev_server_url: "http://127.0.0.1:3000"
```

### Attachments are explicit

If you call `send_email(email, attachments)` with a non-empty list, `Maizzlex` expects an `attachment_adapter` to be configured. If no adapter is configured, the send fails with `{:error, :missing_attachment_adapter}`.

### Email storage is best effort

`email_store` is optional. If configured, it runs after successful delivery. Store failures are logged and do not fail the send.
