import Config

config :ex_aws,
  access_key_id: [File.read!("secret/AWS_ACCESS_KEY_ID"), :instance_role],
  secret_access_key: [File.read!("secret/AWS_SECRET_ACCESS_KEY"), :instance_role]

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
      service_account: "buckets-test@elixir-saas.iam.gserviceaccount.com",
      goth_server: GothTest
    ],
    amazon: [
      strategy: Buckets.Strategy.S3,
      region: "us-east-2",
      bucket: "ex-buckets-test",
      path: "test/objects"
    ]
  ]
