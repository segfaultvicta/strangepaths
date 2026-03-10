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

  @glyph_labels %{
    "⚗" => "Burning",
    "ⵣ" => "Flourishing",
    "⌬" => "Pellucid",
    "☉" => "Radiant",
    "ᛝ" => "Tenebrous",
    "ꙮ" => "Liminal"
  }

  @glyph_chars Map.keys(@glyph_styles)

  def glyph_chars, do: @glyph_chars

  @escape_placeholders @glyph_chars
                        |> Enum.with_index()
                        |> Enum.map(fn {glyph, i} -> {glyph, "\0GESC_#{i}\0"} end)
                        |> Map.new()

  defp protect_escapes(text) do
    Enum.reduce(@escape_placeholders, text, fn {glyph, placeholder}, acc ->
      String.replace(acc, "[#{glyph}]", placeholder)
    end)
  end

  defp restore_escapes(text) do
    Enum.reduce(@escape_placeholders, text, fn {glyph, placeholder}, acc ->
      String.replace(acc, placeholder, glyph)
    end)
  end

  defp strip_bare_glyphs(text) do
    Enum.reduce(@glyph_chars, text, fn glyph, acc ->
      String.replace(acc, glyph, "")
    end)
  end

  @doc """
  Replaces glyph pairs with readable plaintext labels.
  E.g. ⚗text⚗ becomes [Burning]text[/Burning]
  Escaped glyphs like [⚗] render as the literal character.
  Unpaired glyphs are silently stripped.
  """
  def process_inline_glyphs_plaintext(text, opts \\ []) do
    text
    |> protect_escapes()
    |> then(fn t ->
      Enum.reduce(@glyph_labels, t, fn {glyph, label}, acc ->
        Regex.replace(
          ~r/#{Regex.escape(glyph)}(.*?)#{Regex.escape(glyph)}/s,
          acc,
          "[#{label}]\\1[/#{label}]"
        )
      end)
    end)
    |> maybe_strip_bare_glyphs(opts)
    |> restore_escapes()
  end

  @doc """
  Removes glyph marker characters from text without adding styling.
  Escaped glyphs like [⚗] are preserved as literal characters.
  """
  def strip_glyphs(text) do
    text
    |> protect_escapes()
    |> strip_bare_glyphs()
    |> restore_escapes()
  end

  @doc """
  Replaces glyph pairs with styled HTML spans.
  Escaped glyphs like [⚗] render as the literal character.
  Unpaired glyphs are silently stripped unless `narrative: true` is passed.
  """
  def process_inline_glyphs(html, opts \\ []) do
    html
    |> protect_escapes()
    |> then(fn t ->
      Enum.reduce(@glyph_styles, t, fn {glyph, class}, acc ->
        Regex.replace(
          ~r/#{Regex.escape(glyph)}(.*?)#{Regex.escape(glyph)}/s,
          acc,
          "<span class=\"#{class}\">\\1</span>"
        )
      end)
    end)
    |> maybe_strip_bare_glyphs(opts)
    |> restore_escapes()
  end

  defp maybe_strip_bare_glyphs(text, opts) do
    if Keyword.get(opts, :narrative, false), do: text, else: strip_bare_glyphs(text)
  end
end
