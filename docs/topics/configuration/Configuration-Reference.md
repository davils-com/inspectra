# Configuration reference

<primary-label ref="config"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every option of the Inspectra configuration, with its type, default and effect.</link-summary>

<card-summary>The complete list of options, section by section, with defaults.</card-summary>

Keys are shown as they appear under `%pubspec_key%:` in `pubspec.yaml`, or at the top level of `%config_file%`. Paths
and globs are relative to the package root and use `/` on every platform. Durations are written as `500ms`, `30s`,
`10m` or `1h`.

Every key except `ignore` can also be set with `--set <path>=<value>` or an `INSPECTRA_<PATH>` environment variable,
for example `--set trivy.version=latest` or `INSPECTRA_NETWORK_PROXY`. See
[Overriding options](Configuration-Overview.md#overrides).

## Complete example with defaults {collapsible="true" default-state="expanded"}

Every option with its default value. Nothing here needs to be written out; the block shows what an empty
configuration means.

```yaml
inspectra:
  # fail_on: high                  # unset: the command's own default
  min_severity: unknown

  ignore: []                       # entries: id, package, reason, expires

  baseline:
    enabled: true
    file: inspectra-baseline.json
    # max_severity: high             # unset: the baseline covers every severity
    fail_on_stale: false

  dependency_policy:
    enabled: false
    denied: []                       # entries: name, reason, replacement
    allowed: []
    allowed_hosts: []
    allowed_git_hosts: []
    require_upper_bound: false
    # min_sdk: 3.6.0
    # min_flutter: 3.27.0
    dev_only: []
    require_publish_to: false
    published_packages: []
    required_metadata: []
    lockfile_in_sync: false
    lockfile_checksums: false
    check_imports: false
    unused_allow: [cupertino_icons]

  network:
    offline: false
    timeout: 30s
    max_attempts: 3
    retry_base_delay: 1s
    concurrency: 8
    # proxy: http://proxy.corp:3128   # unset: HTTPS_PROXY / HTTP_PROXY / NO_PROXY
    # ca_certificates: certs/corp-ca.pem
    osv_url: https://api.osv.dev
    # pub_hosted_url: https://pub.dev # unset: PUB_HOSTED_URL, else https://pub.dev

  inspect:
    fail_score: 30
    max_archive_bytes: 67108864
    max_extracted_bytes: 268435456
    max_entries: 20000
    entropy_excludes: [.g.dart, .freezed.dart, .mocks.dart, .specia.dart, .pb.dart, .gr.dart]
    exclude_directories: [test, integration_test, example, benchmark, doc, docs, tool, extension]
    trusted_hosts: []

  trust:
    fresh_package_days: 7
    young_package_days: 30
    fresh_release_hours: 24
    min_likes: 5
    min_downloads: 100
    min_points_ratio: 0.5

  typosquat:
    allow: []
    popular: []

  format:
    enabled: false
    run_on_build: false
    fail_on_findings: true
    include: ['**.dart']
    exclude: ['**/.dart_tool/**', '**/build/**', '**.g.dart', '**.freezed.dart', '**.mocks.dart', '**.specia.dart']
    # page_width: 80               # unset: from analysis_options.yaml

  lint:
    enabled: false
    run_on_build: false
    fail_on: info                  # error, warning, info or none

  style:
    enabled: false
    run_on_build: false
    fail_on_findings: true
    preset: recommended            # none, recommended or strict
    rules: {}                      # rule id: true or false
    # license_header: …            # unset: no license_header rule
    custom_rules: []
    include: ['**.dart']
    exclude: ['**/.dart_tool/**', '**/build/**', '**.g.dart', '**.freezed.dart', '**.mocks.dart', '**.specia.dart']

  api:
    enabled: false
    output: api/<package>.api
    ignored_libraries: []
    non_public_annotations: [internal, visibleForTesting]
    semver: false

  trivy:
    enabled: false
    mode: auto                     # auto, required or disabled
    version: 0.75.0                # an exact version or latest
    use_installed: true
    download: true
    # executable: /opt/trivy/trivy # unset: installed, cached or downloaded
    # install_directory: .tools/trivy   # unset: <user cache>/inspectra/trivy
    download_base_url: https://github.com/aquasecurity/trivy/releases/download
    latest_release_url: https://github.com/aquasecurity/trivy/releases/latest
    report_directory: .dart_tool/inspectra/trivy
    skip_db_update: false
    # db_repository: registry.corp/aquasecurity/trivy-db
    # cache_directory: .cache/trivy
    timeout: 10m
    connectivity_timeout: 3s
    extra_args: []

    secret:
      enabled: true
      run_on_build: true
      fail_on_findings: true
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      # config: trivy-secret.yaml  # unset: trivy-secret.yaml when it exists
      include: ['**.dart', '**.yaml', '**.yml', '**.json', '**.env', '**.properties']
      exclude: ['**/.dart_tool/**', '**/build/**', '**/.git/**']

    license:
      enabled: true
      run_on_build: false
      fail_on_findings: true
      severity: [CRITICAL, HIGH, UNKNOWN]
      ignored_licenses: []
      ignored_packages: []
      include_dev_dependencies: false

    vulnerability:
      enabled: true
      run_on_build: false
      fail_on_findings: true
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      include_dev_dependencies: true
      ignore_unfixed: false
      ignored_vulnerabilities: []

    filesystem:
      enabled: false
      fail_on_findings: true
      severity: [CRITICAL, HIGH, MEDIUM, LOW]
      scanners: [vuln, secret, misconfig]
      skip_dirs: [.dart_tool, build, .git]

  coverage:
    enabled: false
    runner: dart
    output_directory: coverage
    report_on: [lib]
    exclude: ['**.g.dart', '**.freezed.dart', '**.mocks.dart', '**.specia.dart']
    # min_line_coverage: 80        # unset: report only, never fail
    test_arguments: []
    merge: []                      # further runs whose coverage is merged

  changelog:
    enabled: false
    file: CHANGELOG.md
    tag_prefix: v
    types: {feat: added, fix: fixed, perf: changed, refactor: changed, revert: changed,
            deprecate: deprecated, remove: removed, security: security, docs: hidden,
            style: hidden, test: hidden, build: hidden, ci: hidden, chore: hidden}
    unconventional: hidden
    # repository: …                # unset: repository of pubspec.yaml
    commit_url: '{repository}/commit/{hash}'
    compare_url: '{repository}/compare/{from}...{to}'
```

## fail_on and min_severity {id="severity-thresholds"}

Thresholds of the supply-chain commands and of the Trivy filesystem scan of `scan` and `trivy`. Severities are
`critical`, `high`, `medium`, `low` and `unknown`, case-insensitive.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `fail_on` | severity | unset | The minimum severity that makes a command exit with `1`. Unset: the command's own default - any finding for `scan`, `audit` and `trivy`, `high` for `typosquat`, `critical` for `trust`. `inspect` and `add` decide by `inspect.fail_score` instead. `--fail-on` overrides it. |
| `min_severity` | severity | `unknown` | Findings below this severity are not reported at all. `--min-severity` overrides it. |

## ignore {id="ignore"}

Documented suppressions of findings of the supply-chain commands and of the Trivy filesystem scan of `scan` and
`trivy`. The configured Trivy scans have their own `ignored_*` lists.

```yaml
inspectra:
  ignore:
    - id: GHSA-xxxx-yyyy-zzzz          # rule id, advisory id or alias (CVE)
      package: http                    # optional: only for this package
      reason: Not reachable, we never parse untrusted multipart bodies.
      expires: 2027-01-31              # optional: revisit after this day
```

| Key | Type | Required | Description |
|:--|:--|:--|:--|
| `id` | string | yes | The rule id, advisory id or alias to suppress, such as `GHSA-…`, `CVE-…` or `HARDCODED_URL`. |
| `reason` | string | yes | Why the finding is acceptable. An entry without it is an error, so every suppression is auditable. |
| `package` | string | no | Restricts the entry to findings of this package. |
| `expires` | date, `YYYY-MM-DD` | no | The last day on which the entry applies. Afterwards it stops matching and every run warns about it. |

`ignore` can only be written in the file. `--ignore <ID>` suppresses an id for one run, without a reason.

## baseline {id="baseline"}

The file of accepted findings that `baseline create` records and `scan`, `audit`, `typosquat`, `trivy`, `lint`,
`style`, `check` and the builders do not report. Details: [Baseline](Baseline.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | bool | `true` | Apply the baseline file when it exists. `--set baseline.enabled=false` shows every finding. |
| `file` | string | `inspectra-baseline.json` | The baseline file, relative to the package root. |
| `max_severity` | severity | unset | Findings more severe than this are never covered by the baseline. |
| `fail_on_stale` | bool | `false` | Fail a check while recorded findings have been fixed and `baseline prune` has not run. |

## dependency_policy {id="dependency_policy"}

Rules for the dependencies of every package, checked by `deps`, `scan` and `check` once `enabled` is set; `deps --fix`
applies the fixable ones. Every rule is off until configured. Details: [Dependency policy](Dependency-Policy.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | bool | `false` | Apply the policy. |
| `denied` | list of entries | `[]` | `name` and `reason` (required) and `replacement` of a forbidden package, direct or transitive. |
| `allowed` | list of strings | `[]` | When not empty, the only hosted packages that may be declared. |
| `allowed_hosts` | list of strings | `[]` | When not empty, the only package registries, such as `https://pub.dev`. |
| `allowed_git_hosts` | list of strings | `[]` | When not empty, the only Git hosts. |
| `require_upper_bound` | bool | `false` | Every hosted constraint needs an upper bound. |
| `min_sdk` | version | unset | The lowest Dart SDK `environment.sdk` may allow. |
| `min_flutter` | version | unset | The lowest Flutter SDK `environment.flutter` may allow. |
| `dev_only` | list of strings | `[]` | Packages that belong in `dev_dependencies`. |
| `require_publish_to` | bool | `false` | Every package needs `publish_to`, except `published_packages`. |
| `published_packages` | list of strings | `[]` | Packages meant for pub.dev. |
| `required_metadata` | list | `[]` | Of `description`, `repository`, `homepage`, `issue_tracker`, `documentation`, `topics`: required in publishable packages. |
| `lockfile_in_sync` | bool | `false` | `pubspec.lock` must match the direct dependencies. |
| `lockfile_checksums` | bool | `false` | Every hosted package of `pubspec.lock` needs a `sha256`. |
| `check_imports` | bool | `false` | Report unused dependencies and development dependencies imported by `lib/` or `bin/`. |
| `unused_allow` | list of strings | `[cupertino_icons]` | Packages never reported as unused. |
| `constraint_style` | `any`, `caret`, `range`, `pinned` | `any` | How hosted constraints are written. |
| `overrides.require_reason` | bool | `false` | Every dependency override needs an entry in `overrides.allowed`. |
| `overrides.allowed` | list of entries | `[]` | `name` and `reason` (required) and `expires` of a justified override. |
| `lockfile_policy` | `any`, `committed`, `ignored`, `auto` | `any` | Whether `pubspec.lock` must be committed; `auto`: applications yes, publishable packages no. |
| `max_major_behind` | whole number | unset | The most breaking releases a direct dependency may be behind; needs the registry. |
| `max_libyear` | number | unset | The most libyears the dependencies may add up to; needs the registry. |
| `libyear_scope` | `direct`, `all` | `direct` | Which packages count towards `max_libyear`. |

## workspace_policy {id="workspace_policy"}

Rules for the packages of a pub workspace, at its root, checked by `deps -r`, `check` and `report` once `enabled` is
set. Details: [Workspace policy](Workspace-Policy.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | bool | `false` | Apply the policy. |
| `align_versions` | `off`, `compatible`, `exact` | `compatible` | How alike the constraints of an external package must be. |
| `require_membership` | bool | `true` | Listed entries exist, members use `resolution: workspace`, no package is left out. |
| `same_sdk` | bool | `false` | Every package has the root's `environment.sdk`. |
| `forbid_cycles` | bool | `true` | Report dependency cycles between the packages. |
| `include_dev_dependencies` | bool | `false` | `dev_dependencies` count for cycles and layers. |
| `layers` | list of entries | `[]` | `name` and `packages` (required), `may_depend_on`, `isolated`, `forbidden_dependencies`. |

## hook {id="hook"}

The checks of the pre-commit hook, which `inspectra hook run` applies to the staged files.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `checks` | list | `[audit, typosquat]` | Of `audit`, `typosquat`, `deps`, `format`, `style`. |

## network {id="network"}

Settings for every connection %product% opens: OSV.dev, the pub repository and Trivy downloads.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `offline` | boolean | `false` | Never open a connection. Commands that need the network exit with `69`; optional steps such as downloading Trivy are skipped, and Trivy runs with `--skip-db-update --offline-scan`. `--offline` sets it. |
| `timeout` | duration | `30s` | The timeout for connecting and for each response. |
| `max_attempts` | whole number, 1 to 100 | `3` | How often a request is attempted before giving up. |
| `retry_base_delay` | duration | `1s` | The first back-off delay; it doubles with every retry. |
| `concurrency` | whole number, 1 to 256 | `8` | The maximum number of concurrent requests to one service. |
| `proxy` | string | unset | An explicit proxy such as `http://proxy.corp:3128`. Unset: `HTTPS_PROXY`, `HTTP_PROXY` and `NO_PROXY` apply. |
| `ca_certificates` | string | unset | A PEM file with additional trusted certificate authorities, for proxies that intercept TLS. |
| `osv_url` | string | `https://api.osv.dev` | An OSV.dev compatible API, for example an internal mirror. |
| `pub_hosted_url` | string | `PUB_HOSTED_URL`, else `https://pub.dev` | The pub repository. |

## inspect {id="inspect"}

The source inspection of `inspect` and `add`.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `fail_score` | whole number, 1 to 100 | `30` | The risk score from which `inspect` exits with `1` and `add` refuses to install. |
| `max_archive_bytes` | whole number | `67108864` (64 MiB) | The largest package archive that is downloaded. |
| `max_extracted_bytes` | whole number | `268435456` (256 MiB) | The largest total size of all archive entries, which stops decompression bombs. |
| `max_entries` | whole number | `20000` | The largest number of archive entries. |
| `entropy_excludes` | list of strings | `[.g.dart, .freezed.dart, .mocks.dart, .specia.dart, .pb.dart, .gr.dart]` | File name suffixes of generated code that the entropy scanner skips. |
| `exclude_directories` | list of strings | `[test, integration_test, example, benchmark, doc, docs, tool, extension]` | Top level directories skipped by the code pattern and entropy scanners. Unicode and archive checks still cover every file. |
| `trusted_hosts` | list of strings | `[]` | Host names the hard-coded URL rule never reports, on top of the built-in Dart, Flutter and GitHub hosts. |

## trust {id="trust"}

Thresholds of the pub.dev trust assessment of `trust`, `inspect` and `add`.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `fresh_package_days` | whole number | `7` | A package first published less than this many days ago is `CRITICAL`. |
| `young_package_days` | whole number | `30` | A package first published less than this many days ago is `MEDIUM`. |
| `fresh_release_hours` | whole number | `24` | A version published less than this many hours ago is `CRITICAL`. |
| `min_likes` | whole number | `5` | Fewer likes are reported as low endorsement. |
| `min_downloads` | whole number | `100` | Fewer downloads in 30 days are reported as low usage. |
| `min_points_ratio` | number, 0 to 1 | `0.5` | A lower ratio of pub points is reported as low quality. |

## typosquat {id="typosquat"}

The typosquatting detector of `typosquat`, `scan`, `add` and the pre-commit hook.

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `allow` | list of strings | `[]` | Package names that are never reported, for example internal packages that resemble popular ones. |
| `popular` | list of strings | `[]` | Additional names to protect, for example your most used internal packages. |

## format {id="format"}

The format check. See [Format check](Format-Check.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether `check` runs the format check. `dart run %package% format` runs it regardless. |
| `run_on_build` | boolean | `false` | Whether the `inspectra:format` builder checks on `build_runner build`. |
| `fail_on_findings` | boolean | `true` | Whether an unformatted file fails the build or the command. |
| `include` | list of globs | `['**.dart']` | The files that are checked. |
| `exclude` | list of globs | `['**/.dart_tool/**', '**/build/**', '**.g.dart', '**.freezed.dart', '**.mocks.dart', '**.specia.dart']` | Files never checked. Replaces the default when set. |
| `page_width` | whole number, 1 to 1000 | unset | The line length passed to `dart format`. Unset: `formatter: page_width` of `analysis_options.yaml`, else 80. |

## lint {id="lint"}

The lint check. See [Lint check](Lint-Check.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether `check` runs the lint check. `dart run %package% lint` runs it regardless. |
| `run_on_build` | boolean | `false` | Whether the `inspectra:lint` builder analyzes on `build_runner build`. |
| `fail_on` | `error`, `warning`, `info` or `none` | `info` | The lowest <tooltip term="diagnostic">diagnostic</tooltip> severity that fails the check. |

The rules themselves live in `analysis_options.yaml`; see [Lint preset](Lint-Preset.md).

## style {id="style"}

The style check. See [Style check](Style-Check.md) and [Custom style rules](Style-Custom-Rules.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether `check` runs the style check. `dart run %package% style` runs it regardless. |
| `run_on_build` | boolean | `false` | Whether the `inspectra:style` builder checks on `build_runner build`. |
| `fail_on_findings` | boolean | `true` | Whether a violation fails the build or the command. |
| `preset` | `none`, `recommended` or `strict` | `recommended` | The built-in rules that run. |
| `rules` | map of rule id to boolean | `{}` | Built-in and custom rules switched on or off; wins over `preset`. An unknown id is an error. |
| `license_header` | string | unset | The header template every file must start with; `{year}` matches any year. Unset: the `license_header` rule does not run. |
| `custom_rules` | list of strings | `[]` | Dart files that declare custom rules in a top level `styleRules`. |
| `include` | list of globs | `['**.dart']` | The files that are checked. |
| `exclude` | list of globs | as for `format` | Files never checked. Replaces the default when set. |

## api {id="api"}

Public API validation. See [Public API validation](API-Overview.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether the API builder writes the dump and `api check` / `check` verify it. |
| `output` | string | `api/<package>.api` | The dump file. `<package>` is the `name` from `pubspec.yaml`. Changing it requires restarting `build_runner`, which reads it when the build starts. |
| `ignored_libraries` | list of globs | `[]` | Public libraries left out of the dump, for example `[lib/testing.dart]`. Matched against the path relative to the package root. |
| `non_public_annotations` | list of strings | `[internal, visibleForTesting]` | Annotations that keep a declaration out of the dump. Either the name of a constant (`internal`) or of the annotation class (`Internal`). |
| `semver` | boolean | `false` | Whether `check` and `report` compare the API with the dump at the last release tag and check the version in `pubspec.yaml`. See [Semantic versioning](API-Semver.md). |

Details: [API configuration](API-Configuration.md).

## trivy {id="trivy"}

The configured scans, and how Trivy is provisioned for every command that runs it. See
[Security and compliance](Trivy-Overview.md) and [Installing Trivy](Trivy-Installation.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether the configured scans run in `check`, `trivy` and the builders. The scans' own `enabled` switches apply on top of it. `scan` runs Trivy regardless. |
| `mode` | `auto`, `required` or `disabled` | `auto` | `auto`: an unavailable Trivy is skipped with a warning. `required`: it is an error, exit code `69`. `disabled`: Trivy is never located, downloaded or run. |
| `version` | string | `0.75.0` | The Trivy version to download, or `latest`. The default is pinned per %product% release. |
| `use_installed` | boolean | `true` | Use an installed Trivy whatever its version. `false` accepts only exactly `version`. |
| `download` | boolean | `true` | Allow downloading Trivy when it is not installed; only when online. |
| `executable` | string | unset | The Trivy executable: a name on the `PATH` or a path relative to the package root. Disables every other lookup. The environment variable `%trivy_env%` overrides it. |
| `install_directory` | string | `<user cache>/inspectra/trivy` | Where downloaded Trivy binaries are stored, one directory per version. |
| `download_base_url` | string | `https://github.com/aquasecurity/trivy/releases/download` | The release assets, or a mirror providing them under `<base>/v<version>/`. |
| `latest_release_url` | string | `https://github.com/aquasecurity/trivy/releases/latest` | The redirect that resolves `version: latest`. |
| `report_directory` | string | `%report_dir%` | Where the command line writes the JSON report of each scan. The builders write theirs to the artifact tree instead. |
| `skip_db_update` | boolean | `false` | Pass `--skip-db-update`, for a pre-seeded `cache_directory`. |
| `db_repository` | string | unset | Pass `--db-repository`, an OCI mirror of the Trivy database. |
| `cache_directory` | string | unset | Pass `--cache-dir`. |
| `timeout` | duration | `10m` | The maximum run time of one Trivy scan. |
| `connectivity_timeout` | duration | `3s` | How long the download host may take to answer before Trivy is not downloaded. |
| `extra_args` | list of strings | `[]` | Arguments appended verbatim to the Trivy command line. |
| `secret` | mapping | | [Secret scan](#trivy-secret) |
| `license` | mapping | | [License scan](#trivy-license) |
| `vulnerability` | mapping | | [Vulnerability scan](#trivy-vulnerability) |
| `filesystem` | mapping | | [Filesystem scan](#trivy-filesystem) |

`skip_db_update`, `db_repository`, `cache_directory`, `timeout` and `extra_args` apply to the Trivy filesystem scan of
`scan` and of `trivy` without configured scans.

### Shared scan options {id="scan-options"}

Each scan has these options; the defaults differ per scan and are listed in its table.

| Key | Type | Description |
|:--|:--|:--|
| `enabled` | boolean | Whether this scan runs when `trivy.enabled` is `true`. Naming a scan on the command line runs it regardless. |
| `run_on_build` | boolean | Whether the scan's builder runs it on `dart run build_runner build`. Not available for the filesystem scan. |
| `fail_on_findings` | boolean | Whether findings fail the build or the command. When `false`, findings are logged as a warning and listed as *(not failing)*. |
| `severity` | list of severities | The severities that are reported; findings of any other severity are dropped. One or more of `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `UNKNOWN`, case-insensitive; an empty list is an error. |

### trivy.secret {id="trivy-secret"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `true` | |
| `run_on_build` | boolean | `true` | |
| `fail_on_findings` | boolean | `true` | |
| `severity` | list | `[CRITICAL, HIGH, MEDIUM, LOW]` | |
| `config` | string | unset | The Trivy secret configuration. Unset: `%secret_config%` when it exists, otherwise Trivy's built-in rules only. A file named here must exist. |
| `include` | list of globs | `['**.dart', '**.yaml', '**.yml', '**.json', '**.env', '**.properties']` | The files that are scanned. Replaces the default when set. |
| `exclude` | list of globs | `['**/.dart_tool/**', '**/build/**', '**/.git/**']` | The files that are never scanned, even when included. Replaces the default when set. |

Details: [Secret scan](Trivy-Secret-Scan.md), [Secret rules](Trivy-Secret-Rules.md).

### trivy.license {id="trivy-license"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `true` | |
| `run_on_build` | boolean | `false` | |
| `fail_on_findings` | boolean | `true` | |
| `severity` | list | `[CRITICAL, HIGH, UNKNOWN]` | Forbidden, restricted and unclassifiable licenses. See [License severities](Trivy-Severities.md#licenses). |
| `ignored_licenses` | list of strings | `[]` | <tooltip term="SPDX identifier">SPDX identifiers</tooltip> that are never reported, case-insensitive. |
| `ignored_packages` | list of strings | `[]` | Package names whose license is never checked. |
| `include_dev_dependencies` | boolean | `false` | Whether packages reachable only through `dev_dependencies` are checked. |

Details: [License scan](Trivy-License-Scan.md).

### trivy.vulnerability {id="trivy-vulnerability"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `true` | |
| `run_on_build` | boolean | `false` | |
| `fail_on_findings` | boolean | `true` | |
| `severity` | list | `[CRITICAL, HIGH, MEDIUM, LOW]` | |
| `include_dev_dependencies` | boolean | `true` | Whether packages reachable only through `dev_dependencies` are checked. When `false`, `pubspec.lock` is narrowed to shipped dependencies first. |
| `ignore_unfixed` | boolean | `false` | Whether vulnerabilities without a released fix are left out (Trivy's `--ignore-unfixed`). |
| `ignored_vulnerabilities` | list of strings | `[]` | <tooltip term="CVE">CVE</tooltip> or <tooltip term="GHSA">GHSA</tooltip> identifiers that are never reported, case-insensitive. A vulnerability is ignored when any of its identifiers is listed. |

Details: [Vulnerability scan](Trivy-Vulnerability-Scan.md).

### trivy.filesystem {id="trivy-filesystem"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Off by default even with `trivy.enabled`, because it overlaps with the other scans. |
| `fail_on_findings` | boolean | `true` | |
| `severity` | list | `[CRITICAL, HIGH, MEDIUM, LOW]` | |
| `scanners` | list | `[vuln, secret, misconfig]` | The Trivy scanners to run: one or more of `vuln`, `secret`, `misconfig`, `license`. |
| `skip_dirs` | list of strings | `[.dart_tool, build, .git]` | Directories Trivy skips, passed as `--skip-dirs`. Replaces the default when set. |

There is no `run_on_build`: the filesystem scan has no builder. `scanners`, `severity` and `skip_dirs` also configure the
Trivy part of `scan`, and of `trivy` without configured scans. Details: [Filesystem scan](Trivy-Filesystem-Scan.md).

## coverage {id="coverage"}

The coverage gate. See [Coverage](Coverage-Overview.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether `check` runs the gate. `dart run %package% coverage` runs it regardless. |
| `runner` | `dart` or `flutter` | `dart` | Which test runner collects the coverage. |
| `output_directory` | string | `coverage` | Where `lcov.info` and the raw hit maps are written. |
| `report_on` | list of directories | `[lib]` | The directories whose files are reported. |
| `exclude` | list of globs | `['**.g.dart', '**.freezed.dart', '**.mocks.dart', '**.specia.dart']` | Files left out of the report. Replaces the default when set. |
| `min_line_coverage` | number, 0 to 100 | unset | The line coverage in percent below which the gate fails. Unset: report only. `--min` overrides it. |
| `test_arguments` | list of strings | `[]` | Extra arguments for the test runner, such as `[--exclude-tags, slow]`. |
| `merge` | list of runs | `[]` | Further test runs, each with a `name` and its `test_arguments`, whose coverage is merged into the report, such as a preset or a browser. Every layer adds its runs. |

Details: [Coverage configuration](Coverage-Configuration.md).

## changelog {id="changelog"}

Changelog generation and validation. See [Changelog](Changelog-Overview.md).

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | boolean | `false` | Whether `check` runs the changelog check. `changelog check`, `generate` and `notes` run regardless. |
| `file` | string | `CHANGELOG.md` | The changelog file. |
| `tag_prefix` | string | `v` | The text before the version in release tags; `''` for tags without prefix. |
| `types` | map of type to section | `feat: added`, `fix: fixed`, … | The section of each Conventional Commits type: `added`, `changed`, `deprecated`, `removed`, `fixed`, `security` or `hidden`. Listed types replace their defaults; other types are hidden. |
| `unconventional` | section | `hidden` | The section of commits that do not follow Conventional Commits. |
| `repository` | URL | `repository` of `pubspec.yaml` | The `https://` repository URL that commit and comparison links point to. |
| `commit_url` | string | `{repository}/commit/{hash}` | The link of each entry; must contain `{hash}`. |
| `compare_url` | string | `{repository}/compare/{from}...{to}` | The comparison link of a release; must contain `{to}`. |

Details: [Changelog configuration](Changelog-Configuration.md).

## extends, profiles and policy {id="extends"}

`extends` names the configurations this one builds on, `profiles` holds named partial configurations that `--profile`
applies, and `policy` locks options, sets minimum values and forbids ignoring severities for the files that build on it.
See [Inheritance and central policies](Configuration-Inheritance.md).

```yaml
extends:
  - package:acme_policy/inspectra.yaml
  - url: https://policy.acme.corp/inspectra.yaml
    sha256: 9f2c6e0d…
profiles:
  ci:
    fail_on: low
policy:
  locked: [trivy.secret.enabled]
  minimum:
    coverage.min_line_coverage: 70
  forbid_ignore_of: [critical]
```

## Lists replace, unless the key ends with +

Every list option replaces its default when you set it. To add to the default, or to the list of the bases, write the
key with a `+`:

```yaml
inspectra:
  trivy:
    secret:
      include+: ['**.ini']             # the default globs plus **.ini
```

The mappings with user defined keys, `changelog.types` and `style.rules`, are the exception: the keys you list
replace their own defaults, and every other default stays. Between a project and the bases it extends, `ignore` and
`dependency_policy.denied` collect the entries of every file.

<seealso>
    <category ref="config">
        <a href="Configuration-Overview.md">Where the configuration lives</a>
        <a href="Build-Sources.md">Build sources</a>
    </category>
    <category ref="security">
        <a href="Trivy-Configuration-Reference.md">Trivy configuration reference</a>
    </category>
    <category ref="reference">
        <a href="Library-API.md">Library API</a>
    </category>
</seealso>
