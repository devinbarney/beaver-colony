defmodule BeaverColonyWeb.BeaverLive.SettingsTest do
  use BeaverColonyWeb.ConnCase, async: true

  alias BeaverColony.Accounts
  import Phoenix.LiveViewTest
  import BeaverColony.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_beaver(beaver_fixture())
        |> live(~p"/beavers/settings")

      assert html =~ "Change Email"
      assert html =~ "Save Password"
    end

    test "redirects if beaver is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/beavers/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/beavers/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if beaver is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_beaver(beaver_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/beavers/settings")
        |> follow_redirect(conn, ~p"/beavers/log-in")

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      beaver = beaver_fixture()
      %{conn: log_in_beaver(conn, beaver), beaver: beaver}
    end

    test "updates the beaver email", %{conn: conn, beaver: beaver} do
      new_email = unique_beaver_email()

      {:ok, lv, _html} = live(conn, ~p"/beavers/settings")

      result =
        lv
        |> form("#email_form", %{
          "beaver" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_beaver_by_email(beaver.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/beavers/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "beaver" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, beaver: beaver} do
      {:ok, lv, _html} = live(conn, ~p"/beavers/settings")

      result =
        lv
        |> form("#email_form", %{
          "beaver" => %{"email" => beaver.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      beaver = beaver_fixture()
      %{conn: log_in_beaver(conn, beaver), beaver: beaver}
    end

    test "updates the beaver password", %{conn: conn, beaver: beaver} do
      new_password = valid_beaver_password()

      {:ok, lv, _html} = live(conn, ~p"/beavers/settings")

      form =
        form(lv, "#password_form", %{
          "beaver" => %{
            "email" => beaver.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/beavers/settings"

      assert get_session(new_password_conn, :beaver_token) != get_session(conn, :beaver_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_beaver_by_email_and_password(beaver.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/beavers/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "beaver" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/beavers/settings")

      result =
        lv
        |> form("#password_form", %{
          "beaver" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Save Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      beaver = beaver_fixture()
      email = unique_beaver_email()

      token =
        extract_beaver_token(fn url ->
          Accounts.deliver_beaver_update_email_instructions(
            %{beaver | email: email},
            beaver.email,
            url
          )
        end)

      %{conn: log_in_beaver(conn, beaver), token: token, email: email, beaver: beaver}
    end

    test "updates the beaver email once", %{
      conn: conn,
      beaver: beaver,
      token: token,
      email: email
    } do
      {:error, redirect} = live(conn, ~p"/beavers/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/beavers/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_beaver_by_email(beaver.email)
      assert Accounts.get_beaver_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/beavers/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/beavers/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, beaver: beaver} do
      {:error, redirect} = live(conn, ~p"/beavers/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/beavers/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_beaver_by_email(beaver.email)
    end

    test "redirects if beaver is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/beavers/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/beavers/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
