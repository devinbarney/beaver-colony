defmodule BeaverColonyWeb.BeaverLive.LoginTest do
  use BeaverColonyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeaverColony.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/beavers/log-in")

      assert html =~ "Log in"
      assert html =~ "Sign up"
      assert html =~ "Log in with email"
    end
  end

  describe "beaver login - magic link" do
    test "sends magic link email when beaver exists", %{conn: conn} do
      beaver = beaver_fixture()

      {:ok, lv, _html} = live(conn, ~p"/beavers/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", beaver: %{email: beaver.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/beavers/log-in")

      assert html =~ "If your email is in our system"

      assert BeaverColony.Repo.get_by!(BeaverColony.Accounts.BeaverToken, beaver_id: beaver.id).context ==
               "login"
    end

    test "does not disclose if beaver is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/beavers/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", beaver: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/beavers/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "beaver login - password" do
    test "redirects if beaver logs in with valid credentials", %{conn: conn} do
      beaver = beaver_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/beavers/log-in")

      form =
        form(lv, "#login_form_password",
          beaver: %{email: beaver.email, password: valid_beaver_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/beavers/log-in")

      form =
        form(lv, "#login_form_password", beaver: %{email: "test@email.com", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/beavers/log-in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/beavers/log-in")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Sign up")
        |> render_click()
        |> follow_redirect(conn, ~p"/beavers/register")

      assert login_html =~ "Register"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      beaver = beaver_fixture()
      %{beaver: beaver, conn: log_in_beaver(conn, beaver)}
    end

    test "shows login page with email filled in", %{conn: conn, beaver: beaver} do
      {:ok, _lv, html} = live(conn, ~p"/beavers/log-in")

      assert html =~ "You need to reauthenticate"
      refute html =~ "Register"
      assert html =~ "Log in with email"

      assert html =~
               ~s(<input type="email" name="beaver[email]" id="login_form_magic_email" value="#{beaver.email}")
    end
  end
end
