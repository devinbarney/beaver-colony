defmodule BeaverColony.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias BeaverColony.Repo

  alias BeaverColony.Accounts.{Beaver, BeaverToken, BeaverNotifier}

  ## Database getters

  @doc """
  Gets a beaver by email.

  ## Examples

      iex> get_beaver_by_email("foo@example.com")
      %Beaver{}

      iex> get_beaver_by_email("unknown@example.com")
      nil

  """
  def get_beaver_by_email(email) when is_binary(email) do
    Repo.get_by(Beaver, email: email)
  end

  @doc """
  Gets a beaver by email and password.

  ## Examples

      iex> get_beaver_by_email_and_password("foo@example.com", "correct_password")
      %Beaver{}

      iex> get_beaver_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_beaver_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    beaver = Repo.get_by(Beaver, email: email)
    if Beaver.valid_password?(beaver, password), do: beaver
  end

  @doc """
  Gets a single beaver.

  Raises `Ecto.NoResultsError` if the Beaver does not exist.

  ## Examples

      iex> get_beaver!(123)
      %Beaver{}

      iex> get_beaver!(456)
      ** (Ecto.NoResultsError)

  """
  def get_beaver!(id), do: Repo.get!(Beaver, id)

  ## Beaver registration

  @doc """
  Registers a beaver.

  ## Examples

      iex> register_beaver(%{field: value})
      {:ok, %Beaver{}}

      iex> register_beaver(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_beaver(attrs) do
    %Beaver{}
    |> Beaver.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the beaver is in sudo mode.

  The beaver is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(beaver, minutes \\ -20)

  def sudo_mode?(%Beaver{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_beaver, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the beaver email.

  See `BeaverColony.Accounts.Beaver.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_beaver_email(beaver)
      %Ecto.Changeset{data: %Beaver{}}

  """
  def change_beaver_email(beaver, attrs \\ %{}, opts \\ []) do
    Beaver.email_changeset(beaver, attrs, opts)
  end

  @doc """
  Updates the beaver email using the given token.

  If the token matches, the beaver email is updated and the token is deleted.
  """
  def update_beaver_email(beaver, token) do
    context = "change:#{beaver.email}"

    Repo.transact(fn ->
      with {:ok, query} <- BeaverToken.verify_change_email_token_query(token, context),
           %BeaverToken{sent_to: email} <- Repo.one(query),
           {:ok, beaver} <- Repo.update(Beaver.email_changeset(beaver, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(BeaverToken, where: [beaver_id: ^beaver.id, context: ^context])) do
        {:ok, beaver}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the beaver password.

  See `BeaverColony.Accounts.Beaver.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_beaver_password(beaver)
      %Ecto.Changeset{data: %Beaver{}}

  """
  def change_beaver_password(beaver, attrs \\ %{}, opts \\ []) do
    Beaver.password_changeset(beaver, attrs, opts)
  end

  @doc """
  Updates the beaver password.

  Returns a tuple with the updated beaver, as well as a list of expired tokens.

  ## Examples

      iex> update_beaver_password(beaver, %{password: ...})
      {:ok, {%Beaver{}, [...]}}

      iex> update_beaver_password(beaver, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_beaver_password(beaver, attrs) do
    beaver
    |> Beaver.password_changeset(attrs)
    |> update_beaver_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_beaver_session_token(beaver) do
    {token, beaver_token} = BeaverToken.build_session_token(beaver)
    Repo.insert!(beaver_token)
    token
  end

  @doc """
  Gets the beaver with the given signed token.

  If the token is valid `{beaver, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_beaver_by_session_token(token) do
    {:ok, query} = BeaverToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the beaver with the given magic link token.
  """
  def get_beaver_by_magic_link_token(token) do
    with {:ok, query} <- BeaverToken.verify_magic_link_token_query(token),
         {beaver, _token} <- Repo.one(query) do
      beaver
    else
      _ -> nil
    end
  end

  @doc """
  Logs the beaver in by magic link.

  There are three cases to consider:

  1. The beaver has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The beaver has not confirmed their email and no password is set.
     In this case, the beaver gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The beaver has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_beaver_by_magic_link(token) do
    {:ok, query} = BeaverToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%Beaver{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%Beaver{confirmed_at: nil} = beaver, _token} ->
        beaver
        |> Beaver.confirm_changeset()
        |> update_beaver_and_delete_all_tokens()

      {beaver, token} ->
        Repo.delete!(token)
        {:ok, {beaver, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given beaver.

  ## Examples

      iex> deliver_beaver_update_email_instructions(beaver, current_email, &url(~p"/beavers/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_beaver_update_email_instructions(
        %Beaver{} = beaver,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    {encoded_token, beaver_token} =
      BeaverToken.build_email_token(beaver, "change:#{current_email}")

    Repo.insert!(beaver_token)
    BeaverNotifier.deliver_update_email_instructions(beaver, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given beaver.
  """
  def deliver_login_instructions(%Beaver{} = beaver, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, beaver_token} = BeaverToken.build_email_token(beaver, "login")
    Repo.insert!(beaver_token)
    BeaverNotifier.deliver_login_instructions(beaver, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_beaver_session_token(token) do
    Repo.delete_all(from(BeaverToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_beaver_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, beaver} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(BeaverToken, beaver_id: beaver.id)

        Repo.delete_all(
          from(t in BeaverToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id))
        )

        {:ok, {beaver, tokens_to_expire}}
      end
    end)
  end
end
