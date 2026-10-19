# Configuration tools

<primary-label ref="cli"/>
<secondary-label ref="no-network"/>
<secondary-label ref="since-2-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>See where every configuration value comes from, validate the configuration and its files, lint it for risky settings, start, migrate and compare configurations, and get completion in the editor.</link-summary>

<card-summary>config show --explain, validate, lint, init, migrate, diff and a JSON Schema for completion and validation in the editor.</card-summary>

<tldr>
<p><b>Where does a value come from?</b> <code>dart run %package% config show --explain</code></p>
<p><b>Is the configuration complete?</b> <code>dart run %package% config validate</code></p>
<p><b>Is it risky?</b> <code>dart run %package% config lint</code></p>
<p><b>New project?</b> <code>dart run %package% config init</code></p>
<p><b>What does this change weaken?</b> <code>dart run %package% config diff git:main --fail-on-weaker</code></p>
<p><b>Editor</b>: <code># yaml-language-server: $schema=…/inspectra.schema.json</code> in <code>%config_file%</code></p>
</tldr>

The effective configuration of a package is layered: the built-in defaults, the configuration file, `INSPECTRA_*`
environment variables set by a CI system or a developer's shell, and the command line. In a large organisation the
question "which value applies here, and who set it?" is asked often and answered slowly. The `config` commands answer
it, and catch the mistakes that the strict validation cannot see: a misspelled environment variable, a file the
configuration names but that does not exist, a setting that silently weakens a gate.

## config show {id="show"}

```bash
dart run %package% config show --explain
```

Prints the effective configuration as YAML, with the same keys as `%config_file%`. Options without a value are
commented out. With `--explain`, every value says where it comes from:

```yaml
# The effective Inspectra configuration: inspectra.yaml and its overrides.
lint:
  enabled: true                      # inspectra.yaml:3
  fail_on: warning                   # inspectra.yaml:4
trivy:
  mode: required                     # environment variable INSPECTRA_TRIVY_MODE
  version: latest                    # command line
  timeout: 10m                       # default
  # executable:                      # unset
```

`config show` reads the configuration exactly like the other commands: `--config`, `--set` and the Trivy flags apply,
so `config show --set trivy.version=latest` shows what `scan --set trivy.version=latest` would use. `--only-changed`
leaves out every value that is the default - the shortest description of what a package configures. With `-f json`,
`values` holds one object per option with `key`, `value`, `default`, `origin` (`default`, `file`, `environment` or
`commandLine`) and, where known, `variable` and `line`.

## config validate {id="validate"}

```bash
dart run %package% config validate
```

Loads the configuration - an unknown key or a wrong type fails with exit code `65`, naming the key and the closest
valid option - and checks that every file it refers to exists: `style.license_header`, `style.custom_rules`,
`trivy.secret.config`, `network.ca_certificates` and, with `changelog.enabled`, `changelog.file`. A baseline file must
be well-formed, and every [profile](Configuration-Inheritance.md#profiles) the configuration or its bases define must
be valid on its own, not only the selected one. All problems are listed at once:

```text
error: The configuration has 2 problem(s):
  style.license_header: the file tool/header.txt does not exist.
  network.ca_certificates: the file certs/corp-ca.pem does not exist.
```

Run it in a pre-commit hook or as the first CI step: it is fast, needs no network and fails before any scan starts.

## config lint {id="lint"}

```bash
dart run %package% config lint
dart run %package% config lint -f sarif -o config.sarif
```

Reports settings that are valid but risky, as findings of the source `config` located at their line in the
configuration file. The shared options apply: `--fail-on`, `-f json|sarif|markdown`, and documented exceptions in
`ignore` like for any finding.

| Rule | Severity | Reported when |
|:--|:--|:--|
| `CONFIG_INSECURE_URL` | high | `network.osv_url`, `network.pub_hosted_url`, `trivy.download_base_url` or `trivy.latest_release_url` uses `http://` |
| `CONFIG_UNKNOWN_VARIABLE` | medium | An `INSPECTRA_*` environment variable names no option and is ignored; the closest option is suggested |
| `CONFIG_TRIVY_DISABLED` | medium | `trivy.mode: disabled` |
| `CONFIG_UNPINNED_TRIVY` | medium | `trivy.version: latest` makes runs of the same commit use different Trivy releases |
| `CONFIG_IGNORE_EXPIRED` | medium | An ignore rule expired and no longer suppresses anything |
| `CONFIG_IGNORE_WITHOUT_EXPIRY` | low | An ignore rule has no `expires` date |
| `CONFIG_GATE_NOT_FAILING` | low | An enabled check has `fail_on_findings: false`, or `lint.fail_on: none` |
| `CONFIG_MIN_SEVERITY` | low | `min_severity` hides findings from every report |
| `CONFIG_DEPRECATED_OPTION` | low | The file uses the old name of a renamed option |
| `CONFIG_NO_COVERAGE_THRESHOLD` | low | `coverage.enabled` without `min_line_coverage` |
| `CONFIG_BASELINE_UNBOUNDED` | low | A [baseline](Baseline.md) file exists and `baseline.max_severity` is unset |
| `CONFIG_PUBSPEC_SECTION_IGNORED` | medium | `pubspec.yaml` has an `inspectra:` section, but a configuration file replaces it, with its `extends` and `policy` |

The environment variables `INSPECTRA_CONFIG`, `INSPECTRA_TRIVY`, `INSPECTRA_DEBUG` and `INSPECTRA_CACHE_DIR` are read
by %product% itself and never reported. A misspelled variable is the most common configuration mistake in CI, because
nothing fails - the option just keeps its default:

```text
[MEDIUM]   The environment variable INSPECTRA_TRIVY_VERSON names no option and is ignored  (CONFIG_UNKNOWN_VARIABLE)
    Inspectra reads INSPECTRA_ followed by the upper case option path, such as INSPECTRA_TRIVY_VERSION for trivy.version. Did you mean "INSPECTRA_TRIVY_VERSION"?
```

## config fetch {id="fetch"}

```bash
dart run %package% config fetch
```

Downloads the remote bases that the configuration [extends](Configuration-Inheritance.md), verifies them against their
SHA-256 and caches them, so that later runs, `build_runner` and machines without network access can use them. Every
command does this before reading the configuration; `config fetch` only lists the bases afterwards:

```text
✓ package:acme_policy/inspectra.yaml (package, available)
✓ https://policy.acme.corp/flutter/v3.yaml (remote, downloaded)
2 base(s) ready, 1 downloaded.
```

`config show --explain` comments values from a base with that base and its line, such as
`# package:acme_policy/inspectra.yaml:4`, and `config show -f json` adds `layers` and a `file` per value.

## config init {id="init"}

```bash
dart run %package% config init
dart run %package% config init --preset enterprise --stdout
```

Writes a starting `%config_file%` for the kind of package, detected from `pubspec.yaml` unless `--preset` names it:

| Preset | Detected when | What it enables |
|:--|:--|:--|
| `app` | `publish_to: none` | format, lint (`fail_on: warning`), style, coverage from 70 %, Trivy, a dependency policy with upper bounds, `require_publish_to` and a lockfile in sync |
| `library` | The package can be published | The `app` checks with `lint.fail_on: info`, coverage from 80 %, the API dump with `semver`, the changelog and `required_metadata` instead of `require_publish_to` |
| `plugin` | `flutter: plugin:` in `pubspec.yaml` | The `library` checks with the Flutter test runner |
| `enterprise` | Never; name it | The `app` or `library` checks with `trivy.mode: required`, `fail_on: medium`, checksums and imports checked, a baseline that never covers HIGH or CRITICAL, and `local` and `ci` [profiles](Configuration-Inheritance.md#profiles) |

A Flutter package gets `coverage.runner: flutter`. The file starts with the schema modeline, so the editor completes the
rest. `config init` refuses to replace an existing `%config_file%` without `--force` (exit code `64`), prints the file
instead with `--stdout`, and warns when `pubspec.yaml` has an `%pubspec_key%:` section that the new file replaces. It
reads no configuration, so it works in a project whose configuration is broken.

## config migrate {id="migrate"}

```bash
dart run %package% config migrate --dry-run
dart run %package% config migrate
```

When an option is renamed, the old name keeps working until the next major version, with a warning and the finding
`CONFIG_DEPRECATED_OPTION`. `config migrate` replaces the old names in the project's configuration file - `%config_file%`,
the file named by `--config` or `INSPECTRA_CONFIG`, or the `%pubspec_key%:` section of `pubspec.yaml` - and in each of
its profiles. Only the keys change; values, comments and order stay. `--dry-run` lists the renames without writing,
`-f json` writes `file`, `dryRun` and `renamed` with `from`, `to` and `line`. Bases are migrated by their owners.

Exit code `0`, also when nothing needs to change; `65` when the file is malformed or names an option twice, under the
old and the new name; `69` when the file cannot be written.

## config diff {id="diff"}

```bash
dart run %package% config diff git:main
dart run %package% config diff git:v1.4.0 git:main
dart run %package% config diff ci/strict.yaml inspectra.yaml --fail-on-weaker
```

Compares two configurations option by option and lists every option whose value differs. A configuration is a file -
`%config_file%`, any other file of the same format, or `pubspec.yaml` for its section - or `git:<revision>`, the
project's configuration file at that revision. Without a second one, `config diff` compares with the effective
configuration. Both are read with the same profile, environment variables and command line, so only the files differ;
bases are always the current ones.

```text
inspectra.yaml at main → the effective configuration:
  fail_on: "high" → "low"
  trivy.mode: "required" → "auto" (weaker)
2 option(s) differ, 1 weaker.
```

A change is **weaker** when the option has an order from weak to strict - the same order as a policy's
[`minimum`](Configuration-Inheritance.md#policy) - and the new value checks less. With `--fail-on-weaker` the command
exits with `1` when any option got weaker, which makes it a gate for pull requests that touch the configuration or a
policy update. References to environment variables are compared as written. `-f json` writes `from`, `to` and
`changes` with `key`, `from`, `to` and `weaker`.

## Editor support with the JSON Schema {id="schema"}

```bash
dart run %package% config schema -o inspectra.schema.json
```

`config schema` prints the JSON Schema (draft-07) of `%config_file%`. It is generated from the options the
configuration actually reads, with their types, allowed values, ranges and defaults, so it never drifts from the
code; it also works while the project's configuration is broken. The schema of each release is published in the
repository, so a modeline at the top of `%config_file%` is enough for VS Code with the YAML extension, IntelliJ IDEA
and every other editor that uses the YAML language server:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/davils-com/Inspectra/main/inspectra.schema.json
trivy:
  enabled: true
```

The editor then completes keys, shows defaults, and underlines unknown keys and invalid values as you type. For a
schema that matches the installed version exactly, generate it into the repository and point the modeline at the
file. The `inspectra:` section of `pubspec.yaml` is not covered, because a schema applies to a whole file.

<seealso>
    <category ref="config">
        <a href="Configuration-Overview.md">Where the configuration lives</a>
        <a href="Configuration-Reference.md">Configuration reference</a>
        <a href="Baseline.md">Baseline</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#config-show">config show, validate, lint, schema, init, migrate and diff</a>
    </category>
    <category ref="external">
        <a href="https://json-schema.org/">JSON Schema</a>
        <a href="https://github.com/redhat-developer/yaml-language-server">YAML language server</a>
    </category>
</seealso>
