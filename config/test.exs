import Config

config :buckets, :volume_opts,
  strategy: Buckets.Strategy.Volume,
  bucket: System.tmp_dir!(),
  path: "test/objects"

config :buckets, :gcs_opts,
  strategy: Buckets.Strategy.GCS,
  bucket: "ex-buckets-test",
  path: "test/objects",
  service_account: "buckets-test@elixir-saas.iam.gserviceaccount.com",
  goth_server: Pod.GothTest
