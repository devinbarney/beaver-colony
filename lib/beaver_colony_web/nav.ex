defmodule BeaverColonyWeb.Nav do
  @moduledoc """
  The sidebar's data: what it shows is a pure function of the current scope.

  Two halves:

    * `on_mount/4` loads what the scope doesn't carry, the beaver's colonies (for the
      switcher) and the pending-request count (for a badge), into `@nav`, and keeps it
      current. It must be the **last** hook in every signed-in `live_session`.
    * `build/2` turns the scope plus `@nav` into plain data: a context item, the page
      items, the footer. No markup. `BeaverColonyWeb.NavComponents` renders it, and
      the layout calls `build/2` at render time, so the sidebar can never disagree with
      the scope it was rendered with.

  ## Which pages appear

  A colony page appears if the scope can open it, using the same `Scope.can?/2` the
  page's own `on_mount {BeaverAuth, {:require, ability}}` uses. `colony_pages/1` is the
  list, and a test checks every entry's ability against its LiveView's requirement.

  ## Live updates

  The hook subscribes the page to the beaver's access topic
  (`BeaverColony.Colonies.subscribe_my_access/1`). On `{:access_changed, _}`,
  `BeaverColonyWeb.BeaverAuth` has already refreshed or left the colony page (its
  hook is attached earlier), so this one reloads `@nav` and halts: pages never see
  the message.
  """
  use BeaverColonyWeb, :verified_routes

  import Phoenix.Component, only: [assign: 3, update: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Colonies
  alias BeaverColony.Colonies.Policy

  ## Loading

  def on_mount(:default, _params, _session, socket) do
    scope = socket.assigns.current_scope

    if connected?(socket), do: Colonies.subscribe_my_access(scope)

    socket =
      socket
      |> assign(:nav, load(scope, ""))
      |> attach_hook(:nav_current_path, :handle_params, fn _params, uri, socket ->
        {:cont, update(socket, :nav, &%{&1 | current_path: URI.parse(uri).path})}
      end)
      |> attach_hook(:nav_refresh, :handle_info, fn
        {:access_changed, _colony_id}, socket ->
          {:halt, refresh(socket)}

        _other, socket ->
          {:cont, socket}
      end)

    {:cont, socket}
  end

  @doc """
  Reloads `@nav`. For pages whose own actions change what the sidebar shows, such as
  the Members page letting a beaver in, which lowers the pending badge.
  """
  def refresh(socket) do
    assign(socket, :nav, load(socket.assigns.current_scope, socket.assigns.nav.current_path))
  end

  defp load(scope, current_path) do
    %{
      memberships: Colonies.list_memberships(scope),
      pending: if(Scope.can?(scope, :manage_members), do: Colonies.count_pending(scope), else: 0),
      current_path: current_path
    }
  end

  ## Building

  @doc """
  Every page of a colony, with the ability each needs. Each LiveView declares the same
  ability with `on_mount {BeaverAuth, {:require, ability}}`.
  """
  def colony_pages(colony) do
    [
      %{
        id: "dashboard",
        label: "Dashboard",
        path: ~p"/colonies/#{colony}",
        requires: :view_colony
      },
      %{
        id: "members",
        label: "Members",
        path: ~p"/colonies/#{colony}/members",
        requires: :manage_members,
        badge: :pending
      },
      %{
        id: "settings",
        label: "Colony settings",
        path: ~p"/colonies/#{colony}/settings",
        requires: :manage_colony
      }
    ]
  end

  @doc """
  The sidebar for `scope`, given the `@nav` data the hook loaded.

  Returns `%{context: [item], items: [item], footer: [item]}`. An item is a map with
  `:id`, `:label`, maybe a `:sublabel`, and either `:path` (a link, maybe with `:badge`
  and `:current`) or `:children` (a flyout).
  """
  def build(%Scope{} = scope, nav) do
    %{
      context: [switcher(scope, nav.memberships)],
      items: items(scope, nav) |> mark_current(nav.current_path),
      footer: [account_menu(scope)]
    }
  end

  # Inside a colony: the colony's pages this role can open.
  defp items(%Scope{colony: colony} = scope, nav) when colony != nil do
    for page <- colony_pages(colony), Scope.can?(scope, page.requires) do
      page
      |> Map.take([:id, :label, :path])
      |> Map.put(:badge, if(page[:badge] == :pending, do: nav.pending))
    end
  end

  # Personal pages: the beaver's own.
  defp items(_scope, _nav) do
    [
      %{id: "my_colonies", label: "My colonies", path: ~p"/me/colonies"},
      %{id: "account", label: "Account settings", path: ~p"/beavers/settings"}
    ]
  end

  defp mark_current(items, current_path) do
    Enum.map(items, &Map.put(&1, :current, &1.path == current_path))
  end

  # Where you are, and where else you could be: yourself, or one of your colonies with
  # your role there. Each option is a plain link; the destination checks access again.
  defp switcher(scope, memberships) do
    me = %{id: "me", label: "🦫 Me", path: ~p"/me/colonies", current: scope.colony == nil}

    colonies =
      for membership <- memberships do
        %{
          id: "colony-#{membership.colony.id}",
          label: membership.colony.name,
          sublabel: Policy.display_name(membership.role),
          path: ~p"/colonies/#{membership.colony}",
          current: scope.colony != nil and scope.colony.id == membership.colony.id
        }
      end

    %{
      id: "switcher",
      label: if(scope.colony, do: scope.colony.name, else: "🦫 Me"),
      sublabel: if(scope.colony, do: Policy.display_name(scope.role), else: "Your own pages"),
      children:
        [me | colonies] ++
          [
            %{id: "switcher-divider", divider: true},
            %{
              id: "find-colony",
              label: "Find or found a colony",
              path: ~p"/me/colonies",
              special: true
            }
          ]
    }
  end

  defp account_menu(scope) do
    %{
      id: "account-menu",
      label: scope.beaver.email,
      children: [
        %{id: "account-settings", label: "Account settings", path: ~p"/beavers/settings"},
        %{id: "log-out", label: "Log out", path: ~p"/beavers/log-out", method: :delete}
      ]
    }
  end
end
