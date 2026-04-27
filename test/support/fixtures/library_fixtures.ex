defmodule Strangepaths.LibraryFixtures do
  alias Strangepaths.Library
  import Strangepaths.AccountsFixtures

  def user_typeface_fixture(user \\ nil, typeface_id \\ "jorule") do
    user = user || user_fixture()
    {:ok, _} = Library.assign_user_typeface(user.id, typeface_id)
    user
  end

  def folio_fixture(user \\ nil, attrs \\ %{}) do
    user = user || user_typeface_fixture()

    merged =
      attrs
      |> Enum.into(%{
        "title" => "Test Folio #{System.unique_integer([:positive])}",
        "subtitle" => nil,
        "body" => nil
      })

    {:ok, folio} = Library.create_folio(user, merged)
    folio
  end

  def post_entry_fixture(folio \\ nil, user \\ nil, scene_post_id \\ nil) do
    folio = folio || folio_fixture()
    user = user || user_typeface_fixture()

    post_id =
      scene_post_id ||
        raise "post_entry_fixture requires a scene_post_id — " <>
                "get one from a scene fixture or create a scene post first"

    {:ok, entry} = Library.create_post_entry(folio, user, post_id)
    entry
  end

  def note_entry_fixture(folio \\ nil, user \\ nil, attrs \\ %{}) do
    folio = folio || folio_fixture()
    user = user || user_typeface_fixture()

    typefaces = Library.folio_editor_typefaces(user.id)
    tf = List.first(typefaces) || raise "user has no typeface — use user_typeface_fixture first"

    merged =
      attrs
      |> Enum.into(%{
        "content" => "A test inline note",
        "name" => tf.name,
        "font" => tf.font,
        "color" => tf.color
      })

    {:ok, entry} = Library.create_note_entry(folio, user, merged)
    entry
  end

  def marginalia_fixture(entry \\ nil, user \\ nil, attrs \\ %{}) do
    folio = folio_fixture()
    entry = entry || note_entry_fixture(folio)
    user = user || user_typeface_fixture()

    typefaces = Library.folio_editor_typefaces(user.id)
    tf = List.first(typefaces) || raise "user has no typeface — use user_typeface_fixture first"

    merged =
      attrs
      |> Enum.into(%{
        "content" => "A test comment",
        "name" => tf.name,
        "font" => tf.font,
        "color" => tf.color
      })

    {:ok, marginalia} = Library.create_marginalia(entry, user, merged)
    marginalia
  end
end
