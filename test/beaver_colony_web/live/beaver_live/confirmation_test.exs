defmodule BeaverColonyWeb.BeaverLive.ConfirmationTest do
  use BeaverColonyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeaverColony.AccountsFixtures

  alias BeaverColony.Accounts

  setup do
    %{unconfirmed_beaver: unconfirmed_beaver_fixture(), confirmed_beaver: beaver_fixture()}
  end

  describe "Confirm beaver" do
    test "renders confirmation page for unconfirmed beaver", %{
      conn: conn,
      unconfirmed_beaver: beaver
    } do
      token =
        extract_beaver_token(fn url ->
          Accounts.deliver_login_instructions(beaver, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/beavers/log-in/#{token}")
      assert html =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed beaver", %{conn: conn, confirmed_beaver: beaver} do
      token =
        extract_beaver_token(fn url ->
          Accounts.deliver_login_instructions(beaver, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/beavers/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Keep me logged in on this device"
    end

    test "renders login page for already logged in beaver", %{
      conn: conn,
      confirmed_beaver: beaver
    } do
      conn = log_in_beaver(conn, beaver)

      token =
        extract_beaver_token(fn url ->
          Accounts.deliver_login_instructions(beaver, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/beavers/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_beaver: beaver} do
      token =
        extract_beaver_token(fn url ->
          Accounts.deliver_login_instructions(beaver, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/beavers/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"beaver" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Beaver confirmed successfully"

      assert Accounts.get_beaver!(beaver.id).confirmed_at
      # we are logged in now
      assert get_session(conn, :beaver_token)
      assert redirected_to(conn) == ~p"/"

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/beavers/log-in/#{token}")
        |> follow_redirect(conn, ~p"/beavers/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "logs confirmed beaver in without changing confirmed_at", %{
      conn: conn,
      confirmed_beaver: beaver
    } do
      token =
        extract_beaver_token(fn url ->
          Accounts.deliver_login_instructions(beaver, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/beavers/log-in/#{token}")

      form = form(lv, "#login_form", %{"beaver" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      assert Accounts.get_beaver!(beaver.id).confirmed_at == beaver.confirmed_at

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/beavers/log-in/#{token}")
        |> follow_redirect(conn, ~p"/beavers/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "raises error for invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/beavers/log-in/invalid-token")
        |> follow_redirect(conn, ~p"/beavers/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end
  end
end
