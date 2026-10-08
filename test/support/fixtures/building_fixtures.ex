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

  @doc """
  Generate a shift tomorrow morning at a site of the scope's colony (a new one unless
  `attrs` names one).
  """
  def shift_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        hours: 3,
        needed: 3,
        starts_at: NaiveDateTime.new!(Date.add(Date.utc_today(), 1), ~T[09:00:00])
      })

    attrs = Map.put_new_lazy(attrs, :site_id, fn -> site_fixture(scope).id end)

    {:ok, shift} = BeaverColony.Building.create_shift(scope, attrs)
    shift
  end
end
