defmodule BeaverColonyWeb.BeaverSessionControllerTest do
  use BeaverColonyWeb.ConnCase, async: true

  import BeaverColony.AccountsFixtures
  alias BeaverColony.Accounts

  setup do
    %{unconfirmed_beaver: unconfirmed_beaver_fixture(), beaver: beaver_fixture()}
  end

  describe "POST /beavers/log-in - email and password" do
    test "logs the beaver in", %{conn: conn, beaver: beaver} do
      beaver = set_password(beaver)

      conn =
        post(conn, ~p"/beavers/log-in", %{
          "beaver" => %{"email" => beaver.email, "password" => valid_beaver_password()}
        })

      assert get_session(conn, :beaver_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ beaver.email
      assert response =~ ~p"/beavers/settings"
      assert response =~ ~p"/beavers/log-out"
    end

    test "logs the beaver in with remember me", %{conn: conn, beaver: beaver} do
      beaver = set_password(beaver)

      conn =
        post(conn, ~p"/beavers/log-in", %{
          "beaver" => %{
            "email" => beaver.email,
            "password" => valid_beaver_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_beaver_colony_web_beaver_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the beaver in with return to", %{conn: conn, beaver: beaver} do
      beaver = set_password(beaver)

      conn =
        conn
        |> init_test_session(beaver_return_to: "/foo/bar")
        |> post(~p"/beavers/log-in", %{
          "beaver" => %{
            "email" => beaver.email,
            "password" => valid_beaver_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn, beaver: beaver} do
      conn =
        post(conn, ~p"/beavers/log-in?mode=password", %{
          "beaver" => %{"email" => beaver.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/beavers/log-in"
    end
  end

  describe "POST /beavers/log-in - magic link" do
    test "logs the beaver in", %{conn: conn, beaver: beaver} do
      {token, _hashed_token} = generate_beaver_magic_link_token(beaver)

      conn =
        post(conn, ~p"/beavers/log-in", %{
          "beaver" => %{"token" => token}
        })

      assert get_session(conn, :beaver_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ beaver.email
      assert response =~ ~p"/beavers/settings"
      assert response =~ ~p"/beavers/log-out"
    end

    test "confirms unconfirmed beaver", %{conn: conn, unconfirmed_beaver: beaver} do
      {token, _hashed_token} = generate_beaver_magic_link_token(beaver)
      refute beaver.confirmed_at

      conn =
        post(conn, ~p"/beavers/log-in", %{
          "beaver" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :beaver_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Beaver confirmed successfully."

      assert Accounts.get_beaver!(beaver.id).confirmed_at

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ beaver.email
      assert response =~ ~p"/beavers/settings"
      assert response =~ ~p"/beavers/log-out"
    end

    test "redirects to login page when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/beavers/log-in", %{
          "beaver" => %{"token" => "invalid"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/beavers/log-in"
    end
  end

  describe "DELETE /beavers/log-out" do
    test "logs the beaver out", %{conn: conn, beaver: beaver} do
      conn = conn |> log_in_beaver(beaver) |> delete(~p"/beavers/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :beaver_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the beaver is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/beavers/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :beaver_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
