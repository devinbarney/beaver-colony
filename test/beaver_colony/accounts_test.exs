defmodule BeaverColony.AccountsTest do
  use BeaverColony.DataCase

  alias BeaverColony.Accounts

  import BeaverColony.AccountsFixtures
  alias BeaverColony.Accounts.{Beaver, BeaverToken}

  describe "get_beaver_by_email/1" do
    test "does not return the beaver if the email does not exist" do
      refute Accounts.get_beaver_by_email("unknown@example.com")
    end

    test "returns the beaver if the email exists" do
      %{id: id} = beaver = beaver_fixture()
      assert %Beaver{id: ^id} = Accounts.get_beaver_by_email(beaver.email)
    end
  end

  describe "get_beaver_by_email_and_password/2" do
    test "does not return the beaver if the email does not exist" do
      refute Accounts.get_beaver_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the beaver if the password is not valid" do
      beaver = beaver_fixture() |> set_password()
      refute Accounts.get_beaver_by_email_and_password(beaver.email, "invalid")
    end

    test "returns the beaver if the email and password are valid" do
      %{id: id} = beaver = beaver_fixture() |> set_password()

      assert %Beaver{id: ^id} =
               Accounts.get_beaver_by_email_and_password(beaver.email, valid_beaver_password())
    end
  end

  describe "get_beaver!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_beaver!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the beaver with the given id" do
      %{id: id} = beaver = beaver_fixture()
      assert %Beaver{id: ^id} = Accounts.get_beaver!(beaver.id)
    end
  end

  describe "register_beaver/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_beaver(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_beaver(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_beaver(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = beaver_fixture()
      {:error, changeset} = Accounts.register_beaver(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_beaver(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers beavers without password" do
      email = unique_beaver_email()
      {:ok, beaver} = Accounts.register_beaver(valid_beaver_attributes(email: email))
      assert beaver.email == email
      assert is_nil(beaver.hashed_password)
      assert is_nil(beaver.confirmed_at)
      assert is_nil(beaver.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%Beaver{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%Beaver{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%Beaver{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %Beaver{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%Beaver{})
    end
  end

  describe "change_beaver_email/3" do
    test "returns a beaver changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_beaver_email(%Beaver{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_beaver_update_email_instructions/3" do
    setup do
      %{beaver: beaver_fixture()}
    end

    test "sends token through notification", %{beaver: beaver} do
      token =
        extract_beaver_token(fn url ->
          Accounts.deliver_beaver_update_email_instructions(beaver, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert beaver_token = Repo.get_by(BeaverToken, token: :crypto.hash(:sha256, token))
      assert beaver_token.beaver_id == beaver.id
      assert beaver_token.sent_to == beaver.email
      assert beaver_token.context == "change:current@example.com"
    end
  end

  describe "update_beaver_email/2" do
    setup do
      beaver = unconfirmed_beaver_fixture()
      email = unique_beaver_email()

      token =
        extract_beaver_token(fn url ->
          Accounts.deliver_beaver_update_email_instructions(
            %{beaver | email: email},
            beaver.email,
            url
          )
        end)

      %{beaver: beaver, token: token, email: email}
    end

    test "updates the email with a valid token", %{beaver: beaver, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_beaver_email(beaver, token)
      changed_beaver = Repo.get!(Beaver, beaver.id)
      assert changed_beaver.email != beaver.email
      assert changed_beaver.email == email
      refute Repo.get_by(BeaverToken, beaver_id: beaver.id)
    end

    test "does not update email with invalid token", %{beaver: beaver} do
      assert Accounts.update_beaver_email(beaver, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(Beaver, beaver.id).email == beaver.email
      assert Repo.get_by(BeaverToken, beaver_id: beaver.id)
    end

    test "does not update email if beaver email changed", %{beaver: beaver, token: token} do
      assert Accounts.update_beaver_email(%{beaver | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(Beaver, beaver.id).email == beaver.email
      assert Repo.get_by(BeaverToken, beaver_id: beaver.id)
    end

    test "does not update email if token expired", %{beaver: beaver, token: token} do
      {1, nil} = Repo.update_all(BeaverToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_beaver_email(beaver, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(Beaver, beaver.id).email == beaver.email
      assert Repo.get_by(BeaverToken, beaver_id: beaver.id)
    end
  end

  describe "change_beaver_password/3" do
    test "returns a beaver changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_beaver_password(%Beaver{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_beaver_password(
          %Beaver{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_beaver_password/2" do
    setup do
      %{beaver: beaver_fixture()}
    end

    test "validates password", %{beaver: beaver} do
      {:error, changeset} =
        Accounts.update_beaver_password(beaver, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{beaver: beaver} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_beaver_password(beaver, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{beaver: beaver} do
      {:ok, {beaver, expired_tokens}} =
        Accounts.update_beaver_password(beaver, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(beaver.password)
      assert Accounts.get_beaver_by_email_and_password(beaver.email, "new valid password")
    end

    test "deletes all tokens for the given beaver", %{beaver: beaver} do
      _ = Accounts.generate_beaver_session_token(beaver)

      {:ok, {_, _}} =
        Accounts.update_beaver_password(beaver, %{
          password: "new valid password"
        })

      refute Repo.get_by(BeaverToken, beaver_id: beaver.id)
    end
  end

  describe "generate_beaver_session_token/1" do
    setup do
      %{beaver: beaver_fixture()}
    end

    test "generates a token", %{beaver: beaver} do
      token = Accounts.generate_beaver_session_token(beaver)
      assert beaver_token = Repo.get_by(BeaverToken, token: token)
      assert beaver_token.context == "session"
      assert beaver_token.authenticated_at != nil

      # Creating the same token for another beaver should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%BeaverToken{
          token: beaver_token.token,
          beaver_id: beaver_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given beaver in new token", %{beaver: beaver} do
      beaver = %{beaver | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_beaver_session_token(beaver)
      assert beaver_token = Repo.get_by(BeaverToken, token: token)
      assert beaver_token.authenticated_at == beaver.authenticated_at
      assert DateTime.compare(beaver_token.inserted_at, beaver.authenticated_at) == :gt
    end
  end

  describe "get_beaver_by_session_token/1" do
    setup do
      beaver = beaver_fixture()
      token = Accounts.generate_beaver_session_token(beaver)
      %{beaver: beaver, token: token}
    end

    test "returns beaver by token", %{beaver: beaver, token: token} do
      assert {session_beaver, token_inserted_at} = Accounts.get_beaver_by_session_token(token)
      assert session_beaver.id == beaver.id
      assert session_beaver.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return beaver for invalid token" do
      refute Accounts.get_beaver_by_session_token("oops")
    end

    test "does not return beaver for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(BeaverToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_beaver_by_session_token(token)
    end
  end

  describe "get_beaver_by_magic_link_token/1" do
    setup do
      beaver = beaver_fixture()
      {encoded_token, _hashed_token} = generate_beaver_magic_link_token(beaver)
      %{beaver: beaver, token: encoded_token}
    end

    test "returns beaver by token", %{beaver: beaver, token: token} do
      assert session_beaver = Accounts.get_beaver_by_magic_link_token(token)
      assert session_beaver.id == beaver.id
    end

    test "does not return beaver for invalid token" do
      refute Accounts.get_beaver_by_magic_link_token("oops")
    end

    test "does not return beaver for expired token", %{token: token} do
      {1, nil} = Repo.update_all(BeaverToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_beaver_by_magic_link_token(token)
    end
  end

  describe "login_beaver_by_magic_link/1" do
    test "confirms beaver and expires tokens" do
      beaver = unconfirmed_beaver_fixture()
      refute beaver.confirmed_at
      {encoded_token, hashed_token} = generate_beaver_magic_link_token(beaver)

      assert {:ok, {beaver, [%{token: ^hashed_token}]}} =
               Accounts.login_beaver_by_magic_link(encoded_token)

      assert beaver.confirmed_at
    end

    test "returns beaver and (deleted) token for confirmed beaver" do
      beaver = beaver_fixture()
      assert beaver.confirmed_at
      {encoded_token, _hashed_token} = generate_beaver_magic_link_token(beaver)
      assert {:ok, {^beaver, []}} = Accounts.login_beaver_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Accounts.login_beaver_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed beaver has password set" do
      beaver = unconfirmed_beaver_fixture()
      {1, nil} = Repo.update_all(Beaver, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_beaver_magic_link_token(beaver)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_beaver_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_beaver_session_token/1" do
    test "deletes the token" do
      beaver = beaver_fixture()
      token = Accounts.generate_beaver_session_token(beaver)
      assert Accounts.delete_beaver_session_token(token) == :ok
      refute Accounts.get_beaver_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{beaver: unconfirmed_beaver_fixture()}
    end

    test "sends token through notification", %{beaver: beaver} do
      token =
        extract_beaver_token(fn url ->
          Accounts.deliver_login_instructions(beaver, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert beaver_token = Repo.get_by(BeaverToken, token: :crypto.hash(:sha256, token))
      assert beaver_token.beaver_id == beaver.id
      assert beaver_token.sent_to == beaver.email
      assert beaver_token.context == "login"
    end
  end

  describe "inspect/2 for the Beaver module" do
    test "does not include password" do
      refute inspect(%Beaver{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
