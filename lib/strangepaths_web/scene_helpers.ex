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
                        |> Enum.map(fn {glyph, i} -> {glyph, "GLYPHESC#{i}GLYPHESC"} end)
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
  Renders post content: processes glyph pairs before Earmark so that
  markdown inside glyph spans doesn't interfere with the outer *...* italic
  wrapping applied to IC posts.

  Escaped glyphs like [⚗] render as the literal character.
  Unpaired glyphs are silently stripped unless `narrative: true` is passed.
  """
  def render_post_content(content, opts \\ []) do
    {tokenized, token_map} =
      content
      |> protect_escapes()
      |> extract_glyph_tokens()

    tokenized
    |> Earmark.as_html!(sub_sup: true)
    |> restore_glyph_tokens(token_map)
    |> maybe_strip_bare_glyphs(opts)
    |> restore_escapes()
    |> deitalicize_nested_ems()
  end

  defp extract_glyph_tokens(text) do
    Enum.reduce(@glyph_styles, {text, %{}}, fn {glyph, class}, {acc_text, acc_tokens} ->
      pattern = ~r/#{Regex.escape(glyph)}(.*?)#{Regex.escape(glyph)}/s

      Regex.scan(pattern, acc_text)
      |> Enum.reduce({acc_text, acc_tokens}, fn [full_match, content], {t, m} ->
        token = "GLYPHTOKEN#{map_size(m)}GLYPHTOKEN"
        {String.replace(t, full_match, token, global: false), Map.put(m, token, {content, class})}
      end)
    end)
  end

  defp restore_glyph_tokens(html, token_map) do
    Enum.reduce(token_map, html, fn {token, {content, class}}, acc ->
      inner =
        content
        |> Earmark.as_html!(sub_sup: true)
        |> String.replace("<p>", "")
        |> String.replace("</p>", "")
        |> String.trim()

      String.replace(acc, token, "<span class=\"#{class}\">#{inner}</span>")
    end)
  end

  defp deitalicize_nested_ems(html) do
    {parts, _depth} =
      html
      |> String.split(~r/(<\/?em>)/, include_captures: true)
      |> Enum.map_reduce(0, fn
        "<em>", depth when depth > 0 -> {"<em style=\"font-style:normal\">", depth + 1}
        "<em>", depth -> {"<em>", depth + 1}
        "</em>", depth -> {"</em>", max(depth - 1, 0)}
        other, depth -> {other, depth}
      end)

    Enum.join(parts)
  end

  defp maybe_strip_bare_glyphs(text, opts) do
    if Keyword.get(opts, :narrative, false), do: text, else: strip_bare_glyphs(text)
  end
end
