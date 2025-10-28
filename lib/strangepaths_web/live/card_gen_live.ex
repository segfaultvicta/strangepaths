defmodule StrangepathsWeb.CardGenLive do
  use StrangepathsWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    {:ok,
     socket
     |> assign(:card_name, "Test Card")
     |> assign(:art_x, 50)
     |> assign(:art_y, 100)
     |> assign(:art_size, 300)
     |> assign(:text_x, 200)
     |> assign(:text_y, 50)
     |> assign(:font_size, 32)
     |> assign(:font_family, "sans-serif")
     |> assign(:available_fonts, list_available_fonts())
     |> assign(:preview_image, nil)
     |> allow_upload(:frame, accept: ~w(.png .jpg .jpeg), max_entries: 1)
     |> allow_upload(:art, accept: ~w(.png .jpg .jpeg), max_entries: 1)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    # Just return noreply - validation happens automatically for uploads
    {:noreply, socket}
  end

  @impl true
  def handle_event("render", params, socket) do
    # Get parameters
    card_name = params["card_name"] || socket.assigns.card_name
    art_x = String.to_integer(params["art_x"])
    art_y = String.to_integer(params["art_y"])
    art_size = String.to_integer(params["art_size"])
    text_x = String.to_integer(params["text_x"])
    text_y = String.to_integer(params["text_y"])
    font_size = String.to_integer(params["font_size"])
    font_family = params["font_family"]

    # Check if we have uploads
    frame_entries = uploaded_entries(socket, :frame)
    art_entries = uploaded_entries(socket, :art)

    IO.inspect(frame_entries, label: "Frame entries")
    IO.inspect(art_entries, label: "Art entries")

    if frame_entries == {[], []} or art_entries == {[], []} do
      {:noreply, put_flash(socket, :error, "Please upload both frame and art images")}
    else
      # Consume uploads and get paths
      frame_paths =
        consume_uploaded_entries(socket, :frame, fn %{path: path}, _entry ->
          # Copy to temp location since the upload path is temporary
          temp_path = Path.join(System.tmp_dir!(), "frame_#{:rand.uniform(999_999)}.png")
          File.cp!(path, temp_path)
          {:ok, temp_path}
        end)

      art_paths =
        consume_uploaded_entries(socket, :art, fn %{path: path}, _entry ->
          # Copy to temp location since the upload path is temporary
          temp_path = Path.join(System.tmp_dir!(), "art_#{:rand.uniform(999_999)}.png")
          File.cp!(path, temp_path)
          {:ok, temp_path}
        end)

      frame_path = List.first(frame_paths)
      art_path = List.first(art_paths)

      case composite_card(
             frame_path,
             art_path,
             card_name,
             art_x,
             art_y,
             art_size,
             text_x,
             text_y,
             font_size,
             font_family
           ) do
        {:ok, output_path} ->
          # Generate a data URL for display
          base64 = File.read!(output_path) |> Base.encode64()
          data_url = "data:image/png;base64,#{base64}"

          {:noreply,
           socket
           |> assign(:card_name, card_name)
           |> assign(:art_x, art_x)
           |> assign(:art_y, art_y)
           |> assign(:art_size, art_size)
           |> assign(:text_x, text_x)
           |> assign(:text_y, text_y)
           |> assign(:font_size, font_size)
           |> assign(:font_family, font_family)
           |> assign(:preview_image, data_url)
           |> put_flash(:info, "Card rendered!")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Render failed: #{inspect(reason)}")}
      end
    end
  end

  defp composite_card(
         frame_path,
         art_path,
         card_name,
         art_x,
         art_y,
         art_size,
         text_x,
         text_y,
         font_size,
         font_family
       ) do
    try do
      # Load the frame template
      {:ok, frame} = Image.open(frame_path)

      # Load and resize the art to exact square dimensions
      {:ok, art} = Image.open(art_path)
      {:ok, art_resized} = Image.thumbnail(art, art_size, height: art_size, crop: :center)

      # Composite art onto frame
      {:ok, frame_with_art} = Image.compose(frame, art_resized, x: art_x, y: art_y)

      # Add text
      {:ok, final_image} =
        Image.Text.text(card_name,
          text_fill_color: "#FFFFFF",
          font_size: font_size,
          font: font_family,
          background_fill_color: :transparent
        )

      # Composite text onto the card
      {:ok, result} = Image.compose(frame_with_art, final_image, x: text_x, y: text_y)

      # Save to temp file
      output_path = Path.join(System.tmp_dir!(), "card_preview_#{:rand.uniform(999_999)}.png")
      Image.write(result, output_path)

      {:ok, output_path}
    rescue
      e -> {:error, e}
    end
  end

  defp list_available_fonts do
    # Get fonts from fontconfig
    case System.cmd("fc-list", [":family"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.uniq()
        |> Enum.sort()

      _ ->
        ["sans-serif", "serif", "monospace"]
    end
  end
end
