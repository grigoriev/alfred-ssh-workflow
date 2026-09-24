# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases before 1.0.2 are listed on the
[GitHub releases page](https://github.com/grigoriev/alfred-ssh-workflow/releases).

## [Unreleased]

### Changed

- The version bump moves the Unreleased entries of this changelog into a section for
  the new version. The GitHub release takes its notes from that section.

## [1.0.2] - 2026-09-24

### Security

- Audit the workflows with actionlint and zizmor in the lint job.
- Add the OpenSSF Scorecard workflow and its README badge.
- Limit the token permissions of every workflow.
- Stop persisting the checkout credentials where no step needs them.
- Pass template values to scripts through environment variables.
- Pin every action by commit SHA; Renovate keeps the digests current.
- Pin the kcov coverage image by digest; Renovate keeps it current.
- Attach a signed build provenance bundle (`*.intoto.jsonl`) to each release.
- Renovate takes its common rules from the shared preset `github>grigoriev/renovate-config`, which also turns on OSV vulnerability alerts.

### Added

- A Disclaimer section in the README.

### Fixed

- Run CI once per commit on a Renovate branch; a second push run blocked the automerge.
- Upload the files to the existing release on a rerun of the release workflow.
