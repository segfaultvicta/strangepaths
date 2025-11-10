defmodule Strangepaths.Repo.Migrations.RumorNodeImageUrl do
  use Ecto.Migration

  def change do
    alter table(:rumor_nodes) do
      add(:image_url, :string)
    end
  end
end
