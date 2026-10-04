defmodule StrangepathsWeb.RiteListingControllerTest do
  use StrangepathsWeb.ConnCase

  alias Strangepaths.Repo
  alias Strangepaths.Cards.{Aspect, Card}

  defp aspect_id(name), do: Repo.get_by!(Aspect, name: name).id

  defp insert_card(attrs) do
    Repo.insert!(struct(Card, Map.merge(%{type: :Rite, glorified: false, unlocked: true}, attrs)))
  end

  setup do
    insert_card(%{name: "Bash", aspect_id: aspect_id("Fang"), rules: "SECRET RULES", flavortext: "Hit it, <hard>."})
    insert_card(%{name: "Bash Glory", aspect_id: aspect_id("Fang"), glorified: true, flavortext: "x"})
    insert_card(%{name: "Beatdown", aspect_id: aspect_id("Red"), flavortext: "Burn, \"baby\""})
    insert_card(%{name: "Hidden Rite", aspect_id: aspect_id("Blue"), unlocked: false})
    insert_card(%{name: "Some Grace", aspect_id: aspect_id("Fang"), type: :Grace})
    insert_card(%{name: "Secret Truth", aspect_id: aspect_id("Alethic")})
    :ok
  end

  test "HTML listing shows visible tellurian and sidereal rites without rules", %{conn: conn} do
    html = conn |> get("/cosmos/rites") |> html_response(200)

    assert html =~ "<td>Bash</td><td></td><td>Fang</td><td>Tellurian</td><td>Hit it, &lt;hard&gt;.</td>"
    assert html =~ "<td>Beatdown</td><td>Burning</td><td>Red</td><td>Sidereal</td>"
    refute html =~ "SECRET RULES"
    refute html =~ "Bash Glory"
    refute html =~ "Hidden Rite"
    refute html =~ "Some Grace"
    refute html =~ "Secret Truth"
  end

  test "CSV listing quotes fields and has a header row", %{conn: conn} do
    conn = get(conn, "/cosmos/rites?format=csv")
    assert response_content_type(conn, :csv)

    [header | rows] = conn |> response(200) |> String.split("\r\n")
    assert header == "Name,Gnosis,Aspect,Tellurian/Sidereal,Flavor Text"
    assert rows == ["Bash,,Fang,Tellurian,\"Hit it, <hard>.\"", "Beatdown,Burning,Red,Sidereal,\"Burn, \"\"baby\"\"\""]
  end
end
