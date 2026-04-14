defmodule StrangepathsWeb.BBSHelpers do
  @moduledoc """
  Helpers for BBS post rendering, including quote block processing.
  """

  import StrangepathsWeb.SceneHelpers

  @doc """
  Formats a datetime for BBS post display (e.g., "Apr 13, 2026 at 03:45 PM").
  """
  def format_timestamp(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  @doc """
  Renders BBS post content with quote block processing.
  Pre-processes [quote ...] blocks to HTML before markdown rendering.

  The quote tag format is:
  [quote id=N author="..." thread_id=M board="slug"]excerpt[/quote]

  Args:
    - content: The raw post content string
    - current_thread_id: The ID of the current thread (optional, for same-thread detection)

  Returns: HTML string safe for rendering with |> raw
  """
  def render_bbs_post_content(content, current_thread_id \\ nil) do
    # Replace [quote ...] blocks with rendered HTML before Earmark
    processed =
      Regex.replace(
        ~r/\[quote id=(\d+) author="([^"]*)" thread_id=(\d+) board="([^"]*)"\](.*?)\[\/quote\]/s,
        content,
        fn _, id, author, thread_id_str, board, excerpt ->
          thread_id = String.to_integer(thread_id_str)

          render_quote_block(
            String.to_integer(id),
            author,
            thread_id,
            board,
            excerpt,
            current_thread_id
          )
        end
      )

    # Then pass through the existing pipeline
    render_post_content(processed)
  end

  defp render_quote_block(post_id, author, thread_id, board, excerpt, current_thread_id) do
    # HTML-escape author, board, and excerpt
    safe_author = Phoenix.HTML.html_escape(author) |> Phoenix.HTML.safe_to_string()

    safe_excerpt =
      Phoenix.HTML.html_escape(String.slice(excerpt, 0, 200)) |> Phoenix.HTML.safe_to_string()

    safe_board = Phoenix.HTML.html_escape(board) |> Phoenix.HTML.safe_to_string()

    if current_thread_id && thread_id == current_thread_id do
      # Same-thread quote: render as anchor link
      """
      <a href="#post-#{post_id}" class="bbs-quote-block bbs-quote-same-thread">
        <span class="bbs-quote-header">↩ #{safe_author} ##{post_id}</span>
        <span class="bbs-quote-excerpt">#{safe_excerpt}</span>
      </a>
      """
    else
      # Cross-thread quote: render with popover data attributes
      """
      <div class="bbs-quote-block bbs-quote-cross-thread"
           data-bbs-popover="true"
           data-quote-url="/bbs/#{safe_board}/#{thread_id}#post-#{post_id}"
           data-quote-author="#{safe_author}"
           data-quote-excerpt="#{safe_excerpt}">
        <span class="bbs-quote-header">↩ #{safe_author} (other thread)</span>
        <span class="bbs-quote-excerpt">#{safe_excerpt}</span>
        <a href="/bbs/#{safe_board}/#{thread_id}#post-#{post_id}" class="bbs-quote-goto">↗ go to post</a>
      </div>
      """
    end
  end
end
