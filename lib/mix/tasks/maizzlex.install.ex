defmodule Mix.Tasks.Maizzlex.Install do
  use Igniter.Mix.Task

  @shortdoc "Install Maizzlex scaffolding into a Phoenix application"
  @dev_preview_route ~S|forward("/maizzle", Maizzlex.DevServerPlug)|

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

    app = Mix.Project.config()[:app] |> to_string()
    app_module = Macro.camelize(app)
    gettext_module = Keyword.get(opts, :gettext_module, "#{app_module}Web.Gettext")

    igniter
    |> Igniter.mkdir("maizzle")
    |> Igniter.mkdir("maizzle/css")
    |> Igniter.mkdir("maizzle/emails")
    |> Igniter.mkdir("maizzle/layouts")
    |> Igniter.mkdir("maizzle/components")
    |> Igniter.mkdir("maizzle/utils")
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
    |> create_scaffold_file("maizzle/css/tailwind.css", "maizzle/css/tailwind.css.eex", [])
    |> create_scaffold_file(
      "maizzle/css/generated-theme.css",
      "maizzle/css/generated-theme.css.eex",
      []
    )
    |> create_scaffold_file("maizzle/layouts/main.html", "maizzle/layouts/main.html.eex",
      gettext_module: gettext_module
    )
    |> create_scaffold_file(
      "maizzle/components/button.html",
      "maizzle/components/button.html.eex",
      []
    )
    |> create_scaffold_file("maizzle/utils/palette.js", "maizzle/utils/palette.js.eex", [])
    |> create_scaffold_file(
      "maizzle/utils/write-theme.js",
      "maizzle/utils/write-theme.js.eex",
      []
    )
    |> ensure_dev_preview_route()
    |> Igniter.add_notice("""
    Maizzlex scaffolding created. Next steps:

      1. `cd maizzle && npm install`
      2. `cd maizzle && npm run dev`
      3. Open your host app at `/dev/maizzle`
      4. Configure your host mailer to `use Maizzlex.Mailer`
      5. Run `mix maizzlex.emails.build`
    """)
  end

  defp create_scaffold_file(igniter, destination, template, assigns) do
    Igniter.create_new_file(
      igniter,
      destination,
      Maizzlex.Template.render!(template, assigns),
      on_exists: :skip
    )
  end

  defp ensure_dev_preview_route(igniter) do
    {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)

    if router do
      router_path = Igniter.Project.Module.proper_location(igniter, router)
      igniter = Igniter.include_existing_file(igniter, router_path)

      content =
        igniter.rewrite
        |> Rewrite.source!(router_path)
        |> Rewrite.Source.get(:content)

      if String.contains?(content, @dev_preview_route) do
        igniter
      else
        Igniter.Libs.Phoenix.append_to_scope(
          igniter,
          "/dev",
          @dev_preview_route,
          router: router,
          placement: :after
        )
      end
    else
      Igniter.add_warning(
        igniter,
        """
        Could not find a Phoenix router to add the Maizzlex dev preview route.
        Add this manually:

            scope "/dev" do
              forward("/maizzle", Maizzlex.DevServerPlug)
            end
        """
      )
    end
  end
end
