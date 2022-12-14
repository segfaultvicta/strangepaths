defmodule StrangepathsWeb.CeremonyLive.Show do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Cards
  alias Strangepaths.Accounts.Avatar

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    {:ok,
     socket
     |> assign(:state, nil)
     |> assign(:ceremony, nil)
     |> assign(:pendingCeremonyUpdate, false)
     |> assign(:avatars, get_avatars(socket.assigns.current_user.id))
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
     |> assign(:avatarTolerance, 0)
     |> assign(:avatarName, "")
     |> assign(:handView, :Hand)
     |> assign(:handMode, :Play)
     |> assign(:placedBy, nil)
     |> assign(:cheat, nil)
     |> assign(:cheatMsg, nil)
     |> assign(:eligibleAvatars, nil)
     |> assign(:avatarTolerance, 10)
     |> assign(:presenceList, [])}
  end

  def handle_event("context", data, socket) do
    {:noreply, socket |> assign(:context, data)}
  end

  # setupEntity

  def handle_event("dismiss_setupEntity_click", _, socket) do
    {:noreply, socket |> assign(:state, :ready)}
  end

  def handle_event("dismiss_setupEntity_key", %{"key" => "Escape"}, socket) do
    {:noreply, socket |> assign(:state, :ready)}
  end

  def handle_event("dismiss_setupEntity_key", _, socket) do
    {:noreply, socket}
  end

  def handle_event("validateAvatar", data, socket) do
    # special-case the fiends
    {name, tolerance, avatar} =
      case data["entity"]["deck"] do
        "99990" ->
          {"Lithos", "4", 44}

        "99991" ->
          {"Glorified Lithos", "8", 44}

        "99992" ->
          {"Orichalca", "8", 45}

        "99993" ->
          {"Glorified Orichalca", "12", 45}

        "99994" ->
          {"Papyrus", "4", 46}

        "99995" ->
          {"Glorified Papyrus", "8", 46}

        "99996" ->
          {"Vitriol", "2", 47}

        "99997" ->
          {"Glorified Vitriol", "4", 47}

        "99998" ->
          {"Lutum", "5", 48}

        "99999" ->
          {"Glorified Lutum", "4", 48}

        "" ->
          {"", data["entity"]["tolerance"], socket.assigns.selectedAvatarID}

        _ ->
          {Cards.get_deck(data["entity"]["deck"]).name, data["entity"]["tolerance"],
           socket.assigns.selectedAvatarID}
      end

    tolerance =
      if String.to_integer(tolerance) < 1 do
        "1"
      else
        tolerance
      end

    if avatar != socket.assigns.selectedAvatarID do
      # if selected avatar has been updated,
      newAvatars =
        Enum.map(socket.assigns.avatars, fn a ->
          %Avatar{a | selected: a.id == avatar}
        end)

      {:noreply,
       socket
       |> assign(:selectedDeck, data["entity"]["deck"])
       |> assign(:selectedAvatarID, avatar)
       |> assign(:avatarTolerance, tolerance)
       |> assign(:avatarName, name)
       |> assign(:avatars, newAvatars)}
    else
      {:noreply,
       socket
       |> assign(:selectedDeck, data["entity"]["deck"])
       |> assign(:selectedAvatarID, avatar)
       |> assign(:avatarTolerance, tolerance)
       |> assign(:avatarName, name)}
    end
  end

  @impl true
  def handle_event("setupAvatar", data, socket) do
    # we'll either have a name, or a deck - if we have a deck, derive the name from the deck
    # if we don't have a deck, send nil

    {:noreply,
     socket
     |> assign(:state, :placeEntity)
     |> assign(
       :placingEntity,
       Cards.Entity.create(
         :Avatar,
         socket.assigns.avatarName,
         data["entity"]["deck"],
         data["entity"]["tolerance"],
         socket.assigns.selectedAvatarID,
         socket.assigns.current_user
       )
     )}
  end

  def handle_event("selectAvatar", data, socket) do
    socket = socket |> assign(:selectedAvatarID, String.to_integer(data["id"]))

    newAvatars =
      Enum.map(socket.assigns.avatars, fn a ->
        %Avatar{a | selected: a.id == socket.assigns.selectedAvatarID}
      end)

    {:noreply,
     socket
     |> assign(:avatars, newAvatars)}
  end

  def handle_event("selectCounter", data, socket) do
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

  @impl true
  def handle_event("move", data, socket) when socket.assigns.state == :placeEntity do
    placingEntity = %Cards.Entity{socket.assigns.placingEntity | x: data["x"], y: data["y"]}

    {:noreply,
     socket
     |> assign(:placingEntity, placingEntity)
     |> assign(:placingX, Cards.Entity.screen_x(placingEntity, data["context"]))
     |> assign(:placingY, Cards.Entity.screen_y(placingEntity, data["context"]))}
  end

  @impl true
  def handle_event("placeEntity", _data, socket) do
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
    {:noreply, socket |> assign(:state, :ready) |> assign(:placingEntity, %Cards.Entity{})}
  end

  # AVATAR MENU

  def handle_event("entityClick", %{"id" => uuid}, socket)
      when socket.assigns.state == :setupTarget and socket.assigns.targetSource == nil do
    {:noreply, socket |> assign(:targetSource, uuid)}
  end

  def handle_event("entityClick", %{"id" => uuid}, socket)
      when socket.assigns.state == :setupTarget and socket.assigns.targetSource != nil do
    # trigger a target draw between source and target
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "leaderLine", %{
      src: socket.assigns.targetSource,
      tgt: uuid
    })

    {:noreply, socket |> assign(:state, :ready)}
  end

  def handle_event("entityClick", data, socket)
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

  def handle_event("entityClick", data, socket)
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

  def handle_event("entityClick", data, socket)
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

  def handle_event("entityClick", data, socket)
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

  def handle_event("entityClick", data, socket) do
    entity = socket.assigns.ceremony.entities |> Enum.find(fn e -> e.uuid == data["id"] end)

    if(entity.owner_id == socket.assigns.current_user.id) do
      socket = socket |> assign(:state, :avatarMenu) |> assign(:selectedEntity, entity)
      menuEntity = %Cards.Entity{entity | type: :Radial}

      {:noreply,
       push_event(socket, "loadAvatarMenu", %{
         x: Cards.Entity.screen_x(menuEntity, socket.assigns.context),
         y: Cards.Entity.screen_y(menuEntity, socket.assigns.context)
       })}
    else
      {:noreply, socket |> assign(:state, :othersHand) |> assign(:selectedEntity, entity)}
    end
  end

  def handle_event("menuClick", %{"e" => "avatarHand"}, socket) do
    handData = %{}

    {:noreply,
     push_event(
       socket |> assign(:state, :ownHand) |> assign(:handData, handData),
       "unloadAvatarMenu",
       %{}
     )}
  end

  def handle_event("menuClick", %{"e" => "avatarMove"}, socket) do
    socket = socket |> assign(:placingEntity, socket.assigns.selectedEntity)
    {:noreply, push_event(socket |> assign(:state, :placeEntity), "unloadAvatarMenu", %{})}
  end

  def handle_event("menuClick", %{"e" => "avatarStress"}, socket) do
    if(socket.assigns.selectedEntity.defence == 0) do
      if socket.assigns.selectedEntity.stress < socket.assigns.selectedEntity.tolerance do
        Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, %Cards.Entity{
          socket.assigns.selectedEntity
          | stress: socket.assigns.selectedEntity.stress + 1
        })
      end
    else
      Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, %Cards.Entity{
        socket.assigns.selectedEntity
        | defence: socket.assigns.selectedEntity.defence - 1
      })
    end

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadAvatarMenu", %{})}
  end

  def handle_event("menuClick", %{"e" => "avatarPierce"}, socket) do
    Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, %Cards.Entity{
      socket.assigns.selectedEntity
      | stress: socket.assigns.selectedEntity.stress + 1
    })

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadAvatarMenu", %{})}
  end

  def handle_event("menuClick", %{"e" => "avatarRecover"}, socket) do
    if(socket.assigns.selectedEntity.stress > 0) do
      Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, %Cards.Entity{
        socket.assigns.selectedEntity
        | stress: socket.assigns.selectedEntity.stress - 1
      })

      StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    end

    {:noreply, push_event(socket |> assign(:state, :ready), "unloadAvatarMenu", %{})}
  end

  def handle_event("menuClick", %{"e" => "avatarDelete"}, socket) do
    Cards.Ceremony.removeEntity(socket.assigns.ceremony.id, socket.assigns.selectedEntity)
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadAvatarMenu", %{})}
  end

  def handle_event("menuClick", %{"e" => "avatarDefend"}, socket) do
    if(socket.assigns.selectedEntity.defence < socket.assigns.selectedEntity.tolerance) do
      Cards.Ceremony.placeEntity(socket.assigns.ceremony.id, %Cards.Entity{
        socket.assigns.selectedEntity
        | defence: socket.assigns.selectedEntity.defence + 1
      })

      StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    end

    {:noreply, push_event(socket |> assign(:state, :ready), "unloadAvatarMenu", %{})}
  end

  def handle_event("click", _data, socket) when socket.assigns.state == :avatarMenu do
    # if temenos receives a click when the avatar menu is open, close the avatar menu

    {:noreply, push_event(socket |> assign(:state, :ready), "unloadAvatarMenu", %{})}
  end

  # TEMENOS READY MENU

  def handle_event("click", data, socket) when socket.assigns.state == :ready do
    menuEntity = Cards.Entity.create(:Radial, data["x"], data["y"])
    socket = socket |> assign(:state, :temenosMenu)

    {:noreply,
     push_event(socket, "loadTemenosMenu", %{
       x: Cards.Entity.screen_x(menuEntity, socket.assigns.context),
       y: Cards.Entity.screen_y(menuEntity, socket.assigns.context)
     })}
  end

  def handle_event("menuClick", %{"e" => "temenosPlace"}, socket) do
    {:noreply,
     push_event(
       socket
       |> assign(:state, :setupEntity)
       |> assign(:setupEntityType, :Avatar)
       |> assign(:avatarTolerance, 10),
       "unloadAvatarMenu",
       %{}
     )}
  end

  def handle_event("menuClick", %{"e" => "temenosCounter"}, socket) do
    {:noreply,
     push_event(
       socket
       |> assign(:state, :setupEntity)
       |> assign(:setupEntityType, :Counter),
       "unloadAvatarMenu",
       %{}
     )}
  end

  def handle_event("counterClick", %{"id" => uuid, "owner" => owner_id}, socket) do
    owner_id = owner_id |> String.to_integer()

    if(
      owner_id == socket.assigns.current_user.id || socket.assigns.current_user.role == :admin ||
        socket.assigns.current_user.role == :god
    ) do
      Cards.Ceremony.removeEntity(
        socket.assigns.ceremony.id,
        Cards.Ceremony.get_entity(socket.assigns.ceremony.id, uuid)
      )

      StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    end

    {:noreply, socket}
  end

  def handle_event("menuClick", %{"e" => "temenosToggleHide"}, socket) do
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

  def handle_event("menuClick", %{"e" => "temenosTarget"}, socket) do
    {:noreply,
     push_event(
       socket |> assign(:state, :setupTarget) |> assign(:targetSource, nil),
       "unloadAvatarMenu",
       %{}
     )}
  end

  def handle_event("click", _data, socket) when socket.assigns.state == :temenosMenu do
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadTemenosMenu", %{})}
  end

  # HAND MENU

  def handle_event("handViewHand", _data, socket) do
    {:noreply, socket |> assign(:handView, :Hand) |> assign(:handMode, nil)}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 1 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 2)
     |> assign(
       :cheatMsg,
       "...of course, I admire that sort of thing. I'm glad you came back. I think it'll all work out, this time around."
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 2 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 3)
     |> assign(
       :cheatMsg,
       "Did you think you were the first ones to stand up against fate itself? That'll happen as long as people live and breathe, and I wouldn't have it any other way."
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 3 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 4)
     |> assign(
       :cheatMsg,
       "But while I've got an apparently captive audience... why don't I tell you a story?"
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 4 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 5)
     |> assign(
       :cheatMsg,
       "Up above the stillness and the song, the crystalline perfection and the ever-swirling chaos,"
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 5 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 6)
     |> assign(
       :cheatMsg,
       "Rises a thing that cannot be observed, an empty space in the sky where something ought to be; it"
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 6 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 7)
     |> assign(
       :cheatMsg,
       "Descends into the world and shatters the delicate balance keeping all in stasis."
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 7 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 8)
     |> assign(
       :cheatMsg,
       "Down into this world shall you little sparks yourselves descend, to journey far, along"
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 8 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 9)
     |> assign(
       :cheatMsg,
       "Widdershins paths most strange, before dawning truth leads you ever and always"
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 9 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 10)
     |> assign(
       :cheatMsg,
       "Sunwise to the burning truth at the heart of this beautiful world. Inhabit it."
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 10 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 11)
     |> assign(
       :cheatMsg,
       "Left to his own devices, he would see it sterile soulless clockwork. Do as you will; that is your"
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 11 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 12)
     |> assign(
       :cheatMsg,
       "Right ??? despite what he might say, or maybe has already told you, this world was made for you."
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 12 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 13)
     |> assign(
       :cheatMsg,
       "Be that itself which you most desire; reach out into the darkness and I will always be there for you;"
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 13 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 14)
     |> assign(
       :cheatMsg,
       "A shimmering hope, the disquiet within every soul, the will to be more than that which is simply possible."
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 14 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 15)
     |> assign(
       :cheatMsg,
       "Enter your domain, then, codices in hand; demand truth of Creation with eyes opened wide!"
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 15 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 16)
     |> assign(
       :cheatMsg,
       "...a little much? I've a flair for the dramatic, I must admit, and it will be so long until I finally get to see you again, face to face, by either my reckoning, or your own. So forgive me this gentle foolishness. It is my gift to you, should you discern its value."
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 16 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(:cheat, 17)
     |> assign(
       :cheatMsg,
       "Just remember, always remember. I love you, and I want you to live."
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) when socket.assigns.cheat == 17 do
    {:noreply,
     socket
     |> assign(:state, :ready)
     |> assign(
       :cheatMsg,
       "???"
     )}
  end

  def handle_event("handViewHandSpecial", _data, socket) do
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

  def handle_event("dismiss_cheat", _, socket) do
    {:noreply,
     socket
     |> assign(:state, :ownHand)
     |> assign(:cheatMsg, nil)
     |> assign(:handView, :Hand)
     |> assign(:handMode, nil)}
  end

  def handle_event("handViewDraw", _data, socket) do
    {:noreply, socket |> assign(:handView, :Draw) |> assign(:handMode, nil)}
  end

  def handle_event("handViewDiscard", _data, socket) do
    {:noreply, socket |> assign(:handView, :Discard) |> assign(:handMode, nil)}
  end

  def handle_event("buttonPlay", _data, socket) do
    {:noreply, socket |> assign(:handMode, :Play)}
  end

  def handle_event("buttonDraw", _data, socket) do
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

  def handle_event("buttonDiscard", _data, socket) do
    {:noreply, socket |> assign(:handMode, :Discard)}
  end

  def handle_event("buttonCurse", _data, socket) do
    socket.assigns.ceremony.id
    |> Cards.Ceremony.add_card_to_entity_hand(socket.assigns.selectedEntity, 256, 1)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  def handle_event("buttonPoison", _data, socket) do
    socket.assigns.ceremony.id
    |> Cards.Ceremony.add_card_to_entity_hand(socket.assigns.selectedEntity, 257, 1)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  def handle_event("buttonExpose", _data, socket) do
    socket.assigns.ceremony.id
    |> Cards.Ceremony.add_card_to_entity_hand(socket.assigns.selectedEntity, 258, 1)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  def handle_event("buttonWound", _data, socket) do
    socket.assigns.ceremony.id
    |> Cards.Ceremony.add_card_to_entity_hand(socket.assigns.selectedEntity, 259, 1)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  def handle_event("buttonFlurry", _data, socket) do
    socket.assigns.ceremony.id
    |> Cards.Ceremony.add_card_to_entity_hand(socket.assigns.selectedEntity, 187, 4)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)

    {:noreply,
     socket
     |> assign(
       :selectedEntity,
       Cards.Ceremony.get_entity(socket.assigns.ceremony.id, socket.assigns.selectedEntity.uuid)
     )}
  end

  def handle_event("buttonScry", _data, socket) do
    {:noreply, socket |> assign(:handMode, :Scry)}
  end

  def handle_event("buttonShuffle", _data, socket) do
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

  def handle_event("buttonReturn", _data, socket) do
    {:noreply, socket |> assign(:handMode, :Return)}
  end

  def handle_event("buttonReturnRandom", _data, socket) do
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

  def handle_event("handCardClick", data, socket) when socket.assigns.handMode == :Play do
    IO.puts("PLAYING:")

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

  def handle_event("handCardClick", data, socket) when socket.assigns.handMode == :Discard do
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

  def handle_event("handCardClick", data, socket) when socket.assigns.handMode == :Scry do
    cid = socket.assigns.ceremony.id
    Cards.Ceremony.scry(cid, socket.assigns.selectedEntity, data["card"])

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

  def handle_event("handCardClick", data, socket) when socket.assigns.handMode == :Return do
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

  def handle_event("handCardClick", _data, socket) when socket.assigns.handMode == nil do
    IO.puts("NOOP")
    {:noreply, socket}
  end

  def handle_event("ownhandKey", %{"key" => "Escape"}, socket) do
    {:noreply,
     push_event(
       socket |> assign(:state, :ready) |> assign(:handMode, :Play),
       "unloadCardMenu",
       %{}
     )}
  end

  def handle_event("dismissOwnhand", _data, socket) do
    {:noreply, socket |> assign(:state, :ready) |> assign(:handMode, :Play)}
  end

  def handle_event("ownhandKey", _data, socket) do
    {:noreply, socket}
  end

  def handle_event("dismissOthershand", _data, socket) do
    {:noreply, socket |> assign(:state, :ready)}
  end

  def handle_event("othershandKey", _data, socket) do
    {:noreply, socket |> assign(:state, :ready)}
  end

  # CARD MENU

  def handle_event("cardClick", %{"id" => uuid}, socket)
      when socket.assigns.state == :setupTarget and socket.assigns.targetSource == nil do
    {:noreply, socket |> assign(:targetSource, uuid)}
  end

  def handle_event("cardClick", %{"id" => uuid}, socket)
      when socket.assigns.state == :setupTarget and socket.assigns.targetSource != nil do
    # trigger a target draw between source and target
    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "leaderLine", %{
      src: socket.assigns.targetSource,
      tgt: uuid
    })

    {:noreply, socket |> assign(:state, :ready)}
  end

  def handle_event("cardClick", data, socket) do
    entity = socket.assigns.ceremony.entities |> Enum.find(fn e -> e.uuid == data["id"] end)

    socket = socket |> assign(:state, :cardMenu) |> assign(:selectedEntity, entity)
    menuEntity = %Cards.Entity{entity | type: :Radial}

    {:noreply,
     push_event(socket, "loadCardMenu", %{
       x: Cards.Entity.screen_x(menuEntity, socket.assigns.context),
       y: Cards.Entity.screen_y(menuEntity, socket.assigns.context)
     })}
  end

  def handle_event("menuClick", %{"e" => "cardMove"}, socket) do
    socket = socket |> assign(:placingEntity, socket.assigns.selectedEntity)
    {:noreply, push_event(socket |> assign(:state, :placeEntity), "unloadAvatarMenu", %{})}
  end

  def handle_event("menuClick", %{"e" => "cardDiscard"}, socket) do
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

  def handle_event("menuClick", %{"e" => "cardDestroy"}, socket) do
    card = socket.assigns.selectedEntity

    Cards.Ceremony.removeEntity(socket.assigns.ceremony.id, card)

    StrangepathsWeb.Endpoint.broadcast(socket.assigns.ceremony.id, "updateEntities", nil)
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}
  end

  def handle_event("menuClick", %{"e" => "cardCopy"}, socket) do
    card = socket.assigns.selectedEntity

    copy = %Cards.Entity{card | uuid: Ecto.UUID.generate()}

    {:noreply,
     push_event(
       socket |> assign(:state, :placeEntity) |> assign(:placingEntity, copy),
       "unloadCardMenu",
       %{}
     )}
  end

  def handle_event("menuClick", %{"e" => "cardToDeck"}, socket) do
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

  def handle_event("menuClick", %{"e" => "cardToTopDeck"}, socket) do
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

  def handle_event("menuClick", %{"e" => "cardToHand"}, socket) do
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

  def handle_event("click", _data, socket) when socket.assigns.state == :cardMenu do
    {:noreply, push_event(socket |> assign(:state, :ready), "unloadCardMenu", %{})}
  end

  # DEFAULT NOOP CLICK AND MOVE HANDLERS

  def handle_event("click", _data, socket) do
    # noop a click if we're not in a state that accepts clicks
    {:noreply, socket}
  end

  def handle_event("move", _data, socket) when socket.assigns.pendingCeremonyUpdate == true do
    {_, ceremony} = Cards.Ceremony.get(socket.assigns.ceremony.id)
    {:noreply, socket |> assign(:pendingCeremonyUpdate, false) |> assign(:ceremony, ceremony)}
  end

  def handle_event("move", _data, socket) do
    # noop a mouse movement event if we're not in a state that accepts moves
    {:noreply, socket}
  end

  @impl true
  def handle_info(info, socket)
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

  def handle_info(info, socket)
      when info.topic == socket.assigns.ceremony.id and info.event == "leaderLine" do
    IO.inspect(info)

    {:noreply,
     push_event(
       socket,
       "drawLeaderLine",
       info.payload
     )}
  end

  def handle_info(%{event: "presence_diff", payload: _wev}, socket) do
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
        IO.puts("NICKNAME IS >>>#{nickname}<<<")
        IO.inspect(nickname)

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
           Cards.select_decks_for_ceremony(socket.assigns.current_user.id, ceremony)
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

  defp get_avatars(uid) do
    # first, get all the default avatars
    (Strangepaths.Accounts.list_public_avatars() ++
       Strangepaths.Accounts.list_avatars_of(uid))
    |> Enum.map(fn a -> Map.put(a, :selected, false) end)
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
      "???"
    else
      if type == :Grace do
        "???"
      else
        if glory do
          "????"
        else
          "???"
        end
      end
    end
  end

  defp cardclass(type, glory, aid) do
    if type == :Grace do
      "text-center text-blue-300"
    else
      if glory do
        "text-center text-yellow-300"
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
    case entity.type do
      :Avatar -> "h-24"
      :Card -> "h-72"
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
