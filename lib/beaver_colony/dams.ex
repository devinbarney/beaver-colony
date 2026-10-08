defmodule BeaverColony.Dams do
  @moduledoc """
  The Dams context.
  """

  import Ecto.Query, warn: false
  alias BeaverColony.Repo

  alias BeaverColony.Dams.Stick
  alias BeaverColony.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any stick changes.

  The broadcasted messages match the pattern:

    * {:created, %Stick{}}
    * {:updated, %Stick{}}
    * {:deleted, %Stick{}}

  """
  def subscribe_sticks(%Scope{} = scope) do
    key = scope.colony.id

    Phoenix.PubSub.subscribe(BeaverColony.PubSub, "colony:#{key}:sticks")
  end

  defp broadcast_stick(%Scope{} = scope, message) do
    key = scope.colony.id

    Phoenix.PubSub.broadcast(BeaverColony.PubSub, "colony:#{key}:sticks", message)
  end

  @doc """
  Returns the list of sticks.

  ## Examples

      iex> list_sticks(scope)
      [%Stick{}, ...]

  """
  def list_sticks(%Scope{} = scope) do
    Repo.all_by(Stick, colony_id: scope.colony.id)
  end

  @doc """
  Gets a single stick.

  Raises `Ecto.NoResultsError` if the Stick does not exist.

  ## Examples

      iex> get_stick!(scope, 123)
      %Stick{}

      iex> get_stick!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_stick!(%Scope{} = scope, id) do
    Repo.get_by!(Stick, id: id, colony_id: scope.colony.id)
  end

  @doc """
  Creates a stick.

  ## Examples

      iex> create_stick(scope, %{field: value})
      {:ok, %Stick{}}

      iex> create_stick(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_stick(%Scope{} = scope, attrs) do
    with {:ok, stick = %Stick{}} <-
           %Stick{}
           |> Stick.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_stick(scope, {:created, stick})
      {:ok, stick}
    end
  end

  @doc """
  Updates a stick.

  ## Examples

      iex> update_stick(scope, stick, %{field: new_value})
      {:ok, %Stick{}}

      iex> update_stick(scope, stick, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_stick(%Scope{} = scope, %Stick{} = stick, attrs) do
    true = stick.colony_id == scope.colony.id

    with {:ok, stick = %Stick{}} <-
           stick
           |> Stick.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_stick(scope, {:updated, stick})
      {:ok, stick}
    end
  end

  @doc """
  Deletes a stick.

  ## Examples

      iex> delete_stick(scope, stick)
      {:ok, %Stick{}}

      iex> delete_stick(scope, stick)
      {:error, %Ecto.Changeset{}}

  """
  def delete_stick(%Scope{} = scope, %Stick{} = stick) do
    true = stick.colony_id == scope.colony.id

    with {:ok, stick = %Stick{}} <-
           Repo.delete(stick) do
      broadcast_stick(scope, {:deleted, stick})
      {:ok, stick}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stick changes.

  ## Examples

      iex> change_stick(scope, stick)
      %Ecto.Changeset{data: %Stick{}}

  """
  def change_stick(%Scope{} = scope, %Stick{} = stick, attrs \\ %{}) do
    true = stick.colony_id == scope.colony.id

    Stick.changeset(stick, attrs, scope)
  end
end
