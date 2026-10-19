# Command line reference

<primary-label ref="cli"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every command and option of the inspectra command line, with output and exit codes.</link-summary>

<card-summary>scan, audit, inspect, trust, typosquat, add, hook, trivy, check, format, lint, style, api, coverage, changelog, baseline, config, deps, graph, workspace, explain, doctor and report; options and exit codes.</card-summary>

```text
Supply-chain security scanner for Dart and Flutter projects.

Usage: inspectra <command> [arguments]

Global options:
-h, --help                Print this usage information.
    --version             Print the Inspectra version and exit.
-C, --directory=<path>    The package or project to work on.

Available commands:
  add         Audit a package and add its exact version to pubspec.yaml.
  api         Record or check the public API dump, and check semantic versioning.
  audit       Scan pubspec.lock against the OSV.dev vulnerability database.
  baseline    Record the accepted findings, so that only new ones fail, or prune the fixed ones.
  changelog   Generate the changelog from Conventional Commits, check it and print release notes.
  check       Run every enabled package check: format, lint, style, API, API semver, changelog, Trivy scans, dependency and workspace policy and coverage.
  config      Show where each configuration value comes from, validate and lint the configuration, print its JSON Schema, fetch its remote bases, create, migrate and compare configurations.
  coverage    Run the tests with coverage, write lcov.info and check the threshold.
  deps        Check the dependencies of pubspec.yaml against the pubspec rules and the dependency policy, offline unless --online; --fix applies the fixable rules.
  graph       Print the dependency graph of a pub workspace as text, DOT, Mermaid or JSON.
  format      Check that the Dart files are formatted, or format them with --fix.
  hook        Install or remove the Git pre-commit hook, or run its checks on the staged files.
  explain     Explain a rule: what it reports, why, and how to resolve it; without a rule id, list every rule.
  doctor      Check the configuration, the Dart and Flutter SDKs, Git, Trivy, the network and the cache.
  inspect     Statically analyse a pub.dev package before adding it.
  lint        Analyze the package with the rules of analysis_options.yaml.
  report      Run every evaluation - codebase, supply chain, dependencies, configuration, format, lint, style, API, changelog, Trivy and coverage - and report them at once, for example as an HTML dashboard.
  scan        Run every project check: OSV.dev audit, supply chain checks and Trivy (default).
  style       Check the Dart files against the built-in and custom style rules.
  trivy       Run Trivy: the configured scans, or a filesystem scan of the package.
  trust       Query pub.dev and print a trust assessment for a package.
  typosquat   Scan pubspec.yaml for typosquatting and dependency confusion risks.
  workspace   Tools for pub workspaces: the packages a change affects.

Run "inspectra help <command>" for more information about a command.
```

Run it from a package that depends on %product%, or install it globally:

```bash
dart run inspectra <command>               # as a dev dependency
dart pub global activate inspectra         # or globally ...
inspectra <command>                        # ... and run it directly
```

Without a command, `inspectra` runs [`scan`](#scan): `inspectra`, `inspectra -f json` and `inspectra scan -f json`
are the same.

## Global options

Global options go before the command.

| Option | Description |
|:--|:--|
| `-C`, `--directory <path>` | The package or project to work on, relative to the current directory. The configuration is read from there, Trivy runs there, and reports are written there. Defaults to the current directory. |
| `--version` | Print `inspectra <version>` and exit with `0`. |
| `-h`, `--help` | Usage of the command line, or of a command with `inspectra <command> --help`. |

```bash
dart run inspectra -C packages/core check
inspectra --version
```

## Shared options {id="shared-options"}

The supply-chain commands - `scan`, `audit`, `inspect`, `trust`, `typosquat`, `deps`, `add`, `hook` - `trivy`, `style`,
`changelog generate`, `changelog notes`, `baseline create|prune`, `config show|validate|lint` and `report` share these options:

| Option | Description |
|:--|:--|
| `--config <path>` | The configuration file. Default: `%config_file%` if present, else the `%pubspec_key%:` section of `pubspec.yaml`. See [Where the configuration lives](Configuration-Overview.md). |
| `--profile <name>` | Apply a [configuration profile](Configuration-Inheritance.md#profiles), for example `--profile ci`. Default: the environment variable `INSPECTRA_PROFILE`. `check`, `format`, `lint`, `coverage`, `api check|dump` and `changelog check` take it as well. |
| `--set <key=value>` | Override a configuration key by its dotted path, for example `--set trivy.version=latest`. Repeatable. An unknown key is a configuration error. |
| `-f`, `--format` | `text` (default), `json`, `sarif`, `markdown`, `junit`, `gitlab`, `sonarqube`, `checkstyle` or `html`. See [Reports and dashboards](Reports.md#formats). |
| `-o`, `--output <path>` | Write the report to a file instead of standard output. |
| `--[no-]color` | Force or disable ANSI colours. Default: detected from the terminal. |
| `-q`, `--quiet` | Only print warnings and errors. |
| `-v`, `--verbose` | Print diagnostics and list clean packages. |
| `--offline` | Never open a network connection: no HTTP request, no Trivy download, and Trivy runs with `--skip-db-update --offline-scan`. Same as `--set network.offline=true`. |
| `--fail-on <severity>` | Minimum severity that makes the command exit with `1`: `critical`, `high`, `medium`, `low` or `unknown`. Same as `fail_on`. |
| `--min-severity <severity>` | Hide findings below this severity. Same as `min_severity`. |
| `-i`, `--ignore <ID>` | Ignore a rule, advisory id or alias. Repeatable. For a documented, expiring suppression use the [`ignore`](Configuration-Reference.md#ignore) list. |
| `--exit-zero` | Exit with `0` even when findings reach the threshold. Never hides usage, input or availability errors. |

`scan`, `trivy`, `baseline create|prune`, `config show|validate|lint` and `report` also take the Trivy provisioning options:

| Option | Configuration key | Description |
|:--|:--|:--|
| `--trivy-mode <mode>` | `trivy.mode` | `auto`, `required` or `disabled`. |
| `--trivy-version <version>` | `trivy.version` | The Trivy version to download, or `latest`. |
| `--[no-]trivy-download` | `trivy.download` | Allow downloading Trivy when it is not installed. |
| `--[no-]trivy-use-installed` | `trivy.use_installed` | Use an installed Trivy even if its version differs. |
| `--trivy-executable <path>` | `trivy.executable` | The Trivy executable to use; disables every other lookup. |

See [Installing Trivy](Trivy-Installation.md#provisioning) for how these combine.

Progress and errors go to standard error, the report to standard output, so `inspectra audit -f json > report.json`
always produces valid JSON.

## scan {id="scan"}

```bash
inspectra                                     # same as: inspectra scan
inspectra scan -f sarif -o inspectra.sarif    # for GitHub code scanning
inspectra scan packages/app --fail-on high
inspectra scan -r                             # every package of a monorepo or pub workspace
```

The default command. Runs every project check and prints one report: the [OSV.dev audit](#audit) of `pubspec.lock`,
the pubspec rules, [typosquatting and dependency confusion](#typosquat), and a Trivy filesystem scan with the scanners,
severities and skipped directories of `trivy.filesystem`.

Trivy runs unless `trivy.mode` is `disabled`; `trivy.enabled` does not apply here. In `auto` mode an unavailable Trivy is
skipped with a warning, in `required` mode it is an error. Offline, the dependency confusion check is skipped with a
warning.

| Argument or option | Description |
|:--|:--|
| `[directory]` | The project to scan. Default: the current directory. |
| `-r`, `--recursive` | Also scan nested packages (monorepos and pub workspaces). |

Fails with `1` on any finding unless `--fail-on` or `fail_on` raise the threshold.

## audit {id="audit"}

```bash
inspectra audit
inspectra audit --format json > audit.json
inspectra audit -l app/pubspec.lock --fail-on high
```

Checks every hosted package of `pubspec.lock` against [OSV.dev](https://osv.dev), or the mirror in `network.osv_url`.
Git, path, SDK and private-registry packages are listed as not auditable.

| Option | Description |
|:--|:--|
| `-l`, `--lockfile <path>` | Path to `pubspec.lock`. Default: `pubspec.lock`. |

| Result | Exit code |
|:--|:--|
| No vulnerability at or above the threshold (default: any) | `0` |
| Vulnerabilities at or above the threshold | `1` |
| `pubspec.lock` missing or unreadable | `65` |
| OSV.dev unreachable, or `--offline` | `69` |

## inspect {id="inspect"}

```bash
inspectra inspect http 1.2.0
inspectra inspect http 1.2.0 -f json
```

Downloads the archive of exactly this version from the pub repository, verifies it against its published SHA-256,
reads it in memory and statically analyses the source, the archive structure and the package's own `pubspec.yaml`,
together with the [trust assessment](#trust). Tests, examples and tooling - `inspect.exclude_directories` - are skipped
for code patterns. Tune it in the [`inspect`](Configuration-Reference.md#inspect) section.

| Result | Exit code |
|:--|:--|
| Risk score below `inspect.fail_score` (default 30) | `0` |
| Risk score at or above `inspect.fail_score` | `1` |
| Missing `<package>` or `<version>`, an invalid name or version | `64` |
| Download or verification incomplete | `69` |

## trust {id="trust"}

```bash
inspectra trust http
inspectra trust http 1.2.0
```

Queries pub.dev and prints a trust assessment: first publication, release freshness, retraction, discontinuation,
verified publisher, likes, downloads and pub points. The thresholds are in the
[`trust`](Configuration-Reference.md#trust) section.

| Result | Exit code |
|:--|:--|
| No finding at or above the threshold (default: `critical`) | `0` |
| A finding at or above the threshold | `1` |
| Missing `<package>`, or a package that does not exist | `64` |
| pub.dev unreachable | `69` |

## typosquat {id="typosquat"}

```bash
inspectra typosquat
inspectra typosquat --pubspec app/pubspec.yaml
```

Checks the dependencies declared in `pubspec.yaml` for typosquatting - closeness to popular package names - and for
dependency confusion: private packages whose name also exists on pub.dev. Offline, the confusion check is skipped. Tune
it in the [`typosquat`](Configuration-Reference.md#typosquat) section.

| Option | Description |
|:--|:--|
| `--pubspec <path>` | Path to `pubspec.yaml`. Default: `pubspec.yaml`. |

Fails with `1` on a finding at or above `high` unless `--fail-on` or `fail_on` set another threshold.

## add {id="add"}

```bash
inspectra add http 1.2.0             # audit, then add exactly 1.2.0
inspectra add http                   # the latest version
inspectra add mocktail --dev
inspectra add http 1.2.0 --dry-run   # audit only
```

Audits a package - typosquatting, trust assessment and source inspection - and adds exactly the audited version with
`dart pub add <package>:<version>` (or `flutter pub add`), so the resolver cannot pick a different, unaudited release.
The package is blocked when it looks like a typosquat (`HIGH` or worse), when its trust assessment has a `CRITICAL`
finding, or when its risk score reaches `inspect.fail_score`.

| Option | Description |
|:--|:--|
| `-d`, `--dev` | Add under `dev_dependencies`. |
| `--force` | Install despite reported findings. Never overrides an incomplete verification. |
| `--dry-run` | Audit only; do not modify `pubspec.yaml`. |

| Result | Exit code |
|:--|:--|
| Audited and added, or `--dry-run` without a block | `0` |
| Blocked, and not installed | `1` |
| Missing `<package>`, an invalid name or version, an unknown package | `64` |
| No readable `pubspec.yaml` in the project | `65` |
| Audit incomplete, or `pub add` failed | `69` |

## hook {id="hook"}

```bash
inspectra hook                 # install
inspectra hook install
inspectra hook remove          # or: inspectra hook --remove
inspectra hook run             # what the hook runs: the checks of hook.checks on the staged files
```

Installs a Git pre-commit hook that runs `inspectra hook run` before every commit. The hook runs `inspectra` from the
`PATH`, or `dart run inspectra`. It honours `core.hooksPath` and worktrees, and never overwrites a hook it did not
install; installing again updates an older hook of %product%.

`inspectra hook run` checks the files staged for the commit with the checks of `hook.checks`:

| Check | Looks at |
|:--|:--|
| `audit` (default) | The staged content of every `pubspec.lock`, against OSV.dev |
| `typosquat` (default) | The staged content of every `pubspec.yaml`: typosquatting, and dependency confusion while online |
| `deps` | The staged content of every `pubspec.yaml`: the pubspec rules and the dependency policy |
| `format` | The staged Dart files that `format.include` covers, as they are in the working tree |
| `style` | The staged content of the Dart files that `style.include` covers |

```yaml
hook:
  checks: [audit, typosquat, deps, format, style]
```

A staged Dart file with further unstaged changes is named in a warning, because `format` checks the working tree. An
invalid configuration stops the commit with `65`. Ignore rules, the baseline and `--fail-on` apply; typosquatting and
confusion fail from `high`, every other finding by default.

| Option | Description |
|:--|:--|
| `--remove` | Remove the hook installed by %product%. |

`install` and `remove` exit with `0`. `hook run` exits with `0` when no finding reaches the threshold, `1` otherwise, and
with `-f json` writes `checks`, `staged`, `partiallyStaged` and `findings`.

## trivy {id="trivy"}

```bash
dart run inspectra trivy                         # configured scans, or a filesystem scan
dart run inspectra trivy secret                  # one scan
dart run inspectra trivy license vulnerability   # several scans
dart run inspectra trivy --where                 # which Trivy would be used
dart run inspectra trivy --install               # make Trivy available, e.g. to warm a CI cache
```

| Arguments | Runs |
|:--|:--|
| none, `trivy.enabled: true` | Every scan whose `enabled` is `true` |
| none, `trivy.enabled: false` | A Trivy filesystem scan of the package, like the Trivy part of [`scan`](#scan), with the scanners, severities and skipped directories of `trivy.filesystem` |
| scan names | Exactly the named scans, in the order secret, license, vulnerability, filesystem - regardless of `enabled` |

Scan names: `secret`, `license`, `vulnerability`, `filesystem`. An unknown name is a usage error.

The configured scans print their summary, write `%report_dir%/<scan>.json` and fail according to each scan's
`fail_on_findings`; see [Reports](Trivy-Reports.md). They need Trivy: when it cannot be provisioned, the command exits
with `69`. The filesystem scan without configured scans follows `trivy.mode` instead and fails on findings at or above
`--fail-on`.

| Option | Description |
|:--|:--|
| `--install` | Only provision Trivy - find it or download it - and print the executable, its version and its origin. |
| `--where` | Only print which Trivy executable would be used, its version and its origin. Never downloads. |

Both accept the [Trivy provisioning options](#shared-options). `--where` only considers executables that already exist -
configured, installed or cached - so it has no side effects. The origin is `configured`, `installed`, `cached` or
`downloaded`. When no Trivy can be provisioned, both print the reason and exit with `69`. A successful lookup prints:

```text
inspectra — Trivy · .
────────────────────────────────────────────────────────────
  Trivy 0.75.0 (cached): /home/me/.cache/inspectra/trivy/0.75.0/trivy
```

## check {id="check"}

```bash
dart run inspectra check
```

Runs every enabled package check in this order and fails if any of them fails:

1. The [format check](#format), when `format.enabled`.
2. The [lint check](#lint), when `lint.enabled`.
3. The [style check](#style), when `style.enabled`.
4. The [API check](#api-check), when `api.enabled`.
5. The [semantic versioning check](#api-semver), when `api.semver`.
6. The [changelog check](#changelog-check), when `changelog.enabled`.
7. Every [enabled Trivy scan](#trivy), when `trivy.enabled`.
8. The [dependency policy](#deps) with the pubspec rules, when `dependency_policy.enabled`; ignore rules and the
   baseline apply, and it fails from `fail_on`.
9. The [coverage gate](#coverage), when `coverage.enabled`.

All checks run even when an earlier one fails, so one run reports everything; an error such as a missing Trivy stops
the run with its exit code. With nothing enabled it prints
`Nothing is enabled. Enable "format", "lint", "style", "api", "changelog", "trivy", "dependency_policy" or "coverage" in the Inspectra configuration.`
and exits with `0`.

`check`, `format`, `lint`, `api`, `coverage` and `changelog check` need a `pubspec.yaml` in the package root. They take no shared options;
`INSPECTRA_*` environment variables and `INSPECTRA_CONFIG` apply to them as well. See
[Overriding options](Configuration-Overview.md#overrides).

## format {id="format"}

```bash
dart run inspectra format          # check
dart run inspectra format --fix    # format in place
```

Checks the files selected by `format.include` and `format.exclude` with `dart format`, or formats them with `--fix`.
Runs whether or not `format.enabled` is set, and writes `.dart_tool/inspectra/format.json`.

| Option | Description |
|:--|:--|
| `--fix` | Format the files instead of checking them. Lists the files it changed and never fails on formatting. |

| Result | Exit code |
|:--|:--|
| Everything formatted, or `--fix` | `0` |
| Unformatted files, with `fail_on_findings: true` | `1` |
| A file that does not parse, or `dart` cannot be started | `69` |

## lint {id="lint"}

```bash
dart run inspectra lint            # analyze
dart run inspectra lint --fix      # dart fix --apply, then analyze
```

Runs `dart analyze` in the package root and fails when a diagnostic at or above `lint.fail_on` is found. Runs whether
or not `lint.enabled` is set, and writes `.dart_tool/inspectra/lint.json`.

| Option | Description |
|:--|:--|
| `--fix` | Run `dart fix --apply` before analyzing. |

| Result | Exit code |
|:--|:--|
| No diagnostic at or above `lint.fail_on` | `0` |
| Diagnostics at or above `lint.fail_on` | `1` |
| `dart analyze` or `dart fix --apply` did not complete | `69` |

## style {id="style"}

```bash
dart run inspectra style
dart run inspectra style -f sarif -o style.sarif
```

Checks the files selected by `style.include` and `style.exclude` against the built-in rules of `style.preset` and
`style.rules` and the [custom rules](Style-Custom-Rules.md) of `style.custom_rules`, and writes
`.dart_tool/inspectra/style.json`. Runs whether or not `style.enabled` is set. The shared options apply; every
violation is a finding of the source `style` in JSON, SARIF and Markdown. See [Style check](Style-Check.md).

| Result | Exit code |
|:--|:--|
| No violation, or `style.fail_on_findings: false` | `0` |
| Violations | `1` |
| A missing header template or custom rule file, custom rules that do not compile or have invalid ids, an unknown rule in `style.rules` | `65` |
| `dart` cannot be started for the custom rules | `69` |

When the package has a [baseline](Baseline.md), the violations it covers are not reported; the text report counts them
and the JSON result has `"baseline": {"covered": …, "stale": …}`.

## api dump {id="api-dump"}

```bash
dart run inspectra api dump
```

Renders the public API and writes it to `api.output`. Prints `Wrote the public API to <path>.` Works whether or not
`api.enabled` is set.

## api check {id="api-check"}

```bash
dart run inspectra api check
```

Renders the public API and compares it with the dump at `api.output`.

| Result | Output | Exit code |
|:--|:--|:--|
| Equal | `The public API matches api/<package>.api.` | `0` |
| Different | `The public API changed.`, the diff, and how to record it | `1` |
| No dump | `No public API dump has been recorded yet at …` | `1` |

## api semver {id="api-semver"}

```bash
dart run inspectra api semver
dart run inspectra api semver --from v1.2.0 -f json
```

Compares the public API of the code with the dump committed at the last release tag, classifies every change as
breaking or additive, and checks that the `version` in `pubspec.yaml` makes the step the changes require. Works
whether or not `api.semver` is set. See [Semantic versioning](API-Semver.md).

| Option | Description |
|:--|:--|
| `--from <revision>` | Compare with the dump at this tag, branch or commit. Default: the release tag with the prefix `changelog.tag_prefix` and the highest version reachable from `HEAD`. |

The shared options apply; `-f json` lists every change, the required version and the findings.

| Result | Output | Exit code |
|:--|:--|:--|
| The version is high enough | `API semver: 2 change(s) since v1.0.0 (1.0.0).`, the changes, and the required version | `0` |
| The version is too low, or a breaking change is not announced by a commit | The same, plus `SEMVER_VIOLATION` or `SEMVER_UNDECLARED_BREAKING` | `1` |
| No release tag, no dump at the release, or no `version` in `pubspec.yaml` | `API semver: skipped, …` with the reason | `0` |
| Not inside a Git repository, or a `--from` revision Git cannot resolve | The cause | `64` |
| Git is missing or fails | The cause | `69` |

In a shallow clone it warns that tags may be missing.

## coverage {id="coverage"}

```bash
dart run inspectra coverage
dart run inspectra coverage --min 85
```

Runs the tests with coverage, writes `lcov.info`, prints the table and checks the threshold. Runs whether or not
`coverage.enabled` is set.

| Option | Description |
|:--|:--|
| `--min <percent>` | The threshold for this run, overriding `coverage.min_line_coverage`. A number from 0 to 100; anything else is a usage error. |

| Result | Exit code |
|:--|:--|
| No threshold, or at or above it | `0` |
| Below the threshold | `1` |
| A test failed, or the runner could not start | `69` |

## changelog generate {id="changelog-generate"}

```bash
dart run inspectra changelog generate
dart run inspectra changelog generate --write
dart run inspectra changelog generate --from v1.0.0 --to main --release 1.1.0 --date 2026-10-04 -f json
```

Reads the commits reachable from `--to` and not from the previous release tag, groups them into the sections of Keep
a Changelog and prints the section of the next release as Markdown. With `--write` it adds the section to
`changelog.file` instead. The suggested version and why it was chosen go to standard error. See
[Changelog](Changelog-Overview.md) and [Commit conventions](Changelog-Commit-Conventions.md).

| Option | Description |
|:--|:--|
| `--from <revision>` | Leave out the commits reachable from this tag, branch or commit. Default: the release tag with the highest version reachable from `--to`; without one, the whole history. |
| `--to <revision>` | Include the commits reachable from this revision. Default: `HEAD`. |
| `--release <version>` | The version to release, with or without a leading `v`. Default: [suggested](Changelog-Commit-Conventions.md#versions) from the commits. |
| `--date <YYYY-MM-DD>` | The release date. Default: today. |
| `--write` | Add the section to `changelog.file` below its introduction and `Unreleased` section, creating the file when it is missing. |

The shared options apply; `-f json` prints the [JSON report](Changelog-Releasing.md#ci) and `-o` writes the output to
a file. Revisions that start with `-` are rejected, so that no value can become an option of `git`.

| Result | Output | Exit code |
|:--|:--|:--|
| Changes to release | The Markdown section, or `✔ Version 1.2.0 added to CHANGELOG.md (5 changes).` with `--write` | `0` |
| Nothing to release | `No changes to release since v1.1.0.`; nothing is written | `0` |
| The version is already in the changelog | `error: … already has a section for version 1.2.0. …` | `64` |
| An invalid `--release` or `--date`, a revision Git cannot resolve, or no release tag and no `version` in `pubspec.yaml` | The cause | `64` |
| Not inside a Git repository | `error: No Git repository found. Run this command inside a Git repository.` | `64` |
| Git is missing or fails, or the changelog cannot be written | The cause | `69` |

In a shallow clone it warns that commits and tags may be missing.

## changelog check {id="changelog-check"}

```bash
dart run inspectra changelog check
```

Validates `changelog.file`: every level two heading is a release or `Unreleased`, versions are semantic versions
listed once and newest first, dates are `YYYY-MM-DD`, and the version of `pubspec.yaml` has a section with text. Runs
whether or not `changelog.enabled` is set; with it, [`check`](#check) runs it too. See
[What changelog check validates](Changelog-Releasing.md#check).

| Result | Output | Exit code |
|:--|:--|:--|
| Valid | `CHANGELOG.md is well-formed and documents version 1.2.0.` | `0` |
| Problems | `CHANGELOG.md has 2 problem(s):`, one line per problem, and how to generate the missing section | `1` |
| `pubspec.yaml` malformed | The cause | `65` |

## changelog notes {id="changelog-notes"}

```bash
dart run inspectra changelog notes
dart run inspectra changelog notes 1.2.0 --output RELEASE_NOTES.md
```

Prints the text of the section of a release, without its heading: the release notes. The version defaults to the one
in `pubspec.yaml` and matches `## 1.2.0`, `## [1.2.0]` and `## v1.2.0` alike. With `-f json` the report holds
`version`, `date` and `notes`.

| Result | Exit code |
|:--|:--|
| The section was printed | `0` |
| No version given and none in `pubspec.yaml` | `64` |
| The changelog is missing, or has no or an empty section for the version | `65` |

## baseline create {id="baseline-create"}

```bash
dart run inspectra baseline create
dart run inspectra baseline create --only style,lint
```

Runs the scopes and records their findings in `baseline.file` (default `inspectra-baseline.json`), replacing the entries
of those scopes and keeping the others. Without `--only`, the scopes are `scan` and, when enabled, `lint`, `style` and
`trivy`. Ignore rules and `--min-severity` apply first. The file is only written when it changes. With `-f json` the
report holds `action`, `file`, `changed`, `total` and `scopes` with the recorded findings `before` and `after` per
scope. See [Baseline](Baseline.md).

| Option | Description |
|:--|:--|
| `--only <scope>` | `scan`, `lint`, `style` or `trivy`. Repeatable or comma-separated. |
| `-r`, `--recursive` | Also scan nested packages for the `scan` scope. |

| Result | Exit code |
|:--|:--|
| The baseline was written, or is unchanged | `0` |
| A malformed baseline file, lockfile or configuration | `65` |
| A scope cannot run completely: OSV.dev unreachable or offline, `dart analyze` failing, Trivy unavailable; nothing is written | `69` |

## baseline prune {id="baseline-prune"}

```bash
dart run inspectra baseline prune
```

Runs the scopes like [`baseline create`](#baseline-create) and removes what was fixed: every count drops to the number
of findings that still occur, and entries without any are removed. Nothing is ever added. Options, report and exit
codes are those of `baseline create`.

## deps {id="deps"}

```bash
dart run inspectra deps
dart run inspectra deps -r --fix
```

Checks every `pubspec.yaml` against the built-in pubspec rules and, with `dependency_policy.enabled`, the
[dependency policy](Dependency-Policy.md), without network access unless `--online` is given. `directory` defaults to
the current one. The shared options apply; findings are of the source `pubspec`. With `-f json` the report holds
`pubspecs`, `fixed`, `suppressed`, `baselined` and `findings`, and while `max_major_behind` or `max_libyear` is
configured `outdatedChecked` and, once checked, `libyears`.

| Option | Description |
|:--|:--|
| `-r`, `--recursive` | Also check the packages below the directory; at the root of a pub workspace, its members, and with `workspace_policy.enabled` the [workspace policy](Workspace-Policy.md). |
| `--online` | Also check `max_major_behind` and `max_libyear` against the package registry. No effect with `--offline`. |
| `--changed-since <revision>` | With `-r` at the root of a pub workspace, check only the packages changed since the Git revision and the packages depending on them. |
| `--fix` | Bound constraints with a caret, rewrite them in the `constraint_style`, move `dev_only` packages to `dev_dependencies` and add `publish_to: none`, keeping comments and formatting; then report what remains. |

| Result | Exit code |
|:--|:--|
| No finding at or above `--fail-on` (default: any) | `0` |
| Findings | `1` |
| No `pubspec.yaml`, a malformed pubspec or lockfile, an invalid configuration | `65` |
| A fixed `pubspec.yaml` cannot be written, or the registry cannot be queried with `--online` | `69` |

## graph {id="graph"}

```bash
dart run inspectra graph -f mermaid
```

Prints the dependencies between the packages of a pub workspace, grouped by the layers of `workspace_policy`, or the
direct dependencies of a single package. `directory` defaults to the current one. See
[Workspace policy](Workspace-Policy.md#graph).

| Option | Description |
|:--|:--|
| `-f`, `--format` | `text` (default), `dot`, `mermaid` or `json` (`nodes` with `name` and `layer`, `edges` with `from`, `to` and `external`). |
| `--include-dev` | Also draw `dev_dependencies`. |
| `--external` | Also draw the dependencies outside the workspace. |

Exit code `0`; `65` without a `pubspec.yaml`, or for a malformed pubspec or configuration.

## workspace affected {id="workspace-affected"}

```bash
dart run inspectra workspace affected --since origin/main
```

Lists the directories of the packages of a pub workspace that the files changed since the Git revision affect, with
every package depending on them; a change of a file all packages share affects all of them. See
[Workspace policy](Workspace-Policy.md#affected).

| Option | Description |
|:--|:--|
| `--since <revision>` | The revision to compare with. Required. |
| `-f`, `--format` | `text`, one directory per line (default), or `json` with `since`, `changedFiles` and `packages` (`name`, `path`). |
| `--[no-]include-dev` | Count packages that use a changed package only as a `dev_dependency`. Default: on. |

| Result | Exit code |
|:--|:--|
| Listed | `0` |
| No workspace root, or a revision Git cannot resolve | `64` |
| A malformed pubspec | `65` |
| Git is not installed or fails | `69` |

## config show {id="config-show"}

```bash
dart run inspectra config show --explain
dart run inspectra config show --only-changed -f json
```

Prints the effective configuration as YAML; options without a value are commented out. The shared options apply, so
`--config`, `--set` and the Trivy flags change what is shown exactly as they change what other commands use. See
[Configuration tools](Configuration-Tools.md#show).

| Option | Description |
|:--|:--|
| `--explain` | Comment every value with its origin: `default`, the file and line, an environment variable or `command line`. |
| `--only-changed` | Show only values that do not come from the defaults. |

With `-f json` the report holds `source` and `values`, one object per option with `key`, `value`, `default`,
`origin` and, where known, `variable` and `line`. Exit code `0`, or `65` for an invalid configuration.

## config validate {id="config-validate"}

```bash
dart run inspectra config validate
```

Loads the configuration, every [profile](Configuration-Inheritance.md#profiles) it defines, and checks that every file it
refers to exists and that the baseline file is well-formed.
See [Configuration tools](Configuration-Tools.md#validate).

| Result | Exit code |
|:--|:--|
| Valid; with `-f json`: `source`, `valid`, `files` and `profiles` | `0` |
| An invalid key or value, or missing referenced files - all listed at once | `65` |

## config lint {id="config-lint"}

```bash
dart run inspectra config lint
dart run inspectra config lint -f sarif -o config.sarif --fail-on medium
```

Reports risky settings as findings of the source `config`: insecure URLs, a disabled or unpinned Trivy, misspelled
`INSPECTRA_*` variables, ignore rules without or past their expiry, gates that never fail, hidden findings, a coverage
gate without threshold and a baseline without `max_severity`. See the rules in
[Configuration tools](Configuration-Tools.md#lint).

| Result | Exit code |
|:--|:--|
| No finding at or above `--fail-on` (default: any) | `0` |
| Findings | `1` |
| An invalid configuration | `65` |

## config schema {id="config-schema"}

```bash
dart run inspectra config schema -o inspectra.schema.json
```

Prints the JSON Schema (draft-07) of `inspectra.yaml`, generated from the options the configuration reads. It reads no
project configuration and takes only `-o`, `--output <path>`. Exit code `0`, or `69` when the file cannot be written.
See [Editor support](Configuration-Tools.md#schema).

## config init {id="config-init"}

```bash
dart run inspectra config init --preset library
```

Writes a starting `inspectra.yaml` for an `app`, `library`, `plugin` or `enterprise` project; without `--preset` the
kind is detected from `pubspec.yaml`. Reads no configuration. See [Configuration tools](Configuration-Tools.md#init).

| Option | Description |
|:--|:--|
| `--preset <kind>` | `app`, `library`, `plugin` or `enterprise`. Default: `plugin` for a Flutter plugin, `library` for a package that can be published, `app` otherwise. |
| `--stdout` | Print the configuration instead of writing the file. |
| `--force` | Replace an existing `inspectra.yaml`. |

| Result | Exit code |
|:--|:--|
| Written or printed | `0` |
| `inspectra.yaml` exists, without `--force` | `64` |
| A malformed `pubspec.yaml` | `65` |
| The file cannot be written | `69` |

## config migrate {id="config-migrate"}

```bash
dart run inspectra config migrate --dry-run
```

Replaces the old names of renamed options in the configuration file and its profiles, keeping values, comments and
order. Takes `--config <path>`, `--dry-run` and `-f text|json`. Exit code `0`, also when nothing changes; `65` for a
malformed file or an option written under both names; `69` when the file cannot be written. See
[Configuration tools](Configuration-Tools.md#migrate).

## config diff {id="config-diff"}

```bash
dart run inspectra config diff git:main --fail-on-weaker
```

Compares two configurations - files or `git:<revision>` - option by option; with one, the second is the effective
configuration. Takes the [shared options](#shared-options), the Trivy provisioning options and `--fail-on-weaker`. See
[Configuration tools](Configuration-Tools.md#diff).

| Result | Exit code |
|:--|:--|
| Compared; with `-f json`: `from`, `to` and `changes` | `0` |
| An option got weaker, with `--fail-on-weaker` | `1` |
| No or more than two configurations, or an unknown revision | `64` |
| A file that does not exist or an invalid configuration | `65` |
| Git is not installed or fails | `69` |

## report {id="report"}

```bash
dart run inspectra report -f html -o inspectra-report.html --also junit=build/junit.xml
dart run inspectra report --skip scan,coverage
dart run inspectra report --merge app.json --merge api.json -f html -o inspectra-report.html
dart run inspectra report --recursive -f html -o inspectra-report.html
```

Runs every evaluation - the size of the code base, supply chain, dependencies, configuration, format, lint, style,
public API, changelog, the configured Trivy scans and coverage - and reports each as a section with its status, summary, key figures and findings.
Package checks that are not enabled are reported as skipped. An evaluation that cannot run is reported with its cause
while the others still run. Takes the [shared options](#shared-options) and the Trivy provisioning options. See
[Reports and dashboards](Reports.md).

| Option | Description |
|:--|:--|
| `--skip <section>` | Leave out sections: `codebase`, `scan`, `deps`, `config`, `format`, `lint`, `style`, `api`, `changelog`, `trivy`, `coverage`. Repeatable or comma-separated. |
| `--also <format>=<path>` | Also write the report in another format, such as `junit=build/junit.xml`. Repeatable. |
| `--merge <report.json>` | Merge JSON reports of earlier runs instead of running the evaluations. Repeatable. |
| `-r`, `--recursive` | Report every Dart package at or below the directory, each with its own configuration, in one report. The default in a directory without `pubspec.yaml` that has packages below it; `--no-recursive` reports the directory itself. See [Several projects at once](Reports.md#recursive). |

`-f json` writes `project`, `status` and `sections`, one object per section with `id`, `title`, `status` (`passed`,
`failed`, `skipped` or `error`), `summary`, `metrics`, `findings` and, where known, `reason` and `details`.
Across several projects it writes `project`, `status` and `projects`, the body of each project's report with its
`path` relative to the directory.

| Result | Exit code |
|:--|:--|
| Every section passed or was skipped | `0` |
| A section failed, without `--exit-zero` | `1` |
| `--also` without a known format and a path, or `--recursive` with `--merge` | `64` |
| A report to merge cannot be read or is no Inspectra JSON report, or `--recursive` finds no package | `65` |
| A section could not run completely, also with `--exit-zero`; the report is written first | `69` |

## config fetch {id="config-fetch"}

```bash
dart run inspectra config fetch
```

Downloads and verifies the remote bases the configuration [extends](Configuration-Inheritance.md) into the cache and
lists every base. Takes the shared and Trivy provisioning options; `-f json` writes `bases` with `label`, `kind` and
`downloaded`. Exit code `0`; `65` for a malformed configuration or a download that does not match its SHA-256; `69`
when a base cannot be downloaded, for example with `--offline`.

## explain {id="explain"}

```bash
dart run inspectra explain MISSING_UPPER_BOUND
dart run inspectra explain -f markdown
```

Explains a rule offline: its source, default severity, what it reports, why it matters and how to resolve it. The id
is found in any case; an advisory id such as `GHSA-…` or `CVE-…` is pointed to OSV.dev. Without an id, every rule is
listed. `-f text|markdown|json`. Exit code `0`, or `64` with the closest rule for an id that names none. See the
[Rule reference](Rule-Reference.md).

## doctor {id="doctor"}

```bash
dart run inspectra doctor
```

Checks the configuration, the Dart and Flutter SDKs, Git, Trivy, proxy, CA bundle, the reachability of the services,
the registry token and the cache, and says what to do. Works while the configuration is broken. `--offline` contacts
no service, `-f json` writes `healthy` and `checks`. Exit code `0`, or `1` when a check failed. See
[Doctor](Doctor.md).

## Exit codes {id="exit-codes"}

<include from="lib.topic" element-id="exit-codes"/>

Every exit code other than `0` and `1` comes with a message on standard error naming the cause:

| Message | Exit code |
|:--|:--|
| `error: Could not find a command named "frob".` | `64` |
| `error: inspect requires <package> and <version> arguments.` | `64` |
| `error: --set expects key=value, got "foo".` | `64` |
| `error: --min must be a number between 0 and 100.` | `64` |
| `error: Git cannot resolve the range: fatal: ambiguous argument 'v9..HEAD': unknown revision …` | `64` |
| `error: Invalid Inspectra configuration at "inspectra.trivy.secrets": unknown option. Known options here: …` | `65` |
| `error: Invalid Inspectra configuration at "trivy.secrets": unknown option given on the command line.` | `65` |
| `error: Invalid Inspectra configuration at "nope.yaml": the configuration file does not exist.` | `65` |
| `error: …/pubspec.lock not found. Run "dart pub get" first.` | `65` |
| `error: No pubspec.lock found; run "dart pub get" first.: …` | `65` |
| `error: No pubspec.yaml found; run Inspectra from a package root.: …` | `65` |
| `error: The changelog CHANGELOG.md has no section for version 1.2.0.` | `65` |
| `error: The license header template tool/header.txt (style.license_header) does not exist.` | `65` |
| `error: The baseline …/inspectra-baseline.json needs an "entries" list.` | `65` |
| `error: The configuration has 2 problem(s): …` | `65` |
| `error: The custom style rules of style.custom_rules could not be run (dart run exited with 254). …` | `65` |
| `error: Invalid --also "pdf=a.pdf": expected <format>=<path> with one of json, sarif, …` | `64` |
| `error: report.json is no Inspectra JSON report; create it with "--format json".` | `65` |
| `error: Invalid Inspectra configuration at "coverage.min_line_coverage": 50.0 (the command line) is below the minimum 70 set by package:acme_policy/inspectra.yaml.` | `65` |
| `error: Invalid Inspectra configuration at "extends": the base https://… is not in the cache; run "dart run inspectra config fetch" while online.` | `65` |
| `error: The base https://… has the SHA-256 …, but extends pins …; it was not used.` | `65` |
| `error: Git is not installed or not on the PATH.` | `69` |
| `error: The report is incomplete: Trivy secret could not run completely.` | `69` |
| `error: Trivy is not installed and downloading is disabled (trivy.download: false). Trivy is required (trivy.mode: required).` | `69` |
| `error: The configured Trivy executable "…" (trivy.executable) cannot be run.` | `69` |
| `error: Network access is disabled (offline mode), so api.osv.dev cannot be contacted.` | `69` |
| `error: Trivy did not finish scanning …: it exited with 1. This is a failure of Trivy itself, not a finding.` | `69` |
| `error: "dart format" failed with exit code 65.` | `69` |
| `error: "dart analyze" failed with exit code 64.` | `69` |
| `error: "dart test --coverage=…" failed with exit code 1; see its output above.` | `69` |
| `error: Could not start "flutter": …` | `69` |
| `error: internal error: …` | `70` |

## Output streams

Results go to standard output; progress, warnings and errors that prevent a check from running go to standard error.
The test runner's own output during `coverage` is passed through as it is produced.

<seealso>
    <category ref="reference">
        <a href="Builder-Reference.md">Builder reference</a>
        <a href="Library-API.md">Library API</a>
    </category>
    <category ref="config">
        <a href="Configuration-Overview.md#overrides">Overriding options</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
        <a href="Troubleshooting.md">Troubleshooting</a>
    </category>
</seealso>
