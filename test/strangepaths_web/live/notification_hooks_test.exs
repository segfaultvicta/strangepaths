defmodule StrangepathsWeb.NotificationHooksTest do
  use StrangepathsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Strangepaths.BBSFixtures
  alias Strangepaths.BBS

  describe "on_mount(:subscribe) hook" do
    setup :register_and_log_in_user

    test "AC3.1 + AC3.2: subscription and activity broadcast forwarding", %{
      conn: conn,
      user: user
    } do
      # Mount a LiveView through the router
      {:ok, view, _html} = live(conn, "/cosmos")

      # Broadcast an activity message to the user's notifications topic
      payload = %{
        context_key: "bbs_thread:1",
        source: :bbs,
        event: :new_post,
        title: "Test Thread",
        excerpt: "Test content",
        url: "/bbs/x/1",
        actor_name: "TestUser",
        cues: %{sound: true, web: false}
      }

      StrangepathsWeb.Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        payload
      )

      # Assert the activity broadcast was pushed to the client
      assert_push_event(view, "activity", %{context_key: "bbs_thread:1"})
    end

    test "AC3.3: non-activity and unrelated messages pass through unchanged", %{
      conn: conn,
      user: user
    } do
      # Mount BBSLive.Thread with a real board and thread
      board = BBSFixtures.board_fixture()
      thread = BBSFixtures.thread_fixture(board, user, %{"title" => "Test Thread"})

      {:ok, view, html} = live(conn, "/bbs/#{board.slug}/#{thread.id}")
      assert html != ""

      # Create a new post via the BBS context (ensures all fields are properly set)
      {:ok, new_post} =
        BBS.create_post(thread, user, %{
          "content" => "UNIQUE_TEST_BROADCAST_CONTENT_XYZ_123",
          "display_name" => user.nickname
        })

      # Broadcast a "new_post" event on the thread's topic (not an "activity" event)
      # This tests that the notification hook doesn't swallow unrelated handle_info messages
      StrangepathsWeb.Endpoint.broadcast(
        "bbs_thread:#{thread.id}",
        "new_post",
        %{post: new_post}
      )

      # The hook's catch-all should return {:cont, socket}, allowing the
      # LiveView's handle_info to process it and append the post to the render
      assert render(view) =~ "UNIQUE_TEST_BROADCAST_CONTENT_XYZ_123"
    end

    test "AC3.4: disconnected mount does not subscribe or crash", %{conn: _conn} do
      # Call on_mount directly with a disconnected socket
      # A disconnected socket has transport_pid: nil
      socket = %Phoenix.LiveView.Socket{
        transport_pid: nil
      }

      session = %{"user_token" => nil}

      # Should return {:cont, socket} without raising
      assert {:cont, _returned_socket} =
               StrangepathsWeb.NotificationHooks.on_mount(:subscribe, %{}, session, socket)
    end

    test "AC3.4: valid token but disconnected does not subscribe", %{user: user} do
      # Create a session with a valid user token
      token = Strangepaths.Accounts.generate_user_session_token(user)

      session = %{"user_token" => token}

      # Create a disconnected socket (transport_pid: nil)
      socket = %Phoenix.LiveView.Socket{
        transport_pid: nil
      }

      # Call on_mount
      {:cont, _returned_socket} =
        StrangepathsWeb.NotificationHooks.on_mount(:subscribe, %{}, session, socket)

      # Verify no subscribe happened by checking we don't receive a broadcast
      StrangepathsWeb.Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        %{context_key: "test"}
      )

      # This process should not have received the broadcast
      refute_receive %Phoenix.Socket.Broadcast{}
    end
  end
end
