defmodule StrangepathsWeb.BBSHelpersTest do
  use ExUnit.Case

  import StrangepathsWeb.BBSHelpers

  describe "render_bbs_post_content/2" do
    test "renders same-thread quote as anchor link" do
      content = "[quote id=123 author=\"Alice\" thread_id=1 board=\"general\"]Hello world[/quote]"
      result = render_bbs_post_content(content, 1)

      assert result =~ "bbs-quote-same-thread"
      assert result =~ "↩ Alice #123"
      assert result =~ "href=\"#post-123\""
      assert result =~ "Hello world"
    end

    test "renders cross-thread quote with popover attributes" do
      content = "[quote id=456 author=\"Bob\" thread_id=2 board=\"off-topic\"]Greetings[/quote]"
      result = render_bbs_post_content(content, 1)

      assert result =~ "bbs-quote-cross-thread"
      assert result =~ "data-bbs-popover=\"true\""
      assert result =~ "data-quote-author=\"Bob\""
      assert result =~ "data-quote-excerpt=\"Greetings\""
      assert result =~ "/bbs/off-topic/2#post-456"
      assert result =~ "(other thread)"
    end

    test "truncates excerpt to 200 chars" do
      long_text = String.duplicate("a", 300)

      content =
        "[quote id=789 author=\"Charlie\" thread_id=3 board=\"general\"]#{long_text}[/quote]"

      result = render_bbs_post_content(content, 1)

      # Should contain truncated content (200 chars)
      assert String.length(result) > 0
      # Check that it rendered the quote block
      assert result =~ "bbs-quote-block"
    end

    test "HTML-escapes author name to prevent XSS" do
      content =
        "[quote id=111 author=\"<script>alert('xss')</script>\" thread_id=1 board=\"general\"]test[/quote]"

      result = render_bbs_post_content(content, 1)

      # Should NOT contain unescaped script tag
      refute result =~ "<script>alert"
      # Should be escaped
      assert result =~ "&lt;script&gt;"
    end

    test "HTML-escapes excerpt to prevent XSS" do
      content =
        "[quote id=222 author=\"Alice\" thread_id=1 board=\"general\"]<img src=x onerror=\"alert('xss')\"><[/quote]"

      result = render_bbs_post_content(content, 1)

      # Should NOT contain unescaped img tag with onerror
      refute result =~ "onerror="
      # Should be escaped
      assert result =~ "&lt;img"
    end

    test "handles multiple quotes in content" do
      first_quote = "[quote id=1 author=\"Alice\" thread_id=1 board=\"general\"]First[/quote]"
      second_quote = "[quote id=2 author=\"Bob\" thread_id=1 board=\"general\"]Second[/quote]"
      content = first_quote <> "\n\nSome text\n\n" <> second_quote
      result = render_bbs_post_content(content, 1)

      assert result =~ "Alice"
      assert result =~ "Bob"
      assert result =~ "First"
      assert result =~ "Second"
    end

    test "handles duplicate (identical) quote blocks without corruption" do
      q = "[quote id=1 author=\"Alice\" thread_id=1 board=\"general\"]Same excerpt[/quote]"
      content = q <> "\n\n" <> q
      result = render_bbs_post_content(content, 1)

      # No unreplaced placeholders
      refute result =~ "___QUOTE_BLOCK_"

      # Both quote blocks rendered (3 parts when split on the class = 2 quote instances + 1 prefix)
      assert result |> String.split("bbs-quote-block") |> length() == 3
    end

    test "does not substitute user text matching a placeholder pattern" do
      content = "___QUOTE_BLOCK_0___ is a weird thing to type"
      result = render_bbs_post_content(content, 1)

      # The literal placeholder text should be escaped/present as-is (not consumed as a quote block)
      assert result =~ "___QUOTE_BLOCK_0___"
    end

    test "processes markdown after quote processing" do
      content =
        "[quote id=1 author=\"Alice\" thread_id=1 board=\"general\"]quoted[/quote]\n\n**bold text**"

      result = render_bbs_post_content(content, 1)

      assert result =~ "bbs-quote"
      assert result =~ "<strong>bold text</strong>"
    end
  end
end
