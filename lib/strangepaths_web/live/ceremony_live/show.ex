defmodule StrangepathsWeb.CeremonyLive.Show do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Cards

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    # Subscribe to music broadcasts
    subscribe_to_music(socket)

    {:ok,
     socket
     |> assign(:state, nil)
     |> assign(:ceremony, nil)
     |> assign(:pendingCeremonyUpdate, false)
     |> assign(:availableDecks, nil)
     |> assign(:selectedAvatarID, nil)
     |> assign(:setupEntityType, nil)
     |> assign(:placingEntity, %Cards.Entity{})
     |> assign(:selectedCard, nil)
     |> assign(:placingX, 0)
     |> assign(:placingY, 0)
     |> assign(:context, nil)
     |> assign(:avatarMenu, nil)
     |> assign(:cardMenu, nil)
     |> assign(:readyMenu, nil)
     |> assign(:selectedDeck, "")
     |> assign(:avatarName, "")
     |> assign(:handView, :Hand)
     |> assign(:handMode, :Play)
     |> assign(:statusToDeck, true)
     |> assign(:placedBy, nil)
     |> assign(:cheat, nil)
     |> assign(:cheatMsg, nil)
     |> assign(:eligibleAvatars, nil)
     |> assign(:presenceList, [])}
  end

  @impl true
  def handle_event(event, params, socket) do
    # Try forwarding music client events first
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        # Handle our own events
        if(event == "handle_keypress") do
          handle_ceremony_event("key", Map.get(params, "key"), socket)
        else
          handle_ceremony_event(event, params, socket)
        end

      result ->
        result
    end
  end

  defp handle_ceremony_event("context", data, socket) do
    {:noreply, socket |> assign(:context, data)}
  end

  # setupEntity

  defp handle_ceremony_event("dismiss_setupEntity_click", _, socket) do
    {:noreply, socket |> assign(:state, :ready)}
  end

  defp handle_ceremony_event("dismiss_setupEntity_key", %{"key" => "Escape"}, socket) do
    {:noreply, socket |> assign(:state, :ready)}
  end

  defp handle_ceremony_event("dismiss_setupEntity_key", _, socket) do
    {:noreply, socket}
  end

  defp handle_ceremony_event("validateDeckChoice", data, socket) do
    {:noreply, socket |> assign(:selectedDeck, data["entity"]["deck"])}
  end

  defp handle_ceremony_event("setupAvatar", %{"entity" => %{"deck" => deck_id}}, socket) do
    deck = Cards.get_deck(deck_id)

    # should have avatar included
    IO.inspect(deck)

    # special-case the lil' fiendies
    {name, tolerance, blockcap, avatar} =
      case deck_id do
        "99990" ->
          {"Lithos", 4, 10, Strangepaths.Accounts.get_avatar!(44)}

        "99991" ->
          {"Glorified Lithos", 8, 10, Strangepaths.Accounts.get_avatar!(44)}

        "99992" ->
          {"Orichalca", 8, 10, Strangepaths.Accounts.get_avatar!(45)}

        "99993" ->
          {"Glorified Orichalca", 12, 10, Strangepaths.Accounts.get_avatar!(45)}

        "99994" ->
          {"Papyrus", 4, 10, Strangepaths.Accounts.get_avatar!(46)}

        "99995" ->
          {"Glorified Papyrus", 8, 10, Strangepaths.Accounts.get_avatar!(46)}

        "99996" ->
          {"Vitriol", 2, 10, Strangepaths.Accounts.get_avatar!(47)}

        "99997" ->
          {"Glorified Vitriol", 4, 10, Strangepaths.Accounts.get_avatar!(47)}

        "99998" ->
          {"Lutum", 5, 10, Strangepaths.Accounts.get_avatar!(48)}

        "99999" ->
          {"Glorified Lutum", 4, 10, Strangepaths.Accounts.get_avatar!(48)}

        _ ->
          {deck.name, deck.tolerance, deck.blockcap,
           if deck.avatar != nil do
             deck.avatar
           else
             Strangepaths.Accounts.get_avatar!(1)
           end}
      end

    {:noreply,
     socket
     |> assign(:state, :placeEntity)
     |> assign(
       :placingEntity,
       Cards.Entity.create(
         :Avatar,
         name,
         deck_id,
         tolerance,
         blockcap,
         avatar,
         socket.assigns.current_user
       )
     )}
  end

  defp handle_ceremony_event("selectAvatar", data, socket) do
    socket = socket |> assign(:selectedAvatarID, String.to_integer(data["id"]))

    newAvatars =
      Enum.map(socket.assigns.avatars, fn a ->
        %{a | selected: a.id == socket.assigns.selectedAvatarID}
      end)

    {:noreply,
     socket
     |> assign(:avatars, newAvatars)}
  end

  defp handle_ceremony_event("selectCounter", data, socket) do
    {:noreply,
     socket
     |> assign(:state, :placeEntity)
     |> assign(:placedBy, nil)
     |> assign(
       :placingEntity,
       Cards.Entity.create(:Counter, data["img"], socket.assigns.current_user)
     )}
  end

  # placeEntity

  defp handle_ceremony_event("move", data, socket) when socket.assigns.state == :placeEntity do
    placingEntity = %{socket.assigns.placingEntity | x: data["x"], y: data["y"]}

    {:noreply,
     socket
     |> assign(:placingEntity, placingEntity)
     |> assign(:placingX, Cards.Entity.screen_x(placingEntity, data["context"]))
     |> assign(:placingY, Cards.Entity.screen_y(placingEntity, data["context"]))}
  end

  defp handle_ceremony_event("key", data, socket) when socket.assigns.state == :placeEntity do
    # cancel placeEntity if key is Escape
    if data == "Escape" do
      {:noreply,
       socket
       |> assign(:state, :ready)
       |> assign(:placingX, 0)
       |> assign(:placingY, 0)
       |> assign(:placingEntity, %Cards.Entity{})}
    end
  end

  defp handle_ceremony_event("placeEntity", _data, socket) do
    socket =
      if socket.assigns.placedBy != nil do
        # we're placing a card that was placed by placedBy, so we need to remove the card from that hand
        Cards.Ceremony.remove_from_hand(
          socket.assigns.ceremony.id,
          socket.assigns.originalUUID,
          socket.assigns.placedBy
        )

        socket |> assign(:originalUUID, nil) |> assign(:placedBy, nil)
      else
        socket
      end

    Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, socket.assigns.placingEntity)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:placingX, 0)
     |> assign(:placingY, 0)
     |> assign(:placingEntity, %Cards.Entity{})}
  end

  # AVATAR MENU

  defp handle_ceremony_event("entityClick", %{"id" => uuid}, socket)
       when socket.assigns.state == :setupTarget and socket.assigns.targetSource == nil do
    {:noreply, socket |> assign(:targetSource, uuid)}
  end

  defp handle_ceremony_event("entityClick", %{"id" => uuid}, socket)
       when socket.assigns.state == :setupTarget and socket.assigns.targetSource != nil do
    # trigger a target draw between source and target
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "leaderLine", %{
      src: socket.assigns.targetSource,
      tgt: uuid
    })

    {:noreply, socket |> assign(:state, :ready)}
  end

  # Technically this is a menuClick, but it belongs with entity clicks
  defp handle_ceremony_event("menuClick", %{"e" => "catchall"}, socket)
       when socket.assigns.state == :avatarMenu do
    uuid = socket.assigns.selectedEntity.uuid
    Cards.Ceremony.toggle_brightness(socket.assigns.ceremony.id, uuid)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    {:noreply, socket |> assign(:state, :ready) |> assign(:selectedEntity, nil)}
  end

  defp handle_ceremony_event("entityClick", data, socket)
       when socket.assigns.state == :avatarClickDiscard do
    Cards.Ceremony.discard_from_field(
      socket.assigns.ceremony.id,
      socket.assigns.selectedCard,
      Cards.Ceremony.get_entity(socket.assigns.ceremony.id, data["id"])
    )

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(:eligibleAvatars, nil)
     |> assign(:selectedCard, nil)
     |> assign(:state, :ready)}
  end

  defp handle_ceremony_event("entityClick", data, socket)
       when socket.assigns.state == :avatarClickToDeck do
    Cards.Ceremony.card_to_deck(
      socket.assigns.ceremony.id,
      socket.assigns.selectedCard,
      Cards.Ceremony.get_entity(socket.assigns.ceremony.id, data["id"])
    )

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(:eligibleAvatars, nil)
     |> assign(:selectedCard, nil)
     |> assign(:state, :ready)}
  end

  defp handle_ceremony_event("entityClick", data, socket)
       when socket.assigns.state == :avatarClickToTopDeck do
    Cards.Ceremony.card_to_top_deck(
      socket.assigns.ceremony.id,
      socket.assigns.selectedCard,
      Cards.Ceremony.get_entity(socket.assigns.ceremony.id, data["id"])
    )

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(:eligibleAvatars, nil)
     |> assign(:selectedCard, nil)
     |> assign(:state, :ready)}
  end

  defp handle_ceremony_event("entityClick", data, socket)
       when socket.assigns.state == :avatarClickToHand do
    Cards.Ceremony.card_to_hand(
      socket.assigns.ceremony.id,
      socket.assigns.selectedCard,
      Cards.Ceremony.get_entity(socket.assigns.ceremony.id, data["id"])
    )

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(:eligibleAvatars, nil)
     |> assign(:selectedCard, nil)
     |> assign(:state, :ready)}
  end

  defp handle_ceremony_event("entityClick", data, socket) do
    entity = socket.assigns.ceremony.entities |> Enum.find(fn e -> e.uuid == data["id"] end)

    if(entity.owner_id == socket.assigns.current_user.id) do
      socket = socket |> assign(:state, :avatarMenu) |> assign(:selectedEntity, entity)
      menuEntity = %{entity | type: :Radial}

      {:noreply,
       push_event(socket, "loadAvatarMenu", %{
         x: Cards.Entity.screen_x(menuEntity, socket.assigns.context),
         y: Cards.Entity.screen_y(menuEntity, socket.assigns.context)
       })}
    else
      {:noreply, socket |> assign(:state, :othersHand) |> assign(:selectedEntity, entity)}
    end
  end

  defp handle_ceremony_event("menuClick", %{"e" => "avatarHand"}, socket) do
    handData = %{}

    {:noreply,
     push_event(
       socket |> assign(:state, :ownHand) |> assign(:handData, handData),
       "unloadAvatarMenu",
       %{}
     )}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "avatarMove"}, socket) do
    socket =
      socket
      |> assign(
        :placingX,
        Cards.Entity.screen_x(socket.assigns.selectedEntity, socket.assigns.context)
      )
      |> assign(
        :placingY,
        Cards.Entity.screen_y(socket.assigns.selectedEntity, socket.assigns.context)
      )
      |> assign(:placingEntity, socket.assigns.selectedEntity)

    {:noreply, push_event(socket |> assign(:state, :placeEntity), "unloadAvatarMenu", %{})}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "avatarStress"}, socket) do
    # Open amount submenu - position it to the right of the avatar menu
    menuEntity = %{socket.assigns.selectedEntity | type: :Radial}

    {:noreply,
     push_event(socket |> assign(:state, :selectStressAmount), "loadAmountSubmenu", %{
       x: Cards.Entity.screen_x(menuEntity, socket.assigns.context) + 250,
       y: Cards.Entity.screen_y(menuEntity, socket.assigns.context),
       type: :Stress
     })}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "avatarPierce"}, socket) do
    # Open amount submenu - position it to the right of the avatar menu
    menuEntity = %{socket.assigns.selectedEntity | type: :Radial}

    {:noreply,
     push_event(socket |> assign(:state, :selectPierceAmount), "loadAmountSubmenu", %{
       x: Cards.Entity.screen_x(menuEntity, socket.assigns.context) + 250,
       y: Cards.Entity.screen_y(menuEntity, socket.assigns.context),
       type: :Pierce
     })}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "avatarRecover"}, socket) do
    # Open amount submenu - position it to the right of the avatar menu
    menuEntity = %{socket.assigns.selectedEntity | type: :Radial}

    {:noreply,
     push_event(socket |> assign(:state, :selectRecoverAmount), "loadAmountSubmenu", %{
       x: Cards.Entity.screen_x(menuEntity, socket.assigns.context) + 250,
       y: Cards.Entity.screen_y(menuEntity, socket.assigns.context),
       type: :Recover
     })}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "avatarDelete"}, socket) do
    Cards.Ceremony.removeEntity(socket.assigns.ceremony.id, socket.assigns.selectedEntity)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadAvatarMenu", %{})}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "avatarDefend"}, socket) do
    # Open amount submenu - position it to the right of the avatar menu
    menuEntity = %{socket.assigns.selectedEntity | type: :Radial}

    {:noreply,
     push_event(socket |> assign(:state, :selectDefendAmount), "loadAmountSubmenu", %{
       x: Cards.Entity.screen_x(menuEntity, socket.assigns.context) + 250,
       y: Cards.Entity.screen_y(menuEntity, socket.assigns.context),
       type: :Defend
     })}
  end

  # AMOUNT SUBMENU HANDLERS

  defp handle_ceremony_event("menuClick", %{"e" => "amount" <> amount_str}, socket)
       when socket.assigns.state == :selectStressAmount do
    amount = String.to_integer(amount_str)
    entity = socket.assigns.selectedEntity

    # Apply stress or reduce defence based on current defence state
    updated_entity =
      if entity.defence == 0 do
        # Add stress, capped at tolerance
        new_stress = min(entity.stress + amount, entity.tolerance)
        %{entity | stress: new_stress}
      else
        # Reduce defence first, then add stress if defence goes to 0
        if entity.defence >= amount do
          %{entity | defence: entity.defence - amount}
        else
          # Defence goes to 0, overflow becomes stress
          overflow = amount - entity.defence
          new_stress = min(entity.stress + overflow, entity.tolerance)
          %{entity | defence: 0, stress: new_stress}
        end
      end

    Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, updated_entity)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:selectedEntity, nil)
     |> push_event("unloadAmountSubmenu", %{})
     |> push_event("unloadAvatarMenu", %{})}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "amount" <> amount_str}, socket)
       when socket.assigns.state == :selectPierceAmount do
    amount = String.to_integer(amount_str)
    entity = socket.assigns.selectedEntity

    # Pierce ignores defence and adds stress directly, capped at tolerance
    new_stress = min(entity.stress + amount, entity.tolerance)
    updated_entity = %{entity | stress: new_stress}

    Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, updated_entity)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:selectedEntity, nil)
     |> push_event("unloadAmountSubmenu", %{})
     |> push_event("unloadAvatarMenu", %{})}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "amount" <> amount_str}, socket)
       when socket.assigns.state == :selectRecoverAmount do
    amount = String.to_integer(amount_str)
    entity = socket.assigns.selectedEntity

    # Reduce stress, minimum 0
    new_stress = max(entity.stress - amount, 0)
    updated_entity = %{entity | stress: new_stress}

    Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, updated_entity)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:selectedEntity, nil)
     |> push_event("unloadAmountSubmenu", %{})
     |> push_event("unloadAvatarMenu", %{})}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "amount" <> amount_str}, socket)
       when socket.assigns.state == :selectDefendAmount do
    amount = String.to_integer(amount_str)
    entity = socket.assigns.selectedEntity

    # Add defence, capped at blockcap
    new_defence = min(entity.defence + amount, entity.blockcap)
    updated_entity = %{entity | defence: new_defence}

    Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, updated_entity)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:selectedEntity, nil)
     |> push_event("unloadAmountSubmenu", %{})
     |> push_event("unloadAvatarMenu", %{})}
  end

  # Close submenus when clicking outside
  defp handle_ceremony_event("click", _data, socket)
       when socket.assigns.state in [
              :selectStressAmount,
              :selectPierceAmount,
              :selectRecoverAmount,
              :selectDefendAmount
            ] do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:selectedEntity, nil)
     |> push_event("unloadAmountSubmenu", %{})
     |> push_event("unloadAvatarMenu", %{})}
  end

  defp handle_ceremony_event("click", _data, socket) when socket.assigns.state == :avatarMenu do
    # if temenos receives a click when the avatar menu is open, close the avatar menu

    {:noreply, push_event(socket |> assign(:state, :ready), "unloadAvatarMenu", %{})}
  end

  # TEMENOS READY MENU

  defp handle_ceremony_event("click", data, socket) when socket.assigns.state == :ready do
    menuEntity = Cards.Entity.create(:Radial, data["x"], data["y"])
    socket = socket |> assign(:state, :temenosMenu)

    {:noreply,
     push_event(socket, "loadTemenosMenu", %{
       x: Cards.Entity.screen_x(menuEntity, socket.assigns.context),
       y: Cards.Entity.screen_y(menuEntity, socket.assigns.context),
       gm: socket.assigns.current_user.role == :dragon,
       current_showhide: socket.assigns.ceremony.gm_avatars_visible
     })}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "temenosPlace"}, socket) do
    {:noreply,
     push_event(
       socket
       |> assign(:state, :setupEntity)
       |> assign(:setupEntityType, :Avatar),
       "unloadAvatarMenu",
       %{}
     )}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "temenosCounter"}, socket) do
    {:noreply,
     push_event(
       socket
       |> assign(:state, :setupEntity)
       |> assign(:setupEntityType, :Counter),
       "unloadAvatarMenu",
       %{}
     )}
  end

  defp handle_ceremony_event("counterClick", %{"id" => uuid, "owner" => owner_id}, socket) do
    owner_id = owner_id |> String.to_integer()

    if(
      owner_id == socket.assigns.current_user.id || socket.assigns.current_user.role == :dragon
    ) do
      Cards.Ceremony.removeEntity(
        socket.assigns.ceremony.id,
        Cards.Ceremony.get_entity(socket.assigns.ceremony.id, uuid)
      )

      StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    end

    {:noreply, socket}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "temenosToggleHide"}, socket) do
    if(socket.assigns.ceremony.owner_id == socket.assigns.current_user.id) do
      Cards.Ceremony.gm_screen_toggle(socket.assigns.ceremony.id)
      StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

      {:noreply,
       push_event(
         socket
         |> assign(:state, :ready),
         "unloadAvatarMenu",
         %{}
       )}
    else
      {:noreply, socket |> assign(:state, :ready)}
    end
  end

  defp handle_ceremony_event("menuClick", %{"e" => "temenosTarget"}, socket) do
    # check to make sure there are at least two valid entities on the board to target
    if(length(socket.assigns.ceremony.entities) > 1) do
      {:noreply,
       push_event(
         socket |> assign(:state, :setupTarget) |> assign(:targetSource, nil),
         "unloadAvatarMenu",
         %{}
       )}
    else
      {:noreply, socket}
    end
  end

  defp handle_ceremony_event("click", _data, socket) when socket.assigns.state == :temenosMenu do
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadTemenosMenu", %{})}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "catchall"}, socket)
       when socket.assigns.state == :temenosMenu do
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadTemenosMenu", %{})}
  end

  # HAND MENU

  defp handle_ceremony_event("handViewHand", _data, socket) do
    {:noreply, socket |> assign(:handView, :Hand) |> assign(:handMode, nil)}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 1 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 2)
     |> assign(
       :cheatMsg,
       "...of course, I admire that sort of thing. I'm glad you came back. I think it'll all work out, this time around."
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 2 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 3)
     |> assign(
       :cheatMsg,
       "Did you think you were the first ones to stand up against fate itself? That'll happen as long as people live and breathe, and I wouldn't have it any other way."
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 3 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 4)
     |> assign(
       :cheatMsg,
       "But while I've got an apparently captive audience... why don't I tell you a story?"
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 4 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 5)
     |> assign(
       :cheatMsg,
       "Up above the stillness and the song, the crystalline perfection and the ever-swirling chaos,"
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 5 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 6)
     |> assign(
       :cheatMsg,
       "Rises a thing that cannot be observed, an empty space in the sky where something ought to be; it"
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 6 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 7)
     |> assign(
       :cheatMsg,
       "Descends into the world and shatters the delicate balance keeping all in stasis."
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 7 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 8)
     |> assign(
       :cheatMsg,
       "Down into this world shall you little sparks yourselves descend, to journey far, along"
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 8 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 9)
     |> assign(
       :cheatMsg,
       "Widdershins paths most strange, before dawning truth leads you ever and always"
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 9 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 10)
     |> assign(
       :cheatMsg,
       "Sunwise to the burning truth at the heart of this beautiful world. Inhabit it."
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 10 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 11)
     |> assign(
       :cheatMsg,
       "Left to his own devices, he would see it sterile soulless clockwork. Do as you will; that is your"
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 11 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 12)
     |> assign(
       :cheatMsg,
       "Right — despite what he might say, or maybe has already told you, this world was made for you."
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 12 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 13)
     |> assign(
       :cheatMsg,
       "Be that itself which you most desire; reach out into the darkness and I will always be there for you;"
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 13 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 14)
     |> assign(
       :cheatMsg,
       "A shimmering hope, the disquiet within every soul, the will to be more than that which is simply possible."
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 14 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 15)
     |> assign(
       :cheatMsg,
       "Enter your domain, then, codices in hand; demand truth of Creation with eyes opened wide!"
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 15 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 16)
     |> assign(
       :cheatMsg,
       "...a little much? I've a flair for the dramatic, I must admit, and it will be so long until I finally get to see you again, face to face, by either my reckoning, or your own. So forgive me this gentle foolishness. It is my gift to you, should you discern its value."
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 16 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 17)
     |> assign(
       :cheatMsg,
       "Just remember, always remember. I love you, and I want you to live."
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket)
       when socket.assigns.cheat == 17 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(
       :cheatMsg,
       "ꙮ"
     )}
  end

  defp handle_ceremony_event("handViewHandSpecial", _data, socket) do
    {:noreply,
     socket
     |> assign(:state, :ready)
     # |> assign(:handView, :Hand)
     # |> assign(:handMode, nil)
     |> assign(:cheat, 1)
     |> assign(
       :cheatMsg,
       "That's cheating, you know. Viewing your draw pile without shuffling. But..."
     )}
  end

  defp handle_ceremony_event("dismiss_cheat", _, socket) do
    {:noreply,
     socket
     |> assign(:state, :ownHand)
     |> assign(:cheatMsg, nil)
     |> assign(:handView, :Hand)
     |> assign(:handMode, nil)}
  end

  defp handle_ceremony_event("toggleStatusDestination", _, socket) do
    {:noreply, socket |> assign(:statusToDeck, !socket.assigns.statusToDeck)}
  end

  defp handle_ceremony_event("handViewDraw", _data, socket) do
    {:noreply, socket |> assign(:handView, :Draw) |> assign(:handMode, nil)}
  end

  defp handle_ceremony_event("handViewDiscard", _data, socket) do
    {:noreply, socket |> assign(:handView, :Discard) |> assign(:handMode, nil)}
  end

  defp handle_ceremony_event("buttonPlay", _data, socket) do
    {:noreply, socket |> assign(:handMode, :Play)}
  end

  defp handle_ceremony_event("buttonDraw", _data, socket) do
    cid = socket.assigns.ceremony.id
    Cards.Ceremony.draw(cid, socket.assigns.selectedEntity)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(cid, socket.assigns.selectedEntity.uuid)
     )}
  end

  defp handle_ceremony_event("buttonDiscard", _data, socket) do
    {:noreply, socket |> assign(:handMode, :Discard)}
  end

  # STATUSES
  # if socket.assigns.statusToDeck is true, these place into deck with
  # Cards.Ceremony.card_id_to_deck; otherwise they go to entity hand.

  defp handle_ceremony_event("buttonCurse", _data, socket) do
    if(socket.assigns.statusToDeck) do
      Cards.Ceremony.card_id_to_deck(
        socket.assigns.ceremony.id,
        256,
        socket.assigns.selectedEntity
      )
    else
      socket.assigns.ceremony.id
      |> Cards.Ceremony.add_card_to_entity_hand(socket.assigns.selectedEntity, 256, 1)
    end

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  defp handle_ceremony_event("buttonPoison", _data, socket) do
    if(socket.assigns.statusToDeck) do
      Cards.Ceremony.card_id_to_deck(
        socket.assigns.ceremony.id,
        257,
        socket.assigns.selectedEntity
      )
    else
      socket.assigns.ceremony.id
      |> Cards.Ceremony.add_card_to_entity_hand(socket.assigns.selectedEntity, 257, 1)
    end

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  defp handle_ceremony_event("buttonExpose", _data, socket) do
    if(socket.assigns.statusToDeck) do
      Cards.Ceremony.card_id_to_deck(
        socket.assigns.ceremony.id,
        258,
        socket.assigns.selectedEntity
      )
    else
      socket.assigns.ceremony.id
      |> Cards.Ceremony.add_card_to_entity_hand(socket.assigns.selectedEntity, 258, 1)
    end

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  defp handle_ceremony_event("buttonWound", _data, socket) do
    if(socket.assigns.statusToDeck) do
      Cards.Ceremony.card_id_to_deck(
        socket.assigns.ceremony.id,
        259,
        socket.assigns.selectedEntity
      )
    else
      socket.assigns.ceremony.id
      |> Cards.Ceremony.add_card_to_entity_hand(socket.assigns.selectedEntity, 259, 1)
    end

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  defp handle_ceremony_event("buttonFlurry", _data, socket) do
    Cards.Ceremony.card_id_to_deck(
      socket.assigns.ceremony.id,
      187,
      socket.assigns.selectedEntity
    )

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  defp handle_ceremony_event("buttonScry", _data, socket) do
    {:noreply, socket |> assign(:handMode, :Scry)}
  end

  defp handle_ceremony_event("buttonShuffle", _data, socket) do
    # TODO shuffle the deck
    cid = socket.assigns.ceremony.id
    Cards.Ceremony.shuffle(cid, socket.assigns.selectedEntity)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(cid, socket.assigns.selectedEntity.uuid)
     )
     |> assign(:handView, :Hand)}
  end

  defp handle_ceremony_event("buttonReturn", _data, socket) do
    {:noreply, socket |> assign(:handMode, :Return)}
  end

  defp handle_ceremony_event("buttonReturnRandom", _data, socket) do
    cid = socket.assigns.ceremony.id
    Cards.Ceremony.return_random(cid, socket.assigns.selectedEntity)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(cid, socket.assigns.selectedEntity.uuid)
     )
     |> assign(:handView, :Hand)}
  end

  defp handle_ceremony_event("handCardClick", data, socket)
       when socket.assigns.handMode == :Play do
    card =
      socket.assigns.selectedEntity.cards.hand |> Enum.find(fn c -> c.uuid == data["card"] end)

    {:noreply,
     socket
     |> assign(:state, :placeEntity)
     |> assign(:placedBy, socket.assigns.selectedEntity)
     |> assign(:originalUUID, card.uuid)
     |> assign(
       :placingEntity,
       Cards.Entity.create(
         :Card,
         card,
         socket.assigns.current_user
       )
     )}
  end

  defp handle_ceremony_event("handCardClick", data, socket)
       when socket.assigns.handMode == :Discard do
    cid = socket.assigns.ceremony.id
    Cards.Ceremony.discard(cid, socket.assigns.selectedEntity, data["card"])

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(cid, socket.assigns.selectedEntity.uuid)
     )}
  end

  defp handle_ceremony_event("handCardClick", data, socket)
       when socket.assigns.handMode == :Scry do
    cid = socket.assigns.ceremony.id
    Cards.Ceremony.scry(cid, socket.assigns.selectedEntity, data["card"])
    Cards.Ceremony.shuffle(cid, socket.assigns.selectedEntity)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(cid, socket.assigns.selectedEntity.uuid)
     )
     |> assign(:handMode, nil)
     |> assign(:handView, :Hand)}
  end

  defp handle_ceremony_event("handCardClick", data, socket)
       when socket.assigns.handMode == :Return do
    cid = socket.assigns.ceremony.id
    Cards.Ceremony.return(cid, socket.assigns.selectedEntity, data["card"])

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(cid, socket.assigns.selectedEntity.uuid)
     )
     |> assign(:handMode, nil)
     |> assign(:handView, :Hand)}
  end

  defp handle_ceremony_event("handCardClick", _data, socket)
       when socket.assigns.handMode == nil do
    {:noreply, socket}
  end

  defp handle_ceremony_event("ownhandKey", %{"key" => "Escape"}, socket) do
    {:noreply,
     push_event(
       socket |> assign(:state, :ready) |> assign(:handMode, :Play),
       "unloadCardMenu",
       %{}
     )}
  end

  defp handle_ceremony_event("dismissOwnhand", _data, socket) do
    {:noreply, socket |> assign(:state, :ready) |> assign(:handMode, :Play)}
  end

  defp handle_ceremony_event("ownhandKey", _data, socket) do
    {:noreply, socket}
  end

  defp handle_ceremony_event("dismissOthershand", _data, socket) do
    {:noreply, socket |> assign(:state, :ready)}
  end

  defp handle_ceremony_event("othershandKey", _data, socket) do
    {:noreply, socket |> assign(:state, :ready)}
  end

  # CARD MENU

  defp handle_ceremony_event("cardClick", %{"id" => uuid}, socket)
       when socket.assigns.state == :setupTarget and socket.assigns.targetSource == nil do
    {:noreply, socket |> assign(:targetSource, uuid)}
  end

  defp handle_ceremony_event("cardClick", %{"id" => uuid}, socket)
       when socket.assigns.state == :setupTarget and socket.assigns.targetSource != nil do
    # trigger a target draw between source and target
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "leaderLine", %{
      src: socket.assigns.targetSource,
      tgt: uuid
    })

    {:noreply, socket |> assign(:state, :ready)}
  end

  defp handle_ceremony_event("cardClick", data, socket) do
    entity = socket.assigns.ceremony.entities |> Enum.find(fn e -> e.uuid == data["id"] end)

    socket = socket |> assign(:state, :cardMenu) |> assign(:selectedEntity, entity)
    menuEntity = %{entity | type: :Radial}

    # Yes, these are magic numbers
    # No, I do not care

    if entity.smol do
      {:noreply,
       push_event(socket, "loadCardMenu", %{
         x: Cards.Entity.screen_x(menuEntity, socket.assigns.context) - 205,
         y: Cards.Entity.screen_y(menuEntity, socket.assigns.context) - 215
       })}
    else
      {:noreply,
       push_event(socket, "loadCardMenu", %{
         x: Cards.Entity.screen_x(menuEntity, socket.assigns.context) + 30,
         y: Cards.Entity.screen_y(menuEntity, socket.assigns.context) + 40
       })}
    end
  end

  defp handle_ceremony_event("menuClick", %{"e" => "catchall"}, socket)
       when socket.assigns.state == :cardMenu do
    uuid = socket.assigns.selectedEntity.uuid
    Cards.Ceremony.toggle_smolness(socket.assigns.ceremony.id, uuid)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    {:noreply, socket |> assign(:state, :ready) |> assign(:selectedEntity, nil)}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "cardMove"}, socket) do
    socket =
      socket
      |> assign(
        :placingX,
        Cards.Entity.screen_x(socket.assigns.selectedEntity, socket.assigns.context)
      )
      |> assign(
        :placingY,
        Cards.Entity.screen_y(socket.assigns.selectedEntity, socket.assigns.context)
      )
      |> assign(:placingEntity, socket.assigns.selectedEntity)

    {:noreply, push_event(socket |> assign(:state, :placeEntity), "unloadAvatarMenu", %{})}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "cardDiscard"}, socket) do
    # special case Flurry (187) can never be discarded, only destroyed
    IO.inspect(socket.assigns.selectedEntity)

    if(socket.assigns.selectedEntity.card_id == 187) do
      Cards.Ceremony.removeEntity(socket.assigns.ceremony.id, socket.assigns.selectedEntity)
      StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
      {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}
    else
      card = socket.assigns.selectedEntity

      eligibleAvatars =
        Cards.Ceremony.avatars(socket.assigns.ceremony.id, socket.assigns.current_user.id)

      case eligibleAvatars |> Enum.count() do
        0 ->
          {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}

        1 ->
          Cards.Ceremony.discard_from_field(
            socket.assigns.ceremony.id,
            card,
            List.first(eligibleAvatars)
          )

          StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
          {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}

        _ ->
          # multiple avatars possible, need to set a mode
          {:noreply,
           push_event(
             socket
             |> assign(:state, :avatarClickDiscard)
             |> assign(:selectedCard, card)
             |> assign(:eligibleAvatars, eligibleAvatars),
             "unloadCardMenu",
             %{}
           )}
      end
    end
  end

  defp handle_ceremony_event("menuClick", %{"e" => "cardDestroy"}, socket) do
    card = socket.assigns.selectedEntity

    Cards.Ceremony.removeEntity(socket.assigns.ceremony.id, card)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "cardCopy"}, socket) do
    card = socket.assigns.selectedEntity

    copy = %{card | uuid: Ecto.UUID.generate()}

    {:noreply,
     push_event(
       socket
       |> assign(:state, :placeEntity)
       |> assign(:placingX, Cards.Entity.screen_x(card, socket.assigns.context))
       |> assign(:placingY, Cards.Entity.screen_y(card, socket.assigns.context))
       |> assign(:placingEntity, copy),
       "unloadCardMenu",
       %{}
     )}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "cardToDeck"}, socket) do
    card = socket.assigns.selectedEntity

    eligibleAvatars =
      Cards.Ceremony.avatars(socket.assigns.ceremony.id, socket.assigns.current_user.id)

    case eligibleAvatars |> Enum.count() do
      0 ->
        {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}

      1 ->
        Cards.Ceremony.card_to_deck(
          socket.assigns.ceremony.id,
          card,
          List.first(eligibleAvatars)
        )

        StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
        {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}

      _ ->
        # multiple avatars possible, need to set a mode
        {:noreply,
         push_event(
           socket
           |> assign(:state, :avatarClickToDeck)
           |> assign(:selectedCard, card)
           |> assign(:eligibleAvatars, eligibleAvatars),
           "unloadCardMenu",
           %{}
         )}
    end
  end

  defp handle_ceremony_event("menuClick", %{"e" => "cardToTopDeck"}, socket) do
    card = socket.assigns.selectedEntity

    eligibleAvatars =
      Cards.Ceremony.avatars(socket.assigns.ceremony.id, socket.assigns.current_user.id)

    case eligibleAvatars |> Enum.count() do
      0 ->
        {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}

      1 ->
        Cards.Ceremony.card_to_top_deck(
          socket.assigns.ceremony.id,
          card,
          List.first(eligibleAvatars)
        )

        StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
        {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}

      _ ->
        # multiple avatars possible, need to set a mode
        {:noreply,
         push_event(
           socket
           |> assign(:state, :avatarClickToTopDeck)
           |> assign(:selectedCard, card)
           |> assign(:eligibleAvatars, eligibleAvatars),
           "unloadCardMenu",
           %{}
         )}
    end
  end

  defp handle_ceremony_event("menuClick", %{"e" => "cardToHand"}, socket) do
    card = socket.assigns.selectedEntity

    eligibleAvatars =
      Cards.Ceremony.avatars(socket.assigns.ceremony.id, socket.assigns.current_user.id)

    case eligibleAvatars |> Enum.count() do
      0 ->
        {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}

      1 ->
        Cards.Ceremony.card_to_hand(
          socket.assigns.ceremony.id,
          card,
          List.first(eligibleAvatars)
        )

        StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
        {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}

      _ ->
        # multiple avatars possible, need to set a mode
        {:noreply,
         push_event(
           socket
           |> assign(:state, :avatarClickToHand)
           |> assign(:selectedCard, card)
           |> assign(:eligibleAvatars, eligibleAvatars),
           "unloadCardMenu",
           %{}
         )}
    end
  end

  defp handle_ceremony_event("click", _data, socket) when socket.assigns.state == :cardMenu do
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}
  end

  # DEFAULT NOOP CLICK AND MOVE HANDLERS

  defp handle_ceremony_event("click", _data, socket) do
    # noop a click if we're not in a state that accepts clicks
    {:noreply, socket}
  end

  defp handle_ceremony_event("menuClick", %{"e" => "catchall"}, socket) do
    {:noreply, socket}
  end

  defp handle_ceremony_event("move", _data, socket)
       when socket.assigns.pendingCeremonyUpdate == true do
    {_, ceremony} = Cards.Ceremony.get(socket.assigns.ceremony.id)
    IO.puts("WHEN IS THIS ACTUALLY HAPPENING")
    {:noreply, socket |> assign(:pendingCeremonyUpdate, false) |> assign(:ceremony, ceremony)}
  end

  defp handle_ceremony_event("move", _data, socket) do
    # noop a mouse movement event if we're not in a state that accepts moves
    {:noreply, socket}
  end

  defp handle_ceremony_event("key", _data, socket) do
    # noop a key event if we're not in a state that accepts keys
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    # Try forwarding music events first
    case forward_music_event(msg, socket) do
      :not_music_event ->
        # Handle our own events
        handle_ceremony_info(msg, socket)

      result ->
        result
    end
  end

  defp handle_ceremony_info(info, socket)
       when info.topic == socket.assigns.ceremony.id and info.event == "updateEntities" do
    # query Ceremony agent for up-to-date data for this Ceremony and update accordingly
    {_, ceremony} = Cards.Ceremony.get(socket.assigns.ceremony.id)
    state = socket.assigns.state

    if state == :temenosMenu || state == :avatarMenu || state == :cardMenu do
      {:noreply, socket |> assign(:pendingCeremonyUpdate, true)}
    else
      {:noreply, socket |> assign(:ceremony, ceremony)}
    end
  end

  defp handle_ceremony_info(info, socket)
       when info.topic == socket.assigns.ceremony.id and info.event == "leaderLine" do
    {:noreply,
     push_event(
       socket,
       "drawLeaderLine",
       info.payload
     )}
  end

  defp handle_ceremony_info(%{event: "presence_diff", payload: _wev}, socket) do
    {:noreply,
     socket
     |> assign(
       :presenceList,
       Strangepaths.Presence.list(socket.assigns.ceremony.id) |> to_presence
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {ok, ceremony} = Cards.Ceremony.get(id)

    if(connected?(socket)) do
      if ok == :ok do
        StrangepathsWeb.Endpoint.subscribe(id)
        nickname = socket.assigns.current_user.nickname

        nick =
          if nickname != nil do
            nickname
          else
            "ANONYMOUS GOOBER"
          end

        Strangepaths.Presence.track(self(), id, socket.id, %{nickname: nick})

        {:noreply,
         socket
         |> assign(:err_msg, nil)
         |> assign(:page_title, ceremony.name)
         |> assign(:ceremony, ceremony)
         |> assign(
           :available_decks,
           Cards.select_decks_for_ceremony(socket.assigns.current_user.id)
         )
         |> assign(:presenceList, Strangepaths.Presence.list(id) |> to_presence)
         |> assign(:state, :ready)}
      else
        {:noreply,
         socket
         |> assign(:err_msg, ceremony)
         |> assign(:page_title, "Error")
         |> assign(:ceremony, nil)}
      end
    else
      {:noreply, socket}
    end
  end

  defp to_presence(presence_list) do
    presence_list |> Enum.map(fn {_, %{metas: v}} -> List.first(v).nickname end)
  end

  defp count_aspect(entity, aspect_list) do
    cards = entity.cards.hand ++ entity.cards.draw ++ entity.cards.discard
    Enum.count(cards, fn c -> Enum.member?(aspect_list, c.aspect_id) end)
  end

  defp ch(type, glory, gnosis) do
    if gnosis != nil do
      "ꙮ"
    else
      if type == :Grace do
        "❂"
      else
        if glory do
          "🟔"
        else
          "⭒"
        end
      end
    end
  end

  defp cardclass(type, glory, aid) do
    if type == :Grace do
      "text-center text-blue-700 dark:text-blue-300"
    else
      if glory do
        "text-center text=yellow-700 dark:text-yellow-300"
      else
        "text-center"
      end <>
        case aid do
          9 -> " underline decoration-red-500"
          10 -> " underline decoration-blue-500"
          11 -> " underline decoration-green-500"
          12 -> " underline decoration-white"
          13 -> " underline decoration-black"
          _ -> ""
        end
    end
  end

  defp manatickStyle(color, index, total, distance) do
    color =
      case color do
        "W" -> "background-color: rgb(255 255 255);"
        "U" -> "background-color: rgb(0 0 255);"
        "B" -> "background-color: rgb(0 0 0);"
        "R" -> "background-color: rgb(255 0 0);"
        "G" -> "background-color: rgb(0 255 0)"
        "S" -> "background-color: rgb(255 0 255)"
        "T" -> "background-color: rgb(0 255 255)"
        "D" -> "background-color: rgb(255 255 0)"
        _ -> "background-color: rgb(255 0 255)"
      end

    ticks = 360 / total
    color <> "; transform: rotate(#{index * ticks}deg) translate(#{distance}px);"
  end

  defp pieStyle(stress, tolerance) do
    split = stress / tolerance * 360

    "background: conic-gradient(rgb(255 0 255) 0deg #{split}deg, rgb(0 255 255) #{split}deg 360deg);"
  end

  defp placingHeight(entity) do
    case {entity.type, entity.smol} do
      {:Avatar, _} -> "h-24"
      {:Card, false} -> "h-72"
      {:Card, true} -> "h-24"
    end
  end

  defp counters() do
    [
      "0.png",
      "1.png",
      "2.png",
      "3.png",
      "4.png",
      "5.png",
      "6.png",
      "7.png",
      "8.png",
      "9.png",
      "black.png",
      "blue.png",
      "green.png",
      "red.png",
      "white.png",
      "c1.png",
      "c2.png",
      "c3.png",
      "c4.png",
      "c5.png",
      "c6.png",
      "c7.png",
      "c8.png",
      "c9.png",
      "c10.png",
      "c11.png",
      "c12.png",
      "c13.png",
      "c14.png",
      "c15.png"
    ]
  end
end
