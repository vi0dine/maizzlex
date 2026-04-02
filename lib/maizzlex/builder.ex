defmodule Maizzlex.Builder do
  @moduledoc """
  Host-side Maizzle build runner.
  """

  @default_build_command {"npm", ["run", "build"]}
  @default_maizzle_dir "maizzle"

  def build(otp_app, overrides \\ []) do
    config =
      otp_app
      |> Application.get_env(:maizzlex, [])
      |> Keyword.merge(overrides)

    maizzle_dir =
      config
      |> Keyword.get(:maizzle_dir, @default_maizzle_dir)
      |> Path.expand()

    unless File.dir?(maizzle_dir) do
      {:error, {:missing_directory, maizzle_dir}}
    else
      command = Keyword.get(config, :build_command, @default_build_command)
      run_build_command(command, maizzle_dir, config)
    end
  end

  defp run_build_command({:mfa, {module, function, extra_args}}, maizzle_dir, config)
       when is_atom(module) and is_atom(function) and is_list(extra_args) do
    apply(module, function, [maizzle_dir, config | extra_args])
  end

  defp run_build_command({executable, args}, maizzle_dir, _config)
       when is_binary(executable) and is_list(args) do
    case System.cmd(executable, args, cd: maizzle_dir, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, status} ->
        {:error, {:command_failed, executable, status, output}}
    end
  end

  defp run_build_command(other, _maizzle_dir, _config) do
    {:error, {:invalid_build_command, other}}
  end
end
