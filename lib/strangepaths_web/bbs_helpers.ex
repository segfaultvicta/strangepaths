defmodule StrangepathsWeb.BBSHelpers do
  @moduledoc """
  Helpers for BBS post rendering, including quote block processing.
  """

  import StrangepathsWeb.SceneHelpers

  @doc """
  Formats a datetime for BBS post display (e.g., "Apr 13, 2026 at 03:45 PM").
  Uses %I for 12-hour zero-padded format (03 instead of 3).
  """
  def format_timestamp(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  @doc """
  Renders BBS post content with quote block processing.
  Pre-processes [quote ...] blocks to HTML before markdown rendering.
  Escapes raw HTML in user content to prevent stored XSS.

  The quote tag format is:
  [quote id=N author="..." thread_id=M board="slug"]excerpt[/quote]

  Args:
    - content: The raw post content string
    - current_thread_id: The ID of the current thread (optional, for same-thread detection)

  Returns: HTML string safe for rendering with |> raw
  """
  def render_bbs_post_content(content, current_thread_id \\ nil) do
    quote_regex =
      ~r/\[quote id=(\d+) author="([^"]*)" thread_id=(\d+) board="([^"]*)"\](.*?)\[\/quote\]/s

    # Extract all quote blocks with their captures for later rendering
    quote_matches = Regex.scan(quote_regex, content, capture: :all_but_first)

    # Replace quote blocks with numbered placeholders to preserve them
    {content_with_placeholders, _} =
      Enum.reduce(quote_matches, {content, 0}, fn _match, {text, index} ->
        placeholder = "___QUOTE_BLOCK_#{index}___"
        # Replace the entire quote block (capture group 0) with placeholder
        new_text = Regex.replace(quote_regex, text, placeholder, global: false)
        {new_text, index + 1}
      end)

    # HTML-escape the remaining user content to prevent raw <tag> injection
    escaped_content =
      Phoenix.HTML.html_escape(content_with_placeholders) |> Phoenix.HTML.safe_to_string()

    # Render quote blocks and restore them
    restored_content =
      Enum.reduce(quote_matches, escaped_content, fn [
                                                       id_str,
                                                       author,
                                                       thread_id_str,
                                                       board,
                                                       excerpt
                                                     ],
                                                     text ->
        index_str =
          Integer.to_string(
            Enum.find_index(
              quote_matches,
              &(&1 == [id_str, author, thread_id_str, board, excerpt])
            )
          )

        placeholder = "___QUOTE_BLOCK_#{index_str}___"

        html =
          render_quote_block(
            String.to_integer(id_str),
            author,
            String.to_integer(thread_id_str),
            board,
            excerpt,
            current_thread_id
          )

        String.replace(text, placeholder, html)
      end)

    # Then pass through the existing markdown pipeline
    render_post_content(restored_content)
  end

  defp render_quote_block(post_id, author, thread_id, board, excerpt, current_thread_id) do
    # HTML-escape author, board, and excerpt (defensive: quote blocks are constructed by server)
    safe_author = Phoenix.HTML.html_escape(author) |> Phoenix.HTML.safe_to_string()

    safe_excerpt =
      Phoenix.HTML.html_escape(String.slice(excerpt, 0, 200)) |> Phoenix.HTML.safe_to_string()

    safe_board = Phoenix.HTML.html_escape(board) |> Phoenix.HTML.safe_to_string()

    if current_thread_id && thread_id == current_thread_id do
      # Same-thread quote: render as anchor link (single line to avoid spurious whitespace)
      "<a href=\"#post-#{post_id}\" class=\"bbs-quote-block bbs-quote-same-thread\"><span class=\"bbs-quote-header\">↩ #{safe_author} ##{post_id}</span><span class=\"bbs-quote-excerpt\">#{safe_excerpt}</span></a>"
    else
      # Cross-thread quote: render with popover data attributes (single line to avoid spurious whitespace)
      "<div class=\"bbs-quote-block bbs-quote-cross-thread\" data-bbs-popover=\"true\" data-quote-url=\"/bbs/#{safe_board}/#{thread_id}#post-#{post_id}\" data-quote-author=\"#{safe_author}\" data-quote-excerpt=\"#{safe_excerpt}\"><span class=\"bbs-quote-header\">↩ #{safe_author} (other thread)</span><span class=\"bbs-quote-excerpt\">#{safe_excerpt}</span><a href=\"/bbs/#{safe_board}/#{thread_id}#post-#{post_id}\" class=\"bbs-quote-goto\">↗ go to post</a></div>"
    end
  end
end
