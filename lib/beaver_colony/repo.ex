defmodule BeaverColony.Repo do
  use Ecto.Repo,
    otp_app: :beaver_colony,
    adapter: Ecto.Adapters.Postgres
end
