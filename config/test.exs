import Config

config :logger, :level, :warning

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
    google: [
      strategy: Buckets.Strategy.GCS,
      bucket: "ex-buckets-test",
      path: "test/objects",
      service_account_path: "secret/elixir-saas-82a32641f1b6.json"
    ],
    amazon: [
      strategy: Buckets.Strategy.S3,
      region: "us-east-2",
      bucket: "ex-buckets-test",
      path: "test/objects",
      access_key_id: File.read!("secret/AWS_ACCESS_KEY_ID"),
      secret_access_key: File.read!("secret/AWS_SECRET_ACCESS_KEY")
    ]
  ]
