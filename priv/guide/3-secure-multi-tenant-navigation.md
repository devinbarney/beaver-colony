%{
  title: "Secure multi-tenant navigation",
  description: "The URL picks the colony, the membership picks the role, every page says what it needs, and every context function checks."
}
---

> **Draft.** Written from the build journal; to be rewritten in the author's voice.

## My first design, and what was wrong with it

The first time, I let **the route decide the role**. Each role had its own URL prefix and its own `live_session`, and a hook checked that you held the role the route declared. It worked, and it kept each browser tab in its own role. But tracing one request through it turned up problems:

- **The same LiveView was mounted under several prefixes** just to give it a different role. Every new page multiplied, and adding a role route meant updating five other places.
- **Authorization lived only at the edge.** Context functions took a bare tenant id and trusted the caller, so one forgotten check on one page could leak another tenant's data.
- **The tenant was loaded before it was authorized.**
- **Open pages kept stale authority.** When a role was revoked, the nav rebuilt, but the page kept acting with the old role until the next navigation.

Beaver Colony uses four rules instead.

## 1. The URL picks the colony, never the role

All colony pages live in **one** `live_session`:

```elixir
live_session :colony,
  on_mount: [
    {BeaverColonyWeb.BeaverAuth, :require_authenticated},
    {BeaverColonyWeb.BeaverAuth, :assign_colony},
    BeaverColonyWeb.Nav
  ] do
  live "/colonies/:colony_id", ColonyLive.Dashboard, :show
  live "/colonies/:colony_id/members", ColonyLive.Members, :index
  live "/colonies/:colony_id/settings", ColonyLive.Settings, :edit
end
```

URLs name places, not personas. The router never mentions a role.

## 2. The membership picks the role

`:assign_colony` (Part 2) reads the beaver's approved membership and puts the colony and the role into the scope together. There's one role per colony, so there's never a question of which hat you're wearing.

## 3. Every page says what it needs

```elixir
defmodule BeaverColonyWeb.ColonyLive.Members do
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :manage_members}}
```

What each ability needs lives in exactly one table:

```elixir
@roles [:builder, :lodge_keeper, :dam_developer]

@abilities %{
  view_colony: :builder,
  manage_members: :lodge_keeper,
  manage_colony: :dam_developer
}

def allows?(role, ability) when role in @roles do
  rank(role) >= rank(Map.fetch!(@abilities, ability))
end
```

An unknown ability *raises*. A typo in a page's requirement fails loudly instead of quietly locking everyone out.

## 4. Every context function checks

The page's check exists for a friendly redirect. The context doesn't trust that it ran:

```elixir
def rename_colony(%Scope{} = scope, attrs) do
  with :ok <- authorize(scope, :manage_colony) do
    scope.colony |> Colony.changeset(attrs) |> Repo.update()
  end
end
```

Two rules hold for every function:
- **reads are filtered by the scope's colony;**
- **writes check the scope's ability.**

For managing members there's one more rule: you can only act on beavers ranked *below* you, and only hand out roles below your own. That single rule means no one can make a second Dam Developer, Lodge Keepers can't remove each other, and a colony can't lose its Dam Developer.

## The patch hole

`on_mount` runs when a LiveView mounts. A **patch** (`push_patch`, `<.link patch>`) keeps the mounted LiveView, so `on_mount` doesn't run, but the URL can still change. Patch from `/colonies/A/members` to `/colonies/B/members` and the page would show B's URL with A's scope. One hook closes it:

```elixir
defp pin_colony(params, _uri, socket) do
  if params["colony_id"] == socket.assigns.current_scope.colony.id do
    {:cont, socket}
  else
    {:halt, deny_colony(socket)}
  end
end
```

There's a test for it. With the hook deleted, that test fails.

## Authority that stays current

When a beaver's membership changes, the context broadcasts a message that says only **which colony** changed, never the new role. The open page reads the membership again from the database:

- **Promoted:** the scope is rebuilt and the page shows the new role.
- **Demoted below what the page needs:** the page is left.
- **Removed:** the colony is left.

Because the page re-reads the database, a message can't grant anything. A stale or forged one does no harm.

## Who owns a message

LiveView passes any message no hook halted on to the page. A page with some `handle_info` clauses, but none for that message, crashes. So each PubSub topic has one kind of listener:

| Topic | Listener |
|---|---|
| `beaver:<id>:access` | the app shell: `BeaverAuth` reacts, then `Nav` refreshes and halts |
| `beaver:<id>:memberships` | pages listing your colonies |
| `colony:<id>:memberships` | pages listing a colony's members |

A hook only halts messages on topics it subscribed to.

## Try it

Use the switcher's **Try it as a Lodge Keeper**, open Members, then switch to the Builder and paste the Members URL into the address bar. You'll be sent back to the dashboard with a flash, by the page's own `{:require, :manage_members}`.
