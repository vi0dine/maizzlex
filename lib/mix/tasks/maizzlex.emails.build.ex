defmodule Mix.Tasks.Maizzlex.Emails.Build do
  use Mix.Task

  @shortdoc "Build Maizzle templates into Phoenix priv/emails"

  @moduledoc """
  Runs application's configured Maizzle build command.

  Configuration is read from:

      config :your_app, :maizzlex,
        maizzle_dir: "maizzle",
        build_command: {"npm", ["run", "build"]}

  For tests or custom integrations you can also use:

      config :your_app, :maizzlex,
        build_command: {:mfa, {MyBuilder, :run, []}}
  """

  @impl Mix.Task
  def run(_args) do
    app = Mix.Project.config()[:app]

    case Maizzlex.Builder.build(app) do
      :ok ->
        Mix.shell().info("Maizzlex build completed")

      {:error, {:missing_directory, path}} ->
        Mix.raise("Expected Maizzle directory at #{path}")

      {:error, {:command_failed, executable, status, output}} ->
        Mix.raise("""
        Maizzle build failed.
        Command: #{executable}
        Exit status: #{status}

        #{output}
        """)

      {:error, reason} ->
        Mix.raise("Maizzle build failed: #{inspect(reason)}")
    end
  end
end
