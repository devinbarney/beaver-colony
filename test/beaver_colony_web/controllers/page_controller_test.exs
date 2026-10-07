defmodule BeaverColonyWeb.PageControllerTest do
  use BeaverColonyWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Beavers form colonies to build dams."
  end
end
