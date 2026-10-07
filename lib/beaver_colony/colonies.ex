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
  alias BeaverColony.Colonies.{Colony, Membership, Policy}

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
  Colonies the beaver could join: every colony they aren't a member of, by name, each
  with `:pending` if they've already asked or `nil` if not.

  Colony *names* are public so beavers can find one to join. Nothing else about a
  colony is visible without an approved membership.
  """
  def list_other_colonies(%Scope{beaver: beaver}) do
    Repo.all(
      from c in Colony,
        left_join: m in Membership,
        on: m.colony_id == c.id and m.beaver_id == ^beaver.id,
        where: is_nil(m.id) or m.status == :pending,
        order_by: c.name,
        select: {c, m.status}
    )
  end

  @doc """
  Asks to join the colony with id `colony_id`, as a Builder. The request waits for a
  Lodge Keeper or the Dam Developer (see `approve_membership/2`).
  """
  def request_to_join(%Scope{beaver: beaver}, colony_id) do
    with {:ok, colony_id} <- Ecto.UUID.cast(colony_id),
         {:ok, membership} <-
           %Membership{
             beaver_id: beaver.id,
             colony_id: colony_id,
             role: :builder,
             status: :pending
           }
           |> Membership.insert_changeset()
           |> Repo.insert() do
      broadcast_changed(membership)
      {:ok, membership}
    else
      :error -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
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
  The colony's requests to join, with their beavers, oldest first.
  """
  def list_pending(%Scope{colony: %Colony{id: colony_id}}) do
    Repo.all(
      from m in Membership,
        where: m.colony_id == ^colony_id and m.status == :pending,
        order_by: m.inserted_at,
        preload: :beaver
    )
  end

  @doc """
  Lets a beaver who asked to join into the colony. Needs `:manage_members`.
  """
  def approve_membership(%Scope{} = scope, membership_id) do
    with :ok <- authorize(scope, :manage_members),
         {:ok, membership} <- fetch_colony_membership(scope, membership_id, :pending),
         {:ok, membership} <-
           membership |> Ecto.Changeset.change(status: :approved) |> Repo.update() do
      broadcast_changed(membership)
      {:ok, membership}
    end
  end

  @doc """
  Turns down a request to join. Needs `:manage_members`.
  """
  def decline_membership(%Scope{} = scope, membership_id) do
    with :ok <- authorize(scope, :manage_members),
         {:ok, membership} <- fetch_colony_membership(scope, membership_id, :pending),
         {:ok, membership} <- Repo.delete(membership) do
      broadcast_changed(membership)
      {:ok, membership}
    end
  end

  @doc """
  Gives a member a new role. Needs `:manage_colony`, and both the member's current
  role and the new one must rank below the caller's, so no one can promote someone to
  their own level or touch a peer.
  """
  def change_role(%Scope{} = scope, membership_id, role) do
    with :ok <- authorize(scope, :manage_colony),
         {:ok, membership} <- fetch_colony_membership(scope, membership_id, :approved),
         :ok <- authorize_outranks(scope, membership.role),
         :ok <- authorize_outranks(scope, role),
         {:ok, membership} <- membership |> Ecto.Changeset.change(role: role) |> Repo.update() do
      broadcast_changed(membership)
      {:ok, membership}
    end
  end

  @doc """
  Removes a member from the colony. Needs `:manage_members`, and the member must rank
  below the caller.
  """
  def remove_member(%Scope{} = scope, membership_id) do
    with :ok <- authorize(scope, :manage_members),
         {:ok, membership} <- fetch_colony_membership(scope, membership_id, :approved),
         :ok <- authorize_outranks(scope, membership.role),
         {:ok, membership} <- Repo.delete(membership) do
      broadcast_changed(membership)
      {:ok, membership}
    end
  end

  # A membership by the caller's id, but only within the scope's colony: an id from
  # another colony is simply not found.
  defp fetch_colony_membership(%Scope{colony: %Colony{id: colony_id}}, membership_id, status) do
    with {:ok, membership_id} <- Ecto.UUID.cast(membership_id),
         %Membership{} = membership <-
           Repo.get_by(Membership, id: membership_id, colony_id: colony_id, status: status) do
      {:ok, membership}
    else
      _ -> {:error, :not_found}
    end
  end

  # Always called after `authorize/2`, so the scope has a role. `other_role` may be nil
  # (an unknown role from a form), which is refused like any other bad role.
  defp authorize_outranks(%Scope{role: role}, other_role) do
    if other_role in Policy.roles() and Policy.outranks?(role, other_role),
      do: :ok,
      else: {:error, :unauthorized}
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

  ## Live updates
  #
  # A membership change is announced on two topics, both derived from the scope the
  # way `phx.gen.live` derives its topics:
  #
  #   * the beaver's, so their open pages re-check their access (`BeaverColonyWeb.BeaverAuth`)
  #   * the colony's, so its Members page can refresh
  #
  # The messages only say *which* colony changed, never the new role. Receivers read
  # the membership again from the database, so a message can't grant anything.

  @doc """
  Subscribes to changes in the scope's beaver's own memberships.

  Messages: `{:membership_changed, colony_id}`.
  """
  def subscribe_my_memberships(%Scope{beaver: beaver}) do
    Phoenix.PubSub.subscribe(BeaverColony.PubSub, beaver_topic(beaver.id))
  end

  @doc """
  Subscribes to changes in the scope's colony's memberships.

  Messages: `{:memberships_changed, colony_id}`.
  """
  def subscribe_colony_memberships(%Scope{colony: %Colony{id: colony_id}}) do
    Phoenix.PubSub.subscribe(BeaverColony.PubSub, colony_topic(colony_id))
  end

  defp broadcast_changed(%Membership{beaver_id: beaver_id, colony_id: colony_id}) do
    Phoenix.PubSub.broadcast(
      BeaverColony.PubSub,
      beaver_topic(beaver_id),
      {:membership_changed, colony_id}
    )

    Phoenix.PubSub.broadcast(
      BeaverColony.PubSub,
      colony_topic(colony_id),
      {:memberships_changed, colony_id}
    )
  end

  defp beaver_topic(beaver_id), do: "beaver:#{beaver_id}:memberships"
  defp colony_topic(colony_id), do: "colony:#{colony_id}:memberships"
end
