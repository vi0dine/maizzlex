# Custom Attachment and Email Store Adapters

`Maizzlex` uses behaviors instead of shipping storage or file-fetching logic.

That keeps the library reusable across apps with very different persistence and asset pipelines.

## Attachment adapter

Behavior:

```elixir
@callback add_attachments(Swoosh.Email.t(), [term()], keyword()) ::
            {:ok, Swoosh.Email.t()} | {:error, term()}
```

Your adapter receives:

- the current `Swoosh.Email`
- the raw host-provided attachment descriptors
- adapter options from config

## Example attachment adapter

```elixir
defmodule MyApp.Mailers.AttachmentAdapter do
  @behaviour Maizzlex.AttachmentAdapter

  import Swoosh.Email

  @impl true
  def add_attachments(email, attachments, _opts) do
    updated_email =
      Enum.reduce(attachments, email, fn attachment_data, acc ->
        attachment(
          acc,
          Swoosh.Attachment.new(
            {:data, attachment_data.body},
            filename: attachment_data.filename,
            content_type: attachment_data.content_type
          )
        )
      end)

    {:ok, updated_email}
  rescue
    error ->
      {:error, error}
  end
end
```

## Example with remote file lookup

```elixir
defmodule MyApp.Mailers.AssetStoreAttachmentAdapter do
  @behaviour Maizzlex.AttachmentAdapter

  import Swoosh.Email

  @impl true
  def add_attachments(email, attachments, opts) do
    client = Keyword.fetch!(opts, :http_client)

    updated_email =
      Enum.reduce_while(attachments, email, fn attachment_info, acc ->
        with {:ok, body} <- client.get_body(attachment_info.url) do
          next_email =
            attachment(
              acc,
              Swoosh.Attachment.new(
                {:data, body},
                filename: attachment_info.filename,
                content_type: attachment_info.content_type
              )
            )

          {:cont, next_email}
        else
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case updated_email do
      {:error, reason} -> {:error, reason}
      %Swoosh.Email{} = final_email -> {:ok, final_email}
    end
  end
end
```

## Configuring the attachment adapter

```elixir
config :my_app, MyApp.Mailer,
  attachment_adapter: {MyApp.Mailers.AssetStoreAttachmentAdapter, http_client: MyApp.HTTP}
```

If `send_email/2` receives a non-empty attachment list and the adapter fails, the send fails too.

## Email store behavior

Behavior:

```elixir
@callback store(
            Swoosh.Email.t(),
            %{required(:text_body) => String.t(), required(:sent_at) => DateTime.t()},
            keyword()
          ) :: :ok | {:error, term()}
```

Your store receives:

- the delivered `Swoosh.Email`
- metadata produced by `Maizzlex`
- store options from config

## Example database email store

```elixir
defmodule MyApp.Mailers.DatabaseEmailStore do
  @behaviour Maizzlex.EmailStore

  alias MyApp.Mails.EmailLog
  alias MyApp.Repo

  @impl true
  def store(email, metadata, _opts) do
    attrs = %{
      to: extract_recipient(email.to),
      subject: email.subject,
      html_body: email.html_body,
      text_body: metadata.text_body,
      sent_at: metadata.sent_at
    }

    %EmailLog{}
    |> EmailLog.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, _record} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp extract_recipient([{_name, address} | _]), do: address
  defp extract_recipient([address | _]) when is_binary(address), do: address
  defp extract_recipient(_), do: nil
end
```

## Configuring the email store

```elixir
config :my_app, MyApp.Mailer,
  email_store: {MyApp.Mailers.DatabaseEmailStore, repo: MyApp.Repo}
```

The email store is best effort:

- delivery happens first
- `store/3` is called after delivery
- a store failure is logged and ignored

That makes `email_store` suitable for audit logs, analytics, or internal mail history without making delivery dependent on secondary persistence.
