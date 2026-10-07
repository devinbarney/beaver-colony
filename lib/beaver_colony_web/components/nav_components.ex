defmodule BeaverColonyWeb.NavComponents do
  @moduledoc """
  Renders the sidebar from the plain data `BeaverColonyWeb.Nav.build/2` returns. All
  display decisions live here; none of the "what may this beaver see" decisions do.

  Sliding off and on screen is pure CSS: the label in the header toggles the
  `#nav-toggle` checkbox in the root layout, which live navigation never re-renders,
  so the sidebar stays open or closed across pages without any server state.
  """
  use Phoenix.Component
  use BeaverColonyWeb, :verified_routes

  slot :inner_block, doc: "controls at the right end of the bar"

  def topbar(assigns) do
    ~H"""
    <header class="nav__header">
      <label for="nav-toggle" class="nav__toggle" aria-label="Show or hide navigation">
        <svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true">
          <rect x="4" y="4" width="16" height="16" rx="2" />
          <line x1="9" y1="4" x2="9" y2="20" />
        </svg>
      </label>
      <.link navigate={~p"/"} class="nav__brand">🦫 Beaver Colony</.link>
      <div class="nav__header-end">
        {render_slot(@inner_block)}
      </div>
    </header>
    """
  end

  attr :nav, :map, required: true, doc: "the result of `BeaverColonyWeb.Nav.build/2`"

  def sidebar(assigns) do
    ~H"""
    <aside class="nav__aside" aria-label="Main navigation">
      <ul class="nav__context">
        <.nav_item :for={item <- @nav.context} item={item} float={:down} />
      </ul>

      <nav class="nav__menu">
        <ul class="nav__list">
          <.nav_item :for={item <- @nav.items} item={item} float={:down} />
        </ul>
      </nav>

      <ul class="nav__footer">
        <.nav_item :for={item <- @nav.footer} item={item} float={:up} />
      </ul>
    </aside>
    """
  end

  attr :item, :map, required: true
  attr :float, :atom, values: [:up, :down], default: :down

  defp nav_item(%{item: %{children: _}} = assigns) do
    ~H"""
    <li class="nav-item nav-item--flyout" id={"nav-#{@item.id}"}>
      <button type="button" class="nav-item__trigger" aria-haspopup="true">
        <span class="nav-item__label">{@item.label}</span>
        <span :if={@item[:sublabel]} class="nav-item__sublabel">{@item.sublabel}</span>
      </button>
      <ul class={["nav-submenu", "nav-submenu--float-#{@float}"]} role="menu">
        <.nav_child :for={child <- @item.children} child={child} />
      </ul>
    </li>
    """
  end

  defp nav_item(assigns) do
    ~H"""
    <li class="nav-item" id={"nav-#{@item.id}"}>
      <.link
        navigate={@item.path}
        class={["nav-item__link", @item[:current] && "nav-item__link--current"]}
        aria-current={@item[:current] && "page"}
      >
        <span class="nav-item__text">
          <span class="nav-item__label">{@item.label}</span>
          <span :if={@item[:sublabel]} class="nav-item__sublabel">{@item.sublabel}</span>
        </span>
        <span :if={@item[:badge] not in [nil, 0]} class="nav-item__badge">{@item.badge}</span>
      </.link>
    </li>
    """
  end

  attr :child, :map, required: true

  defp nav_child(%{child: %{divider: true}} = assigns) do
    ~H"""
    <li class="nav-submenu__divider" role="separator"></li>
    """
  end

  defp nav_child(%{child: %{method: _}} = assigns) do
    ~H"""
    <li role="menuitem">
      <.link
        href={@child.path}
        method={@child.method}
        class={["nav-submenu__item", @child[:special] && "nav-submenu__item--special"]}
      >
        {@child.label}
      </.link>
    </li>
    """
  end

  defp nav_child(assigns) do
    ~H"""
    <li role="menuitem">
      <.link
        navigate={@child.path}
        class={[
          "nav-submenu__item",
          @child[:current] && "nav-submenu__item--current",
          @child[:special] && "nav-submenu__item--special"
        ]}
        aria-current={@child[:current] && "true"}
      >
        <span class="nav-submenu__label">{@child.label}</span>
        <span :if={@child[:sublabel]} class="nav-submenu__sublabel">{@child.sublabel}</span>
      </.link>
    </li>
    """
  end
end
