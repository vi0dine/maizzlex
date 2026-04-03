defmodule Mix.Tasks.Maizzlex.Install do
  use Igniter.Mix.Task

  alias Igniter.Project.Config, as: ProjectConfig

  @shortdoc "Install Maizzlex scaffolding into a Phoenix application"

  @impl Igniter.Mix.Task
  def info(_argv, _parent) do
    %Igniter.Mix.Task.Info{
      aliases: [g: :gettext_module],
      example: "mix igniter.install maizzlex",
      schema: [gettext_module: :string]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {opts, _positional, _invalid} =
      OptionParser.parse(igniter.args.argv,
        strict: [gettext_module: :string],
        aliases: [g: :gettext_module]
      )

    app = Igniter.Project.Application.app_name(igniter)
    app_name = to_string(app)
    app_module = Macro.camelize(app_name)
    mailer_module = Module.concat([app_module, "Mailer"])
    gettext_module = Keyword.get(opts, :gettext_module, "#{app_module}.Gettext")

    igniter
    |> Igniter.mkdir("maizzle")
    |> Igniter.mkdir("maizzle/css")
    |> Igniter.mkdir("maizzle/emails")
    |> Igniter.mkdir("maizzle/images")
    |> Igniter.mkdir("maizzle/layouts")
    |> Igniter.mkdir("maizzle/components")
    |> Igniter.mkdir("maizzle/utils")
    |> Igniter.create_new_file("maizzle/images/.gitkeep", "", on_exists: :skip)
    |> create_scaffold_file("maizzle/README.md", "maizzle/README.md.eex", app_module: app_module)
    |> create_scaffold_file("maizzle/package.json", "maizzle/package.json.eex", [])
    |> create_scaffold_file("maizzle/config.js", "maizzle/config.js.eex",
      gettext_module: gettext_module
    )
    |> create_scaffold_file(
      "maizzle/config.production.js",
      "maizzle/config.production.js.eex",
      []
    )
    |> create_scaffold_file(
      "maizzle/tailwind.config.js",
      "maizzle/tailwind.config.js.eex",
      []
    )
    |> create_scaffold_file("maizzle/css/tailwind.css", "maizzle/css/tailwind.css.eex", [])
    |> create_scaffold_file("maizzle/layouts/main.html", "maizzle/layouts/main.html.eex", [])
    |> create_scaffold_file(
      "maizzle/components/button.html",
      "maizzle/components/button.html.eex",
      []
    )
    |> create_scaffold_file("maizzle/utils/palette.js", "maizzle/utils/palette.js.eex", [])
    |> ensure_gitignore_entry("/maizzle/node_modules/")
    |> configure_host_configs(app, mailer_module)
    |> Igniter.add_notice("""
    Maizzlex scaffolding created. Next steps:

      1. Define `#{inspect(mailer_module)}` with `use Maizzlex.Mailer, otp_app: :#{app}, template_root: "emails"`
      2. Review the generated config in `config/config.exs`, `config/dev.exs`, `config/test.exs`, `config/prod.exs`, and `config/runtime.exs`
      3. `cd maizzle && npm install` (Node.js 18.20+)
      4. `mix igniter maizzlex.gen.email welcome_message`
      5. Start your Phoenix app
      6. `mix maizzlex.emails.dev`
      7. Open the Maizzle dev server directly at `http://127.0.0.1:3000`
      8. Replace the production mailer placeholder config before deploying
      9. Run `mix maizzlex.emails.build`
    """)
  end

  defp configure_host_configs(igniter, app, mailer_module) do
    igniter
    |> ProjectConfig.configure_new(
      "config.exs",
      app,
      [mailer_module, :from],
      {"My App", "noreply@example.com"}
    )
    |> ProjectConfig.configure_new(
      "config.exs",
      app,
      [:maizzlex, :maizzle_dir],
      "maizzle"
    )
    |> ProjectConfig.configure_new(
      "config.exs",
      app,
      [:maizzlex, :build_command],
      {"npm", ["run", "build"]}
    )
    |> ProjectConfig.configure_new("config.exs", :swoosh, [:api_client], false)
    |> ProjectConfig.configure_new(
      "dev.exs",
      app,
      [mailer_module, :adapter],
      code!("Swoosh.Adapters.Local")
    )
    |> ProjectConfig.configure_new(
      "test.exs",
      app,
      [mailer_module, :adapter],
      code!("Swoosh.Adapters.Test")
    )
    |> ProjectConfig.configure_new(
      "prod.exs",
      app,
      [mailer_module, :adapter],
      code!("Swoosh.Adapters.Local")
    )
    |> ProjectConfig.configure_new(
      "prod.exs",
      :swoosh,
      [:api_client],
      code!("Swoosh.ApiClient.Req")
    )
    |> ProjectConfig.configure_runtime_env(
      :prod,
      app,
      [mailer_module, :from],
      code!(
        ~s[{System.get_env("MAILER_FROM_NAME") || "My App", System.get_env("MAILER_FROM_EMAIL") || "noreply@example.com"}]
      )
    )
  end

  defp create_scaffold_file(igniter, destination, template, assigns) do
    Igniter.create_new_file(
      igniter,
      destination,
      Maizzlex.Template.render!(template, assigns),
      on_exists: :skip
    )
  end

  defp ensure_gitignore_entry(igniter, entry) do
    igniter
    |> Igniter.include_or_create_file(".gitignore", "#{entry}\n")
    |> Igniter.update_file(".gitignore", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, entry) do
        source
      else
        separator = if String.ends_with?(content, "\n") or content == "", do: "", else: "\n"
        Rewrite.Source.update(source, :content, content <> separator <> "#{entry}\n")
      end
    end)
  end

  defp code!(string) do
    {:code, Sourceror.parse_string!(string)}
  end
end
