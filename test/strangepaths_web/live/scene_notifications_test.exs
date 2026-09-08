defmodule StrangepathsWeb.SceneNotificationsTest do
  use StrangepathsWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures

  alias Strangepaths.Scenes

  setup do
    # Create actor (dragon with public_ascension to enable posting)
    actor = user_fixture()

    actor =
      Strangepaths.Repo.update!(
        Ecto.Changeset.change(actor, role: :dragon, public_ascension: true)
      )

    {:ok, actor} =
      Strangepaths.Accounts.update_notification_prefs(actor, %{
        notif_scene_sound: true,
        notif_scene_web: true
      })

    # Create recipient user with scene notifications enabled and public_ascension
    # so they can post IC messages (post_message requires user to be in rhs_users)
    recipient = user_fixture()

    recipient =
      Strangepaths.Repo.update!(
        Ecto.Changeset.change(recipient, public_ascension: true)
      )

    {:ok, recipient} =
      Strangepaths.Accounts.update_notification_prefs(recipient, %{
        notif_scene_sound: true,
        notif_scene_web: true
      })

    # Create an active test scene
    scene =
      Strangepaths.Repo.insert!(%Strangepaths.Scenes.Scene{
        name: "Test Scene",
        slug: "test-scene",
        owner_id: actor.id,
        locked_to_users: [],
        status: :active
      })

    %{actor: actor, recipient: recipient, scene: scene}
  end

  describe "AC1.1: Scene narrative post publishes exactly one activity broadcast" do
    test "post_narrative publishes activity notification", %{
      actor: actor,
      recipient: recipient,
      scene: scene
    } do
      # Create a logged-in connection for the actor
      conn = log_in_user(build_conn(), actor)

      # Subscribe recipient to their notifications topic
      recipient_topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(recipient_topic)

      # Mount the scenes LiveView and select the scene
      {:ok, view, _html} = live(conn, "/scenes")

      # Render the select_scene hook to select the scene
      render_hook(view, "select_scene", %{"scene_id" => to_string(scene.id)})

      # Render the post_narrative hook to post a narrative
      render_hook(view, "post_narrative", %{"content" => "hello narrative"})

      # Verify exactly one activity broadcast is received
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity",
                       payload: %{
                         source: :scene,
                         event: :new_post,
                         context_key: "scene:" <> _
                       }
                     },
                     2000

      # Verify no second broadcast
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity"
                     },
                     300
    end
  end

  describe "AC1.8: System message does not publish an activity broadcast" do
    test "system_message does not trigger activity broadcast", %{
      recipient: recipient,
      scene: scene
    } do
      # Subscribe recipient to both the scene topic (to verify system message path runs)
      # and their notifications topic (to verify no activity broadcast)
      scene_topic = "scene:#{scene.id}"
      recipient_topic = "user:#{recipient.id}:notifications"

      StrangepathsWeb.Endpoint.subscribe(scene_topic)
      StrangepathsWeb.Endpoint.subscribe(recipient_topic)

      # Call system_message directly (production path for system posts)
      Scenes.system_message("System test message", false, scene.id)

      # Verify the system message path ran (broadcast on scene topic)
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^scene_topic,
                       event: "new_post"
                     },
                     1000

      # Verify NO activity broadcast on recipient topic
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity"
                     },
                     100
    end
  end
end
