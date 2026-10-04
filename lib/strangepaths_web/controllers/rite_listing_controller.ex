defmodule StrangepathsWeb.RiteListingController do
  @moduledoc """
  Plain reference listing of every player-visible Tellurian/Sidereal Rite
  (name, gnosis, aspect, origin, flavor text). Rules text is intentionally omitted.

  `GET /cosmos/rites` renders a standalone HTML table; `?format=csv` downloads CSV.
  """
  use StrangepathsWeb, :controller

  alias Strangepaths.Cards

  @columns [
    {"Name", :name},
    {"Gnosis", :gnosis},
    {"Aspect", :aspect},
    {"Tellurian/Sidereal", :origin},
    {"Flavor Text", :flavortext}
  ]

  def index(conn, %{"format" => "csv"}) do
    rows = Cards.list_visible_rites_for_reference()

    csv =
      [Enum.map(@columns, &elem(&1, 0)) | Enum.map(rows, &row_values/1)]
      |> Enum.map_join("\r\n", fn cells -> Enum.map_join(cells, ",", &csv_cell/1) end)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="rites.csv"))
    |> send_resp(200, csv)
  end

  def index(conn, _params) do
    rows = Cards.list_visible_rites_for_reference()

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, render_html(rows))
  end

  defp row_values(row), do: Enum.map(@columns, fn {_, key} -> Map.get(row, key) || "" end)

  defp csv_cell(value) do
    value = to_string(value)

    if String.contains?(value, [",", "\"", "\n", "\r"]),
      do: ~s(") <> String.replace(value, ~s("), ~s("")) <> ~s("),
      else: value
  end

  defp esc(value), do: value |> Kernel.||("") |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp render_html(rows) do
    header = Enum.map_join(@columns, "", fn {label, _} -> "<th>#{esc(label)}</th>" end)

    body =
      Enum.map_join(rows, "\n", fn row ->
        cells = row |> row_values() |> Enum.map_join("", &"<td>#{esc(&1)}</td>")
        "<tr>#{cells}</tr>"
      end)

    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Rites of the Cosmos</title>
    <style>
      body { font-family: Georgia, serif; margin: 1.5rem; color: #1a1a2e; background: #fff; }
      h1 { font-size: 1.4rem; margin-bottom: 0.25rem; }
      p.meta { color: #555; margin-top: 0; font-size: 0.9rem; }
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid #ccc; padding: 0.4rem 0.6rem; text-align: left; vertical-align: top; }
      th { background: #eee; position: sticky; top: 0; }
      td:last-child { font-style: italic; white-space: pre-line; }
      tr:nth-child(even) td { background: #fafafa; }
    </style>
    </head>
    <body>
    <h1>Rites of the Cosmos</h1>
    <p class="meta">#{length(rows)} visible rites &middot; <a href="?format=csv">Download CSV</a></p>
    <table>
    <thead><tr>#{header}</tr></thead>
    <tbody>
    #{body}
    </tbody>
    </table>
    </body>
    </html>
    """
  end
end
