defmodule BeaverColonyWeb.BeaverAuthTest do
  use BeaverColonyWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias BeaverColony.Accounts
  alias BeaverColony.Accounts.Scope
  alias BeaverColonyWeb.BeaverAuth

  import BeaverColony.AccountsFixtures

  @remember_me_cookie "_beaver_colony_web_beaver_remember_me"
  @remember_me_cookie_max_age 60 * 60 * 24 * 14

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, BeaverColonyWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{beaver: %{beaver_fixture() | authenticated_at: DateTime.utc_now(:second)}, conn: conn}
  end

  describe "log_in_beaver/3" do
    test "stores the beaver token in the session", %{conn: conn, beaver: beaver} do
      conn = BeaverAuth.log_in_beaver(conn, beaver)
      assert token = get_session(conn, :beaver_token)
      assert get_session(conn, :live_socket_id) == "beavers_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_beaver_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, beaver: beaver} do
      conn = conn |> put_session(:to_be_removed, "value") |> BeaverAuth.log_in_beaver(beaver)
      refute get_session(conn, :to_be_removed)
    end

    test "keeps session when re-authenticating", %{conn: conn, beaver: beaver} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_beaver(beaver))
        |> put_session(:to_be_removed, "value")
        |> BeaverAuth.log_in_beaver(beaver)

      assert get_session(conn, :to_be_removed)
    end

    test "clears session when beaver does not match when re-authenticating", %{
      conn: conn,
      beaver: beaver
    } do
      other_beaver = beaver_fixture()

      conn =
        conn
        |> assign(:current_scope, Scope.for_beaver(other_beaver))
        |> put_session(:to_be_removed, "value")
        |> BeaverAuth.log_in_beaver(beaver)

      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, beaver: beaver} do
      conn = conn |> put_session(:beaver_return_to, "/hello") |> BeaverAuth.log_in_beaver(beaver)
      assert redirected_to(conn) == "/hello"
    end

    test "clears the return-to path from the session after logging in", %{conn: conn, beaver: beaver} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_beaver(beaver))
        |> put_session(:beaver_return_to, "/hello")
        |> BeaverAuth.log_in_beaver(beaver)

      assert redirected_to(conn) == "/hello"
      refute get_session(conn, :beaver_return_to)
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, beaver: beaver} do
      conn = conn |> fetch_cookies() |> BeaverAuth.log_in_beaver(beaver, %{"remember_me" => "true"})
      assert get_session(conn, :beaver_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :beaver_remember_me) == true

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :beaver_token)
      assert max_age == @remember_me_cookie_max_age
    end

    test "redirects to settings when beaver is already logged in", %{conn: conn, beaver: beaver} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_beaver(beaver))
        |> BeaverAuth.log_in_beaver(beaver)

      assert redirected_to(conn) == ~p"/beavers/settings"
    end

    test "writes a cookie if remember_me was set in previous session", %{conn: conn, beaver: beaver} do
      conn = conn |> fetch_cookies() |> BeaverAuth.log_in_beaver(beaver, %{"remember_me" => "true"})
      assert get_session(conn, :beaver_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :beaver_remember_me) == true

      conn =
        conn
        |> recycle()
        |> Map.replace!(:secret_key_base, BeaverColonyWeb.Endpoint.config(:secret_key_base))
        |> fetch_cookies()
        |> init_test_session(%{beaver_remember_me: true})

      # the conn is already logged in and has the remember_me cookie set,
      # now we log in again and even without explicitly setting remember_me,
      # the cookie should be set again
      conn = conn |> BeaverAuth.log_in_beaver(beaver, %{})
      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :beaver_token)
      assert max_age == @remember_me_cookie_max_age
      assert get_session(conn, :beaver_remember_me) == true
    end
  end

  describe "logout_beaver/1" do
    test "erases session and cookies", %{conn: conn, beaver: beaver} do
      beaver_token = Accounts.generate_beaver_session_token(beaver)

      conn =
        conn
        |> put_session(:beaver_token, beaver_token)
        |> put_req_cookie(@remember_me_cookie, beaver_token)
        |> fetch_cookies()
        |> BeaverAuth.log_out_beaver()

      refute get_session(conn, :beaver_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_beaver_by_session_token(beaver_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "beavers_sessions:abcdef-token"
      BeaverColonyWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> BeaverAuth.log_out_beaver()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if beaver is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> BeaverAuth.log_out_beaver()
      refute get_session(conn, :beaver_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_scope_for_beaver/2" do
    test "authenticates beaver from session", %{conn: conn, beaver: beaver} do
      beaver_token = Accounts.generate_beaver_session_token(beaver)

      conn =
        conn |> put_session(:beaver_token, beaver_token) |> BeaverAuth.fetch_current_scope_for_beaver([])

      assert conn.assigns.current_scope.beaver.id == beaver.id
      assert conn.assigns.current_scope.beaver.authenticated_at == beaver.authenticated_at
      assert get_session(conn, :beaver_token) == beaver_token
    end

    test "authenticates beaver from cookies", %{conn: conn, beaver: beaver} do
      logged_in_conn =
        conn |> fetch_cookies() |> BeaverAuth.log_in_beaver(beaver, %{"remember_me" => "true"})

      beaver_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> BeaverAuth.fetch_current_scope_for_beaver([])

      assert conn.assigns.current_scope.beaver.id == beaver.id
      assert conn.assigns.current_scope.beaver.authenticated_at == beaver.authenticated_at
      assert get_session(conn, :beaver_token) == beaver_token
      assert get_session(conn, :beaver_remember_me)

      assert get_session(conn, :live_socket_id) ==
               "beavers_sessions:#{Base.url_encode64(beaver_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, beaver: beaver} do
      _ = Accounts.generate_beaver_session_token(beaver)
      conn = BeaverAuth.fetch_current_scope_for_beaver(conn, [])
      refute get_session(conn, :beaver_token)
      refute conn.assigns.current_scope
    end

    test "reissues a new token after a few days and refreshes cookie", %{conn: conn, beaver: beaver} do
      logged_in_conn =
        conn |> fetch_cookies() |> BeaverAuth.log_in_beaver(beaver, %{"remember_me" => "true"})

      token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      offset_beaver_token(token, -10, :day)
      {beaver, _} = Accounts.get_beaver_by_session_token(token)

      conn =
        conn
        |> put_session(:beaver_token, token)
        |> put_session(:beaver_remember_me, true)
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> BeaverAuth.fetch_current_scope_for_beaver([])

      assert conn.assigns.current_scope.beaver.id == beaver.id
      assert conn.assigns.current_scope.beaver.authenticated_at == beaver.authenticated_at
      assert new_token = get_session(conn, :beaver_token)
      assert new_token != token
      assert %{value: new_signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert new_signed_token != signed_token
      assert max_age == @remember_me_cookie_max_age
    end
  end

  describe "on_mount :mount_current_scope" do
    setup %{conn: conn} do
      %{conn: BeaverAuth.fetch_current_scope_for_beaver(conn, [])}
    end

    test "assigns current_scope based on a valid beaver_token", %{conn: conn, beaver: beaver} do
      beaver_token = Accounts.generate_beaver_session_token(beaver)
      session = conn |> put_session(:beaver_token, beaver_token) |> get_session()

      {:cont, updated_socket} =
        BeaverAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.beaver.id == beaver.id
    end

    test "assigns nil to current_scope assign if there isn't a valid beaver_token", %{conn: conn} do
      beaver_token = "invalid_token"
      session = conn |> put_session(:beaver_token, beaver_token) |> get_session()

      {:cont, updated_socket} =
        BeaverAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end

    test "assigns nil to current_scope assign if there isn't a beaver_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        BeaverAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_authenticated" do
    test "authenticates current_scope based on a valid beaver_token", %{conn: conn, beaver: beaver} do
      beaver_token = Accounts.generate_beaver_session_token(beaver)
      session = conn |> put_session(:beaver_token, beaver_token) |> get_session()

      {:cont, updated_socket} =
        BeaverAuth.on_mount(:require_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.beaver.id == beaver.id
    end

    test "redirects to login page if there isn't a valid beaver_token", %{conn: conn} do
      beaver_token = "invalid_token"
      session = conn |> put_session(:beaver_token, beaver_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: BeaverColonyWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = BeaverAuth.on_mount(:require_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_scope == nil
    end

    test "redirects to login page if there isn't a beaver_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: BeaverColonyWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = BeaverAuth.on_mount(:require_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_sudo_mode" do
    test "allows beavers that have authenticated in the last 10 minutes", %{conn: conn, beaver: beaver} do
      beaver_token = Accounts.generate_beaver_session_token(beaver)
      session = conn |> put_session(:beaver_token, beaver_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: BeaverColonyWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:cont, _updated_socket} =
               BeaverAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end

    test "redirects when authentication is too old", %{conn: conn, beaver: beaver} do
      eleven_minutes_ago = DateTime.utc_now(:second) |> DateTime.add(-11, :minute)
      beaver = %{beaver | authenticated_at: eleven_minutes_ago}
      beaver_token = Accounts.generate_beaver_session_token(beaver)
      {beaver, token_inserted_at} = Accounts.get_beaver_by_session_token(beaver_token)
      assert DateTime.compare(token_inserted_at, beaver.authenticated_at) == :gt
      session = conn |> put_session(:beaver_token, beaver_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: BeaverColonyWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:halt, _updated_socket} =
               BeaverAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end
  end

  describe "require_authenticated_beaver/2" do
    setup %{conn: conn} do
      %{conn: BeaverAuth.fetch_current_scope_for_beaver(conn, [])}
    end

    test "redirects if beaver is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> BeaverAuth.require_authenticated_beaver([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/beavers/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> BeaverAuth.require_authenticated_beaver([])

      assert halted_conn.halted
      assert get_session(halted_conn, :beaver_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> BeaverAuth.require_authenticated_beaver([])

      assert halted_conn.halted
      assert get_session(halted_conn, :beaver_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> BeaverAuth.require_authenticated_beaver([])

      assert halted_conn.halted
      refute get_session(halted_conn, :beaver_return_to)
    end

    test "does not redirect if beaver is authenticated", %{conn: conn, beaver: beaver} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_beaver(beaver))
        |> BeaverAuth.require_authenticated_beaver([])

      refute conn.halted
      refute conn.status
    end
  end

  describe "disconnect_sessions/1" do
    test "broadcasts disconnect messages for each token" do
      tokens = [%{token: "token1"}, %{token: "token2"}]

      for %{token: token} <- tokens do
        BeaverColonyWeb.Endpoint.subscribe("beavers_sessions:#{Base.url_encode64(token)}")
      end

      BeaverAuth.disconnect_sessions(tokens)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "beavers_sessions:dG9rZW4x"
      }

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "beavers_sessions:dG9rZW4y"
      }
    end
  end
end
