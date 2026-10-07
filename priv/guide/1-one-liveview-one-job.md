%{
  title: "One LiveView, one job",
  description: "Why navigation between LiveViews is its own problem, and the beaver colonies we'll use to solve it."
}
---

> **Draft.** Written from the build journal; to be rewritten in the author's voice.

## The LiveView that ate the app

My first multi-tenant LiveView app had an organization page. It started as a dashboard. Then it grew tabs, and the tabs grew sub-pages. Before long, that one LiveView decided which "page" you were on, kept that in its own state, loaded data for every tab, and checked who was allowed to see what.

It had quietly become a router *inside* a LiveView. Every new feature made it bigger, and every bug fix had to remember every tab.

The fix wasn't a refactor. It was a different idea of what a LiveView is for:

1. **One LiveView does one job.** A members page lists members. A settings page edits settings. Neither knows the other exists.
2. **Getting between them is a separate problem.** Who you are, which tenant you're in, what you're allowed to open, and how the sidebar shows all of that. That deserves its own architecture, outside any one page.

This series builds that architecture from zero, in a small app you can run, read and fork.

## Beaver colonies

The app needs to be multi-tenant, but it shouldn't need any explaining. So: **beavers form colonies to build dams.**

- A **colony** is the tenant. Everything a colony owns is invisible to other colonies.
- Every account is a **beaver**. A beaver can belong to many colonies, with one role in each:

| Role | Can |
|---|---|
| Dam Developer | founded the colony, runs it |
| Lodge Keeper | lets new beavers in, removes Builders |
| Builder | belongs |

- Every beaver also has **personal pages** that belong to no colony.

The roles are ranked: a Dam Developer can do everything a Lodge Keeper can, and a Lodge Keeper everything a Builder can. That keeps the rules small, and Part 3 shows why it matters.

## Try it now

You're reading this inside the app. The sidebar on the left is the one this series is about. Open the switcher at the top of it and pick **Try it as a Builder**: you'll be signed in as a demo beaver in Willamette Colony. Then try the Lodge Keeper and the Dam Developer, and watch which pages appear.

## Starting from zero

```sh
mix phx.new beaver_colony --binary-id
cd beaver_colony
mix phx.gen.auth Accounts Beaver beavers --live
```

The second command does more than add log in and registration. It generates a **scope**, `BeaverColony.Accounts.Scope`, and wires it through the router and every generated LiveView. That scope is the subject of Part 2, and the foundation of everything after it.

Two small things worth knowing on day one:

- **The generated code fails `mix format --check-formatted`.** The templates are sized for `User`, and `Beaver` is two characters longer. Run `mix format` once before CI tells you.
- **Don't commit your database password.** Make `config/dev.exs` read it from the environment instead:

```elixir
config :beaver_colony, BeaverColony.Repo,
  username: "postgres",
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: "localhost"
```

## Where we're going

- **Part 2:** what a Phoenix Scope is, and how to put a colony and a role in it.
- **Part 3:** making it secure. The URL picks the colony, the membership picks the role, every page says what it needs, and every context function checks.
- **Part 4:** the sidebar. A pure function of the scope that slides off and on screen without asking the server.
