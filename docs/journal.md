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
