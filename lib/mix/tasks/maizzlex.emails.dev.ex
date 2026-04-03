defmodule Mix.Tasks.Maizzlex.Emails.Dev do
  use Mix.Task

  @shortdoc "Run the Maizzle development server from the host app"

  @moduledoc """
  Runs the application's configured Maizzle dev command.

  Configuration is read from:

      config :your_app, :maizzlex,
        maizzle_dir: "maizzle",
        dev_command: {"npm", ["run", "dev"]}
  """

  @impl Mix.Task
  def run(_args) do
    app = Mix.Project.config()[:app]

    case Maizzlex.Builder.dev(app) do
      :ok ->
        :ok

      {:error, {:missing_directory, path}} ->
        Mix.raise("Expected Maizzle directory at #{path}")

      {:error, {:command_failed, executable, status, output}} ->
        Mix.raise("""
        Maizzle dev server failed.
        Command: #{executable}
        Exit status: #{status}

        #{output}
        """)

      {:error, reason} ->
        Mix.raise("Maizzle dev server failed: #{inspect(reason)}")
    end
  end
end
