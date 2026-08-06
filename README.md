# Alfred SSH Workflow

![CI](https://github.com/grigoriev/alfred-ssh-workflow/actions/workflows/ci.yml/badge.svg)
[![Release](https://img.shields.io/github/v/release/grigoriev/alfred-ssh-workflow)](https://github.com/grigoriev/alfred-ssh-workflow/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An [Alfred](https://www.alfredapp.com/) workflow that lists the hosts from your
`~/.ssh/config` and opens an SSH session in iTerm2.

Built in the same style as
[alfred-network-workflow](https://github.com/grigoriev/alfred-network-workflow):
plain Bash, JSON feedback, a Makefile-driven build, bats tests and self-update.

## Usage

| Keyword        | What it does                                             |
| -------------- | -------------------------------------------------------- |
| `ssh`          | List hosts from `~/.ssh/config`, filtered as you type    |
| `ssh <query>`  | Filter by alias, hostname or user                        |
| `ssh update`   | Check for and install a new version of the workflow      |

Press ⏎ on a host to open `ssh <alias>` in a new iTerm2 window.

## How it works

The `ssh` keyword runs `src/ssh.sh`, which parses `~/.ssh/config` (expanding
`Include` directives, skipping wildcard `Host` patterns) into a JSON list of
hosts and returns Alfred feedback. Selecting a host runs `ssh <alias>` in iTerm2
through `osascript`. `info.plist` wires the `ssh` Script Filter to a Run Script.

## Requirements

- macOS with [iTerm2](https://iterm2.com/)
- `jq` (bundled with macOS since Sequoia)

## Development

A `Makefile` drives the same steps locally and in CI:

```sh
make lint     # ShellCheck the action scripts
make test     # run the bats tests
make build    # fetch the updater and build SSH.alfredworkflow
make clean    # remove the build artifact and fetched files
```

Install the tools with `brew install bats-core shellcheck jq`. System commands
are replaced by mocks under `tests/mocks/bin`, and the ssh config is a fixture
pointed to by `SSH_CONFIG`, so the tests run without touching real state.

The self-update logic is shared, not vendored. `make build` fetches
[`update.sh`](https://github.com/grigoriev/alfred-workflow-updater) at build
time and bundles it, so it is never stored in this repository.

## Releases

Run the **Bump Version & Release** workflow from the Actions tab and pick
`patch`, `minor` or `major`. It bumps the version, tags it, and the release
workflow builds `SSH.alfredworkflow` and publishes a GitHub Release with the
asset attached. Pushing a `v*` tag by hand does the same.
