defmodule Strangepaths.BBSFixtures do
  @moduledoc """
  This module defines test fixtures for the BBS context.
  """

  alias Strangepaths.Accounts

  def board_fixture(attrs \\ %{}) do
    {:ok, board} =
      attrs
      |> Enum.into(%{
        name: "Test Board",
        description: "A test board"
      })
      |> Strangepaths.BBS.create_board()

    board
  end

  def thread_fixture(board \\ nil, user \\ nil, attrs \\ %{}) do
    board = board || board_fixture()
    user = user || user_fixture()

    merged_attrs =
      attrs
      |> Enum.into(%{
        "title" => "Test Thread",
        "content" => "Test content",
        "display_name" => user.nickname
      })

    {:ok, {thread, _post}} = Strangepaths.BBS.create_thread(board, user, merged_attrs)

    thread
  end

  def post_fixture(thread \\ nil, user \\ nil, attrs \\ %{}) do
    thread = thread || thread_fixture()
    user = user || user_fixture()

    merged_attrs =
      attrs
      |> Enum.into(%{
        "content" => "Test post content",
        "display_name" => user.nickname
      })

    {:ok, post} = Strangepaths.BBS.create_post(thread, user, merged_attrs)

    post
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "user-#{System.unique_integer()}@example.com",
        nickname: "TestUser",
        password: "Test123456789"
      })
      |> Accounts.register_user()

    user
  end
end
