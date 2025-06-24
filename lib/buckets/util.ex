defmodule Buckets.Util do
  @moduledoc """
  Utility functions for the Buckets library.

  This module provides helper functions used internally by Buckets for
  file operations and string manipulation.
  """

  @doc """
  Gets the size of a file in bytes. Raises if the file does not exist or cannot be accessed

  ## Examples

      iex> Buckets.Util.size("/path/to/file.pdf")
      12345

      iex> Buckets.Util.size("non_existent.txt")
      ** (File.Error) could not read file stats "non_existent.txt": no such file or directory
  """
  @spec size(String.t()) :: integer()
  def size(path) when is_binary(path) do
    File.stat!(path).size
  end

  @doc """
  Normalizes a filename for safe storage in cloud systems.

  This function sanitizes filenames by:
  - Replacing whitespace with underscores
  - Removing all characters except letters, numbers, dots, underscores, and hyphens

  This normalization helps prevent issues with special characters in different
  storage systems and URLs.

  This function is used by Cloud modules when generating storage paths. It can be overridden
  in your Cloud module if you need different normalization rules:

      defmodule MyApp.Cloud do
        use Buckets.Cloud, otp_app: :my_app

        def normalize_filename(filename) do
          # Custom normalization logic
        end
      end

  ## Examples

      iex> Buckets.Util.normalize_filename("My Document.pdf")
      "My_Document.pdf"

      iex> Buckets.Util.normalize_filename("invoice #123 (final).xlsx")
      "invoice_123_final.xlsx"

      iex> Buckets.Util.normalize_filename("photo@event!.jpg")
      "photoevent.jpg"
  """
  @spec normalize_filename(String.t()) :: String.t()
  def normalize_filename(filename) do
    filename
    |> String.replace(~r/\s/, "_")
    |> String.replace(~r/[^\.a-zA-Z0-9_-]/, "")
  end
end
