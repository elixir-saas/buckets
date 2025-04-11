import Config

config :buckets, TestCloud,
  locations: [
    local: [
      strategy: Buckets.Strategy.Volume,
      bucket: System.tmp_dir!(),
      base_url: "http://localhost:4000",
      path: "test/objects"
    ],
    other_local: [
      strategy: Buckets.Strategy.Volume,
      bucket: System.tmp_dir!(),
      path: "test_other/objects"
    ],
    google_cloud: [
      strategy: Buckets.Strategy.GCS,
      bucket: "ex-buckets-test",
      path: "test/objects",
      service_account: "buckets-test@elixir-saas.iam.gserviceaccount.com",
      goth_server: GothTest
    ]
  ]

config :buckets, :volume_opts,
  strategy: Buckets.Strategy.Volume,
  bucket: System.tmp_dir!(),
  base_url: "http://localhost:4000",
  path: "test/objects"

config :buckets, :gcs_opts,
  strategy: Buckets.Strategy.GCS,
  bucket: "ex-buckets-test",
  path: "test/objects",
  service_account: "buckets-test@elixir-saas.iam.gserviceaccount.com",
  goth_server: GothTest
