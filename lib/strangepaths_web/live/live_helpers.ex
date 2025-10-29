defmodule StrangepathsWeb.LiveHelpers do
  import Phoenix.LiveView
  import Phoenix.LiveView.Helpers

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
    <div id="modal" class="overflow-y-auto fixed inset-0 z-10 pt-6 phx-modal" phx-remove={hide_modal()}>
      <div class="flex justify-center items-end px-4 pt-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 transition-opacity" aria-hidden="true">
          <div class="absolute inset-0 bg-gray-900 opacity-75"></div>
        </div>
        <div
          id="modal-content"
          class="inline-block overflow-hidden px-4 pt-5 pb-4 text-left align-bottom bg-indigo-200 dark:bg-gray-700 rounded-lg shadow-xl transition-all transform phx-modal-content sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6"
          role="dialog" aria-modal="true" aria-labelledby="modal-headline"
          phx-click-away={JS.dispatch("click", to: "#close")}
          phx-window-keydown={JS.dispatch("click", to: "#close")}
          phx-key="escape">
          <%= if @return_to do %>
            <%= live_patch "✖",
              to: @return_to,
              id: "close",
              class: "phx-modal-close",
              phx_click: hide_modal()
            %>
          <% else %>
            <a id="close" href="#" class="phx-modal-close" phx-click={hide_modal()}>✖</a>
          <% end %>
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
