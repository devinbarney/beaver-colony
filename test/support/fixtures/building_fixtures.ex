defmodule BeaverColony.BuildingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BeaverColony.Building` context.
  """

  @doc """
  Generate a site.
  """
  def site_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "some name",
        notes: "some notes",
        river_mile: 120.5
      })

    {:ok, site} = BeaverColony.Building.create_site(scope, attrs)
    site
  end
end
