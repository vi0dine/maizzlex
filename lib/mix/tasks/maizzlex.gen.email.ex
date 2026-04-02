defmodule Mix.Tasks.Maizzlex.Gen.Email do
  use Igniter.Mix.Task

  @shortdoc "Generate a Maizzlex email template and Phoenix email module"

  @impl Igniter.Mix.Task
  def info(_argv, _parent) do
    %Igniter.Mix.Task.Info{
      aliases: [g: :gettext_module],
      example: "mix igniter maizzlex.gen.email welcome_message",
      positional: [:name],
      schema: [gettext_module: :string]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {opts, positional, _invalid} =
      OptionParser.parse(igniter.args.argv,
        strict: [gettext_module: :string],
        aliases: [g: :gettext_module]
      )

    case positional do
      [name | _] ->
        app = Mix.Project.config()[:app] |> to_string()
        app_module = Macro.camelize(app)
        gettext_module = Keyword.get(opts, :gettext_module, "#{app_module}Web.Gettext")
        snake_name = Macro.underscore(name)
        template_scope = Macro.camelize(snake_name)
        module_base = "#{template_scope}Email"

        igniter
        |> Igniter.mkdir("maizzle/emails")
        |> Igniter.mkdir("lib/#{app}/emails")
        |> Igniter.create_new_file(
          "maizzle/emails/#{snake_name}.html",
          Maizzlex.Template.render!("email_template.html.eex",
            gettext_scope: template_scope
          ),
          on_exists: :warning
        )
        |> Igniter.create_new_file(
          "lib/#{app}/emails/#{snake_name}_email.ex",
          Maizzlex.Template.render!("email_module.ex.eex",
            app_module: app_module,
            gettext_module: gettext_module,
            module_base: module_base,
            snake_name: snake_name
          ),
          on_exists: :warning
        )
        |> Igniter.add_notice("Generated #{module_base} and maizzle/emails/#{snake_name}.html")

      _ ->
        Igniter.add_issue(
          igniter,
          "Expected an email name, for example: mix igniter maizzlex.gen.email welcome_message"
        )
    end
  end
end
