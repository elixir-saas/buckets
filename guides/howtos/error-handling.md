# Error Handling

This guide covers error handling strategies for robust file storage operations with Buckets.

## Error Types

### Common Errors

Buckets operations can return various error types:

```elixir
# Configuration errors
{:error, [:bucket, :access_key_id]}  # Missing required fields

# Network errors
{:error, %Mint.TransportError{}}     # Connection failed
{:error, {:http_error, 500}}         # Server error

# Permission errors
{:error, :unauthorized}              # Invalid credentials
{:error, :forbidden}                 # Insufficient permissions

# Resource errors
{:error, :not_found}                 # Object doesn't exist
{:error, :already_exists}            # Duplicate object

# Validation errors
{:error, :file_too_large}            # Size limit exceeded
{:error, :invalid_content_type}      # Type not allowed
```

## Basic Error Handling

### Pattern Matching

```elixir
case MyApp.Cloud.insert(object) do
  {:ok, stored} ->
    # Success path
    {:ok, stored}
    
  {:error, :unauthorized} ->
    # Handle auth error
    Logger.error("Invalid cloud storage credentials")
    {:error, "Authentication failed"}
    
  {:error, %{status: 507}} ->
    # Storage full
    Logger.error("Cloud storage quota exceeded")
    {:error, "Storage limit reached"}
    
  {:error, reason} ->
    # Generic error
    Logger.error("Upload failed: #{inspect(reason)}")
    {:error, "Upload failed"}
end
```

### Using Bang Functions

```elixir
def upload_or_raise(file_path) do
  try do
    object = Buckets.Object.from_file(file_path)
    stored = MyApp.Cloud.insert!(object)
    {:ok, stored}
  rescue
    e in RuntimeError ->
      Logger.error("Upload failed: #{e.message}")
      reraise e, __STACKTRACE__
  end
end
```

## Retry Strategies

### Simple Retry

```elixir
defmodule MyApp.Storage.Retry do
  def with_retry(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    delay = Keyword.get(opts, :delay, 1000)
    
    do_retry(fun, max_attempts, delay, 1)
  end
  
  defp do_retry(fun, max_attempts, delay, attempt) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}
        
      {:error, reason} when attempt < max_attempts ->
        if retryable_error?(reason) do
          Process.sleep(delay * attempt)  # Exponential backoff
          do_retry(fun, max_attempts, delay, attempt + 1)
        else
          {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp retryable_error?(:timeout), do: true
  defp retryable_error?({:http_error, status}) when status >= 500, do: true
  defp retryable_error?(%Mint.TransportError{}), do: true
  defp retryable_error?(_), do: false
end

# Usage
MyApp.Storage.Retry.with_retry(fn ->
  MyApp.Cloud.insert(object)
end, max_attempts: 5, delay: 2000)
```

## User-Friendly Errors

### Error Translation

```elixir
defmodule MyApp.Storage.ErrorMessages do
  def translate({:error, :unauthorized}) do
    "Storage authentication failed. Please check your credentials."
  end
  
  def translate({:error, :not_found}) do
    "The requested file could not be found."
  end
  
  def translate({:error, {:http_error, 507}}) do
    "Storage quota exceeded. Please upgrade your plan."
  end
  
  def translate({:error, :timeout}) do
    "The operation timed out. Please try again."
  end
  
  def translate({:error, :file_too_large}) do
    "The file is too large. Maximum size is 10MB."
  end
  
  def translate(_error) do
    "An unexpected error occurred. Please try again later."
  end
end

# In controller
case MyApp.Cloud.insert(object) do
  {:ok, _} ->
    put_flash(conn, :info, "Upload successful")
    
  {:error, _} = error ->
    message = MyApp.Storage.ErrorMessages.translate(error)
    put_flash(conn, :error, message)
end
```