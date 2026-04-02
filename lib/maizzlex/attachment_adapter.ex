defmodule Maizzlex.AttachmentAdapter do
  @moduledoc """
  Behaviour for host-defined attachment resolution.

  The adapter receives the current `Swoosh.Email`, a host-provided list of
  attachment descriptors, and adapter options from mailer config.
  """

  @callback add_attachments(Swoosh.Email.t(), [term()], keyword()) ::
              {:ok, Swoosh.Email.t()} | {:error, term()}
end
