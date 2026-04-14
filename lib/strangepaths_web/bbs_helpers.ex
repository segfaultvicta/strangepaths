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

    quote_matches = Regex.scan(quote_regex, content, capture: :all_but_first)

    if quote_matches == [] do
      # No quotes — escape and render markdown
      content
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()
      |> render_post_content()
    else
      # Batch-load titles for any cross-thread quote targets (one query for all)
      cross_thread_ids =
        quote_matches
        |> Enum.map(fn [_, _, thread_id_str, _, _] -> String.to_integer(thread_id_str) end)
        |> Enum.reject(&(&1 == current_thread_id))
        |> Enum.uniq()

      thread_titles = Strangepaths.BBS.get_thread_titles(cross_thread_ids)
      # Step 1: Replace each [quote] block with a unique alphanumeric placeholder.
      # Alphanumeric only — no HTML or markdown special characters, so neither
      # html_escape nor Earmark will touch them.
      {placeholdered, _} =
        Enum.reduce(quote_matches, {content, 0}, fn _match, {text, idx} ->
          new_text = Regex.replace(quote_regex, text, "XBBSQ#{idx}XBBSQ", global: false)
          {new_text, idx + 1}
        end)

      # Strip any stray [/quote] tags left behind by nested quotes. When a post contains
      # [quote A] [quote B] ... [/quote] ... [/quote], the non-greedy regex matches the outer
      # quote's excerpt up to the inner [/quote], leaving the outer [/quote] as stray text.
      placeholdered = String.replace(placeholdered, "[/quote]", "")

      # Step 2: HTML-escape user content. Placeholders are alphanumeric and pass through unchanged.
      escaped = Phoenix.HTML.html_escape(placeholdered) |> Phoenix.HTML.safe_to_string()

      # Step 3: Replace text placeholders with HTML comment stubs AFTER html_escape so the
      # stubs won't be re-escaped. Earmark passes HTML comments through verbatim, without
      # adding newlines or other modifications.
      stubbed =
        Enum.reduce(Enum.with_index(quote_matches), escaped, fn {_, idx}, text ->
          String.replace(text, "XBBSQ#{idx}XBBSQ", "<!-- BBSQPH:#{idx} -->")
        end)

      # Step 4: Render through glyph + Earmark pipeline. Comment stubs pass through unchanged.
      rendered = render_post_content(stubbed)

      # Step 5: Replace comment stubs with rendered quote HTML, AFTER Earmark — so Earmark never
      # sees or re-escapes the quote block HTML. Replace one occurrence at a time (parts: 2)
      # so duplicate quote blocks are each restored exactly once.
      Enum.reduce(Enum.with_index(quote_matches), rendered, fn
        {[id_str, author, thread_id_str, board, excerpt], idx}, text ->
          stub = "<!-- BBSQPH:#{idx} -->"
          thread_id = String.to_integer(thread_id_str)

          quote_html =
            render_quote_block(
              String.to_integer(id_str),
              author,
              thread_id,
              board,
              excerpt,
              current_thread_id,
              thread_titles
            )

          case String.split(text, stub, parts: 2) do
            [before, rest] -> before <> quote_html <> rest
            [_] -> text
          end
      end)
    end
  end

  defp render_quote_block(post_id, author, thread_id, board, excerpt, current_thread_id, thread_titles \\ %{}) do
    safe_author = Phoenix.HTML.html_escape(author) |> Phoenix.HTML.safe_to_string()

    # Strip any nested [quote ...] / [/quote] tags from the excerpt — one level of nesting max.
    clean_excerpt =
      excerpt
      |> String.replace(~r/\[quote[^\]]*\]/, "")
      |> String.replace("[/quote]", "")
      |> String.trim()

    safe_excerpt =
      Phoenix.HTML.html_escape(String.slice(clean_excerpt, 0, 200)) |> Phoenix.HTML.safe_to_string()

    safe_board = Phoenix.HTML.html_escape(board) |> Phoenix.HTML.safe_to_string()

    if current_thread_id && thread_id == current_thread_id do
      ~s{<a href="#post-#{post_id}" class="bbs-quote-block bbs-quote-same-thread"><span class="bbs-quote-header">↩ #{safe_author} ##{post_id}</span><span class="bbs-quote-excerpt">#{safe_excerpt}</span></a>}
    else
      thread_label =
        case Map.get(thread_titles, thread_id) do
          nil -> "other thread"
          title -> Phoenix.HTML.html_escape(title) |> Phoenix.HTML.safe_to_string()
        end

      ~s{<div class="bbs-quote-block bbs-quote-cross-thread" data-bbs-popover="true" data-quote-url="/bbs/#{safe_board}/#{thread_id}#post-#{post_id}" data-quote-author="#{safe_author}" data-quote-excerpt="#{safe_excerpt}"><span class="bbs-quote-header">↩ #{safe_author} in "#{thread_label}"</span><span class="bbs-quote-excerpt">#{safe_excerpt}</span><a href="/bbs/#{safe_board}/#{thread_id}#post-#{post_id}" class="bbs-quote-goto">↗ go to post</a></div>}
    end
  end
end
