# Installation and Host Setup

## Dependency

Add `maizzlex` to your host application's dependencies:

```elixir
defp deps do
  [
    {:maizzlex, path: "../maizzlex"}
  ]
end
```

Replace `path:` with your Git or Hex dependency once the package is published.

## Define a host mailer

Create a host mailer that uses `Maizzlex.Mailer`:

```elixir
defmodule MyApp.Mailer do
  use Maizzlex.Mailer, otp_app: :my_app, template_root: "emails"
end
```

`template_root` is resolved inside the host app's `priv` directory, so `"emails"` means:

```text
priv/emails
```

## Minimal runtime config

At minimum, configure a Swoosh adapter and a sender:

```elixir
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Test,
  from: {"My App", "noreply@example.com"}
```

`from` can be either:

```elixir
from: {"My App", "noreply@example.com"}
```

or:

```elixir
from: "noreply@example.com"
```

## Install Maizzle scaffolding

Use Igniter to create the host-side Maizzle tree:

```bash
mix igniter.install maizzlex
```

This creates:

- `maizzle/config.js`
- `maizzle/config.production.js`
- `maizzle/css/tailwind.css`
- `maizzle/css/generated-theme.css`
- `maizzle/layouts/main.html`
- `maizzle/components/button.html`
- `maizzle/utils/palette.js`
- `maizzle/utils/write-theme.js`
- `maizzle/package.json`

When a Phoenix router is found, the installer also appends:

```elixir
scope "/dev" do
  forward("/maizzle", Maizzlex.DevServerPlug)
end
```

That gives the host app a stable preview entrypoint at `/dev/maizzle`.
Requests stay on the host app origin and are proxied to the Maizzle dev server upstream.

If your app uses a different Gettext backend than `MyAppWeb.Gettext`, pass it explicitly:

```bash
mix igniter.install maizzlex --gettext-module MyApp.I18n
```

## Install JavaScript dependencies

The scaffolded `maizzle/package.json` is owned by the host app. Install its dependencies from the host project:

```bash
cd maizzle && npm install
```

## Run the Maizzle dev server

Start the scaffolded Maizzle server:

```bash
cd maizzle && npm run dev
```

Then open the host app preview at:

```text
/dev/maizzle
```

## Generate an email module and template

```bash
mix igniter maizzlex.gen.email welcome_message
```

This creates:

- `maizzle/emails/welcome_message.html`
- `lib/my_app/emails/welcome_message_email.ex`

You can also override the imported Gettext module:

```bash
mix igniter maizzlex.gen.email welcome_message --gettext-module MyApp.I18n
```
