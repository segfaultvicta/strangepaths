defmodule StrangepathsWeb.CeremonyLive.FormComponent do
  use StrangepathsWeb, :live_component

  alias Strangepaths.Cards

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:error_msg, nil)}
  end

  @impl true
  def handle_event("validate", %{"ceremony" => _ceremony_params}, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"ceremony" => ceremony_params}, socket) do
    save_ceremony(socket, socket.assigns.action, ceremony_params)
  end

  defp save_ceremony(socket, :new, ceremony_params) do
    case Cards.create_ceremony(ceremony_params, socket.assigns.current_user.id) do
      {:ok, _ceremony} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ceremony created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, msg} ->
        {:noreply, assign(socket, error_msg: msg)}
    end
  end
end
