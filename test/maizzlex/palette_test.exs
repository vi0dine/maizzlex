defmodule Maizzlex.PaletteTest do
  use ExUnit.Case, async: true

  test "palette helper expands base colors into full semantic scales" do
    tmp_dir =
      Path.join(System.tmp_dir!(), "maizzlex-palette-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    palette_path = Path.join(tmp_dir, "palette.js")

    File.write!(
      palette_path,
      Maizzlex.Template.render!("maizzle/utils/palette.js.eex", [])
    )

    {output, 0} =
      System.cmd("node", [
        "-e",
        """
        const palette = require(#{inspect(palette_path)});
        const result = palette.buildPalette({ primary: "#112233" });
        console.log(JSON.stringify(result.primary));
        """
      ])

    colors = Jason.decode!(String.trim(output))

    assert colors["500"] == "#112233"
    assert Map.has_key?(colors, "50")
    assert Map.has_key?(colors, "950")
  end
end
