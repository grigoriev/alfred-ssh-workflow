# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

- Audit the workflows with actionlint and zizmor in the lint job.
- Add the OpenSSF Scorecard workflow and its README badge.
- Limit the token permissions of every workflow.
- Stop persisting the checkout credentials where no step needs them.
- Pass template values to scripts through environment variables.
- Pin every action by commit SHA; Renovate keeps the digests current.
- Pin the kcov coverage image by digest; Renovate keeps it current.
- Attach a signed build provenance bundle (`*.intoto.jsonl`) to each release.

### Added

- A Disclaimer section in the README.

### Fixed

- Run CI once per commit on a Renovate branch; a second push run blocked the automerge.
- Upload the files to the existing release on a rerun of the release workflow.

Earlier releases are listed on the
[GitHub releases page](https://github.com/grigoriev/alfred-ssh-workflow/releases).
