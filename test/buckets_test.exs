defmodule BucketsTest do
  use ExUnit.Case

  test "version in README matches mix.exs" do
    # Get version from mix.exs
    mix_version = Buckets.MixProject.project()[:version]

    # Read README content
    readme_content = File.read!("README.md")

    # Extract version from README installation section
    version_regex = ~r/{:buckets, "~> ([^"]+)"}/

    assert [_, readme_version] = Regex.run(version_regex, readme_content),
           "Could not find version in README.md installation section"

    assert readme_version == mix_version,
           "Version mismatch: mix.exs has '#{mix_version}' but README has '#{readme_version}'"
  end
end
