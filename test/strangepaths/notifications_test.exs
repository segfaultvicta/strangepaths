defmodule Strangepaths.NotificationsTest do
  use Strangepaths.DataCase, async: false

  import Strangepaths.AccountsFixtures

  alias Strangepaths.Notifications
  alias Strangepaths.Accounts

  # ---- Task 1: pref_fields unit tests ----

  describe "pref_fields/1" do
    test "returns correct atom pairs for each source" do
      assert Notifications.pref_fields(:scene) == {:notif_scene_sound, :notif_scene_web}
      assert Notifications.pref_fields(:library) == {:notif_library_sound, :notif_library_web}
      assert Notifications.pref_fields(:bbs) == {:notif_bbs_sound, :notif_bbs_web}
      assert Notifications.pref_fields(:rumor) == {:notif_rumor_sound, :notif_rumor_web}
    end
  end

  # ---- Task 2: publish/3 tests ----

  describe "publish/3" do
    setup do
      # Create test users with various flag combinations
      user_sound_only = user_fixture()

      {:ok, user_sound_only} =
        Accounts.update_notification_prefs(user_sound_only, %{
          notif_bbs_sound: true,
          notif_bbs_web: false,
          notif_rumor_sound: false,
          notif_rumor_web: false
        })

      user_web_only = user_fixture()

      {:ok, user_web_only} =
        Accounts.update_notification_prefs(user_web_only, %{
          notif_bbs_sound: false,
          notif_bbs_web: true,
          notif_rumor_sound: false,
          notif_rumor_web: false
        })

      user_both = user_fixture()

      {:ok, user_both} =
        Accounts.update_notification_prefs(user_both, %{
          notif_bbs_sound: true,
          notif_bbs_web: true,
          notif_rumor_sound: true,
          notif_rumor_web: true
        })

      user_neither = user_fixture()
      # user_neither gets default values (all false), no need to update

      actor = user_fixture()

      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_bbs_sound: true,
          notif_bbs_web: true
        })

      %{
        user_sound_only: user_sound_only,
        user_web_only: user_web_only,
        user_both: user_both,
        user_neither: user_neither,
        actor: actor
      }
    end

    test "AC1.9: published payload has required fields", %{user_both: user} do
      topic = "user:#{user.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      meta = %{
        actor_id: 999,
        actor_name: "Dragon",
        title: "Test Thread",
        excerpt: "Test excerpt",
        url: "/bbs/test",
        context_key: "bbs_thread:1"
      }

      Notifications.publish(:bbs, :new_thread, meta)

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^topic,
        event: "activity",
        payload: payload
      }

      assert payload.title == "Test Thread"
      assert payload.excerpt == "Test excerpt"
      assert payload.url == "/bbs/test"
      assert payload.context_key == "bbs_thread:1"
      assert is_map(payload.cues)
      assert Map.has_key?(payload.cues, :sound)
      assert Map.has_key?(payload.cues, :web)
    end

    test "AC6.1: recipient with sound:true, web:false receives correct cues", %{
      user_sound_only: user
    } do
      topic = "user:#{user.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      meta = %{
        actor_id: 999,
        actor_name: "Dragon",
        title: "Test",
        url: "/bbs/test",
        context_key: "bbs_thread:1"
      }

      Notifications.publish(:bbs, :new_thread, meta)

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^topic,
        event: "activity",
        payload: %{cues: %{sound: true, web: false}}
      }
    end

    test "AC6.2: recipient with both flags false receives no broadcast", %{
      user_neither: user
    } do
      topic = "user:#{user.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      meta = %{
        actor_id: 999,
        actor_name: "Dragon",
        title: "Test",
        url: "/bbs/test",
        context_key: "bbs_thread:1"
      }

      Notifications.publish(:bbs, :new_thread, meta)

      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic
                     },
                     500
    end

    test "AC6.3: gating uses flag values at broadcast time", %{user_both: user} do
      topic = "user:#{user.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      meta = %{
        actor_id: 999,
        actor_name: "Dragon",
        title: "Test",
        url: "/bbs/test",
        context_key: "bbs_thread:1"
      }

      # First publish with flags enabled
      Notifications.publish(:bbs, :new_thread, meta)

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^topic,
        event: "activity"
      }

      # Disable flags
      Accounts.update_notification_prefs(user, %{
        notif_bbs_sound: false,
        notif_bbs_web: false
      })

      # Second publish should not reach the user
      Notifications.publish(:bbs, :new_thread, meta)

      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic
                     },
                     500
    end

    test "AC6.4: recipient receives broadcast only for enabled source", %{
      user_sound_only: user
    } do
      topic = "user:#{user.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      # BBS should be received (notif_bbs_sound: true)
      meta_bbs = %{
        actor_id: 999,
        actor_name: "Dragon",
        title: "Test BBS",
        url: "/bbs/test",
        context_key: "bbs_thread:1"
      }

      Notifications.publish(:bbs, :new_thread, meta_bbs)

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^topic,
        event: "activity",
        payload: %{source: :bbs}
      }

      # RUMOR should not be received (both rumor flags: false)
      meta_rumor = %{
        actor_id: 999,
        actor_name: "Dragon",
        title: "Test Rumor",
        url: "/rumor",
        context_key: "rumor"
      }

      Notifications.publish(:rumor, :node_create, meta_rumor)

      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "activity",
                       payload: %{source: :rumor}
                     },
                     500
    end

    test "actor is excluded from recipients even with flags enabled", %{actor: user} do
      topic = "user:#{user.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      meta = %{
        actor_id: user.id,
        actor_name: user.nickname || "Unknown",
        title: "Test",
        url: "/bbs/test",
        context_key: "bbs_thread:1"
      }

      Notifications.publish(:bbs, :new_thread, meta)

      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic
                     },
                     500
    end
  end

  describe "publish/3 with no eligible recipients" do
    test "AC2.6: when actor is the only eligible recipient, no broadcast is sent" do
      # Create an actor with flags enabled
      actor = user_fixture()

      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_bbs_sound: true,
          notif_bbs_web: true
        })

      # Create another user with all flags disabled
      user_no_flags = user_fixture()
      # user_no_flags gets default values (all false), no need to update

      # Subscribe both users' topics
      actor_topic = "user:#{actor.id}:notifications"
      user_no_flags_topic = "user:#{user_no_flags.id}:notifications"

      StrangepathsWeb.Endpoint.subscribe(actor_topic)
      StrangepathsWeb.Endpoint.subscribe(user_no_flags_topic)

      meta = %{
        actor_id: actor.id,
        actor_name: actor.nickname || "Unknown",
        title: "Test",
        url: "/bbs/test",
        context_key: "bbs_thread:1"
      }

      Notifications.publish(:bbs, :new_thread, meta)

      # No broadcast should be sent to the actor (excluded because they are the actor)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^actor_topic
                     },
                     500

      # No broadcast should be sent to user_no_flags (no flags enabled)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^user_no_flags_topic
                     },
                     500
    end

    test "AC2.6 non-vacuous: adding a flagged user causes broadcast to be sent" do
      # Create an actor with flags enabled
      actor = user_fixture()

      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_bbs_sound: true,
          notif_bbs_web: true
        })

      # Create another user WITH flags enabled to verify non-vacuity
      user_with_flags = user_fixture()

      {:ok, user_with_flags} =
        Accounts.update_notification_prefs(user_with_flags, %{
          notif_bbs_sound: true,
          notif_bbs_web: false
        })

      # Subscribe both users' topics
      actor_topic = "user:#{actor.id}:notifications"
      user_with_flags_topic = "user:#{user_with_flags.id}:notifications"

      StrangepathsWeb.Endpoint.subscribe(actor_topic)
      StrangepathsWeb.Endpoint.subscribe(user_with_flags_topic)

      meta = %{
        actor_id: actor.id,
        actor_name: actor.nickname || "Unknown",
        title: "Test",
        url: "/bbs/test",
        context_key: "bbs_thread:1"
      }

      Notifications.publish(:bbs, :new_thread, meta)

      # Verify the test is non-vacuous: user_with_flags DOES receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^user_with_flags_topic,
        event: "activity"
      }

      # Actor still excluded
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^actor_topic
                     },
                     500
    end
  end

  # ---- Task 1: Payload-builder unit tests ----

  describe "publish_bbs_new_thread/4" do
    setup do
      board =
        Strangepaths.Repo.insert!(%Strangepaths.BBS.Board{
          name: "Test Board",
          slug: "test-board"
        })

      actor = user_fixture()

      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_bbs_sound: true,
          notif_bbs_web: true
        })

      thread =
        Strangepaths.Repo.insert!(%Strangepaths.BBS.Thread{
          board_id: board.id,
          title: "Test Thread",
          user_id: actor.id,
          last_post_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      post =
        Strangepaths.Repo.insert!(%Strangepaths.BBS.Post{
          thread_id: thread.id,
          user_id: actor.id,
          display_name: "Actor Display",
          character_name: "Actor Char",
          content: "Test post content",
          posted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      %{board: board, actor: actor, thread: thread, post: post}
    end

    test "AC1.9: publishes payload with required fields", %{
      board: board,
      actor: actor,
      thread: thread,
      post: post
    } do
      recipient = user_fixture()

      {:ok, recipient} =
        Accounts.update_notification_prefs(recipient, %{
          notif_bbs_sound: true,
          notif_bbs_web: true
        })

      topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      Notifications.publish_bbs_new_thread(board, thread, post, actor)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "activity",
        payload: payload
      }

      assert is_binary(payload.title)
      assert String.length(payload.title) > 0
      assert is_binary(payload.excerpt)
      assert String.starts_with?(payload.url, "/")
      assert is_binary(payload.context_key)
      assert String.starts_with?(payload.context_key, "bbs_thread:")
      assert payload.cues == %{sound: true, web: true}
      assert payload.source == :bbs
      assert payload.event == :new_thread

      refute_receive %Phoenix.Socket.Broadcast{event: "activity"}, 100
    end
  end

  describe "publish_bbs_new_post/3" do
    setup do
      board =
        Strangepaths.Repo.insert!(%Strangepaths.BBS.Board{
          name: "Test Board",
          slug: "test-board"
        })

      actor = user_fixture()

      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_bbs_sound: true,
          notif_bbs_web: true
        })

      thread =
        Strangepaths.Repo.insert!(%Strangepaths.BBS.Thread{
          board_id: board.id,
          title: "Test Thread",
          user_id: actor.id,
          last_post_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      post =
        Strangepaths.Repo.insert!(%Strangepaths.BBS.Post{
          thread_id: thread.id,
          user_id: actor.id,
          display_name: "Actor Display",
          character_name: "Actor Char",
          content: "Test reply content",
          posted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      %{board: board, actor: actor, thread: thread, post: post}
    end

    test "AC1.9: publishes payload with required fields", %{
      actor: actor,
      thread: thread,
      post: post
    } do
      recipient = user_fixture()

      {:ok, recipient} =
        Accounts.update_notification_prefs(recipient, %{
          notif_bbs_sound: true,
          notif_bbs_web: true
        })

      topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      Notifications.publish_bbs_new_post(thread, post, actor)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "activity",
        payload: payload
      }

      assert is_binary(payload.title)
      assert String.length(payload.title) > 0
      assert is_binary(payload.excerpt)
      assert String.starts_with?(payload.url, "/")
      assert is_binary(payload.context_key)
      assert String.starts_with?(payload.context_key, "bbs_thread:")
      assert payload.cues == %{sound: true, web: true}
      assert payload.source == :bbs
      assert payload.event == :new_post

      refute_receive %Phoenix.Socket.Broadcast{event: "activity"}, 100
    end
  end

  describe "publish_library_body_edit/3" do
    setup do
      actor = user_fixture()

      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_library_sound: true,
          notif_library_web: true
        })

      folio =
        Strangepaths.Repo.insert!(%Strangepaths.Library.Folio{
          title: "Test Folio",
          slug: "test-folio",
          body: "Old body",
          is_private: false,
          user_id: actor.id
        })

      %{actor: actor, folio: folio}
    end

    test "AC1.3, AC1.9: publishes with non-empty excerpt, no diff markup", %{
      actor: actor,
      folio: folio
    } do
      recipient = user_fixture()

      {:ok, recipient} =
        Accounts.update_notification_prefs(recipient, %{
          notif_library_sound: true,
          notif_library_web: true
        })

      topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      diff_summary = "The [+quick+] brown [-lazy-] fox ... jumps"

      Notifications.publish_library_body_edit(folio, actor.id, diff_summary)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "activity",
        payload: payload
      }

      assert is_binary(payload.title)
      assert String.length(payload.title) > 0
      assert is_binary(payload.excerpt)
      assert String.length(payload.excerpt) > 0
      refute String.contains?(payload.excerpt, "[+")
      refute String.contains?(payload.excerpt, "[-")
      refute String.contains?(payload.excerpt, "]")
      assert String.starts_with?(payload.url, "/")
      assert payload.cues == %{sound: true, web: true}
      assert payload.source == :library
      assert payload.event == :body_edit

      refute_receive %Phoenix.Socket.Broadcast{event: "activity"}, 100
    end
  end

  describe "publish_library_marginalia/4" do
    setup do
      actor = user_fixture()

      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_library_sound: true,
          notif_library_web: true
        })

      folio =
        Strangepaths.Repo.insert!(%Strangepaths.Library.Folio{
          title: "Test Folio",
          slug: "test-folio",
          body: "Folio body",
          is_private: false,
          user_id: actor.id
        })

      entry =
        Strangepaths.Repo.insert!(%Strangepaths.Library.Entry{
          folio_id: folio.id,
          user_id: actor.id,
          kind: :note,
          position: 1,
          content: "Note content",
          name: "Note Name",
          font: "jorule",
          color: "#ff00ff"
        })

      marginalia =
        Strangepaths.Repo.insert!(%Strangepaths.Library.Marginalia{
          entry_id: entry.id,
          user_id: actor.id,
          content: "Test marginalia",
          name: "Test Nota",
          font: "jorule",
          color: "#ff00ff"
        })

      %{actor: actor, folio: folio, entry: entry, marginalia: marginalia}
    end

    test "AC1.9: publishes payload with required fields", %{
      actor: actor,
      folio: folio,
      entry: entry,
      marginalia: marginalia
    } do
      recipient = user_fixture()

      {:ok, recipient} =
        Accounts.update_notification_prefs(recipient, %{
          notif_library_sound: true,
          notif_library_web: true
        })

      topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      Notifications.publish_library_marginalia(folio, entry, marginalia, actor)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "activity",
        payload: payload
      }

      assert is_binary(payload.title)
      assert String.length(payload.title) > 0
      assert is_binary(payload.excerpt)
      assert String.starts_with?(payload.url, "/")
      assert is_binary(payload.context_key)
      assert String.starts_with?(payload.context_key, "folio:")
      assert payload.cues == %{sound: true, web: true}
      assert payload.source == :library
      assert payload.event == :marginalia

      refute_receive %Phoenix.Socket.Broadcast{event: "activity"}, 100
    end
  end

  describe "publish_scene_post/1" do
    setup do
      actor = user_fixture()

      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_scene_sound: true,
          notif_scene_web: true
        })

      scene =
        Strangepaths.Repo.insert!(%Strangepaths.Scenes.Scene{
          name: "Test Scene",
          slug: "test-scene",
          owner_id: actor.id
        })

      post =
        Strangepaths.Repo.insert!(%Strangepaths.Scenes.Post{
          scene_id: scene.id,
          user_id: actor.id,
          post_type: :character,
          author_nickname: "Display",
          content: "Test post",
          posted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      %{actor: actor, scene: scene, post: post}
    end

    test "AC1.9: publishes payload with required fields when user_id is not nil", %{
      scene: scene,
      post: post
    } do
      recipient = user_fixture()

      {:ok, recipient} =
        Accounts.update_notification_prefs(recipient, %{
          notif_scene_sound: true,
          notif_scene_web: true
        })

      topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      Notifications.publish_scene_post(%{post: post, scene: scene})

      assert_receive %Phoenix.Socket.Broadcast{
        event: "activity",
        payload: payload
      }

      assert is_binary(payload.title)
      assert String.length(payload.title) > 0
      assert is_binary(payload.excerpt)
      assert String.starts_with?(payload.url, "/")
      assert payload.cues == %{sound: true, web: true}
      assert payload.source == :scene
      assert payload.event == :new_post

      refute_receive %Phoenix.Socket.Broadcast{event: "activity"}, 100
    end

    test "AC1.8: returns :ok and publishes nothing when user_id is nil", %{scene: scene} do
      recipient = user_fixture()

      {:ok, recipient} =
        Accounts.update_notification_prefs(recipient, %{
          notif_scene_sound: true,
          notif_scene_web: true
        })

      topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      system_post =
        Strangepaths.Repo.insert!(%Strangepaths.Scenes.Post{
          scene_id: scene.id,
          user_id: nil,
          post_type: :system,
          author_nickname: "System",
          content: "System message",
          posted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      result = Notifications.publish_scene_post(%{post: system_post, scene: scene})
      assert result == :ok

      refute_receive %Phoenix.Socket.Broadcast{event: "activity"}, 100
    end
  end

  describe "publish_rumor_node/3" do
    setup do
      actor = user_fixture()

      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_rumor_sound: true,
          notif_rumor_web: true
        })

      node =
        Strangepaths.Repo.insert!(%Strangepaths.Rumor.Node{
          title: "Test Node",
          content: "Test content",
          x: 100,
          y: 100,
          color_category: "redacted"
        })

      %{actor: actor, node: node}
    end

    test "AC1.9: publishes payload for :node_create with required fields", %{
      actor: actor,
      node: node
    } do
      recipient = user_fixture()

      {:ok, recipient} =
        Accounts.update_notification_prefs(recipient, %{
          notif_rumor_sound: true,
          notif_rumor_web: true
        })

      topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      Notifications.publish_rumor_node(:node_create, node, actor)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "activity",
        payload: payload
      }

      assert is_binary(payload.title)
      assert String.length(payload.title) > 0
      assert is_binary(payload.excerpt)
      assert String.starts_with?(payload.url, "/")
      assert payload.context_key == "rumor"
      assert payload.cues == %{sound: true, web: true}
      assert payload.source == :rumor
      assert payload.event == :node_create

      refute_receive %Phoenix.Socket.Broadcast{event: "activity"}, 100
    end

    test "AC1.9: publishes payload for :node_update with required fields", %{
      actor: actor,
      node: node
    } do
      recipient = user_fixture()

      {:ok, recipient} =
        Accounts.update_notification_prefs(recipient, %{
          notif_rumor_sound: true,
          notif_rumor_web: true
        })

      topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      Notifications.publish_rumor_node(:node_update, node, actor)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "activity",
        payload: payload
      }

      assert payload.source == :rumor
      assert payload.event == :node_update

      refute_receive %Phoenix.Socket.Broadcast{event: "activity"}, 100
    end
  end

  # ---- Task 3: Recipient-resolution integration tests ----

  describe "publish/3 recipient resolution" do
    setup do
      # Create test cast
      actor = user_fixture()
      viewer_on = user_fixture()
      viewer_off = user_fixture()
      outsider = user_fixture()

      # Create dragon user and set role
      dragon = user_fixture()
      dragon = Strangepaths.Repo.update!(Ecto.Changeset.change(dragon, role: :dragon))

      # Set notification preferences
      {:ok, actor} =
        Accounts.update_notification_prefs(actor, %{
          notif_scene_sound: true,
          notif_scene_web: true,
          notif_library_sound: true,
          notif_library_web: true,
          notif_bbs_sound: true,
          notif_bbs_web: true,
          notif_rumor_sound: true,
          notif_rumor_web: true
        })

      {:ok, viewer_on} =
        Accounts.update_notification_prefs(viewer_on, %{
          notif_scene_sound: true,
          notif_scene_web: false,
          notif_library_sound: true,
          notif_library_web: false,
          notif_bbs_sound: true,
          notif_bbs_web: false,
          notif_rumor_sound: true,
          notif_rumor_web: false
        })

      {:ok, dragon} =
        Accounts.update_notification_prefs(dragon, %{
          notif_scene_sound: true,
          notif_scene_web: false,
          notif_library_sound: true,
          notif_library_web: false,
          notif_bbs_sound: true,
          notif_bbs_web: false,
          notif_rumor_sound: true,
          notif_rumor_web: false
        })

      {:ok, outsider} =
        Accounts.update_notification_prefs(outsider, %{
          notif_scene_sound: true,
          notif_scene_web: false,
          notif_library_sound: true,
          notif_library_web: false,
          notif_bbs_sound: true,
          notif_bbs_web: false,
          notif_rumor_sound: true,
          notif_rumor_web: false
        })

      # viewer_off gets default values (all false)

      %{
        actor: actor,
        viewer_on: viewer_on,
        viewer_off: viewer_off,
        dragon: dragon,
        outsider: outsider
      }
    end

    test "AC2.1: open scene reaches all flagged non-actor users",
         %{
           actor: actor,
           viewer_on: viewer_on,
           viewer_off: viewer_off,
           dragon: dragon,
           outsider: outsider
         } do
      # Subscribe all cast members
      actor_topic = "user:#{actor.id}:notifications"
      viewer_on_topic = "user:#{viewer_on.id}:notifications"
      viewer_off_topic = "user:#{viewer_off.id}:notifications"
      dragon_topic = "user:#{dragon.id}:notifications"
      outsider_topic = "user:#{outsider.id}:notifications"

      StrangepathsWeb.Endpoint.subscribe(actor_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_on_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_off_topic)
      StrangepathsWeb.Endpoint.subscribe(dragon_topic)
      StrangepathsWeb.Endpoint.subscribe(outsider_topic)

      # Create an open scene
      scene =
        Strangepaths.Repo.insert!(%Strangepaths.Scenes.Scene{
          name: "Open Scene",
          slug: "open-scene",
          locked_to_users: [],
          is_elsewhere: false,
          owner_id: actor.id
        })

      meta = %{
        actor_id: actor.id,
        actor_name: "Actor",
        title: "New post in Open Scene",
        excerpt: "Some activity",
        url: "/scenes/#{scene.slug}",
        context_key: "scene:#{scene.id}",
        scene: scene
      }

      Notifications.publish(:scene, :new_post, meta)

      # viewer_on should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^viewer_on_topic,
        event: "activity"
      }

      # dragon should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dragon_topic,
        event: "activity"
      }

      # actor should NOT receive
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^actor_topic
                     },
                     500

      # viewer_off should NOT receive (no flags)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^viewer_off_topic
                     },
                     500

      # outsider should receive (flagged and open scene)
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^outsider_topic,
        event: "activity"
      }
    end

    test "AC2.2: locked scene reaches only dragons and whitelisted users",
         %{
           actor: actor,
           viewer_on: viewer_on,
           viewer_off: viewer_off,
           dragon: dragon,
           outsider: outsider
         } do
      # Subscribe all cast members
      actor_topic = "user:#{actor.id}:notifications"
      viewer_on_topic = "user:#{viewer_on.id}:notifications"
      viewer_off_topic = "user:#{viewer_off.id}:notifications"
      dragon_topic = "user:#{dragon.id}:notifications"
      outsider_topic = "user:#{outsider.id}:notifications"

      StrangepathsWeb.Endpoint.subscribe(actor_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_on_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_off_topic)
      StrangepathsWeb.Endpoint.subscribe(dragon_topic)
      StrangepathsWeb.Endpoint.subscribe(outsider_topic)

      # Create a locked scene (only viewer_on is whitelisted)
      scene =
        Strangepaths.Repo.insert!(%Strangepaths.Scenes.Scene{
          name: "Locked Scene",
          slug: "locked-scene",
          locked_to_users: [viewer_on.id],
          is_elsewhere: false,
          owner_id: actor.id
        })

      meta = %{
        actor_id: actor.id,
        actor_name: "Actor",
        title: "New post in Locked Scene",
        excerpt: "Backchannel activity",
        url: "/scenes/#{scene.slug}",
        context_key: "scene:#{scene.id}",
        scene: scene
      }

      Notifications.publish(:scene, :new_post, meta)

      # viewer_on should receive (whitelisted)
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^viewer_on_topic,
        event: "activity"
      }

      # dragon should receive (dragons see all)
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dragon_topic,
        event: "activity"
      }

      # actor should NOT receive
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^actor_topic
                     },
                     500

      # viewer_off should NOT receive (locked and not whitelisted)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^viewer_off_topic
                     },
                     500

      # outsider should NOT receive (flagged but not whitelisted)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^outsider_topic
                     },
                     500
    end

    test "AC2.3: non-private folio reaches all flagged non-actor users",
         %{
           actor: actor,
           viewer_on: viewer_on,
           viewer_off: viewer_off,
           dragon: dragon,
           outsider: outsider
         } do
      # Subscribe all cast members
      actor_topic = "user:#{actor.id}:notifications"
      viewer_on_topic = "user:#{viewer_on.id}:notifications"
      viewer_off_topic = "user:#{viewer_off.id}:notifications"
      dragon_topic = "user:#{dragon.id}:notifications"
      outsider_topic = "user:#{outsider.id}:notifications"

      StrangepathsWeb.Endpoint.subscribe(actor_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_on_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_off_topic)
      StrangepathsWeb.Endpoint.subscribe(dragon_topic)
      StrangepathsWeb.Endpoint.subscribe(outsider_topic)

      # Create a non-private folio
      folio =
        Strangepaths.Repo.insert!(%Strangepaths.Library.Folio{
          title: "Public Folio",
          slug: "public-folio",
          body: "Some content",
          is_private: false,
          user_id: actor.id
        })

      meta = %{
        actor_id: actor.id,
        actor_name: "Actor",
        title: "Folio updated: Public Folio",
        excerpt: "Body was edited",
        url: "/library/#{folio.slug}",
        context_key: "folio:#{folio.id}",
        folio: folio
      }

      Notifications.publish(:library, :body_edit, meta)

      # viewer_on should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^viewer_on_topic,
        event: "activity"
      }

      # dragon should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dragon_topic,
        event: "activity"
      }

      # outsider should receive (folio is public)
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^outsider_topic,
        event: "activity"
      }

      # actor should NOT receive
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^actor_topic
                     },
                     500

      # viewer_off should NOT receive (no flags)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^viewer_off_topic
                     },
                     500
    end

    test "AC2.4: private folio reaches only author and dragons",
         %{
           actor: actor,
           viewer_on: viewer_on,
           viewer_off: viewer_off,
           dragon: dragon,
           outsider: outsider
         } do
      # Let viewer_on be the author of the private folio
      author = viewer_on

      # Subscribe all cast members
      actor_topic = "user:#{actor.id}:notifications"
      author_topic = "user:#{author.id}:notifications"
      viewer_off_topic = "user:#{viewer_off.id}:notifications"
      dragon_topic = "user:#{dragon.id}:notifications"
      outsider_topic = "user:#{outsider.id}:notifications"

      StrangepathsWeb.Endpoint.subscribe(actor_topic)
      StrangepathsWeb.Endpoint.subscribe(author_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_off_topic)
      StrangepathsWeb.Endpoint.subscribe(dragon_topic)
      StrangepathsWeb.Endpoint.subscribe(outsider_topic)

      # Create a private folio (owned by author)
      folio =
        Strangepaths.Repo.insert!(%Strangepaths.Library.Folio{
          title: "Private Folio",
          slug: "private-folio",
          body: "Secret content",
          is_private: true,
          user_id: author.id
        })

      # actor publishes the event
      meta = %{
        actor_id: actor.id,
        actor_name: "Actor",
        title: "Folio updated: Private Folio",
        excerpt: "Body was edited",
        url: "/library/#{folio.slug}",
        context_key: "folio:#{folio.id}",
        folio: folio
      }

      Notifications.publish(:library, :body_edit, meta)

      # author should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^author_topic,
        event: "activity"
      }

      # dragon should receive (dragons see all)
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dragon_topic,
        event: "activity"
      }

      # actor should NOT receive (excluded)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^actor_topic
                     },
                     500

      # viewer_off should NOT receive (locked folio and not author)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^viewer_off_topic
                     },
                     500

      # outsider should NOT receive (locked folio, flagged but not author)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^outsider_topic
                     },
                     500
    end

    test "AC2.5: bbs events reach all flagged non-actor users",
         %{
           actor: actor,
           viewer_on: viewer_on,
           viewer_off: viewer_off,
           dragon: dragon,
           outsider: outsider
         } do
      # Subscribe all cast members
      actor_topic = "user:#{actor.id}:notifications"
      viewer_on_topic = "user:#{viewer_on.id}:notifications"
      viewer_off_topic = "user:#{viewer_off.id}:notifications"
      dragon_topic = "user:#{dragon.id}:notifications"
      outsider_topic = "user:#{outsider.id}:notifications"

      StrangepathsWeb.Endpoint.subscribe(actor_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_on_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_off_topic)
      StrangepathsWeb.Endpoint.subscribe(dragon_topic)
      StrangepathsWeb.Endpoint.subscribe(outsider_topic)

      meta = %{
        actor_id: actor.id,
        actor_name: "Actor",
        title: "New thread in General",
        excerpt: "Check this out",
        url: "/bbs/general/123",
        context_key: "bbs_thread:123"
      }

      Notifications.publish(:bbs, :new_thread, meta)

      # viewer_on should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^viewer_on_topic,
        event: "activity"
      }

      # dragon should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dragon_topic,
        event: "activity"
      }

      # outsider should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^outsider_topic,
        event: "activity"
      }

      # actor should NOT receive
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^actor_topic
                     },
                     500

      # viewer_off should NOT receive (no flags)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^viewer_off_topic
                     },
                     500
    end

    test "AC2.5: rumor events reach all flagged non-actor users",
         %{
           actor: actor,
           viewer_on: viewer_on,
           viewer_off: viewer_off,
           dragon: dragon,
           outsider: outsider
         } do
      # Subscribe all cast members
      actor_topic = "user:#{actor.id}:notifications"
      viewer_on_topic = "user:#{viewer_on.id}:notifications"
      viewer_off_topic = "user:#{viewer_off.id}:notifications"
      dragon_topic = "user:#{dragon.id}:notifications"
      outsider_topic = "user:#{outsider.id}:notifications"

      StrangepathsWeb.Endpoint.subscribe(actor_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_on_topic)
      StrangepathsWeb.Endpoint.subscribe(viewer_off_topic)
      StrangepathsWeb.Endpoint.subscribe(dragon_topic)
      StrangepathsWeb.Endpoint.subscribe(outsider_topic)

      meta = %{
        actor_id: actor.id,
        actor_name: "Actor",
        title: "New rumor node",
        excerpt: "Interesting development",
        url: "/rumor",
        context_key: "rumor"
      }

      Notifications.publish(:rumor, :node_create, meta)

      # viewer_on should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^viewer_on_topic,
        event: "activity"
      }

      # dragon should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^dragon_topic,
        event: "activity"
      }

      # outsider should receive
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^outsider_topic,
        event: "activity"
      }

      # actor should NOT receive
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^actor_topic
                     },
                     500

      # viewer_off should NOT receive (no flags)
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^viewer_off_topic
                     },
                     500
    end
  end
end
