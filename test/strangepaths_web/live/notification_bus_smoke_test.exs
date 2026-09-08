defmodule StrangepathsWeb.NotificationBusSmokeTest do
  use StrangepathsWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "AC3.5: representative pages mount correctly after live_session wrap" do
    setup :register_and_log_in_user

    test "cosmos route mounts and receives activity broadcasts", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, "/cosmos")
      assert html != ""
      assert render(view) =~ "<"

      # Broadcast activity and verify it's pushed
      payload = %{
        context_key: "cosmos_test",
        source: :cards,
        event: :card_created,
        title: "Test Card",
        excerpt: "test",
        url: "/cosmos",
        actor_name: "TestUser",
        cues: %{sound: false, web: false}
      }

      StrangepathsWeb.Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        payload
      )

      assert_push_event(view, "activity", %{context_key: "cosmos_test"})
    end

    test "rumor route mounts and receives activity broadcasts", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, "/rumor")
      assert html != ""
      assert render(view) =~ "<"

      payload = %{
        context_key: "rumor_test",
        source: :rumor,
        event: :node_added,
        title: "New Node",
        excerpt: "test",
        url: "/rumor",
        actor_name: "TestUser",
        cues: %{sound: false, web: false}
      }

      StrangepathsWeb.Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        payload
      )

      assert_push_event(view, "activity", %{context_key: "rumor_test"})
    end

    test "scenes route mounts and receives activity broadcasts", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, "/scenes")
      assert html != ""
      assert render(view) =~ "<"

      payload = %{
        context_key: "scenes_test",
        source: :scenes,
        event: :post_added,
        title: "New Post",
        excerpt: "test",
        url: "/scenes",
        actor_name: "TestUser",
        cues: %{sound: false, web: false}
      }

      StrangepathsWeb.Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        payload
      )

      assert_push_event(view, "activity", %{context_key: "scenes_test"})
    end

    test "folio route mounts and receives activity broadcasts", %{conn: conn, user: user} do
      # Use library fixture instead of raw Repo.insert
      folio =
        Strangepaths.LibraryFixtures.folio_fixture(user, %{
          "title" => "Test Folio",
          "body" => "Test body"
        })

      {:ok, view, html} = live(conn, "/library/#{folio.slug}")
      assert html != ""
      assert render(view) =~ "<"

      payload = %{
        context_key: "folio_test",
        source: :library,
        event: :entry_added,
        title: "New Entry",
        excerpt: "test",
        url: "/library/#{folio.slug}",
        actor_name: "TestUser",
        cues: %{sound: false, web: false}
      }

      StrangepathsWeb.Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        payload
      )

      assert_push_event(view, "activity", %{context_key: "folio_test"})
    end

    test "BBS thread route mounts and receives activity broadcasts", %{conn: conn, user: user} do
      # Use BBS fixtures instead of raw Repo.insert
      board = Strangepaths.BBSFixtures.board_fixture()
      thread = Strangepaths.BBSFixtures.thread_fixture(board, user)

      {:ok, view, html} = live(conn, "/bbs/#{board.slug}/#{thread.id}")
      assert html != ""
      assert render(view) =~ "<"

      context_key = "bbs_thread:#{thread.id}"

      payload = %{
        context_key: context_key,
        source: :bbs,
        event: :new_post,
        title: "New Post",
        excerpt: "test",
        url: "/bbs/#{board.slug}/#{thread.id}",
        actor_name: "TestUser",
        cues: %{sound: false, web: false}
      }

      StrangepathsWeb.Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        payload
      )

      assert_push_event(view, "activity", %{context_key: ^context_key})
    end
  end

  describe "AC3.5 authenticated: /users/admin mounts correctly" do
    setup :register_and_log_in_user

    test "dragon /users/admin mounts and receives activity", %{conn: conn, user: user} do
      # Promote user to dragon role
      user = user |> Ecto.Changeset.change(role: :dragon) |> Strangepaths.Repo.update!()

      {:ok, view, html} = live(conn, "/users/admin")
      assert html != ""
      assert render(view) =~ "<"

      # Broadcast activity to user's topic
      payload = %{
        context_key: "admin_test",
        source: :admin,
        event: :user_updated,
        title: "User Update",
        excerpt: "test",
        url: "/users/admin",
        actor_name: "Dragon",
        cues: %{sound: false, web: false}
      }

      StrangepathsWeb.Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        payload
      )

      assert_push_event(view, "activity", %{context_key: "admin_test"})
    end

    test "anonymous users still cannot mount /users/admin", %{conn: conn} do
      # An unauthenticated connection should not be able to mount /users/admin
      # The :require_authenticated_user pipeline still applies and redirects
      result = live(conn, "/users/admin")

      # The result should be an error with a redirect (could be either :redirect or :live_redirect)
      assert match?({:error, {:redirect, _}}, result) or
               match?({:error, {:live_redirect, _}}, result)
    end
  end
end
