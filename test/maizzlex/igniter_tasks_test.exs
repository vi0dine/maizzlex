defmodule Maizzlex.IgniterTasksTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  test "install task proposes maizzle scaffolding" do
    igniter =
      phx_test_project()
      |> Map.put(:args, %Igniter.Mix.Task.Args{argv: []})
      |> Mix.Tasks.Maizzlex.Install.igniter()

    assert Igniter.changed?(igniter, "maizzle/package.json")
    assert Igniter.changed?(igniter, "maizzle/config.js")
    assert Igniter.changed?(igniter, "maizzle/utils/palette.js")
    assert Igniter.changed?(igniter, "maizzle/images/.gitkeep")

    config_exs =
      igniter.rewrite
      |> Rewrite.source!("config/config.exs")
      |> Rewrite.Source.get(:content)

    dev_exs =
      igniter.rewrite
      |> Rewrite.source!("config/dev.exs")
      |> Rewrite.Source.get(:content)

    test_exs =
      igniter.rewrite
      |> Rewrite.source!("config/test.exs")
      |> Rewrite.Source.get(:content)

    prod_exs =
      igniter.rewrite
      |> Rewrite.source!("config/prod.exs")
      |> Rewrite.Source.get(:content)

    runtime_exs =
      igniter.rewrite
      |> Rewrite.source!("config/runtime.exs")
      |> Rewrite.Source.get(:content)

    layout_html =
      igniter.rewrite
      |> Rewrite.source!("maizzle/layouts/main.html")
      |> Rewrite.Source.get(:content)

    gitignore =
      igniter.rewrite
      |> Rewrite.source!(".gitignore")
      |> Rewrite.Source.get(:content)

    assert config_exs =~ "config :test, Test.Mailer"
    assert config_exs =~ ~s(from: {"My App", "noreply@example.com"})

    assert config_exs =~
             ~s(maizzlex: [maizzle_dir: "maizzle", build_command: {"npm", ["run", "build"]}])

    assert config_exs =~ ~s(config :swoosh, api_client: false)
    assert dev_exs =~ ~s(config :test, Test.Mailer, adapter: Swoosh.Adapters.Local)
    assert test_exs =~ ~s(config :test, Test.Mailer, adapter: Swoosh.Adapters.Test)
    assert prod_exs =~ ~s(config :test, Test.Mailer, adapter: Swoosh.Adapters.Local)
    assert prod_exs =~ ~s(config :swoosh, api_client: Swoosh.ApiClient.Req)
    assert runtime_exs =~ "if config_env() == :prod do"
    assert runtime_exs =~ ~s|System.get_env("MAILER_FROM_NAME")|
    refute layout_html =~ "Gettext"
    assert gitignore =~ "/maizzle/node_modules/"
  end

  test "generator task proposes email module and template" do
    igniter =
      Igniter.new()
      |> Map.put(:args, %Igniter.Mix.Task.Args{argv: ["welcome_message"]})
      |> Mix.Tasks.Maizzlex.Gen.Email.igniter()

    assert Igniter.changed?(igniter, "maizzle/emails/welcome_message.html")
    assert Igniter.changed?(igniter, "lib/maizzlex/emails/welcome_message_email.ex")

    email_module =
      igniter.rewrite
      |> Rewrite.source!("lib/maizzlex/emails/welcome_message_email.ex")
      |> Rewrite.Source.get(:content)

    assert email_module =~ "use Gettext, backend: Maizzlex.Gettext"
    assert email_module =~ "Maizzlex.Mailer.with_locale(assigns, @gettext_backend"

    assert email_module =~
             "Maizzlex.Mailer.put_gettext_helpers(localized_assigns, @gettext_backend)"
  end
end
