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
    user = user || Accounts.get_user!(1) || user_fixture()

    {:ok, {thread, _post}} =
      attrs
      |> Enum.into(%{
        "title" => "Test Thread",
        "content" => "Test content",
        "display_name" => user.nickname
      })
      |> Strangepaths.BBS.create_thread(board, user)

    thread
  end

  def post_fixture(thread \\ nil, user \\ nil, attrs \\ %{}) do
    thread = thread || thread_fixture()
    user = user || Accounts.get_user!(1) || user_fixture()

    {:ok, post} =
      attrs
      |> Enum.into(%{
        "content" => "Test post content",
        "display_name" => user.nickname
      })
      |> Strangepaths.BBS.create_post(thread, user)

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
