defmodule TestCloud do
  use Buckets.Cloud,
    otp_app: :buckets,
    default_location: :local
end
