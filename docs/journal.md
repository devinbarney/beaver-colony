# Build journal

Decisions, dead ends and surprises, in the order they happened. The articles are written from this.

## 2026-10-05 — Day zero

**Why this app exists.** In an earlier multi-tenant LiveView app, one organization LiveView grew until it was doing the work *and* deciding which sub-page you were on. The lesson: each LiveView does one job, and navigating between them is its own problem. This app solves that problem on purpose, from the start.

**The story.** Beavers form colonies (tenants) to build dams. Roles in a colony, highest first: Dam Developer, Lodge Keeper, Builder. Every account is a beaver, and every beaver also has personal pages that belong to no colony.

**Generated, not hand-written.**
- `mix phx.new beaver_colony --binary-id`
- `mix phx.gen.auth Accounts Beaver beavers --live`

The second command gives us `BeaverColony.Accounts.Scope` with `defstruct beaver: nil`, plus a `:scopes` entry in `config/config.exs` named `beaver`. That generated scope is the starting point for everything tenant-related.

**Local database password.** Phoenix writes `password: "postgres"` into dev and test config. Rather than commit a real local password to a public repo, both read `System.get_env("PGPASSWORD", "postgres")`.

**Architecture decisions so far** (reasons in the articles):
- The URL picks the **colony**, never the role.
- The **membership** supplies the role, and the scope carries it: `%Scope{beaver, colony, role}`.
- Each LiveView declares the **ability** it needs. The router only declares the colony context.
- Every context function takes the scope first and checks it. Isolation lives in the function signatures, not in the pages.
- The sidebar is a pure function of the scope. Its slide state lives in the root layout, so it costs the server nothing.

**A small surprise.** The generated auth code fails `mix format --check-formatted`. The templates are sized for `user`, and `beaver` is two characters longer, which pushes some lines past 98 columns. One `mix format` fixes it. Worth knowing before CI tells you.

## 2026-10-07 — Phase 2: colonies in the scope

**What was built**
- `Colony` (the tenant) and `Membership` (beaver, colony, role, status). One membership per beaver per colony, enforced by a unique index. A beaver has exactly one role in each colony.
- `Colonies.Policy`: the *only* table of who may do what. Roles are ranked (Builder < Lodge Keeper < Dam Developer), so each ability names just the lowest role that has it. An unknown ability raises, so a typo fails loudly instead of locking everyone out.
- `%Scope{beaver, colony, role}`, with `Scope.put_colony/3` and `Scope.can?/2`. `can?/2` is always false without a colony.
- Two `on_mount` clauses in the generated `BeaverAuth`:
  - `:assign_colony` loads the colony **through** the beaver's approved membership, in one query, and puts it in the scope. It also attaches the pin hook.
  - `{:require, ability}` is declared by each LiveView itself: `on_mount {BeaverAuth, {:require, :manage_members}}`.
- One `live_session :colony` for every colony page. The router never names a role.
- A `colony` generator scope in `config.exs`, now the default. `mix phx.gen.live` will produce colony-scoped code from here on.
- Placeholder pages: My colonies (found one), Dashboard (any member), Members (Lodge Keeper+), Settings (Dam Developer).

**Two rules every context function follows**
1. *Reads are filtered by the scope.* A colony's data is only queried with `scope.colony.id`, never with an id from the caller.
2. *Writes check the scope's ability* and return `{:error, :unauthorized}`. The page checks first only to give a friendly redirect; the context doesn't trust that it did.

**Not found means not found.** A colony that doesn't exist, one you're not in, one where you're still pending, and an id that isn't a UUID all give the same answer. Otherwise the error would tell a stranger which colonies exist.

**The patch hole, proven.** `on_mount` doesn't run on a patch. A test patches from colony A's members page to colony B's, where the beaver *is* a member, and expects a redirect. With the pin hook removed, that test fails: the page would show B's URL with A's scope.

## 2026-10-07 — Phase 3: joining, and authority that stays current

**The flow.** A beaver sees *Other colonies* on My colonies and asks to join. That makes a pending Builder membership. A Lodge Keeper (or the Dam Developer) lets them in or declines. The Dam Developer changes roles. Anyone can remove a member ranked below them.

**One rank rule covers every management action.** You can only act on beavers ranked *below* you, and only give out roles *below* your own. That single rule in `Policy.outranks?/2` means:
- no one can create a second Dam Developer;
- a Lodge Keeper can't remove another Lodge Keeper;
- a colony can never lose its Dam Developer.

The Members page uses the same rule only to decide which buttons to show. The context enforces it.

**Colony names are public, colony data isn't.** Beavers need to find a colony to join, so names are listed. Everything else still needs an approved membership.

**Messages are nudges, not facts.** Every membership change is broadcast on two topics: the beaver's (`beaver:<id>:memberships`) and the colony's (`colony:<id>:memberships`). The message only says *which colony* changed, never the new role. Whoever receives it reads the membership again from the database. A message can't grant anything, and a stale or forged one does no harm.

**Authority stays current on open pages.** `:assign_colony` subscribes to the beaver's topic and attaches a `handle_info` hook that owns those messages, so pages never handle them. When the beaver's membership in *this* colony changes, the hook:
- rebuilds the scope with the new role (a promoted Builder sees "Lodge Keeper" without reloading);
- leaves the page if the new role can't open it (each `{:require, ability}` page records its ability for exactly this check);
- leaves the colony if the membership is gone.

Without this, a demoted or removed beaver keeps their old powers on any page they already have open, until their next navigation. A mutation check confirmed it: delete the hook and exactly those three tests fail.

**A compiler catch.** A hidden input named `id` triggers a LiveView warning: it shadows the form element's own `id`. It's now `membership_id`.

## 2026-10-07 — Phase 4: the sidebar

**The nav is a pure function of the scope.** `Nav.build(scope, nav)` returns plain data (the context switcher, the page items, the footer) and `NavComponents` renders it. The layout calls `build/2` *at render time*, so the sidebar can never disagree with the scope it was drawn with. When a role changes, the scope changes and the sidebar follows; nothing has to remember to rebuild it.

**Pages are filtered, not hand-written per role.** `Nav.colony_pages/1` lists every colony page with the ability it needs, and the nav keeps the ones `Scope.can?/2` allows. One test logs in as every role, opens every page, and checks a page is in the nav *exactly* when it opens. Making the Members page ask for less than the nav assumes fails that test. In the old design, the nav trees and the route guards were written separately and could drift.

**The switcher looks like a role switcher but is a colony switcher.** It shows where you are: "🦫 Me" or a colony with your role there. The options are every colony with your role in each. Each option is a plain link, and the destination checks access again.

**Who owns which message.** The sidebar, the colony check and the My colonies page all care when a membership changes. LiveView passes a message no hook halted on to the page, and a page with *some* `handle_info` clauses but none for that message crashes. So each topic now has one kind of listener:
- `beaver:<id>:access` is the app shell's. `BeaverAuth`'s hook reacts first (rebuild the scope, or leave), then `Nav`, last in every signed-in `live_session`, reloads and **halts**.
- `beaver:<id>:memberships` and `colony:<id>:memberships` are the pages'. They subscribe themselves.

The context broadcasts to all three.

**Open/closed costs the server nothing.** The checkbox lives in the root layout, which live navigation never re-renders, so it survives every `navigate`. CSS reads it as a sibling of the LiveView container: `.nav-toggle:checked ~ [data-phx-main] .nav__aside`. On wide screens checked means closed and the page widens; on phones checked means open and the sidebar slides over the page. About twenty lines of JS do the two things CSS can't: remember a closed sidebar across full reloads, and close the phone overlay after you pick a page.

**Checked in a real browser** (headless Chromium via Playwright), not just in tests:
- collapse → full reload → still collapsed;
- collapse → live navigate → still collapsed (the sidebar's right edge sits at 0px);
- on a phone the overlay closes after a link;
- no console errors.

**Smaller things**
- The generated home page didn't use `Layouts.app`. Its signed-in menu came from the root layout, so moving that menu broke three generated tests. The home page is now a short Beaver Colony welcome that uses the plain layout.
- `priv/repo/seeds.exs` adds three demo beavers across two colonies, with a pending request. It's safe to run again.

## 2026-10-07 — Phase 6: the guide inside the app

**The articles live in the app, in the sidebar they describe.**
- `BeaverColony.Guide` compiles `priv/guide/<part>-<slug>.md` with NimblePublisher, the same pattern as the blog that will host them later, so they can move over unchanged.
- `/guide` and `/guide/:id` are public, in a `:guide` live_session.
- `Nav` gained a second area. `on_mount(:guide, ...)` loads the articles, and `build/2` turns them into the page items. The switcher reads "📖 The guide" and, when demos are on, offers *Try it as a Builder / Lodge Keeper / Dam Developer*.
- The app's switcher links back to the guide.

Same function, same components, one more area. That's the payoff of keeping the nav as data.

**Demo sign-in is a passwordless login, so it's off by default.**
- `POST /demo/:role` signs you in as a seeded demo beaver and lands you in Willamette Colony.
- It's a 404 unless `config :beaver_colony, :demo, enabled: true`: on in dev and test, and in production only with `DEMO_MODE=true`.
- It's a POST behind CSRF protection, so a link on another site can't sign a visitor in. Tests skip CSRF, so this was checked in a real browser.
- `Demo.Reset` re-seeds on an interval, but only where `reset_every` is set. It never runs in dev, where it would wipe your changes.
- Seeding moved from `seeds.exs` into `BeaverColony.Demo.seed!/0` so the reset can reuse it.

**Code highlighting** comes from Makeup: a friendly light style, and monokai under `[data-theme=dark]`, generated once into `assets/css/makeup.css`.

**The articles are drafts**, written from this journal, waiting to be rewritten in the author's voice.
