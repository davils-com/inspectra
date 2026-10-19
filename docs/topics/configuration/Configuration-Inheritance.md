# Inheritance and central policies

<primary-label ref="config"/>
<secondary-label ref="since-2-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Share one configuration across many repositories with extends, and enforce organisation rules with policy: locked options and minimum values that no repository, environment variable or flag can weaken.</link-summary>

<card-summary>extends builds on files, packages and pinned URLs; policy locks options and sets minimums that bind every layer above.</card-summary>

<tldr>
<p><b>Inherit</b>: <code>extends: package:acme_policy/inspectra.yaml</code>, a relative path, or <code>{url: https://…, sha256: …}</code></p>
<p><b>Enforce</b>: <code>policy: { locked: [...], minimum: {...}, forbid_ignore_of: [...] }</code> in the base</p>
<p><b>Inspect</b>: <code>dart run %package% config show --explain</code> names the file of every value</p>
<p><b>Offline</b>: <code>dart run %package% config fetch</code> caches remote bases</p>
</tldr>

Large organisations copy the same `inspectra.yaml` into hundreds of repositories, and over time every copy drifts: one
repository turns the secret scan off, another lowers the coverage threshold, a third never got the new denied package.
With `extends`, a repository builds on a shared base and only writes what is different. With `policy`, the base states
what the repository must not weaken.

## Extending a base {id="extends"}

```yaml
# inspectra.yaml of a repository
extends:
  - package:acme_policy/inspectra.yaml          # a dev dependency, versioned with pub
  - ../../inspectra.base.yaml                   # a file of the monorepo
  - url: https://policy.acme.corp/flutter/v3.yaml
    sha256: 9f2c6e0d…                            # the SHA-256 of the file, 64 hex digits
coverage:
  min_line_coverage: 85
```

`extends` takes one entry or a list. Bases can extend bases of their own, and `extends` also works in the `inspectra:`
section of `pubspec.yaml` and in a file named by `--config` or `INSPECTRA_CONFIG`.

| Entry | Resolved | Use it for |
|:--|:--|:--|
| `path/to/file.yaml` | Relative to the file that names it | Monorepos and workspaces |
| `package:name/path.yaml` | Below the package's `lib/`, through `.dart_tool/package_config.json` | An organisation policy package, updated like any dependency |
| `{url: https://…, sha256: …}` | Downloaded once, verified and cached | Organisations without a package registry |

A remote base must be pinned: the download is used only when its SHA-256 matches, so a changed or compromised file is
never applied. Plain `http` is accepted for the local machine only. A remote base can extend `package:` bases and other
remote bases, but no relative paths, and is limited to 1 MiB. Bases nest at most 8 levels deep and 32 files in total;
a cycle is an error.

### Precedence {id="precedence"}

From the lowest to the highest:

1. The built-in defaults.
2. The bases: earlier entries of a list below later ones, and the bases of a base below it.
3. The project's own configuration.
4. The selected [profile](#profiles), as the bases and the project define it.
5. `INSPECTRA_*` environment variables.
6. The command line.

Mappings merge key by key, so a base can set `coverage.enabled` and the project `coverage.min_line_coverage`. A scalar or
a list of a higher layer replaces the lower one; `key: ~` resets a base's value to the default. Two lists collect the
entries of every layer instead, the bases' first: `ignore` and `dependency_policy.denied` - an organisation's denied
packages stay denied, and a repository adds its own.

To add to a list of the lower layers instead of replacing it, write the key with a `+`:

```yaml
extends: package:acme_policy/inspectra.yaml
dependency_policy:
  dev_only+: [golden_toolkit]          # the policy's dev_only plus golden_toolkit
coverage:
  exclude+: ['lib/src/l10n/**']        # the default exclusions plus the l10n files
```

`key+` appends to what the layers below produced, or to the default when no layer sets the list; a later `key` replaces
everything again. A file may not set both `key` and `key+`. Every list option accepts the suffix, and the JSON Schema
knows it. A value on the command line or in an `INSPECTRA_*` variable replaces the whole list.

### Files a base ships {id="files"}

`style.license_header`, `trivy.secret.config` and `network.ca_certificates` written in a file or package base resolve
relative to that base, so a policy package can ship the license header, the secret rules and the company CA bundle.
All other paths, such as `baseline.file` or `api.output`, stay relative to the project. A remote base cannot name
files.

## Profiles {id="profiles"}

A profile is a named part of a configuration that is applied only when it is selected - fast checks on the developer's
machine, strict ones in CI, the strictest for a release:

```yaml
extends: package:acme_policy/inspectra.yaml
coverage:
  enabled: true
  min_line_coverage: 70
profiles:
  local:
    network:
      offline: true
    trivy:
      mode: disabled
  ci:
    fail_on: low
  release:
    fail_on: low
    coverage:
      min_line_coverage: 85
```

```bash
dart run %package% check --profile ci
INSPECTRA_PROFILE=release dart run %package% scan
```

`--profile <name>` or the variable `INSPECTRA_PROFILE` selects the profile. Its values sit above the project's own
configuration and below `INSPECTRA_*` variables and the command line. Bases may define profiles as well: a profile of the
same name in the bases and the project is merged like the files themselves, the project's last, so an organisation can
ship `ci` and `release` profiles that every repository refines. A profile cannot set `extends`, `policy` or `profiles`.

Policies bind profiles like any layer above them: a profile cannot unlock a locked option or go below a minimum. An
unknown profile is a configuration error that names the closest one, and `config validate` checks every profile, not only
the selected one. `config show --explain` names the profile each value comes from, and records the selected profile as
`profile`.

## Policies {id="policy"}

```yaml
# lib/inspectra.yaml of the package acme_policy
policy:
  locked:
    - trivy.secret.enabled
    - style.preset
  minimum:
    coverage.min_line_coverage: 70
    fail_on: high
    lint.fail_on: warning
    trivy.mode: auto
  forbid_ignore_of: [critical]
trivy:
  enabled: true
coverage:
  enabled: true
  min_line_coverage: 75
```

A policy binds everything above the file that declares it: the files extending it, `INSPECTRA_*` variables and the
command line, including `--set`, `--fail-on`, `--trivy-mode` and `coverage --min`. A violation is a configuration error
with exit code `65` that names the option, the value, where it comes from and the policy:

```text
error: Invalid Inspectra configuration at "coverage.min_line_coverage": 50.0 (the command line) is below the minimum 70 set by package:acme_policy/inspectra.yaml.
error: Invalid Inspectra configuration at "trivy.secret.enabled": locked to true by package:acme_policy/inspectra.yaml; got false from inspectra.yaml:4.
```

- **`locked`**: the effective value must equal the value of the declaring file with its own bases. Repeating the same
  value is allowed. `ignore` and `dependency_policy.denied` collect entries and cannot be locked.
- **`minimum`**: the effective value must be at least as strict. Tightening is always allowed; an unset value counts
  as the weakest.
- **`forbid_ignore_of`**: findings of these severities stay reported whatever ignores them - an `ignore` rule of any
  layer, an `--ignore` flag or the baseline. A finding an ignore matched carries the attribute `ignoreForbidden: true`
  in JSON and SARIF. The severities of every policy add up; names are accepted in any case.

| Option | Stricter is |
|:--|:--|
| `coverage.min_line_coverage` | A higher number |
| `fail_on`, `min_severity`, `baseline.max_severity` | A lower severity: `low` fails on more than `high` |
| `lint.fail_on` | `info`, then `warning`, `error`, `none` |
| `trivy.mode` | `required`, then `auto`, `disabled` |
| `*.enabled` (but `baseline.enabled`), `*.fail_on_findings`, `*.run_on_build`, `baseline.fail_on_stale`, `style.rules.*`, the switches of `dependency_policy` | `true` |

Options without such an order, such as `trivy.version` or `network.offline`, can only be locked. Unknown options in a
policy are errors that suggest the closest option. A policy in the project's own file binds the environment and the
command line only.

## Offline, CI and build_runner {id="offline"}

Every command downloads missing remote bases before it reads the configuration, using the `network:` settings, the
`INSPECTRA_*` variables and the flags of the project itself. `dart run %package% config fetch` does only that and lists
the bases; run it once on a connected machine, or in a CI step that caches `INSPECTRA_CACHE_DIR`, and every later run
works offline. Without a cached base, `--offline` exits with `69`.

The `build_runner` builders never download: they read file and package bases from disk and remote bases from the
cache, and fail with a hint to run `config fetch` otherwise. Editing a base does not rerun the builders.

`extends` and `policy` cannot be set with `--set` or `INSPECTRA_*` variables. `config show --explain` comments every
value with the base and line it comes from, and `config show -f json` lists the `layers`.

<seealso>
    <category ref="config">
        <a href="Configuration-Overview.md">Where the configuration lives</a>
        <a href="Configuration-Reference.md">Configuration reference</a>
        <a href="Configuration-Tools.md">Configuration tools</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#config-fetch">config fetch</a>
    </category>
</seealso>
