defmodule TestCloud do
  use Buckets.Cloud, otp_app: :buckets
end

defmodule TestCloud.Volume do
  use Buckets.Cloud, otp_app: :buckets
end

defmodule TestCloud.GCS do
  use Buckets.Cloud, otp_app: :buckets
end

defmodule TestCloud.S3 do
  use Buckets.Cloud, otp_app: :buckets
end

defmodule TestCloud.DigitalOcean do
  use Buckets.Cloud, otp_app: :buckets
end

defmodule TestCloud.Tigris do
  use Buckets.Cloud, otp_app: :buckets
end

defmodule TestCloud.Cloudflare do
  use Buckets.Cloud, otp_app: :buckets
end
