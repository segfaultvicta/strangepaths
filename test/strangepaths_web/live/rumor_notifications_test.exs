defmodule StrangepathsWeb.RumorNotificationsTest do
  use StrangepathsWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures

  setup do
    # Create actor (dragon)
    actor = user_fixture()
    actor = Strangepaths.Repo.update!(Ecto.Changeset.change(actor, role: :dragon))

    {:ok, actor} =
      Strangepaths.Accounts.update_notification_prefs(actor, %{
        notif_rumor_sound: true,
        notif_rumor_web: true
      })

    # Create recipient user with all rumor notification flags enabled
    recipient = user_fixture()

    {:ok, recipient} =
      Strangepaths.Accounts.update_notification_prefs(recipient, %{
        notif_rumor_sound: true,
        notif_rumor_web: true
      })

    %{actor: actor, recipient: recipient}
  end

  describe "AC1.4: Node create publishes exactly one activity broadcast" do
    test "create_node publishes activity notification", %{
      actor: actor,
      recipient: recipient
    } do
      # Create a logged-in connection for the actor
      conn = log_in_user(build_conn(), actor)

      # Subscribe recipient to their notifications topic
      recipient_topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(recipient_topic)

      # Mount the rumor map and create a node
      {:ok, view, _html} = live(conn, "/rumor")

      # Render the create_node hook
      render_hook(view, "create_node", %{"x" => 10, "y" => 10})

      # Verify exactly one activity broadcast is received
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity",
                       payload: %{
                         source: :rumor,
                         event: :node_create,
                         context_key: "rumor"
                       }
                     },
                     2000

      # Verify no second broadcast
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity"
                     },
                     100
    end
  end

  describe "AC1.7: Node move does not publish activity broadcast" do
    test "update_node_position does not trigger activity broadcast", %{
      actor: actor,
      recipient: recipient
    } do
      # Create a logged-in connection for the actor
      conn = log_in_user(build_conn(), actor)

      # Subscribe to notifications topic
      recipient_topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(recipient_topic)

      # Also subscribe to rumor_map topic to capture broadcasts
      StrangepathsWeb.Endpoint.subscribe("rumor_map")

      # Mount the rumor map
      {:ok, view, _html} = live(conn, "/rumor")

      # Create a node first
      render_hook(view, "create_node", %{"x" => 100, "y" => 100})

      # Consume the activity broadcast from node creation
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity",
                       payload: %{event: :node_create}
                     },
                     2000

      # Capture the node ID from the node_created broadcast on rumor_map topic
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "rumor_map",
                       event: "node_created",
                       payload: %{node: node}
                     },
                     2000

      # Now move the node using the real node ID
      render_hook(view, "update_node_position", %{
        "node_id" => to_string(node.id),
        "x" => 200,
        "y" => 200
      })

      # CRITICAL: Verify the move handler actually ran by asserting node_moved broadcast
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "rumor_map",
                       event: "node_moved",
                       payload: %{node_id: _}
                     },
                     2000

      # Verify NO activity broadcast on recipient topic after move
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity"
                     },
                     300
    end
  end

  describe "AC1.4: Node update (save) publishes exactly one activity broadcast" do
    test "save_node publishes activity notification", %{
      actor: actor,
      recipient: recipient
    } do
      # Create a logged-in connection for the actor
      conn = log_in_user(build_conn(), actor)

      # Subscribe to notifications topic
      recipient_topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(recipient_topic)

      # Also subscribe to rumor_map to capture node creation
      StrangepathsWeb.Endpoint.subscribe("rumor_map")

      # Mount the rumor map
      {:ok, view, _html} = live(conn, "/rumor")

      # Create a node first
      render_hook(view, "create_node", %{"x" => 100, "y" => 100})

      # Drain the create activity broadcast
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity",
                       payload: %{event: :node_create}
                     },
                     2000

      # Capture the node ID from the node_created broadcast
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "rumor_map",
                       event: "node_created",
                       payload: %{node: node}
                     },
                     2000

      # Start editing the node
      render_hook(view, "start_editing_node", %{"node-id" => to_string(node.id)})

      # Save the node with updated title
      render_hook(view, "save_node", %{"node" => %{"title" => "renamed"}})

      # Verify exactly one activity broadcast for node_update
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity",
                       payload: %{source: :rumor, event: :node_update, context_key: "rumor"}
                     },
                     2000

      # Verify no second broadcast
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity"
                     },
                     100
    end
  end

  describe "AC1.7: Node delete does not publish activity broadcast" do
    test "delete_node does not trigger activity broadcast", %{
      actor: actor,
      recipient: recipient
    } do
      # Create a logged-in connection for the actor
      conn = log_in_user(build_conn(), actor)

      # Subscribe to notifications topic
      recipient_topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(recipient_topic)

      # Also subscribe to rumor_map
      StrangepathsWeb.Endpoint.subscribe("rumor_map")

      # Mount the rumor map
      {:ok, view, _html} = live(conn, "/rumor")

      # Create a node first
      render_hook(view, "create_node", %{"x" => 100, "y" => 100})

      # Drain the create activity broadcast
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity",
                       payload: %{event: :node_create}
                     },
                     2000

      # Capture the node ID from the node_created broadcast
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "rumor_map",
                       event: "node_created",
                       payload: %{node: node}
                     },
                     2000

      # Delete the node
      render_hook(view, "delete_node", %{"node-id" => to_string(node.id)})

      # Verify the delete handler ran by asserting node_deleted broadcast
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "rumor_map",
                       event: "node_deleted",
                       payload: %{node_id: _}
                     },
                     2000

      # Verify NO activity broadcast on recipient topic
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity"
                     },
                     300
    end
  end

  describe "AC1.7: Connection create from modal does not publish activity broadcast" do
    test "create_connection_from_modal does not trigger activity broadcast", %{
      actor: actor,
      recipient: recipient
    } do
      # Create a logged-in connection for the actor
      conn = log_in_user(build_conn(), actor)

      # Subscribe to notifications topic
      recipient_topic = "user:#{recipient.id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(recipient_topic)

      # Also subscribe to rumor_map
      StrangepathsWeb.Endpoint.subscribe("rumor_map")

      # Mount the rumor map
      {:ok, view, _html} = live(conn, "/rumor")

      # Create two nodes
      render_hook(view, "create_node", %{"x" => 100, "y" => 100})
      render_hook(view, "create_node", %{"x" => 200, "y" => 200})

      # Drain both create activity broadcasts
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity",
                       payload: %{event: :node_create}
                     },
                     2000

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity",
                       payload: %{event: :node_create}
                     },
                     2000

      # Capture both node IDs from node_created broadcasts
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "rumor_map",
                       event: "node_created",
                       payload: %{node: node1}
                     },
                     2000

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "rumor_map",
                       event: "node_created",
                       payload: %{node: node2}
                     },
                     2000

      # Create a connection from node1 to node2
      render_hook(view, "create_connection_from_modal", %{
        "from-node-id" => to_string(node1.id),
        "to-node-id" => to_string(node2.id)
      })

      # Verify the connection creation handler ran by asserting connection_created broadcast
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "rumor_map",
                       event: "connection_created",
                       payload: %{connection: _connection}
                     },
                     2000

      # Verify NO activity broadcast on recipient topic
      refute_receive %Phoenix.Socket.Broadcast{
                       topic: ^recipient_topic,
                       event: "activity"
                     },
                     300
    end
  end
end
