# Testing

This guide covers testing strategies for applications using Buckets, including unit tests, integration tests, and testing with live cloud services.

## Test Setup

### Basic Test Configuration

```elixir
# config/test.exs
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.Volume,
  bucket: "tmp/test_storage",
  base_url: "http://localhost:4001"

# Ensure test isolation
config :my_app, :storage_base_path, "tmp/test_#{System.get_pid()}"
```

### Test Helper Module

```elixir
defmodule MyApp.StorageCase do
  use ExUnit.CaseTemplate
  
  using do
    quote do
      import MyApp.StorageCase
      
      setup :create_test_storage
    end
  end
  
  def create_test_storage(_context) do
    # Create unique test directory
    test_dir = "tmp/test_#{:rand.uniform(1_000_000)}"
    File.mkdir_p!(test_dir)
    
    # Configure for this test
    config = [
      adapter: Buckets.Adapters.Volume,
      bucket: test_dir,
      base_url: "http://localhost:4001"
    ]
    
    MyApp.Cloud.put_dynamic_config(config)
    
    on_exit(fn ->
      # Cleanup
      File.rm_rf!(test_dir)
    end)
    
    {:ok, storage_dir: test_dir}
  end
  
  def create_test_object(attrs \\ %{}) do
    defaults = %{
      uuid: Ecto.UUID.generate(),
      filename: "test.pdf",
      content: "test content",
      content_type: "application/pdf"
    }
    
    attrs = Map.merge(defaults, attrs)
    
    Buckets.Object.new(
      attrs.uuid,
      attrs.filename,
      metadata: %{
        content_type: attrs.content_type,
        content_size: byte_size(attrs.content)
      }
    )
  end
end
```

## Unit Tests

### Testing Storage Operations

```elixir
defmodule MyApp.CloudTest do
  use MyApp.StorageCase
  
  describe "insert/1" do
    test "stores object successfully", %{storage_dir: dir} do
      object = create_test_object()
      
      assert {:ok, stored} = MyApp.Cloud.insert(object)
      assert stored.stored?
      assert stored.location.path =~ object.uuid
      
      # Verify file exists
      file_path = Path.join([dir, stored.location.path])
      assert File.exists?(file_path)
    end
    
    test "handles missing file" do
      object = Buckets.Object.from_file("non_existent.pdf")
      
      assert_raise RuntimeError, ~r/non-existent file/, fn ->
        MyApp.Cloud.insert!(object)
      end
    end
  end
  
  describe "read/1" do
    test "reads stored object data" do
      object = create_test_object(content: "Hello, World!")
      {:ok, stored} = MyApp.Cloud.insert(object)
      
      assert {:ok, data} = MyApp.Cloud.read(stored)
      assert data == "Hello, World!"
    end
    
    test "returns error for missing object" do
      fake_object = create_test_object()
      |> Map.put(:location, Buckets.Location.new("fake/path", MyApp.Cloud))
      |> Map.put(:stored?, true)
      
      assert {:error, :not_found} = MyApp.Cloud.read(fake_object)
    end
  end
end
```

## LiveView Testing

### Testing Direct Uploads

```elixir
defmodule MyAppWeb.UploadLiveTest do
  use MyAppWeb.ConnCase
  use MyApp.StorageCase
  import Phoenix.LiveViewTest
  
  describe "file uploads" do
    test "direct upload to cloud storage", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/uploads/new")
      
      # Simulate file selection
      file =
        file_input(view, "form", :document, [
          %{
            name: "invoice.pdf",
            content: File.read!("test/fixtures/sample.pdf"),
            type: "application/pdf"
          }
        ])
      
      # Trigger upload
      assert render_upload(file, "invoice.pdf")
      
      # Submit form
      html = form(view, "form") |> render_submit()
      
      assert html =~ "Upload successful"
      assert MyApp.Files.count() == 1
    end
  end
end
```

## Mocking and Stubbing

### Using Mox for Cloud Operations

```elixir
# test/support/mocks.ex
Mox.defmock(MyApp.CloudMock, for: Buckets.Cloud)

# In tests
defmodule MyApp.ServiceTest do
  use ExUnit.Case
  import Mox
  
  setup :verify_on_exit!
  
  test "processes file after upload" do
    object = create_test_object()
    
    expect(MyApp.CloudMock, :insert, fn ^object ->
      {:ok, %{object | stored?: true}}
    end)
    
    expect(MyApp.CloudMock, :read, fn _object ->
      {:ok, "processed content"}
    end)
    
    assert {:ok, result} = MyApp.FileProcessor.process(object)
    assert result.content == "processed content"
  end
end
```

## Running Tests

```bash
# Run all tests
mix test

# Run only unit tests (exclude external)
mix test --exclude external

# Run specific adapter tests
mix test --only s3

# Run with coverage
mix test --cover
```