# Beaver Colony 🦫

A small Phoenix LiveView app about beavers who form colonies to build dams. It exists to teach three things:

1. **One LiveView, one job.** Navigating between LiveViews is a separate problem with its own architecture.
2. **Phoenix 1.8 Scopes.** `%Scope{}` carries who is asking, which colony they're in and what role they hold, and every context function takes it first.
3. **A secure multi-tenant sidebar.** It adapts to your role in the current colony and slides off and on screen.

The colony is the tenant. A beaver can belong to many colonies, with one role in each:

| Role | Can |
|---|---|
| **Dam Developer** | Founded the colony and runs it |
| **Lodge Keeper** | Approves new members, keeps the colony organized |
| **Builder** | Does the building |

Every account is a beaver, and every beaver has personal pages (`/me`) that belong to no colony.

![The sidebar inside a colony, with the colony switcher open](docs/screenshots/sidebar-switcher.png)

## Running it

Requirements: Elixir 1.17+ and PostgreSQL.

```sh
mix setup        # deps, database, assets
mix phx.server   # http://localhost:4000
```

The database password defaults to `postgres`. If yours is different, set `PGPASSWORD` instead of editing config:

```sh
PGPASSWORD=secret mix setup
```

To set it once for this directory, with [mise](https://mise.jdx.dev), put it in a `mise.local.toml` (already in `.gitignore`) and run `mise trust`:

```toml
[env]
PGPASSWORD = "secret"
```

`mix setup` also seeds demo beavers, all with the password `beavers build dams`:
`dam@example.com`, `keeper@example.com` and `builder@example.com`.

Run the tests with `mix test`.

## The guide

The app explains itself. Open [`/guide`](http://localhost:4000/guide) for the article series about how it's built, in the same sidebar the articles describe. The articles are markdown in `priv/guide`, and `docs/journal.md` records decisions as they're made.

![A guide article, with the parts in the sidebar](docs/screenshots/guide-article.png)

### Demo mode

The guide's switcher offers **Try it as a Builder / Lodge Keeper / Dam Developer**, which signs you in as a seeded demo beaver with no password. Because that is a passwordless sign-in, it is off unless configured:

- on in dev and test (`config :beaver_colony, :demo, enabled: true`)
- off in production unless `DEMO_MODE=true`, with `DEMO_RESET_HOURS` (default 24) putting the demo data back on an interval

Only turn it on where the demo accounts hold nothing that matters.

## License

MIT. See [LICENSE](LICENSE).
