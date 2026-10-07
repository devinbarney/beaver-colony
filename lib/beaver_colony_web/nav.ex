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

  ## Two areas

  `on_mount(:default, ...)` is for the app: personal pages and colony pages, always
  signed in. `on_mount(:guide, ...)` is for the article series, open to anyone, where
  the items are the articles. Both use the same sidebar, so reading the guide is also
  a tour of the nav it describes.

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
  alias BeaverColony.{Colonies, Demo, Guide}
  alias BeaverColony.Colonies.Policy

  ## Loading

  def on_mount(area, _params, _session, socket) when area in [:default, :guide] do
    scope = socket.assigns.current_scope
    area = if area == :default, do: :app, else: :guide

    if connected?(socket) and signed_in?(scope), do: Colonies.subscribe_my_access(scope)

    socket =
      socket
      |> assign(:nav, load(scope, area, ""))
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
    %{area: area, current_path: path} = socket.assigns.nav
    assign(socket, :nav, load(socket.assigns.current_scope, area, path))
  end

  defp load(scope, area, current_path) do
    %{
      area: area,
      memberships: if(signed_in?(scope), do: Colonies.list_memberships(scope), else: []),
      pending: if(Scope.can?(scope, :manage_members), do: Colonies.count_pending(scope), else: 0),
      articles: if(area == :guide, do: Guide.list_articles(), else: []),
      demo_roles: if(Demo.enabled?(), do: Demo.roles(), else: []),
      current_path: current_path
    }
  end

  defp signed_in?(scope), do: match?(%Scope{beaver: %{}}, scope)

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
  The sidebar for `scope` (`nil` when signed out, which only the guide allows), given
  the `@nav` data the hook loaded.

  Returns `%{context: [item], items: [item], footer: [item]}`. An item is a map with
  `:id`, `:label`, maybe a `:sublabel`, and either `:path` (a link, maybe with `:badge`,
  `:current` or `:method`) or `:children` (a flyout).
  """
  def build(scope, nav) do
    %{
      context: [switcher(scope, nav)],
      items: items(scope, nav) |> mark_current(nav.current_path),
      footer: footer(scope)
    }
  end

  # The guide: its contents page, then each article.
  defp items(_scope, %{area: :guide} = nav) do
    contents = %{id: "guide-contents", label: "Contents", path: ~p"/guide"}

    articles =
      for article <- nav.articles do
        %{
          id: "guide-#{article.id}",
          label: article.title,
          sublabel: "Part #{article.part}",
          path: ~p"/guide/#{article.id}"
        }
      end

    [contents | articles]
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

  # Where you are, and where else you could be: yourself, one of your colonies (with
  # your role there), or the guide, and in a demo, one of the demo beavers. Each option
  # is a plain link; the destination checks access again.
  defp switcher(scope, nav) do
    {label, sublabel} = where(scope, nav)

    %{
      id: "switcher",
      label: label,
      sublabel: sublabel,
      children: places(scope, nav) ++ guide_option(scope, nav) ++ demo_options(nav)
    }
  end

  defp where(_scope, %{area: :guide}), do: {"📖 The guide", "How this app is built"}
  defp where(%Scope{colony: nil}, _nav), do: {"🦫 Me", "Your own pages"}
  defp where(scope, _nav), do: {scope.colony.name, Policy.display_name(scope.role)}

  defp places(scope, nav) do
    if signed_in?(scope) do
      in_app = nav.area == :app

      me = %{
        id: "me",
        label: "🦫 Me",
        path: ~p"/me/colonies",
        current: in_app and scope.colony == nil
      }

      colonies =
        for membership <- nav.memberships do
          %{
            id: "colony-#{membership.colony.id}",
            label: membership.colony.name,
            sublabel: Policy.display_name(membership.role),
            path: ~p"/colonies/#{membership.colony}",
            current: in_app and scope.colony != nil and scope.colony.id == membership.colony.id
          }
        end

      [me | colonies] ++ [%{id: "places-divider", divider: true}]
    else
      []
    end
  end

  defp guide_option(scope, nav) do
    guide = %{id: "guide", label: "📖 The guide", path: ~p"/guide", current: nav.area == :guide}

    if signed_in?(scope) do
      find = %{id: "find-colony", label: "Find or found a colony", path: ~p"/me/colonies"}
      [guide, Map.put(find, :special, true)]
    else
      [guide]
    end
  end

  # Signing in as a demo beaver is a POST, so these are form-backed links.
  defp demo_options(%{demo_roles: []}), do: []

  defp demo_options(nav) do
    options =
      for role <- nav.demo_roles do
        %{
          id: "demo-#{role}",
          label: "Try it as a #{Policy.display_name(role)}",
          path: ~p"/demo/#{role}",
          method: :post,
          special: true
        }
      end

    [%{id: "demo-divider", divider: true} | options]
  end

  defp footer(scope) do
    if signed_in?(scope) do
      [
        %{
          id: "account-menu",
          label: scope.beaver.email,
          children: [
            %{id: "account-settings", label: "Account settings", path: ~p"/beavers/settings"},
            %{id: "log-out", label: "Log out", path: ~p"/beavers/log-out", method: :delete}
          ]
        }
      ]
    else
      [
        %{id: "log-in", label: "Log in", path: ~p"/beavers/log-in"},
        %{id: "register", label: "Become a beaver", path: ~p"/beavers/register"}
      ]
    end
  end
end
