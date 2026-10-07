defmodule BeaverColonyWeb.GuideLiveTest do
  use BeaverColonyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BeaverColony.Guide

  describe "the articles" do
    test "are four parts, in order, with unique ids" do
      articles = Guide.list_articles()

      assert Enum.map(articles, & &1.part) == [1, 2, 3, 4]
      assert articles |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 4
    end

    test "know their neighbors" do
      [first, second | _] = Guide.list_articles()

      assert Guide.neighbors(first) == {nil, second}
      assert {^first, _} = Guide.neighbors(second)
    end
  end

  describe "reading the guide signed out" do
    test "the contents lists every part", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/guide")

      for article <- Guide.list_articles() do
        assert has_element?(lv, "#guide-contents a", article.title)
      end
    end

    test "an article is in the sidebar, marked as the current page", %{conn: conn} do
      [first, second | _] = Guide.list_articles()
      {:ok, lv, _html} = live(conn, ~p"/guide/#{first.id}")

      assert has_element?(lv, "#guide-#{first.id} h1", first.title)
      assert has_element?(lv, "#nav-guide-#{first.id} a[aria-current=page]")
      assert has_element?(lv, "#nav-guide-#{second.id} a")
      assert has_element?(lv, ".guide-article__pager a", second.title)
    end

    test "the sidebar offers sign in and the demo beavers", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/guide")

      assert has_element?(lv, "#nav-switcher", "The guide")
      assert has_element?(lv, "#nav-log-in a")
      assert has_element?(lv, ~s|#nav-switcher a[href="/demo/builder"][data-method=post]|)
      refute has_element?(lv, "#nav-switcher a", "🦫 Me")
    end

    test "an unknown article is a 404", %{conn: conn} do
      assert_raise Guide.NotFoundError, fn -> live(conn, ~p"/guide/nope") end
    end
  end

  describe "reading the guide signed in" do
    setup :register_and_log_in_beaver_with_colony

    test "the switcher also leads back to your colonies", %{conn: conn, colony: colony} do
      {:ok, lv, _html} = live(conn, ~p"/guide")

      assert has_element?(lv, "#nav-switcher a", colony.name)
      assert has_element?(lv, "#nav-account-menu")
    end

    test "the app's switcher leads to the guide", %{conn: conn, colony: colony} do
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}")

      assert has_element?(lv, ~s|#nav-switcher a[href="/guide"]|)
    end
  end
end
