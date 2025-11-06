defmodule StrangepathsWeb.CardLive.FormComponent do
  use StrangepathsWeb, :live_component

  alias Strangepaths.Cards

  @impl true
  def update(%{card: card} = assigns, socket) do
    changeset = Cards.change_card(card)

    # Only dragons create cards, so show all aspects without filtering
    aspects_hierarchy = Cards.list_aspects_with_hierarchy()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:aspects_hierarchy, aspects_hierarchy)
     |> allow_upload(:cardart, accept: ~w(.png .jpg .jpeg), max_entries: 1)}
  end

  @impl true
  def handle_event("save", %{"card" => card_params}, socket) do
    save_card(socket, socket.assigns.action, card_params)
  end

  defp save_card(socket, :edit, card_params) do
    # Handle cardart upload if present
    card_params = handle_cardart_upload(socket, card_params)

    case Cards.update_card(socket.assigns.card, card_params) do
      {:ok, _card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Card updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_card(socket, :new, card_params) do
    # Handle cardart upload if present
    card_params = handle_cardart_upload(socket, card_params)

    case Cards.create_card(card_params) do
      {:ok, _card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Card created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp handle_cardart_upload(socket, card_params) do
    cardart_paths = consume_uploaded_entries(socket, :cardart, fn %{path: path}, entry ->
      # Generate unique filename based on card name and timestamp
      filename = "#{card_params["name"]}_#{System.system_time(:second)}#{Path.extname(entry.client_name)}"

      dest = Path.join([
        :code.priv_dir(:strangepaths),
        "static",
        "uploads",
        filename
      ])

      File.cp!(path, dest)
      {:ok, Routes.static_path(socket, "/uploads/#{filename}")}
    end)

    if length(cardart_paths) > 0 do
      Map.put(card_params, "cardart", List.first(cardart_paths))
    else
      card_params
    end
  end

  def friendly_error(:too_large), do: "Image too large"
  def friendly_error(:too_many_files), do: "Too many files"
  def friendly_error(:not_accepted), do: "Unacceptable file type"
end
