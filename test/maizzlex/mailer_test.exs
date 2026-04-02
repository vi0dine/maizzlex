defmodule Maizzlex.MailerTest do
  use ExUnit.Case, async: true

  import Swoosh.Email

  defmodule TestAttachmentAdapter do
    @behaviour Maizzlex.AttachmentAdapter

    def add_attachments(email, attachments, _opts) do
      updated =
        Enum.reduce(attachments, email, fn %{filename: filename, body: body}, acc ->
          attachment(acc, Swoosh.Attachment.new({:data, body}, filename: filename))
        end)

      {:ok, updated}
    end
  end

  defmodule FailingAttachmentAdapter do
    @behaviour Maizzlex.AttachmentAdapter

    def add_attachments(_email, _attachments, _opts), do: {:error, :boom}
  end

  defmodule TestEmailStore do
    @behaviour Maizzlex.EmailStore

    def store(email, metadata, _opts) do
      send(self(), {:stored_email, email.subject, metadata})
      :ok
    end
  end

  defmodule FailingEmailStore do
    @behaviour Maizzlex.EmailStore

    def store(_email, _metadata, _opts), do: {:error, :storage_unavailable}
  end

  defmodule TestMailer do
    use Maizzlex.Mailer,
      otp_app: :maizzlex,
      template_root: "../test/support/fixture_host/priv/emails"
  end

  setup do
    original = Application.get_env(:maizzlex, TestMailer)

    Application.put_env(:maizzlex, TestMailer,
      adapter: Swoosh.Adapters.Test,
      from: {"Maizzlex", "noreply@example.com"},
      attachment_adapter: {TestAttachmentAdapter, []},
      email_store: {TestEmailStore, []}
    )

    on_exit(fn ->
      if original do
        Application.put_env(:maizzlex, TestMailer, original)
      else
        Application.delete_env(:maizzlex, TestMailer)
      end
    end)

    :ok
  end

  test "base_email adds default anti spam headers" do
    email = TestMailer.base_email()

    assert email.from == {"Maizzlex", "noreply@example.com"}
    assert {"X-Mailer", "Maizzlex Mailer"} in email.headers
    assert {"Importance", "Normal"} in email.headers
  end

  test "transactional_email adds transactional headers and unsubscribe headers" do
    Application.put_env(:maizzlex, TestMailer,
      adapter: Swoosh.Adapters.Test,
      from: {"Maizzlex", "noreply@example.com"},
      list_unsubscribe_email: "unsubscribe@example.com",
      list_unsubscribe_url: "https://example.com/unsubscribe"
    )

    email = TestMailer.transactional_email()

    assert {"X-Transactional", "true"} in email.headers

    assert {"List-Unsubscribe",
            "<mailto:unsubscribe@example.com>, <https://example.com/unsubscribe>"} in email.headers

    assert {"List-Unsubscribe-Post", "List-Unsubscribe=One-Click"} in email.headers
  end

  test "render_template reads templates from the host priv directory" do
    assert TestMailer.render_template("welcome.html", %{name: "Ada"}) == "<p>Hello Ada</p>\n"
  end

  test "send_email delivers, adds text body, attachments, and stores as best effort" do
    email =
      TestMailer.transactional_email()
      |> to("user@example.com")
      |> subject("Hello")
      |> html_body("<h1>Hello</h1>")

    assert {:ok, delivered_email} =
             TestMailer.send_email(email, [%{filename: "hello.txt", body: "hello"}])

    assert delivered_email.text_body =~ "Hello"
    assert [%Swoosh.Attachment{filename: "hello.txt"}] = delivered_email.attachments
    assert_receive {:stored_email, "Hello", %{text_body: text_body, sent_at: %DateTime{}}}
    assert text_body =~ "Hello"
  end

  test "send_email returns attachment adapter errors" do
    Application.put_env(:maizzlex, TestMailer,
      adapter: Swoosh.Adapters.Test,
      from: {"Maizzlex", "noreply@example.com"},
      attachment_adapter: {FailingAttachmentAdapter, []}
    )

    email =
      TestMailer.transactional_email()
      |> to("user@example.com")
      |> subject("Hello")
      |> html_body("<h1>Hello</h1>")

    assert {:error, :boom} =
             TestMailer.send_email(email, [%{filename: "hello.txt", body: "hello"}])
  end

  test "send_email ignores failing email store after successful delivery" do
    Application.put_env(:maizzlex, TestMailer,
      adapter: Swoosh.Adapters.Test,
      from: {"Maizzlex", "noreply@example.com"},
      attachment_adapter: {TestAttachmentAdapter, []},
      email_store: {FailingEmailStore, []}
    )

    email =
      TestMailer.transactional_email()
      |> to("user@example.com")
      |> subject("Hello")
      |> html_body("<h1>Hello</h1>")

    assert {:ok, delivered_email} = TestMailer.send_email(email)
    assert delivered_email.text_body =~ "Hello"
  end
end
