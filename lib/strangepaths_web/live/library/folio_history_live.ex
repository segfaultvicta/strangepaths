defmodule StrangepathsWeb.LibraryLive.FolioHistory do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Library

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    socket = assign_defaults(session, socket)
    user = socket.assigns.current_user

    case Library.get_folio_by_slug(slug) do
      nil ->
        {:ok, socket |> put_flash(:error, "Folio not found.") |> push_redirect(to: "/library")}

      folio ->
        is_dragon = user != nil && user.role == :dragon
        is_author = user != nil && folio.user_id == user.id

        if folio.is_private && !is_dragon && !is_author do
          {:ok,
           socket
           |> put_flash(:error, "This folio is private.")
           |> push_redirect(to: "/library")}
        else
          events = build_timeline(folio.id)

          {:ok,
           socket
           |> assign(:page_title, "Edit History: #{folio.title}")
           |> assign(:folio, folio)
           |> assign(:events, events)}
        end
    end
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  defp build_timeline(folio_id) do
    edits =
      Library.list_folio_edits(folio_id)
      |> Enum.map(fn e -> Map.put(e, :event_type, :edit) end)

    marginalia =
      Library.list_all_marginalia_for_folio(folio_id)
      |> Enum.map(fn m ->
        %{
          event_type: :marginalia,
          inserted_at: m.inserted_at,
          editor_nickname: m.name,
          summary: m.content
        }
      end)

    (edits ++ marginalia)
    |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
  end
end
