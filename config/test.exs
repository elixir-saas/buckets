import Config

config :logger, :level, :warning

# Default TestCloud - uses Volume
config :buckets, TestCloud,
  adapter: Buckets.Adapters.Volume,
  bucket: System.tmp_dir!(),
  base_url: "http://localhost:4000",
  path: "test/objects"

# Volume/Local Storage
config :buckets, TestCloud.Volume,
  adapter: Buckets.Adapters.Volume,
  bucket: System.tmp_dir!(),
  base_url: "http://localhost:4000",
  path: "test/objects"

# Google Cloud Storage
config :buckets, TestCloud.GCS,
  adapter: Buckets.Adapters.GCS,
  bucket: "ex-buckets-test",
  path: "test/objects",
  service_account_path: "secret/gcs/elixir-saas-82a32641f1b6.json"

# Amazon S3
config :buckets, TestCloud.S3,
  adapter: Buckets.Adapters.S3,
  region: "us-east-2",
  bucket: "ex-buckets-test",
  path: "test/objects",
  access_key_id: File.read!("secret/s3/AWS_ACCESS_KEY_ID"),
  secret_access_key: File.read!("secret/s3/AWS_SECRET_ACCESS_KEY")

# DigitalOcean Spaces
config :buckets, TestCloud.DigitalOcean,
  adapter: Buckets.Adapters.S3,
  provider: :digitalocean,
  bucket: "ex-buckets-test",
  path: "test/objects",
  access_key_id: File.read!("secret/digitalocean/AWS_ACCESS_KEY_ID"),
  secret_access_key: File.read!("secret/digitalocean/AWS_SECRET_ACCESS_KEY")

# Cloudflare R2
config :buckets, TestCloud.Cloudflare,
  adapter: Buckets.Adapters.S3,
  provider: :cloudflare,
  endpoint_url: "https://261f9f435619b5b4c8fd3bd26cac7bff.r2.cloudflarestorage.com",
  bucket: "ex-buckets-test",
  path: "test/objects",
  access_key_id: File.read!("secret/cloudflare/AWS_ACCESS_KEY_ID"),
  secret_access_key: File.read!("secret/cloudflare/AWS_SECRET_ACCESS_KEY")

# Fly.io Tigris
config :buckets, TestCloud.Tigris,
  adapter: Buckets.Adapters.S3,
  provider: :tigris,
  bucket: "aged-feather-1704",
  path: "test/objects",
  access_key_id: File.read!("secret/tigris/AWS_ACCESS_KEY_ID"),
  secret_access_key: File.read!("secret/tigris/AWS_SECRET_ACCESS_KEY")
