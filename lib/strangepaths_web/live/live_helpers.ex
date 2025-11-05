defmodule StrangepathsWeb.LiveHelpers do
  import Phoenix.LiveView
  import Phoenix.LiveView.Helpers
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  alias Strangepaths.Accounts
  alias Strangepaths.Accounts.User

  def find_current_user(session) do
    user =
      with user_token when not is_nil(user_token) <- session["user_token"],
           %User{} = user <- Accounts.get_user_by_session_token(user_token),
           do: user

    techne =
      case user do
        nil ->
          [{"", ""}]

        user ->
          case user.techne do
            nil ->
              [{"", ""}]

            _ ->
              Enum.map(user.techne, fn techne ->
                case String.split(techne, ":", parts: 2) do
                  [name, desc] -> %{name: String.trim(name), desc: String.trim(desc)}
                  [name] -> %{name: String.trim(name), desc: ""}
                end
              end)
          end
      end

    if user != nil do
      %{user | techne: techne}
    else
      nil
    end
  end

  def assign_defaults(session, socket) do
    user = find_current_user(session)

    role =
      if user != nil do
        user.role
      else
        nil
      end

    socket
    |> assign(:current_user, user)
    |> assign(:role, role)
  end

  @doc """
  Renders a live component inside a modal.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <.modal return_to={Routes.card_index_path(@socket, :index)}>
        <.live_component
          module={StrangepathsWeb.CardLive.FormComponent}
          id={@card.id || :new}
          title={@page_title}
          action={@live_action}
          return_to={Routes.card_index_path(@socket, :index)}
          card: @card
        />
      </.modal>
  """
  def modal(assigns) do
    assigns = assign_new(assigns, :return_to, fn -> nil end)

    ~H"""
    <div id="modal" class="overflow-y-auto fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6" phx-remove={hide_modal()}>
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity" aria-hidden="true"></div>

      <!-- Modal Content -->
      <div
        id="modal-content"
        class="relative bg-white dark:bg-gray-800 rounded-xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto transition-all transform"
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-headline"
        phx-click-away={JS.dispatch("click", to: "#close")}
        phx-window-keydown={JS.dispatch("click", to: "#close")}
        phx-key="escape">

        <!-- Close Button -->
        <%= if @return_to do %>
          <%= live_patch to: @return_to,
                id: "close",
                class: "absolute top-4 right-4 z-10 w-8 h-8 flex items-center justify-center rounded-full bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 transition cursor-pointer",
                phx_click: hide_modal(),
                title: "Close (Esc)" do %>
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          <% end %>
        <% else %>
          <a id="close" href="#"
             class="absolute top-4 right-4 z-10 w-8 h-8 flex items-center justify-center rounded-full bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 transition"
             phx-click={hide_modal()}
             title="Close (Esc)">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </a>
        <% end %>

        <!-- Modal Body -->
        <div class="p-6 sm:p-8">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  defp hide_modal(js \\ %JS{}) do
    js
    |> JS.hide(to: "#modal", transition: "fade-out")
    |> JS.hide(to: "#modal-content", transition: "fade-out-scale")
  end
end
