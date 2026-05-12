defmodule Strangepaths.Rumor.Diff do
  @context_size 3

  @doc """
  Returns a list of `{:eq | :del | :ins, word}` segments plus `:sep` separators,
  or `nil` if the texts are identical. Each segment represents a word from the
  diff with its change type; `:sep` marks a gap between non-adjacent windows.
  """
  def word_diff(old_text, new_text) do
    old_words = String.split(old_text || "", ~r/\s+/, trim: true)
    new_words = String.split(new_text || "", ~r/\s+/, trim: true)

    flat =
      List.myers_difference(old_words, new_words)
      |> Enum.flat_map(fn {type, words} -> Enum.map(words, &{type, &1}) end)

    change_positions = for {{type, _}, i} <- Enum.with_index(flat), type != :eq, do: i

    if change_positions == [] do
      nil
    else
      windows = merge_windows(change_positions, length(flat), @context_size)

      windows
      |> Enum.with_index()
      |> Enum.flat_map(fn {{s, e}, idx} ->
        prefix = if idx > 0, do: [:sep], else: []
        prefix ++ Enum.slice(flat, s..e)
      end)
    end
  end

  defp merge_windows(positions, total, ctx) do
    positions
    |> Enum.map(fn pos -> {max(0, pos - ctx), min(total - 1, pos + ctx)} end)
    |> Enum.sort()
    |> Enum.reduce([], fn
      {s, e}, [] -> [{s, e}]
      {s, e}, [{ps, pe} | rest] when s <= pe + 1 -> [{ps, max(e, pe)} | rest]
      {s, e}, acc -> [{s, e} | acc]
    end)
    |> Enum.reverse()
  end
end
