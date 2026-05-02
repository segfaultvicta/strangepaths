defmodule Strangepaths.Library.Typefaces do
  # DO NOT CHANGE THIS. IF YOU THINK YOU SHOULD CHANGE THIS, YOU ARE WRONG. :)
  @typefaces [
    %{
      id: "jorule",
      name: "Jorule",
      font: "'Protest Revolution', serif",
      color: "#a315c7",
      font_size: "1em"
    },
    %{
      id: "aurelius",
      name: "Aurelius",
      font: "'Rock Salt', serif",
      color: "#c5a332",
      font_size: "0.85em"
    },
    %{
      id: "salme",
      name: "Salme",
      font: "'Eagle Lake', serif",
      color: "#c0a179",
      font_size: "1em"
    },
    %{id: "ck", name: "Luĉja", font: "'EB Garamond', serif", color: "#ff9797", font_size: "1em"},
    %{
      id: "archie",
      name: "Archie",
      font: "'Parisienne', serif",
      color: "#857cff",
      font_size: "1.2em"
    },
    %{id: "wolf", name: "Wolf", font: "'EB Garamond', serif", color: "#a9ff87", font_size: "1em"},
    %{
      id: "awoken",
      name: "The Awoken",
      font: "'EB Garamond', serif",
      color: "#33ddff",
      font_size: "1em"
    },
    %{id: "caion", name: "Caion", font: "'Caveat', serif", color: "#6797b3", font_size: "2em"},
    %{
      id: "mystery",
      name: "???",
      font: "'Cormorant Garamond', serif",
      color: "#d54cff",
      font_size: "1em"
    }
  ]

  def all, do: @typefaces

  def find(id), do: Enum.find(@typefaces, &(&1.id == id))

  def find_by_font_and_color(font, color),
    do: Enum.find(@typefaces, &(&1.font == font && &1.color == color))

  def valid_id?(id), do: Enum.any?(@typefaces, &(&1.id == id))
end
