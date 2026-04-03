# Generators and Build Workflow

## Recommended workflow

1. scaffold host files with `mix igniter.install maizzlex`
2. install JS dependencies in `maizzle/`
3. run `mix maizzlex.emails.dev`
4. preview directly through the Maizzle dev server at `http://127.0.0.1:3000`
5. generate email templates/modules with `mix igniter maizzlex.gen.email ...`
6. edit `maizzle/emails/*.html`
7. run `mix maizzlex.emails.build`
8. run `mix gettext.extract --merge`
9. send through `MyApp.Mailer`

## Build task

`mix maizzlex.emails.build` delegates to `Maizzlex.Builder.build/2`.

By default it runs:

```elixir
{"npm", ["run", "build"]}
```

inside:

```text
maizzle
```

The task expects the host build to write compiled templates into:

```text
priv/emails
```

That output directory should contain only built email templates.
Source-only folders such as `layouts`, `components`, and `images` stay in `maizzle/`.

## Why compiled templates stay as EEx

The generated Maizzle config is intentionally set up so that:

- Tailwind/Maizzle transforms the HTML
- EEx/Gettext fragments are preserved
- the host app can still use `EEx.eval_file/2`
- `mix gettext.extract --merge` can still find strings in compiled `priv/emails`

That is why the host app renders email HTML from `priv/emails` instead of rendering directly from the source `maizzle/emails`.

## Email generator

`mix igniter maizzlex.gen.email welcome_message` creates:

- `maizzle/emails/welcome_message.html`
- `lib/my_app/emails/welcome_message_email.ex`

The generated module:

- imports the chosen Gettext module
- uses `MyApp.Mailer.render_template/2`
- calls `MyApp.Mailer.transactional_email/0`
- preserves the `call(receiver, assigns, attachments \\ [])` contract

## Installer and generator options

### `--gettext-module`

Available for both install and email generation:

```bash
mix igniter.install maizzlex --gettext-module MyApp.I18n
mix igniter maizzlex.gen.email welcome_message --gettext-module MyApp.I18n
```

Use it when your app does not follow the default `MyAppWeb.Gettext` naming.
