defmodule StrangepathsWeb.LibraryHelpersTest do
  use ExUnit.Case

  import StrangepathsWeb.LibraryHelpers

  # Verifies: liminal-library.AC3.4
  describe "render_library_content/2 - known typeface tags" do
    test "renders known typeface tag as styled span" do
      # "jorule" must be a valid typeface id in Strangepaths.Library.Typefaces
      [tf | _] = Strangepaths.Library.Typefaces.all()
      content = "[#{tf.id}]some text[/#{tf.id}]"

      result = render_library_content(content)

      assert result =~ "<span style=\"font-family: #{tf.font}; color: #{tf.color};\""
      assert result =~ "some text"
      refute result =~ "[#{tf.id}]"
    end

    test "renders multiple typeface tags in one string" do
      [tf1, tf2 | _] = Strangepaths.Library.Typefaces.all()
      content = "[#{tf1.id}]first[/#{tf1.id}] and [#{tf2.id}]second[/#{tf2.id}]"

      result = render_library_content(content)

      assert result =~ tf1.color
      assert result =~ tf2.color
      assert result =~ "first"
      assert result =~ "second"
    end
  end

  # Verifies: liminal-library.AC3.5
  describe "render_library_content/2 - unknown typeface tags" do
    test "renders unknown typeface name as literal text with brackets" do
      content = "[unknowntypeface]some text[/unknowntypeface]"

      result = render_library_content(content)

      assert result =~ "[unknowntypeface]"
      assert result =~ "[/unknowntypeface]"
      assert result =~ "some text"
      refute result =~ "<span"
      refute result =~ "<a"
    end
  end

  describe "render_library_content/2 - XSS safety" do
    test "HTML-escapes user text inside a typeface tag" do
      [tf | _] = Strangepaths.Library.Typefaces.all()
      content = "[#{tf.id}]<script>alert('xss')</script>[/#{tf.id}]"

      result = render_library_content(content)

      refute result =~ "<script>alert"
      assert result =~ "&lt;script&gt;"
    end
  end

  describe "render_library_content/2 - passthrough" do
    test "content with no typeface tags passes through unchanged (modulo markdown)" do
      content = "Plain text with **bold**."

      result = render_library_content(content)

      assert result =~ "Plain text with"
      assert result =~ "<strong>bold</strong>"
    end

    test "glyph pairs in content still render correctly" do
      [tf | _] = Strangepaths.Library.Typefaces.all()
      content = "[#{tf.id}]hello[/#{tf.id}] and some other text"

      result = render_library_content(content)

      assert result =~ "hello"
      assert result =~ "some other text"
    end
  end
end
