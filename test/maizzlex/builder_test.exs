defmodule Maizzlex.BuilderTest do
  use ExUnit.Case, async: true

  alias Maizzlex.Builder

  test "supports MFA build commands for host-side builds" do
    tmp_dir =
      Path.join(System.tmp_dir!(), "maizzlex-builder-#{System.unique_integer([:positive])}")

    maizzle_dir = Path.join(tmp_dir, "maizzle")
    output_dir = Path.join(tmp_dir, "priv/emails")

    File.mkdir_p!(maizzle_dir)
    File.mkdir_p!(Path.join(output_dir, "layouts"))
    File.write!(Path.join(output_dir, "layouts/main.html"), "<html>stale</html>\n")

    result =
      Builder.build(:maizzlex,
        maizzle_dir: maizzle_dir,
        build_command: {:mfa, {__MODULE__, :fake_build, [output_dir]}}
      )

    assert result == :ok

    assert File.read!(Path.join(output_dir, "welcome.html")) ==
             "<h1><%= gettext(\"Hello\") %></h1>\n"

    refute File.exists?(Path.join(output_dir, "layouts/main.html"))
  end

  test "supports MFA dev commands for host-side dev server tasks" do
    tmp_dir =
      Path.join(System.tmp_dir!(), "maizzlex-dev-#{System.unique_integer([:positive])}")

    maizzle_dir = Path.join(tmp_dir, "maizzle")
    marker = Path.join(tmp_dir, "dev.txt")

    File.mkdir_p!(maizzle_dir)

    result =
      Builder.dev(:maizzlex,
        maizzle_dir: maizzle_dir,
        dev_command: {:mfa, {__MODULE__, :fake_dev, [marker]}}
      )

    assert result == :ok
    assert File.read!(marker) == "dev started\n"
  end

  def fake_build(_maizzle_dir, _config, output_dir) do
    File.mkdir_p!(output_dir)
    File.write!(Path.join(output_dir, "welcome.html"), "<h1><%= gettext(\"Hello\") %></h1>\n")
    :ok
  end

  def fake_dev(_maizzle_dir, _config, marker) do
    File.write!(marker, "dev started\n")
    :ok
  end
end
