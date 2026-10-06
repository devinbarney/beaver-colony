defmodule BeaverColonyWeb.PageController do
  use BeaverColonyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
