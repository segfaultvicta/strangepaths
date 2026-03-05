defmodule StrangepathsWeb.SceneHelpers do
  @moduledoc """
  Shared helpers for scene rendering used by both live scenes and archives.
  """

  @glyph_styles %{
    "⚗" => "inline-burning-gnosis",
    "ⵣ" => "inline-flourishing-gnosis",
    "⌬" => "inline-pellucid-gnosis",
    "☉" => "inline-radiant-gnosis",
    "ᛝ" => "inline-tenebrous-gnosis",
    "ꙮ" => "inline-liminal"
  }

  @doc """
  Wraps text between matching glyph pairs in colored spans.
  E.g. ⚗text⚗ becomes <span class="inline-burning-gnosis">text</span>
  """
  @glyph_chars Map.keys(@glyph_styles)

  @doc """
  Removes glyph marker characters from text without adding styling.
  """
  def strip_glyphs(text) do
    Enum.reduce(@glyph_chars, text, fn glyph, acc ->
      String.replace(acc, glyph, "")
    end)
  end

  def process_inline_glyphs(html) do
    Enum.reduce(@glyph_styles, html, fn {glyph, class}, acc ->
      Regex.replace(
        ~r/#{Regex.escape(glyph)}(.*?)#{Regex.escape(glyph)}/s,
        acc,
        "<span class=\"#{class}\">\\1</span>"
      )
    end)
  end
end
