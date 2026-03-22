defmodule Strangepaths.Repo.Migrations.NormalizeConnectionColors do
  use Ecto.Migration

  import Ecto.Query

  @palette [
    {"#ef4444", {239, 68, 68}},
    {"#3b82f6", {59, 130, 246}},
    {"#43e106", {67, 225, 6}},
    {"#ceb900", {206, 185, 0}},
    {"#ffe6ff", {255, 230, 255}},
    {"#a855f7", {168, 85, 247}}
  ]

  def up do
    connections =
      Strangepaths.Repo.all(
        from c in Strangepaths.Rumor.Connection,
          where: not is_nil(c.line_style)
      )

    for conn <- connections do
      color = get_in(conn.line_style, ["color"])

      if is_binary(color) do
        normalized = nearest_palette_color(color)

        if normalized != color do
          new_style = Map.put(conn.line_style, "color", normalized)

          conn
          |> Ecto.Changeset.change(line_style: new_style)
          |> Strangepaths.Repo.update!()
        end
      end
    end
  end

  def down do
    :ok
  end

  defp nearest_palette_color(hex) do
    case parse_hex(hex) do
      nil ->
        hex

      rgb ->
        {best_hex, _} =
          Enum.min_by(@palette, fn {_, palette_rgb} ->
            color_distance(rgb, palette_rgb)
          end)

        best_hex
    end
  end

  # Accept 6-digit (#rrggbb) or 8-digit (#rrggbbaa) hex
  defp parse_hex("#" <> rest) when byte_size(rest) >= 6 do
    with {r, ""} <- Integer.parse(String.slice(rest, 0, 2), 16),
         {g, ""} <- Integer.parse(String.slice(rest, 2, 2), 16),
         {b, ""} <- Integer.parse(String.slice(rest, 4, 2), 16) do
      {r, g, b}
    else
      _ -> nil
    end
  end

  defp parse_hex(_), do: nil

  defp color_distance({r1, g1, b1}, {r2, g2, b2}) do
    (r1 - r2) * (r1 - r2) + (g1 - g2) * (g1 - g2) + (b1 - b2) * (b1 - b2)
  end
end
