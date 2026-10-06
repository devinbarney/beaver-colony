defmodule BeaverColony.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BeaverColony.Accounts` context.
  """

  import Ecto.Query

  alias BeaverColony.Accounts
  alias BeaverColony.Accounts.Scope

  def unique_beaver_email, do: "beaver#{System.unique_integer()}@example.com"
  def valid_beaver_password, do: "hello world!"

  def valid_beaver_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_beaver_email()
    })
  end

  def unconfirmed_beaver_fixture(attrs \\ %{}) do
    {:ok, beaver} =
      attrs
      |> valid_beaver_attributes()
      |> Accounts.register_beaver()

    beaver
  end

  def beaver_fixture(attrs \\ %{}) do
    beaver = unconfirmed_beaver_fixture(attrs)

    token =
      extract_beaver_token(fn url ->
        Accounts.deliver_login_instructions(beaver, url)
      end)

    {:ok, {beaver, _expired_tokens}} =
      Accounts.login_beaver_by_magic_link(token)

    beaver
  end

  def beaver_scope_fixture do
    beaver = beaver_fixture()
    beaver_scope_fixture(beaver)
  end

  def beaver_scope_fixture(beaver) do
    Scope.for_beaver(beaver)
  end

  def set_password(beaver) do
    {:ok, {beaver, _expired_tokens}} =
      Accounts.update_beaver_password(beaver, %{password: valid_beaver_password()})

    beaver
  end

  def extract_beaver_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    BeaverColony.Repo.update_all(
      from(t in Accounts.BeaverToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_beaver_magic_link_token(beaver) do
    {encoded_token, beaver_token} = Accounts.BeaverToken.build_email_token(beaver, "login")
    BeaverColony.Repo.insert!(beaver_token)
    {encoded_token, beaver_token.token}
  end

  def offset_beaver_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    BeaverColony.Repo.update_all(
      from(ut in Accounts.BeaverToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
