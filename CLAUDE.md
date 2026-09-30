# CLAUDE.md

Alfred workflow that lists the hosts of `~/.ssh/config` and opens `ssh <alias>` in iTerm2.
Plain bash, Alfred JSON feedback, bats tests, a shared self-updater.
Keyword: `ssh`. Artifact: `SSH.alfredworkflow`.

## Layout

- `src/ssh.sh` - the entry point. It takes `mode` (`list` for the Script Filter, `run` for the Run Script) and `query`.
- `src/hosts.sh` - parses the SSH config, expands `Include`, skips wildcard `Host` patterns.
- `src/parse-hosts.awk`, `src/rows-to-hosts.jq`, `src/list-hosts.jq` - extracted awk and jq programs.
- `src/workflow_handler.sh` - shared JSON feedback helpers, identical in all sibling workflows.
- `src/media.sh` - icon paths.
- `src/update.sh`, `src/autoupdate.sh` - fetched at build time from `alfred-workflow-updater`. Gitignored, never committed.
- `info.plist` - Alfred objects and the workflow `version`.
- `tests/*.bats` - one file per source file, plus `tests/perf_tests.bats`.
- `tests/mocks/bin/` - fake `open` and `osascript`.

## Commands

```sh
make lint       # ShellCheck src/ssh.sh and src/hosts.sh in Docker
make test       # fetch the updater, then run bats tests (macOS)
make coverage   # bats under kcov in Docker, writes sonar-coverage.xml
make build      # fetch and verify the updater, zip SSH.alfredworkflow
make clean      # remove the artifact, fetched updater and coverage
```

1. Install tools with `brew install bats-core jq`.
2. `make lint SHELLCHECK=shellcheck` uses a local ShellCheck instead of Docker.
3. `make test` needs network access, because it fetches the updater bundle first.
4. The SSH config fixture comes from the `SSH_CONFIG` env var.

## Constraints and conventions

- Scripts run under stock macOS `/bin/bash` 3.2.
- No bash 4+ features: no `mapfile`, `readarray`, `declare -A`, `${var,,}` or `${var^^}`.
- Check a construct with `/bin/bash -c '...'`. zsh and Homebrew bash 5 hide 3.2 gaps.
- No perl. Use `awk`, `sed`, `jq` or bash.
- Build Script Filter JSON with `add_result` and `get_json_results`, never by hand.
- The Script Filter must feel instant. Spawn `jq` once per run, not once per host.
- Put multi-line jq or awk programs in `src/*.jq` or `src/*.awk` and call them with `-f`.
- Settings and updates live behind the `ssh >` menu. `globals_menu` calls the shared `autoupdate_menu`.
- Update logic lives only in `alfred-workflow-updater`. Never reimplement it here.
- SonarCloud shell rules: `[[ ]]` not `[ ]`, positional params into named lowercase `local`s, snake_case functions, explicit `return` at function end, a `*)` default in every `case`, HTTPS for `curl`.
- iTerm2 AppleScript: compile-check with `osacompile -o /dev/null -` before shipping.
- kcov cannot cover the `done` of `while read ... done < "$file"`. Coverage tops out near 99.3%. Accept it.

## Review focus

Flag these in a pull request:

- Any bash 4+ feature, or any perl call.
- A new or changed function without a bats test. A bug fix without a test that fails before the fix.
- Unquoted variable expansions, especially host names and paths from the SSH config.
- `jq`, `awk` or a subshell spawned inside a per-host loop.
- A multi-line jq or awk program embedded in `$(...)` instead of a `src/*.jq` or `src/*.awk` file.
- Hand-built JSON strings instead of `add_result` and `json_encode`.
- A violation of the Sonar shell rules listed above.
- A new `src/*.sh` script that the `SCRIPTS` list in the Makefile does not lint.
- Tests that touch real state: the real `~/.ssh/config`, iTerm2 or `open` without a mock.
- Update or autoupdate logic added here instead of in `alfred-workflow-updater`.
- A committed `src/update.sh` or `src/autoupdate.sh`.
- A change to `.github/workflows/ci.yml`, `release.yml` or `bump-version.yml` in this repo only. These are byte-identical across all 8 Alfred repos.
- A user-facing change without an entry under `## [Unreleased]` in `CHANGELOG.md`.
- A behavior or configuration change without a README update.

Commit, branch and pull request rules are in `CONTRIBUTING.md`.

## CI and release

- `ci.yml`: ShellCheck, actionlint and zizmor on Ubuntu, bats on `macos-latest`, the build, and a SonarCloud scan with kcov coverage.
- The version lives in `info.plist`. `make print-version` and `make set-version VERSION=x.y.z` read and write it.
- A maintainer runs **Bump Version & Release**. It cuts the `CHANGELOG.md` section and tags `v*`.
- `release.yml` builds with `CHECK_PROVENANCE=1`, attests the artifact, and publishes an immutable release.
