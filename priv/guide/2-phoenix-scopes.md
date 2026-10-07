%{
  title: "Phoenix Scopes, really understood",
  description: "What phx.gen.auth's %Scope{} is for, how it reaches every LiveView, and how to carry a tenant and a role in it."
}
---

> **Draft.** Written from the build journal; to be rewritten in the author's voice.

## What a scope is

Phoenix 1.8's guide calls a scope "a data structure used to keep information about the current request or session, such as the current user, the user's organization/company, permissions, and so on."

The point isn't the struct. It's a habit: **every context function takes the scope as its first argument, and filters by it.** If a function can't be called without saying who is asking, you can't forget to scope a query. The Phoenix guide ties this directly to OWASP's top web risk, broken access control.

Here is what `phx.gen.auth Accounts Beaver beavers` generated:

```elixir
defmodule BeaverColony.Accounts.Scope do
  alias BeaverColony.Accounts.Beaver

  defstruct beaver: nil

  def for_beaver(%Beaver{} = beaver), do: %__MODULE__{beaver: beaver}
  def for_beaver(nil), do: nil
end
```

## How it reaches a LiveView

A plug puts it on the conn for ordinary requests, and an `on_mount` hook puts it on the socket:

```elixir
defp mount_current_scope(socket, session) do
  Phoenix.Component.assign_new(socket, :current_scope, fn ->
    {beaver, _} =
      if beaver_token = session["beaver_token"] do
        Accounts.get_beaver_by_session_token(beaver_token)
      end || {nil, nil}

    Scope.for_beaver(beaver)
  end)
end
```

Why `assign_new`? Every LiveView mounts **twice**:
1. once during the plain HTTP request, so the first HTML arrives fast;
2. again in a new process when the websocket connects.

On the first mount `assign_new` reuses the scope the plug already put on the conn. On the second there is no conn, so it loads the beaver from the session. Everything `on_mount` does happens twice, which is worth remembering when you add queries to it.

## Putting a colony in the scope

The scope grows two fields:

```elixir
defstruct beaver: nil, colony: nil, role: nil

def put_colony(%__MODULE__{beaver: %Beaver{}} = scope, %Colony{} = colony, role) do
  %{scope | colony: colony, role: role}
end

def can?(%__MODULE__{colony: %Colony{}, role: role}, ability), do: Policy.allows?(role, ability)
def can?(_scope, _ability), do: false
```

The important rule: **a colony only ever enters a scope together with the beaver's role there**, and only from their approved membership. That happens in one `on_mount` clause and one query:

```elixir
def on_mount(:assign_colony, %{"colony_id" => colony_id}, _session, socket) do
  scope = socket.assigns.current_scope

  case Colonies.fetch_membership(scope, colony_id) do
    {:ok, membership} ->
      scope = Scope.put_colony(scope, membership.colony, membership.role)
      {:cont, assign(socket, :current_scope, scope)}

    {:error, :not_found} ->
      {:halt, deny_colony(socket)}
  end
end
```

`fetch_membership/2` loads the colony *through* the membership: `WHERE beaver_id = scope.beaver.id AND colony_id = ? AND status = 'approved'`. Four different situations get the same answer, `{:error, :not_found}`:
- a colony you're not in;
- one where you're still waiting to be let in;
- one that doesn't exist;
- an id that isn't even a UUID.

So the answer never tells a stranger which colonies exist.

## Scoped contexts

Every function in `BeaverColony.Colonies` takes the scope first:

```elixir
def list_members(%Scope{colony: %Colony{id: colony_id}}) do
  Repo.all(
    from m in Membership,
      where: m.colony_id == ^colony_id and m.status == :approved,
      preload: :beaver
  )
end
```

Notice what isn't there: a `colony_id` argument. The caller can't name a colony, only hand over a scope that already has one. Call it without a colony and it doesn't quietly return everything. It raises.

## Teaching the generators

`config.exs` describes the colony scope, so `mix phx.gen.live` writes colony-scoped code from now on:

```elixir
config :beaver_colony, :scopes,
  colony: [
    default: true,
    module: BeaverColony.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:colony, :id],
    route_prefix: "/colonies/:colony_id",
    route_access_path: [:colony, :id],
    schema_key: :colony_id,
    schema_type: :binary_id,
    schema_table: :colonies,
    test_data_fixture: BeaverColony.ColoniesFixtures,
    test_setup_helper: :register_and_log_in_beaver_with_colony
  ]
```

`access_path` is how the generator writes `where: x.colony_id == ^scope.colony.id`. `route_prefix` nests the routes, and `test_setup_helper` names the setup function generated tests call.

## What the guide leaves open

The Phoenix guide is about filtering data by tenant. It says a scope *can* carry permissions, but it doesn't design roles. Where does the role come from? Who checks it? What happens when it changes while a page is open? That's Part 3.
