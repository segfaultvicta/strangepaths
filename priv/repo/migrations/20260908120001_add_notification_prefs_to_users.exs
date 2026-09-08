defmodule Strangepaths.Repo.Migrations.AddNotificationPrefsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :notif_scene_sound, :boolean, null: false, default: false
      add :notif_scene_web, :boolean, null: false, default: false
      add :notif_library_sound, :boolean, null: false, default: false
      add :notif_library_web, :boolean, null: false, default: false
      add :notif_bbs_sound, :boolean, null: false, default: false
      add :notif_bbs_web, :boolean, null: false, default: false
      add :notif_rumor_sound, :boolean, null: false, default: false
      add :notif_rumor_web, :boolean, null: false, default: false
    end
  end
end
