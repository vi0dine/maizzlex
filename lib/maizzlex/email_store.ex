defmodule Maizzlex.EmailStore do
  @moduledoc """
  Behaviour for optionally persisting sent emails in a host application.
  """

  @callback store(
              Swoosh.Email.t(),
              %{required(:text_body) => String.t(), required(:sent_at) => DateTime.t()},
              keyword()
            ) ::
              :ok | {:error, term()}
end
