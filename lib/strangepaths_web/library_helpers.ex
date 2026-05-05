defmodule StrangepathsWeb.LibraryHelpers do
  @moduledoc """
  Helper functions for rendering Liminal Library content with typeface tags.

  Provides tokenize-before/restore-after pipeline to protect user content
  from Earmark interference while enabling inline HTML spans for styled text.
  """

  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 2]

  @doc """
  Renders library content with typeface tag support.

  Processes `[name]text[/name]` tags into styled spans for known typefaces,
  or literal text if the typeface name is unknown. Uses regex with `/s` and `/u`
  flags to handle newlines and Unicode. Raw user text is HTML-escaped before
  embedding; font and color values come from the hardcoded Typefaces master list.

  Returns a string containing HTML safe for raw interpolation in templates.
  """
  def render_library_content(content, opts \\ []) when is_binary(content) do
    {tokenized, token_map} = extract_typeface_tokens(content)

    tokenized
    |> render_post_content(opts)
    |> restore_typeface_tokens(token_map)
  end

  defp extract_typeface_tokens(content) do
    pattern = ~r/\[([a-z][a-z0-9_-]*)\](.*?)\[\/\1\]/su

    Regex.scan(pattern, content)
    |> Enum.reduce({content, %{}}, fn [full_match, name, text], {acc_content, acc_tokens} ->
      # Use unicode private-use area prefix to prevent collision with user text.
      # Trailing LLITOK suffix prevents token-vs-token prefix collisions: LLITOK1 is no longer a prefix of LLITOK10.
      token = <<0xE000::utf8>> <> "LLITOK#{map_size(acc_tokens)}LLITOK"

      {
        # global: false replaces the first match only — prevents corrupting later matches that share text
        String.replace(acc_content, full_match, token, global: false),
        Map.put(acc_tokens, token, {name, text})
      }
    end)
  end

  defp restore_typeface_tokens(html, token_map) do
    Enum.reduce(token_map, html, fn {token, {name, raw_text}}, acc ->
      replacement =
        case Strangepaths.Library.Typefaces.find(name) do
          nil ->
            "[#{name}]#{raw_text}[/#{name}]"

          tf ->
            inner =
              raw_text
              |> render_post_content([])
              |> String.replace(~r/<\/p>\s*<p>/, "<br><br>")
              |> String.replace("<p>", "")
              |> String.replace("</p>", "")
              |> String.trim()

            ~s(<span style="font-family: #{tf.font}; color: #{tf.color}; font-size: #{tf.font_size};">#{inner}</span>)
        end

      String.replace(acc, token, replacement)
    end)
  end
end
