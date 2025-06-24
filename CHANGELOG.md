# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0-rc.2] - 2025-06-24

### Added
- Support for multiple cloud storage providers:
  - Local filesystem (Volume adapter)
  - Google Cloud Storage (GCS adapter)
  - Amazon S3 (S3 adapter)
  - Cloudflare R2 (via S3 adapter with `provider: :cloudflare`)
  - DigitalOcean Spaces (via S3 adapter with `provider: :digitalocean`)
  - Tigris (via S3 adapter with `provider: :tigris`)
- Multi-cloud support with multiple Cloud modules
- Dynamic cloud configuration for runtime-determined storage
- Signed URL support for secure uploads and downloads
- Phoenix LiveView integration for direct-to-cloud uploads
- Development router for local file uploads/downloads
- Telemetry integration for monitoring and metrics
- Comprehensive test suite with live service testing

### Changed
- Switched from multiple strategies per cloud to one adapter per cloud approach
- Renamed Strategy modules to Adapter modules
- Replaced external dependencies (gcs_signed_url, google_api_storage, goth, ex_aws) with req
- Renamed `cloudflare_r2` provider to `cloudflare` for consistency
- Cloud modules now act as supervisors for adapters that need background processes

### Fixed
- Router configuration to allow cloud module in location config
- Automatic setting of correct GCS options for uploads
- Warning messages for cloud supervisors with no children

### Internal
- Added `validate_config` callback to adapter behavior
- Improved Location struct with derived inspect that ignores :config
- Enhanced documentation and README with core concepts
