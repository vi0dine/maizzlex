defmodule Maizzlex.Template do
  @moduledoc false

  def render!(template_path, assigns) do
    template_path
    |> source_path()
    |> EEx.eval_file(assigns)
  end

  def source_path(template_path) do
    :maizzlex
    |> :code.priv_dir()
    |> Path.join("templates/igniter")
    |> Path.join(template_path)
  end
end
