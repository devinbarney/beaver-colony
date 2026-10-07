defmodule BeaverColony.Colonies do
  @moduledoc """
  Colonies and the beavers in them.

  Every function takes the caller's `%Scope{}` first. Two rules hold throughout:

    * **Reads are filtered by the scope.** A colony's data is only ever queried with
      `scope.colony.id`, never with an id from the caller, so one colony can't read
      another's.
    * **Writes check the scope's ability** through `Scope.can?/2` and return
      `{:error, :unauthorized}` when it's missing. Pages check first so they can show
      a friendly redirect, but the context doesn't rely on them having done so.
  """

  import Ecto.Query

  alias BeaverColony.Repo
  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Colonies.{Colony, Membership}

  ## Personal: the beaver's own colonies (no colony in the scope)

  @doc """
  The beaver's approved memberships, with their colonies, by colony name.
  """
  def list_memberships(%Scope{beaver: beaver}) do
    Repo.all(
      from m in Membership,
        join: c in assoc(m, :colony),
        where: m.beaver_id == ^beaver.id and m.status == :approved,
        order_by: c.name,
        preload: [colony: c]
    )
  end

  @doc """
  Founds a new colony. The founder becomes its Dam Developer.
  """
  def create_colony(%Scope{beaver: beaver}, attrs) do
    Repo.transact(fn ->
      with {:ok, colony} <- %Colony{} |> Colony.changeset(attrs) |> Repo.insert(),
           {:ok, _membership} <-
             Repo.insert(%Membership{
               beaver_id: beaver.id,
               colony_id: colony.id,
               role: :dam_developer,
               status: :approved
             }) do
        {:ok, colony}
      end
    end)
  end

  @doc """
  A changeset for the colony form.
  """
  def change_colony(%Colony{} = colony, attrs \\ %{}) do
    Colony.changeset(colony, attrs)
  end

  ## Entering a colony

  @doc """
  The beaver's approved membership in the colony with id `colony_id`, with the colony
  preloaded. This is how a colony gets into a scope (see `Scope.put_colony/3`).

  Loading the colony *through* the membership keeps the two inseparable. A colony that
  doesn't exist, one the beaver isn't in, one where they're still pending, and an id
  that isn't even a UUID all return the same `{:error, :not_found}`, so the answer
  can't be used to discover which colonies exist.
  """
  def fetch_membership(%Scope{beaver: beaver}, colony_id) do
    with {:ok, colony_id} <- Ecto.UUID.cast(colony_id),
         %Membership{} = membership <-
           Repo.one(
             from m in Membership,
               join: c in assoc(m, :colony),
               where:
                 m.beaver_id == ^beaver.id and m.colony_id == ^colony_id and
                   m.status == :approved,
               preload: [colony: c]
           ) do
      {:ok, membership}
    else
      _ -> {:error, :not_found}
    end
  end

  ## Inside a colony (the scope carries the colony)

  @doc """
  The colony's approved members, with their beavers, oldest first.
  """
  def list_members(%Scope{colony: %Colony{id: colony_id}}) do
    Repo.all(
      from m in Membership,
        where: m.colony_id == ^colony_id and m.status == :approved,
        order_by: m.inserted_at,
        preload: :beaver
    )
  end

  @doc """
  Renames the scope's colony. Needs `:manage_colony`.

  The colony comes from the scope, so there is no way to name a different one.
  """
  def rename_colony(%Scope{} = scope, attrs) do
    with :ok <- authorize(scope, :manage_colony) do
      scope.colony
      |> Colony.changeset(attrs)
      |> Repo.update()
    end
  end

  defp authorize(scope, ability) do
    if Scope.can?(scope, ability), do: :ok, else: {:error, :unauthorized}
  end
end
