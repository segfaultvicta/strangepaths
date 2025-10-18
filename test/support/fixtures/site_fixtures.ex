defmodule Strangepaths.SiteFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Strangepaths.Site` context.
  """

  @doc """
  Generate a song.
  """
  def song_fixture(attrs \\ %{}) do
    {:ok, song} =
      attrs
      |> Enum.into(%{
        link: "some link",
        title: "some title",
        text: "some text",
        unlocked: true
      })
      |> Strangepaths.Site.create_song()

    song
  end
end
