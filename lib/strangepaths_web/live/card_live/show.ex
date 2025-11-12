defmodule StrangepathsWeb.CardLive.Show do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Cards

  @impl true
  def mount(_params, session, socket) do
    socket =
      assign_defaults(session, socket)
      |> assign(:preview_image, nil)

    # Subscribe to music broadcasts
    subscribe_to_music(socket)

    {:ok, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    # Try forwarding music client events first
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        # Handle our own events
        handle_card_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_card_event("delete", %{"id" => id}, socket) do
    card = Cards.get_card!(id)
    {:ok, _} = Cards.delete_card(card)

    {:noreply,
     push_redirect(socket |> put_flash(:info, card.name <> " successfully deleted!"),
       to: Routes.card_index_path(socket, :index)
     )}
  end

  defp handle_card_event("render_card_art", %{"id" => id}, socket) do
    card = Cards.get_card!(id)

    case composite_card(card) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Card rendered!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Render failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info(msg, socket) do
    # Forward music broadcasts to the component
    case forward_music_event(msg, socket) do
      :not_music_event ->
        # Handle other non-music events here if needed
        {:noreply, socket}

      result ->
        result
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {card, glory, foredit} = Cards.get_card_and_alt(id)

    useful_type =
      case card.type do
        :Rite -> "Tellurian Rite"
        :Grace -> "Grace"
        :Status -> "Status"
      end

    aspectline =
      case card.aspect_id do
        1 ->
          "a " <> useful_type <> " of the Dragon's Fang"

        2 ->
          "a " <> useful_type <> " of the Dragon's Claw"

        3 ->
          "a " <> useful_type <> " of the Dragon's Scale"

        4 ->
          "a " <> useful_type <> " of the Dragon's Breath"

        9 ->
          "a Burning Sidereal Rite"

        10 ->
          "a Pellucid Sidereal Rite"

        11 ->
          "a Flourishing Sidereal Rite"

        12 ->
          "a Radiant Sidereal Rite"

        13 ->
          "a Tenebrous Sidereal Rite"

        14 ->
          "a Status Effect"

        15 ->
          "an Alethic " <>
            if card.type == :Rite do
              "Rite"
            else
              "Grace"
            end

        _ ->
          "a Veiled " <> useful_type <> " of the " <> Cards.name_aspect(card.aspect_id)
      end

    # Calculate prev/next card IDs based on glorified rite logic
    prev_card_id = get_prev_card_id(card)
    next_card_id = get_next_card_id(card)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action, card.name))
     |> assign(
       card: card,
       glory: glory,
       foredit: foredit,
       aspect: Cards.name_aspect(card.aspect_id),
       aspectline: aspectline,
       prev_card_id: prev_card_id,
       next_card_id: next_card_id
     )}
  end

  defp page_title(:show, name), do: name
  defp page_title(:edit, name), do: "Editing " <> name

  # Navigation logic for prev/next cards
  defp get_prev_card_id(card) do
    cond do
      # If we're on a glorified Rite, go back 3 cards (skip the base version)
      card.type == :Rite && card.glorified == true ->
        if card.id - 3 >= 1, do: card.id - 3, else: nil

      card.type == :Glory ->
        if card.id - 1 >= 1, do: card.id - 1, else: nil

      # Otherwise, go back 2 card
      card.type == :Rite && card.glorified == false ->
        if card.id - 2 >= 1, do: card.id - 2, else: nil

      true ->
        if card.id - 1 >= 1, do: card.id - 1, else: nil
    end
  end

  defp get_next_card_id(card) do
    cond do
      # If we're on a base Rite (not glorified), skip forward 2 cards
      card.type == :Rite && (card.glorified == false || card.glorified == nil) ->
        card.id + 2

      # Otherwise, go forward 1 card
      true ->
        card.id + 1
    end
  end

  defp composite_card(card) do
    base_path = Application.get_env(:strangepaths, :base_image_store_path)
    art_path = base_path <> card.cardart
    art_x = 105
    art_y = 147
    art_size = 790

    aspect = Cards.get_aspect_with_parent(card.aspect_id)

    title_decoration =
      case {card.type, aspect.name, card.glorified, aspect.parent_aspect_id} do
        {_, "Alethic", _, _} -> "ꙮ"
        {:Grace, _, _, nil} -> "❂"
        {:Grace, _, _, _} -> "～❂～"
        {:Rite, "Fang", false, nil} -> "···"
        {:Rite, "Fang", true, nil} -> "·❁·"
        {:Rite, "Fang", _, _} -> "·～·"
        {:Rite, "Claw", false, nil} -> "···"
        {:Rite, "Claw", true, nil} -> "·❁·"
        {:Rite, "Claw", _, _} -> "·～·"
        {:Rite, "Scale", false, nil} -> "···"
        {:Rite, "Scale", true, nil} -> "·❁·"
        {:Rite, "Scale", _, _} -> "·～·"
        {:Rite, "Breath", false, nil} -> "···"
        {:Rite, "Breath", true, nil} -> "·❁·"
        {:Rite, "Breath", _, _} -> "·～·"
        {:Rite, "Red", false, _} -> "···"
        {:Rite, "Red", true, _} -> "·❁·"
        {:Rite, "Green", false, _} -> "···"
        {:Rite, "Green", true, _} -> "·❁·"
        {:Rite, "Blue", false, _} -> "···"
        {:Rite, "Blue", true, _} -> "·❁·"
        {:Rite, "White", false, _} -> "···"
        {:Rite, "White", true, _} -> "·❁·"
        {:Rite, "Black", false, _} -> "···"
        {:Rite, "Black", true, _} -> "·❁·"
        {:Rite, _, _, _} -> "～"
        {:Status, "Status", _, _} -> "✴"
      end

    title_text = title_decoration <> " " <> card.name <> " " <> title_decoration
    title_center_x = 500
    title_y = 75
    statusline_x = 105
    statusline_y = 945
    icon_x = 845
    icon_y = 905
    rules_x = 105
    rules_y = 1005

    {font, font_file, text_color} =
      case aspect.name do
        "Fang" ->
          {"Anaktoria", "/usr/share/fonts/truetype/Anaktoria.ttf", "#000000"}

        "Claw" ->
          {"Anaktoria", "/usr/share/fonts/truetype/Anaktoria.ttf", "#000000"}

        "Scale" ->
          {"Anaktoria", "/usr/share/fonts/truetype/Anaktoria.ttf", "#000000"}

        "Breath" ->
          {"Anaktoria", "/usr/share/fonts/truetype/Anaktoria.ttf", "#000000"}

        "Red" ->
          {"Oxanium", "/usr/share/fonts/truetype/Oxanium-VariableFont_wght.ttf", "#660000"}

        "Green" ->
          {"Aladin", "/usr/share/fonts/truetype/Aladin-Regular.ttf", "#006600"}

        "Blue" ->
          {"Noto Sans", "/usr/share/fonts/truetype/NotoSans-Italic-VariableFont_wdth,wght.ttf",
           "#000066"}

        "White" ->
          {"Quintessential", "/usr/share/fonts/truetype/Quintessential-Regular.ttf", "#000000"}

        "Black" ->
          {"Bellefair", "/usr/share/fonts/truetype/Bellefair-Regular.ttf", "#FFFFFF"}

        "Status" ->
          {"Anaktoria", "/usr/share/fonts/truetype/Anaktoria.ttf", "#000000"}

        "Alethic" ->
          {"Cormorant Garamond Light",
           "/usr/share/fonts/truetype/CormorantGaramond-VariableFont_wght.ttf", "#000000"}

        _ ->
          {"Anaktoria", "/usr/share/fonts/truetype/Anaktoria.ttf", "#000000"}
      end

    try do
      # Load the frame template
      frame_path =
        case {aspect.name, aspect.parent_aspect_id} do
          {"Fang", nil} -> "/images/baseframes/Tellurian.png"
          {_, 1} -> "/images/baseframes/Tellurian.png"
          {"Claw", nil} -> "/images/baseframes/Tellurian.png"
          {_, 2} -> "/images/baseframes/Tellurian.png"
          {"Scale", nil} -> "images/baseframes/Tellurian.png"
          {_, 3} -> "/images/baseframes/Tellurian.png"
          {"Breath", nil} -> "/images/baseframes/Tellurian.png"
          {_, 4} -> "/images/baseframes/Tellurian.png"
          {"Red", nil} -> "/images/baseframes/Burning.png"
          {"Green", nil} -> "/images/baseframes/Flourishing.png"
          {"Blue", nil} -> "/images/baseframes/Pellucid.png"
          {"White", nil} -> "/images/baseframes/Radiant.png"
          {"Black", nil} -> "/images/baseframes/Tenebrous.png"
          {"Status", nil} -> "/images/baseframes/Tellurian.png"
          {"Alethic", nil} -> "/images/baseframes/Alethic.png"
          _ -> "/images/baseframes/Alethic.png"
        end

      frame_path = base_path <> frame_path

      IO.puts("frame path is #{frame_path}")
      {:ok, frame} = Image.open(frame_path)
      IO.puts("got past frame load")

      icon_path =
        case {aspect.name, aspect.parent_aspect_id} do
          {"Fang", nil} -> "/images/counters/fang.png"
          {_, 1} -> "/images/counters/fang.png"
          {"Claw", nil} -> "/images/counters/claw.png"
          {_, 2} -> "/images/counters/claw.png"
          {"Scale", nil} -> "/images/counters/scale.png"
          {_, 3} -> "/images/counters/scale.png"
          {"Breath", nil} -> "/images/counters/breath.png"
          {_, 4} -> "/images/counters/breath.png"
          {"Red", nil} -> "/images/counters/red.png"
          {"Green", nil} -> "/images/counters/green.png"
          {"Blue", nil} -> "/images/counters/blue.png"
          {"White", nil} -> "/images/counters/white.png"
          {"Black", nil} -> "/images/counters/black.png"
          {"Status", nil} -> "/images/counters/status.png"
          {"Alethic", nil} -> nil
          _ -> "/images/counters/alethic.png"
        end

      icon_path =
        if icon_path == nil do
          nil
        else
          base_path <> icon_path
        end

      IO.puts("art path is #{art_path}")
      # Load and resize the art to exact square dimensions
      {:ok, art} = Image.open(art_path)
      IO.puts("got past art load")

      {:ok, art_resized} = Image.thumbnail(art, art_size, height: art_size, crop: :center)

      # Composite art onto frame
      {:ok, frame_with_art} = Image.compose(frame, art_resized, x: art_x, y: art_y)

      # Add text
      {:ok, title_image} =
        Image.Text.text(title_text,
          text_fill_color: text_color,
          font_size: 56,
          font: font,
          font_file: font_file
        )

      title_text_width = Image.width(title_image)
      title_x = title_center_x - div(title_text_width, 2)

      # Composite text onto the card
      {:ok, img} = Image.compose(frame_with_art, title_image, x: title_x, y: title_y)

      base_statusline =
        cond do
          aspect.name in ["Fang", "Claw", "Scale", "Breath"] ->
            if card.type == :Rite do
              "Tellurian Rite of the " <> aspect.name
            else
              "Grace of the " <> aspect.name
            end

          aspect.name == "Red" ->
            "Burning Sidereal Rite"

          aspect.name == "Green" ->
            "Flourishing Sidereal Rite"

          aspect.name == "Blue" ->
            "Pellucid Sidereal Rite"

          aspect.name == "White" ->
            "Radiant Sidereal Rite"

          aspect.name == "Black" ->
            "Tenebrous Sidereal Rite"

          aspect.name == "Alethic" ->
            "Alethic Rite"

          aspect.name == "Status" ->
            "Status Effect"

          true ->
            "Veiled Rite of the " <> aspect.name
        end

      true_statusline =
        base_statusline <>
          if card.statusline != "" and card.statusline != nil do
            " — " <> card.statusline
          else
            ""
          end

      {:ok, statusline_image} =
        Image.Text.text(true_statusline,
          text_fill_color: text_color,
          font_size: 36,
          font: font,
          font_file: font_file
        )

      {:ok, img} = Image.compose(img, statusline_image, x: statusline_x, y: statusline_y)

      img =
        if icon_path != nil do
          {:ok, icon} = Image.open(icon_path)
          {:ok, icon_resized} = Image.thumbnail(icon, 110, height: 110)
          {:ok, img} = Image.compose(img, icon_resized, x: icon_x, y: icon_y)
          img
        else
          img
        end

      IO.puts("got past icon load")

      # Do preprocessing on rules text
      rules_text = String.replace(card.rules, "[One]", "✱")
      rules_text = String.replace(rules_text, "[Multi]", "⁂")
      rules_text = String.replace(rules_text, "[Self]", "⊙")
      rules_text = String.replace(rules_text, "[Special]", "✦")
      rules_text = String.replace(rules_text, "[Reach]", "⤨")
      rules_text = String.replace(rules_text, "[Ripple]", "≋")

      rules_img =
        render_text_block_with_newlines(
          rules_text,
          800,
          # Reduced to 200px to give flavor text more room
          200,
          text_color,
          font,
          font_file,
          64
        )

      {:ok, img} = Image.compose(img, rules_img, x: rules_x, y: rules_y)

      # Add separator - moved up to around 210px
      {:ok, separator} = Image.new(700, 3, color: text_color)
      {:ok, img} = Image.compose(img, separator, x: rules_x + 50, y: rules_y + 200)

      # Render flavor text - increased to 180px height, starts at 220px
      {:ok, img} =
        if card.flavortext && card.flavortext != "" do
          flavor_img =
            render_text_block_with_newlines(
              card.flavortext,
              800,
              # Increased to 180px for more space
              180,
              text_color,
              font,
              font_file,
              # Start with smaller font size for flavor text
              42
            )

          Image.compose(img, flavor_img, x: rules_x, y: rules_y + 220)
        end

      IO.puts("got past rendering of text blocks")

      {:ok, final_img} = Image.thumbnail(img, 900, height: 900)

      # Overwrite @card.img with the final image
      output_path =
        if card.img != nil do
          "priv/static" <> card.img
        else
          "priv/static/images/#{Slug.slugify(card.name)}.png"
        end

      IO.puts("in guts of render, about to write final img")
      IO.puts(output_path)
      foo = Image.write(final_img, output_path)
      IO.inspect(foo)
      {:ok, output_path}
    rescue
      e -> {:error, e}
    end
  end

  defp render_text_block_with_newlines(
         text,
         max_width,
         max_height,
         color,
         font,
         font_file,
         max_font_size
       ) do
    lines = String.split(text, "\n", trim: false)

    # Find font size that fits BOTH width AND height constraints
    # Fallback
    font_size =
      Enum.find(max_font_size..12//-1, fn size ->
        line_height = round(size * 1.15)
        total_height = length(lines) * line_height

        # Check 1: Does it fit vertically?
        if total_height > max_height do
          false
        else
          # Check 2: Does the widest line fit horizontally?
          widest_line = Enum.max_by(lines, &String.length/1)

          {:ok, test_img} =
            Image.Text.text(widest_line,
              font_size: size,
              font: font,
              font_file: font_file,
              text_fill_color: color,
              background_fill_color: :transparent
            )

          Image.width(test_img) <= max_width
        end
      end) || 12

    line_height = round(font_size * 1.15)

    # Render all lines
    line_images =
      Enum.map(lines, fn line ->
        if line == "" || String.trim(line) == "" do
          # For empty lines, create a 1px transparent image as spacer
          {:ok, spacer} =
            Image.Text.text(" ",
              text_fill_color: color,
              font_size: font_size,
              font: font,
              font_file: font_file
            )

          spacer
        else
          {:ok, line_img} =
            Image.Text.text(line,
              text_fill_color: color,
              font_size: font_size,
              font: font,
              font_file: font_file
            )

          line_img
        end
      end)

    # Stack all the line images vertically
    # We need to create a canvas tall enough for all lines
    total_height = length(lines) * line_height
    max_line_width = Enum.map(line_images, &Image.width/1) |> Enum.max()

    # Create transparent canvas using RGBA with alpha channel = 0
    {:ok, canvas} = Image.new(max_line_width, total_height, color: [0, 0, 0, 0])

    # Compose each line onto the canvas
    {final_img, _} =
      Enum.reduce(line_images, {canvas, 0}, fn line_img, {img, y_offset} ->
        {:ok, result} = Image.compose(img, line_img, x: 0, y: y_offset)
        {result, y_offset + line_height}
      end)

    final_img
  end
end
