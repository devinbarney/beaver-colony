defmodule BeaverColony.Accounts.Scope do
  @moduledoc """
  Who is asking, and in what capacity. Every context function takes one as its first
  argument.

    * `beaver` - the signed-in beaver. Set for every signed-in request.
    * `colony` - the colony the request is about, taken from the URL and only ever set
      together with `role`, from the beaver's approved membership there. `nil` on
      personal pages.
    * `role` - the beaver's role in `colony`.

  A scope with a colony always means "this beaver is an approved member of this
  colony, with this role". Nothing else may build one: the colony only gets in through
  `put_colony/3`, which `BeaverColony.Colonies.fetch_membership/2` feeds.
  """

  alias BeaverColony.Accounts.Beaver
  alias BeaverColony.Colonies.{Colony, Policy}

  defstruct beaver: nil, colony: nil, role: nil

  @doc """
  Creates a scope for the given beaver.

  Returns nil if no beaver is given.
  """
  def for_beaver(%Beaver{} = beaver) do
    %__MODULE__{beaver: beaver}
  end

  def for_beaver(nil), do: nil

  @doc """
  Narrows the scope to one colony, acting with the beaver's role there.
  """
  def put_colony(%__MODULE__{beaver: %Beaver{}} = scope, %Colony{} = colony, role) do
    %{scope | colony: colony, role: role}
  end

  @doc """
  Whether this scope may do `ability` in its colony (see `BeaverColony.Colonies.Policy`).

  Always `false` without a colony: abilities only exist inside one.
  """
  def can?(%__MODULE__{colony: %Colony{}, role: role}, ability), do: Policy.allows?(role, ability)
  def can?(_scope, _ability), do: false
end
