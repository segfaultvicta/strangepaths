defmodule Strangepaths.Site.SiteSettings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "site_settings" do
    field :bbs_enabled, :boolean, default: false
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:bbs_enabled])
    |> validate_required([:bbs_enabled])
  end
end
