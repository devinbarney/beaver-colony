defmodule BeaverColonyWeb.DemoController do
  @moduledoc """
  "Try it as..." from the guide: signs the reader in as the demo beaver for a role and
  lands them in the demo colony. A 404 unless demos are on (see `BeaverColony.Demo`).
  """
  use BeaverColonyWeb, :controller

  alias BeaverColony.Demo
  alias BeaverColony.Colonies.Policy
  alias BeaverColonyWeb.BeaverAuth

  def create(conn, %{"role" => role}) do
    with role when role != nil <- Policy.role_from_param(role),
         {beaver, landing} <- Demo.sign_in_as(role) do
      conn
      |> put_session(:beaver_return_to, landing)
      |> put_flash(
        :info,
        "You're the demo #{Policy.display_name(role)} now. Look at the sidebar."
      )
      |> BeaverAuth.log_in_beaver(beaver)
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> put_view(html: BeaverColonyWeb.ErrorHTML)
        |> render(:"404")
    end
  end
end
