defmodule BeaverColonyWeb.BeaverSessionController do
  use BeaverColonyWeb, :controller

  alias BeaverColony.Accounts
  alias BeaverColonyWeb.BeaverAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "Beaver confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"beaver" => %{"token" => token} = beaver_params}, info) do
    case Accounts.login_beaver_by_magic_link(token) do
      {:ok, {beaver, tokens_to_disconnect}} ->
        BeaverAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> BeaverAuth.log_in_beaver(beaver, beaver_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/beavers/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"beaver" => beaver_params}, info) do
    %{"email" => email, "password" => password} = beaver_params

    if beaver = Accounts.get_beaver_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> BeaverAuth.log_in_beaver(beaver, beaver_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/beavers/log-in")
    end
  end

  def update_password(conn, %{"beaver" => beaver_params} = params) do
    beaver = conn.assigns.current_scope.beaver
    true = Accounts.sudo_mode?(beaver)
    {:ok, {_beaver, expired_tokens}} = Accounts.update_beaver_password(beaver, beaver_params)

    # disconnect all existing LiveViews with old sessions
    BeaverAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:beaver_return_to, ~p"/beavers/settings")
    |> create(params, "Password updated successfully!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> BeaverAuth.log_out_beaver()
  end
end
