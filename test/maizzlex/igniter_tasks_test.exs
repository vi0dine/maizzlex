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

    router =
      igniter.rewrite
      |> Rewrite.source!("lib/test_web/router.ex")
      |> Rewrite.Source.get(:content)

    assert router =~ ~S|forward("/maizzle", Maizzlex.DevServerPlug)|
  end

  test "generator task proposes email module and template" do
    igniter =
      Igniter.new()
      |> Map.put(:args, %Igniter.Mix.Task.Args{argv: ["welcome_message"]})
      |> Mix.Tasks.Maizzlex.Gen.Email.igniter()

    assert Igniter.changed?(igniter, "maizzle/emails/welcome_message.html")
    assert Igniter.changed?(igniter, "lib/maizzlex/emails/welcome_message_email.ex")
  end

  test "install task keeps the dev preview route idempotent" do
    igniter =
      phx_test_project()
      |> Map.put(:args, %Igniter.Mix.Task.Args{argv: []})
      |> Mix.Tasks.Maizzlex.Install.igniter()
      |> apply_igniter!()
      |> Map.put(:args, %Igniter.Mix.Task.Args{argv: []})
      |> Mix.Tasks.Maizzlex.Install.igniter()

    router =
      igniter.rewrite
      |> Rewrite.source!("lib/test_web/router.ex")
      |> Rewrite.Source.get(:content)

    assert route_occurrences(router) == 1
  end

  defp route_occurrences(router_content) do
    router_content
    |> String.split(~S|forward("/maizzle", Maizzlex.DevServerPlug)|)
    |> length()
    |> Kernel.-(1)
  end
end
