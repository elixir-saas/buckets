# Direct Uploads with LiveView

This guide shows how to implement direct-to-cloud uploads using Phoenix LiveView, allowing users to upload files directly to your storage provider without going through your server.

## Overview

Direct uploads improve performance and reduce server load by:
- Uploading files directly from the browser to cloud storage
- Reducing bandwidth usage on your servers
- Enabling progress tracking and cancellation
- Supporting large file uploads

## Basic Setup

### 1. Configure Your Cloud Module

Enable direct uploads by setting the `uploader` option:

```elixir
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.S3,
  bucket: "my-uploads",
  uploader: "S3",  # or "GCS" for Google Cloud Storage
  # ... other config
```

### 2. Basic LiveView Upload

```elixir
defmodule MyAppWeb.UploadLive do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 5_000_000,
       external: &presign_upload/2
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form id="upload-form" phx-submit="save" phx-change="validate">
      <.live_file_input upload={@uploads.avatar} />
      <button type="submit">Upload</button>
    </form>

    <div :for={file <- @uploaded_files}>
      Uploaded: <%= file.filename %>
    </div>
    """
  end

  defp presign_upload(entry, socket) do
    {:ok, config} = MyApp.Cloud.live_upload(entry)
    {:ok, config, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{key: key}, entry ->
        object = Buckets.Object.from_upload({entry, %{key: key}})
        {:ok, object}
      end)

    {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
  end
end
```

## Multiple File Uploads

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:uploaded_files, [])
   |> allow_upload(:documents,
     accept: ~w(.pdf .doc .docx),
     max_entries: 10,
     max_file_size: 10_000_000,
     external: &presign_upload/2,
     auto_upload: true
   )}
end
```

## Error Handling

```elixir
def render(assigns) do
  ~H"""
  <div :for={err <- upload_errors(@uploads.avatar)} class="error">
    <%= error_to_string(err) %>
  </div>
  """
end

defp error_to_string(:too_large), do: "File is too large"
defp error_to_string(:not_accepted), do: "File type not accepted"
defp error_to_string(:too_many_files), do: "Too many files"
defp error_to_string(:external_client_failure), do: "Upload failed"

defp presign_upload(entry, socket) do
  case MyApp.Cloud.live_upload(entry) do
    {:ok, config} ->
      {:ok, config, socket}
      
    {:error, reason} ->
      {:error, "Failed to generate upload URL: #{inspect(reason)}", socket}
  end
end
```

## CORS Configuration

For direct uploads to work, configure CORS on your bucket:

### S3 CORS

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration>
  <CORSRule>
    <AllowedOrigin>https://myapp.com</AllowedOrigin>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <ExposeHeader>ETag</ExposeHeader>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
```

### GCS CORS

```json
[
  {
    "origin": ["https://myapp.com"],
    "method": ["PUT", "POST"],
    "responseHeader": ["*"],
    "maxAgeSeconds": 3600
  }
]
```