defmodule BeaverColony.Colonies.Policy do
  @moduledoc """
  What each role in a colony may do. This is the one place that answers that question.

  Roles are ranked: a Dam Developer can do everything a Lodge Keeper can, and a Lodge
  Keeper everything a Builder can. So each ability names only the *lowest* role that
  has it.

  Pages, the navigation and the contexts all ask through `BeaverColony.Accounts.Scope.can?/2`,
  which reads this table. They can't disagree, because none of them keeps its own list.
  """

  # Lowest role first.
  @roles [:builder, :lodge_keeper, :dam_developer]

  @abilities %{
    view_colony: :builder,
    view_dam: :builder,
    place_stick: :builder,
    remove_stick: :lodge_keeper,
    view_sites: :builder,
    manage_sites: :lodge_keeper,
    view_schedule: :builder,
    sign_up: :builder,
    manage_schedule: :lodge_keeper,
    manage_members: :lodge_keeper,
    manage_colony: :dam_developer
  }

  @doc "Every role, lowest first."
  def roles, do: @roles

  @doc "Every ability."
  def abilities, do: Map.keys(@abilities)

  @doc """
  Whether `role` has `ability`.

  An unknown ability raises rather than returning `false`, so a typo in a page's
  requirement fails loudly instead of quietly locking everyone out.
  """
  def allows?(role, ability) when role in @roles do
    rank(role) >= rank(Map.fetch!(@abilities, ability))
  end

  @doc """
  Whether role `a` ranks above role `b`. A beaver can only manage beavers ranked below
  them, and only give out roles below their own.
  """
  def outranks?(a, b) when a in @roles and b in @roles, do: rank(a) > rank(b)

  @doc """
  The role named by a form param, or `nil`. Never `String.to_atom/1` on user input.
  """
  def role_from_param(param), do: Enum.find(@roles, &(Atom.to_string(&1) == param))

  @doc "How a role reads on screen."
  def display_name(:dam_developer), do: "Dam Developer"
  def display_name(:lodge_keeper), do: "Lodge Keeper"
  def display_name(:builder), do: "Builder"

  defp rank(role), do: Enum.find_index(@roles, &(&1 == role))
end
