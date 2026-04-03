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

## Minimal host config

At minimum, configure a sender and the Maizzlex build settings:

```elixir
config :my_app, MyApp.Mailer,
  from: {"My App", "noreply@example.com"}

config :my_app, :maizzlex,
  maizzle_dir: "maizzle",
  build_command: {"npm", ["run", "build"]}

config :swoosh, :api_client, false
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
- `maizzle/tailwind.config.js`
- `maizzle/css/tailwind.css`
- `maizzle/images/.gitkeep`
- `maizzle/layouts/main.html`
- `maizzle/components/button.html`
- `maizzle/utils/palette.js`
- `maizzle/package.json`

It also seeds config entries in:

- `config/config.exs`
- `config/dev.exs`
- `config/test.exs`
- `config/prod.exs`
- `config/runtime.exs`

If your app uses a different Gettext backend than `MyAppWeb.Gettext`, pass it explicitly:

```bash
mix igniter.install maizzlex --gettext-module MyApp.I18n
```

## Install JavaScript dependencies

The scaffolded `maizzle/package.json` is owned by the host app. Install its dependencies from the host project:

```bash
cd maizzle && npm install
```

Use Node.js `18.20` or newer. Maizzle 5 will warn or fail on older runtimes.

## Run the Maizzle dev server

Start the scaffolded Maizzle server:

```bash
mix maizzlex.emails.dev
```

Then open the Maizzle preview directly at:

```text
http://127.0.0.1:3000
```

## Generate an email module and template

Generate the first template only after the installer has created the host-side tree:

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

## Recommended order

```bash
mix deps.get
mix igniter.install maizzlex
cd maizzle && npm install
mix igniter maizzlex.gen.email welcome_message

# terminal 1
mix phx.server

# terminal 2
mix maizzlex.emails.dev

# optional production build
mix maizzlex.emails.build
```

The generated `prod.exs` and `runtime.exs` entries are placeholders. Replace the production
adapter and credentials before deploying.
