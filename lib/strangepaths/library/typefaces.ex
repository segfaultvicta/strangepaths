defmodule Strangepaths.Library.Typefaces do
  @typefaces [
    %{id: "jorule", name: "Jorule", font: "'IM Fell English', serif", color: "#8b5cf6"},
    %{id: "seraph", name: "Seraph", font: "'Crimson Text', serif", color: "#dc2626"},
    %{id: "inkwell", name: "Inkwell", font: "'Patrick Hand', cursive", color: "#0369a1"},
    %{id: "lacuna", name: "Lacuna", font: "'Courier Prime', monospace", color: "#065f46"}
  ]

  def all, do: @typefaces

  def find(id), do: Enum.find(@typefaces, &(&1.id == id))

  def valid_id?(id), do: Enum.any?(@typefaces, &(&1.id == id))
end
