defmodule StrangepathsWeb.LibraryHelpers do
  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 2]

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
      token = "LLITOK#{map_size(acc_tokens)}LLITOK"

      {
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
            escaped = Phoenix.HTML.html_escape(raw_text) |> Phoenix.HTML.safe_to_string()
            ~s(<span style="font-family: #{tf.font}; color: #{tf.color};">#{escaped}</span>)
        end

      String.replace(acc, token, replacement)
    end)
  end
end
