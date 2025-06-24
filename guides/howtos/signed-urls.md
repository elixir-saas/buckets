# Signed URLs

Signed URLs provide temporary, secure access to objects in cloud storage without requiring authentication. This guide explains how to generate and use signed URLs with Buckets.

## What are Signed URLs?

Signed URLs are time-limited URLs that grant temporary access to private objects. They include:
- The object location
- Expiration time
- Cryptographic signature
- Optional permissions (read/write)

## Basic Usage

### Generating Download URLs

```elixir
# Generate a signed URL for downloads (default: 1 hour)
{:ok, signed_url} = MyApp.Cloud.url(object)

# Access the URL string
download_url = signed_url.url

# Or use String protocol
download_url = to_string(signed_url)
```

### Custom Expiration

```elixir
# Expires in 5 minutes
{:ok, signed_url} = MyApp.Cloud.url(object, expires_in: 300)

# Expires in 24 hours
{:ok, signed_url} = MyApp.Cloud.url(object, expires_in: 86400)

# Expires in 7 days (maximum for S3)
{:ok, signed_url} = MyApp.Cloud.url(object, expires_in: 604800)
```

### Upload URLs

Generate URLs for direct uploads:

```elixir
# Create a placeholder object
object = Buckets.Object.new(
  Ecto.UUID.generate(),
  "document.pdf",
  location: {"uploads/documents/document.pdf", MyApp.Cloud}
)

# Generate upload URL
{:ok, upload_url} = MyApp.Cloud.url(object, 
  expires_in: 3600,
  for_upload: true
)
```

## Use Cases

### Secure File Downloads

```elixir
defmodule MyAppWeb.DocumentController do
  def download(conn, %{"id" => id}) do
    document = Documents.get!(id)
    
    # Load object from storage location
    object = Buckets.Object.new(
      document.id,
      document.filename,
      location: {document.storage_path, MyApp.Cloud}
    )
    
    # Generate temporary download URL
    {:ok, signed_url} = MyApp.Cloud.url(object, expires_in: 300)
    
    # Redirect to signed URL
    redirect(conn, external: signed_url.url)
  end
end
```

### Email Attachments

```elixir
defmodule MyApp.Mailer do
  def invoice_email(user, invoice) do
    # Generate URL valid for 7 days
    {:ok, download_url} = MyApp.Cloud.url(invoice.document, 
      expires_in: 604800
    )
    
    new()
    |> to(user.email)
    |> subject("Your Invoice")
    |> html_body("""
    <p>Your invoice is ready!</p>
    <p><a href="#{download_url}">Download Invoice</a></p>
    <p>This link expires in 7 days.</p>
    """)
    |> deliver()
  end
end
```

### API Responses

```elixir
defmodule MyAppWeb.API.FileController do
  def show(conn, %{"id" => id}) do
    file = Files.get!(id)
    
    # Generate short-lived URL
    {:ok, signed_url} = MyApp.Cloud.url(file.object, 
      expires_in: 600  # 10 minutes
    )
    
    json(conn, %{
      id: file.id,
      filename: file.filename,
      size: file.size,
      content_type: file.content_type,
      download_url: signed_url.url,
      expires_at: DateTime.add(DateTime.utc_now(), 600)
    })
  end
end
```