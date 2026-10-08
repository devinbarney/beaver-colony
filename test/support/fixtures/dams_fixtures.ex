defmodule BeaverColony.DamsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BeaverColony.Dams` context.
  """

  @doc """
  Generate a stick.
  """
  def stick_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        length: 42,
        x: 42
      })

    {:ok, stick} = BeaverColony.Dams.create_stick(scope, attrs)
    stick
  end
end
