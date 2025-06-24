# File Uploads

This guide covers various ways to handle file uploads with Buckets.

## Controller Uploads

The most common scenario is handling file uploads in Phoenix controllers.

### Basic Upload

```elixir
defmodule MyAppWeb.DocumentController do
  use MyAppWeb, :controller
  
  def create(conn, %{"document" => %{"file" => upload}}) do
    # Create object from Plug.Upload
    object = Buckets.Object.from_upload(upload)
    
    # Upload to cloud storage
    case MyApp.Cloud.insert(object) do
      {:ok, stored_object} ->
        # Save metadata to database
        {:ok, document} = Documents.create_document(%{
          filename: stored_object.filename,
          path: stored_object.location.path,
          content_type: stored_object.metadata.content_type,
          size: stored_object.metadata.content_size
        })
        
        conn
        |> put_flash(:info, "Document uploaded successfully")
        |> redirect(to: ~p"/documents/#{document}")
        
      {:error, reason} ->
        conn
        |> put_flash(:error, "Upload failed: #{inspect(reason)}")
        |> redirect(to: ~p"/documents/new")
    end
  end
end
```

### Multiple File Upload

```elixir
def create(conn, %{"files" => uploads}) when is_list(uploads) do
  results = Enum.map(uploads, fn upload ->
    object = Buckets.Object.from_upload(upload)
    MyApp.Cloud.insert(object)
  end)
  
  successful = Enum.filter(results, &match?({:ok, _}, &1))
  failed = Enum.filter(results, &match?({:error, _}, &1))
  
  conn
  |> put_flash(:info, "Uploaded #{length(successful)} files")
  |> maybe_put_error_flash(failed)
  |> redirect(to: ~p"/documents")
end
```

## Direct File Upload

Upload files directly from disk:

```elixir
# From a file path
{:ok, object} = MyApp.Cloud.insert("/path/to/file.pdf")

# With custom metadata
object = Buckets.Object.new(
  Ecto.UUID.generate(),
  "report.pdf",
  metadata: %{
    author: "John Doe",
    category: "financial"
  }
)

{:ok, stored} = MyApp.Cloud.insert(object)
```

## Post-Upload Processing

Process files after upload:

```elixir
def create(conn, %{"image" => upload}) do
  with object <- Buckets.Object.from_upload(upload),
       {:ok, stored} <- MyApp.Cloud.insert(object),
       {:ok, _} <- generate_thumbnails(stored) do
    # Success
  else
    {:error, reason} -> 
      # Handle error
  end
end

defp generate_thumbnails(object) do
  # Load the image data
  {:ok, loaded} = MyApp.Cloud.load(object)
  {:ok, data} = Buckets.Object.read(loaded)
  
  # Generate thumbnails
  sizes = [
    {:thumb, 150},
    {:medium, 500},
    {:large, 1200}
  ]
  
  Enum.each(sizes, fn {name, width} ->
    resized = resize_image(data, width)
    
    thumb_object = Buckets.Object.new(
      object.uuid,
      "#{name}_#{object.filename}",
      metadata: %{content_type: "image/jpeg"}
    )
    
    MyApp.Cloud.insert(thumb_object)
  end)
end
```

## Next Steps

- Learn about [Direct Uploads with LiveView](direct-uploads-liveview.html)
- Explore [Signed URLs](signed-urls.html) for secure access
- Set up [Error Handling](error-handling.html) strategies