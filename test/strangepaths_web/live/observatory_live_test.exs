defmodule StrangepathsWeb.ObservatoryLiveTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the observatory shell for anonymous visitors", %{conn: conn} do
    {:ok, view, html} = live(conn, "/observatory")

    assert has_element?(view, "#observatory[phx-hook=Observatory]")
    assert html =~ "/images/observatory/sky-catalogue.json"
    assert html =~ "/images/observatory/nebula-atlas.png"
    assert html =~ "/images/observatory/star-atlas.png"
    assert has_element?(view, "button[data-zenith]", "Zenith")
    assert has_element?(view, "input[data-veil][min='0'][max='4'][value='4']")
  end

  test "observatory assets are served", %{conn: conn} do
    for path <- ~w(sky-catalogue.json nebula-atlas.png star-atlas.png) do
      assert conn |> get("/images/observatory/#{path}") |> response(200)
    end
  end
end
