%{
  title: "A sidebar that knows who you are",
  description: "The nav as a pure function of the scope, a colony switcher, and a slide that never asks the server."
}
---

> **Draft.** Written from the build journal; to be rewritten in the author's voice.

## Data first, markup second

The sidebar is two modules:

- `BeaverColonyWeb.Nav.build(scope, nav)` returns **plain data**: a context item (the switcher), the page items, the footer. No markup.
- `BeaverColonyWeb.NavComponents` renders that data. It makes every display decision and none of the "what may this beaver see" ones.

`Nav.build/2` runs **at render time**, inside the layout:

```elixir
def app(%{nav: nav} = assigns) when nav != nil do
  assigns = assign(assigns, :sidebar, Nav.build(assigns.current_scope, nav))
  ...
end
```

So the sidebar can never disagree with the scope it was drawn with. When a role changes (Part 3), the scope changes and the sidebar follows; nothing has to remember to rebuild it.

## Pages are filtered, not hand-written per role

My first sidebar had a hand-written tree for every role. Now there's one list, and the nav keeps what the scope can open:

```elixir
def colony_pages(colony) do
  [
    %{id: "dashboard", label: "Dashboard", path: ~p"/colonies/#{colony}", requires: :view_colony},
    %{id: "members", label: "Members", path: ~p"/colonies/#{colony}/members",
      requires: :manage_members, badge: :pending},
    %{id: "settings", label: "Colony settings", path: ~p"/colonies/#{colony}/settings",
      requires: :manage_colony}
  ]
end

for page <- colony_pages(colony), Scope.can?(scope, page.requires), do: page
```

The nav and the pages each name an ability, so could they disagree? One test answers that. For every role it opens every page and checks that a page is in the nav **exactly** when it opens. Make the Members page ask for less than the nav assumes, and the test fails.

## The switcher

The top of the sidebar looks like a role switcher. It shows your colony and your role there, and lists every colony with your role in each:

- 🦫 Me
- Klamath Colony, *Dam Developer*
- **Willamette Colony**, *Lodge Keeper*

Underneath, it's a **colony switcher**. Each entry is a plain `navigate` link, and the destination checks access again, so the switcher grants nothing by itself. In this guide it also offers the demo beavers.

## Sliding off and on, with no server

The open/closed state is a checkbox in the **root layout**:

```heex
<body>
  <input type="checkbox" id="nav-toggle" class="nav-toggle" hidden />
  {@inner_content}
</body>
```

Live navigation never re-renders the root layout, so the checkbox and the sidebar's state survive every `navigate`. A label in the top bar toggles it, and CSS reads it as a sibling of the LiveView container:

```css
@media (min-width: 768px) {
  .nav-toggle:checked ~ [data-phx-main] .nav__aside { transform: translateX(-100%); }
  .nav-toggle:checked ~ [data-phx-main] .shell__main { margin-left: 0; }
}
```

On phones the meaning flips: closed by default, and checking it slides the sidebar over the page. About twenty lines of JavaScript do the two things CSS can't:
- remember a closed sidebar across full page loads;
- close the phone overlay after you pick a page.

My first version kept this state in a LiveComponent on the server and pushed it back to the browser on every toggle.

## Keeping it current

`Nav`'s `on_mount` loads what the scope doesn't carry, your memberships and the pending-request count, into `@nav`. It refreshes them on the shell's access topic and halts the message, so pages never see it. A page whose own action changes the sidebar, like the Members page letting a beaver in, calls `Nav.refresh/1`.

## You've been using it

Every link on the left of this page came from `Nav.build/2`. The guide is just another area of the same sidebar: its items are these articles, and its switcher knows whether you're signed in. Try each demo beaver and watch the same function draw three different sidebars.
