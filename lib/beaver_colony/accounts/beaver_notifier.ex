defmodule BeaverColony.Accounts.BeaverNotifier do
  import Swoosh.Email

  alias BeaverColony.Mailer
  alias BeaverColony.Accounts.Beaver

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"BeaverColony", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a beaver email.
  """
  def deliver_update_email_instructions(beaver, url) do
    deliver(beaver.email, "Update email instructions", """

    ==============================

    Hi #{beaver.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(beaver, url) do
    case beaver do
      %Beaver{confirmed_at: nil} -> deliver_confirmation_instructions(beaver, url)
      _ -> deliver_magic_link_instructions(beaver, url)
    end
  end

  defp deliver_magic_link_instructions(beaver, url) do
    deliver(beaver.email, "Log in instructions", """

    ==============================

    Hi #{beaver.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(beaver, url) do
    deliver(beaver.email, "Confirmation instructions", """

    ==============================

    Hi #{beaver.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
