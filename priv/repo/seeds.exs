# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     BeaverColony.Repo.insert!(%BeaverColony.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Demo beavers, one per role, in two colonies. See BeaverColony.Demo for who is where.
# Safe to run again.
BeaverColony.Demo.seed!()
