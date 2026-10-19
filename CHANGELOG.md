# Changelog

All notable changes to this project are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/).

## 2.1.0

### Reports and dashboards

- `inspectra report --recursive` (`-r`) reports every Dart package at or below the directory in one report: each
  directory with a `pubspec.yaml`, the roots and members of pub workspaces and nested workspaces included, without
  `.dart_tool`, `.git` and other hidden directories, `build`, `coverage`, `node_modules`, `Pods` and `ephemeral`. Each
  project runs every evaluation with its own configuration, as `-C <project> report` would; one whose configuration
  cannot be read becomes an error section and the others still run. It is the default in a directory without
  `pubspec.yaml` that has packages below it; `--no-recursive` reports the directory itself. A single package reports
  as before.
- The HTML dashboard of several projects has a sidebar of the projects, key figures across them - projects passed,
  findings, the coverage of all measured lines, the lines of code -, charts of the projects with the most findings
  and the largest projects, a table of the projects, the finding explorer of all of them and an accordion item per
  project with its evaluations. A link to a project or a nested section opens it.
- JSON: `projects`, the report of each project with its new `path`, instead of `sections`. The other formats see the
  sections of every project with the path of the project leading their id and title, and with the files of the
  findings relative to the directory. `--merge` reads such reports.
- In such a report, the codebase section of a project leaves out the projects below it, such as the members of a
  workspace, so that no line is counted twice.

### Coverage

- `coverage.merge`, further test runs whose coverage is merged into the report, each with a `name` and its
  `test_arguments`, such as the tests of a preset or the tests in a browser; every layer adds its runs. The hits of
  the VM add up; the hits of a browser, which only reports the lines that ran, count only for lines a VM run knows.
  A file only a browser loaded is listed in the new `CoverageReport.browserOnly`, and as `browserOnly` in the JSON of
  the coverage section, and is not counted. A suite a run skips as a whole, such as one whose tag is skipped, writes
  a report without hits, which is left out. The public `CoverageRun`, `CoverageHits` and `mergeCoverageHits`.

### Style check

- `no_late`, a built-in rule that reports the `late` modifier of every field, top level and local
  variable, so that no read can fail with a `LateInitializationError`. It is part of the `strict`
  preset, so a package on `strict` reports its `late` variables after the update;
  `rules: {no_late: false}` switches it off. Ported from the custom rule of Essentia.
- `no_platform_imports`, a built-in rule that reports every platform library - `dart:io`,
  `dart:ffi`, `dart:html`, `dart:js_interop` and the others - a file under `lib/` imports or exports,
  unless the file is a variant of a conditional import (`_io`, `_native`, `_web`); `dart:mirrors`
  is refused everywhere. It is part of no preset and is switched on with
  `rules: {no_platform_imports: true}`. Ported from the custom rule of Cryptia.

## 2.0.0

### Baseline

- `inspectra baseline create` records the current findings of a package in a committed
  `inspectra-baseline.json`, and `inspectra baseline prune` removes the fixed ones without ever adding
  any. `--only scan,lint,style,trivy` selects scopes, `--recursive` covers nested packages; a scope
  that cannot run completely exits with `69` and writes nothing.
- `scan`, `audit`, `typosquat`, `trivy`, `lint`, `style`, `check` and the `build_runner` builders leave
  out recorded findings. Entries are matched by scope, source, rule, package and file, without line
  numbers or package versions, and count their occurrences. `inspect`, `add` and `trust` do not use the
  baseline.
- The `baseline:` configuration section: `enabled`, `file`, `max_severity`, `fail_on_stale`; the
  public `BaselineConfig` and `BaselineSummary`, and the `baseline` field of `InspectraConfig`,
  `StyleResult`, `LintResult` and `ScanResult`.
- JSON: `baselined` in the reports of `scan` and `audit`, and `baseline` with `covered` and `stale` in
  the results of `lint`, `style` and the Trivy scans, present only when a baseline was applied.

### Dependency policy

- The `dependency_policy:` section turns organisation rules for dependencies into checks, each opt-in:
  `DENIED_PACKAGE` (also transitive), `PACKAGE_NOT_ALLOWED`, `DISALLOWED_HOST` (registries and Git
  hosts, also transitive), `MISSING_UPPER_BOUND`, `SDK_BELOW_POLICY`, `DEV_ONLY_DEPENDENCY`,
  `MISSING_PUBLISH_TO`, `MISSING_METADATA`, `LOCKFILE_OUT_OF_SYNC`, `MISSING_CHECKSUM`,
  `UNUSED_DEPENDENCY` and `DEV_DEPENDENCY_IN_LIB`, all of the source `pubspec`.
- `inspectra deps [directory] [-r] [--fix]` runs the pubspec rules and the policy without network
  access, for every package of a workspace with `-r`; `--fix` bounds constraints with a caret, moves
  development packages to `dev_dependencies` and adds `publish_to: none`, keeping comments and
  formatting.
- `constraint_style: caret|range|pinned` reports `CONSTRAINT_STYLE` (low) for hosted constraints written
  otherwise; `--fix` rewrites caret and range constraints into each other and exact versions into
  either.
- `overrides.require_reason` with `overrides.allowed` (`name`, `reason`, `expires`, collected across
  layers) reports `UNJUSTIFIED_OVERRIDE` (medium) for overrides without a valid justification; a
  justified override no longer reports `DEPENDENCY_OVERRIDE`.
- `lockfile_policy: committed|ignored|auto` reports `LOCKFILE_POLICY` (medium) when Git tracks
  `pubspec.lock` against the policy; `auto` asks applications to commit it and publishable packages
  not to. `deps` and `check` apply it.
- `max_major_behind` and `max_libyear` with `libyear_scope: direct|all` report `OUTDATED_MAJOR` and
  `LIBYEAR_EXCEEDED` (medium) from the version listings of the registry, cached for a day:
  `deps --online`, `check` and `report` check them unless offline. JSON of `deps`: `outdatedChecked`
  and `libyears`. A policy's `minimum` may only lower both limits.
- Library: `ConstraintStyle`, `LockfilePolicy`, `LibyearScope`, `AllowedOverride` and the matching
  fields of `DependencyPolicyConfig`, `ConfigStrictness.lowerNumber`.
- `scan` applies the policy to its pubspecs, and `check` runs it as the step "Dependency policy"
  while `dependency_policy.enabled` is set.
- New runtime dependency: `yaml_edit`, for the fixes.
- Library: `DependencyPolicyConfig`, `DeniedPackage` and `InspectraConfig.dependencyPolicy`.

### Configuration tools

- `inspectra config show` prints the effective configuration as YAML; `--explain` comments every
  value with its origin (file and line, environment variable, command line or default) and
  `--only-changed` leaves out the defaults. `-f json` lists `key`, `value`, `default`, `origin`,
  `variable` and `line` per option.
- `inspectra config validate` checks the configuration and that every file it refers to exists, and
  lists all problems at once (exit code `65`).
- `inspectra config lint` reports risky settings as findings of the new source `config`:
  `CONFIG_INSECURE_URL`, `CONFIG_UNKNOWN_VARIABLE`, `CONFIG_TRIVY_DISABLED`, `CONFIG_UNPINNED_TRIVY`,
  `CONFIG_IGNORE_EXPIRED`, `CONFIG_IGNORE_WITHOUT_EXPIRY`, `CONFIG_GATE_NOT_FAILING`,
  `CONFIG_MIN_SEVERITY`, `CONFIG_NO_COVERAGE_THRESHOLD` and `CONFIG_BASELINE_UNBOUNDED`.
- `inspectra config schema` prints the JSON Schema of `inspectra.yaml`, generated from the code and
  published as `inspectra.schema.json`; `inspectra.example.yaml` starts with its
  `yaml-language-server` modeline.
- Unknown keys in the configuration file, in `ignore` entries and on the command line name the closest
  valid option: `Did you mean "secret"?`.
- Renamed options keep working under their old names until the next major version: every command
  warns, `config lint` reports `CONFIG_DEPRECATED_OPTION`, and the old and the new name side by side
  are an error. Library: `ConfigDeprecation`, `configDeprecations`, `DeprecatedOption` and
  `InspectraConfig.deprecatedOptions`.
- Library: `ConfigRecorder`, `ConfigEntry`, `ConfigKind`, `ConfigOrigin`, `ConfigOverride`,
  `ConfigOverrides.resolve` and `knownPaths`, a `recorder` parameter of `loadConfig`,
  `InspectraConfig.parse` and `InspectraConfig.fromSources`, and `FindingSource.config`.
- `inspectra config init [--preset app|library|plugin|enterprise] [--stdout] [--force]` writes a
  starting `inspectra.yaml` for the kind of package, detected from `pubspec.yaml`.
- `inspectra config migrate [--dry-run]` replaces the old names of renamed options in the
  configuration file and its profiles, keeping values, comments and order.
- `inspectra config diff <a> [<b>] [--fail-on-weaker]` compares two configurations, files or
  `git:<revision>`, with the effective configuration by default, and marks values that got weaker.
- `trivy.filesystem.scanners` accepts scanner names in any case, like the severities.

### Reports and dashboards

- `inspectra report` runs every evaluation - supply chain, dependencies, configuration, format, lint,
  style, public API, changelog, each configured Trivy scan and coverage - and reports each as a section
  with status, summary, key figures and findings. Package checks that are not enabled are reported as
  skipped with the option that enables them; an evaluation that cannot run is reported with its cause
  while the others still run, and the command exits with `69` after writing the report, also with
  `--exit-zero`. `--skip` leaves out sections, `--also <format>=<path>` writes further formats from
  the same run and `--merge` combines JSON reports of earlier runs.
- `-f html` writes a self-contained, offline HTML dashboard in the style of shadcn/ui: a sidebar with
  every evaluation, key figure cards, charts of findings by severity, line coverage and code
  composition, a table of the evaluations, a filterable finding explorer and an accordion with the
  details of each evaluation - coverage per file, the API diff, the code base per directory; light and
  dark mode, responsive and printable, with a content security policy that allows only its own inline
  stylesheet and script.
- The codebase section of `report` counts the lines of every Dart file: code with and without
  comments, comment and documentation lines, blank lines, the comment ratio and TODO markers, per
  directory and for the largest files, apart from generated files; and the dependencies of
  `pubspec.yaml` and `pubspec.lock`.
- New output formats for every command with `--format`: `junit`, `gitlab` (Code Quality, with
  fingerprints that survive moved lines), `sonarqube` (generic issue import) and `checkstyle`.
- The package check results become findings of the new source `quality`: `UNFORMATTED`, lint codes,
  `API_CHANGED`, `API_DUMP_MISSING`, `CHANGELOG_PROBLEM` and `COVERAGE_BELOW_THRESHOLD`.
- Library: `FindingSource.quality` and `FindingSource.tryParse`, `Finding.fromJson`.
- New runtime dependency: `xml`, for the JUnit and Checkstyle reports.

### Configuration inheritance and central policies

- `extends:` builds a configuration on bases: paths relative to the declaring file, `package:` files
  resolved through `.dart_tool/package_config.json`, and `https` URLs pinned by their SHA-256, which
  are verified and cached. Bases nest; mappings merge key by key, scalars and lists of the higher
  layer win, `key: ~` resets a value, and `ignore` and `dependency_policy.denied` collect the entries
  of every layer. License headers, secret rules and CA bundles named in a base resolve relative to it.
- A list option written as `key+:` adds to the list of the lower layers, or to the default, instead
  of replacing it: `dependency_policy.dev_only+: [golden_toolkit]`. The JSON Schema describes the
  `+` variant of every list option.
- `policy:` with `locked` options and `minimum` values binds every layer above its file, including
  `INSPECTRA_*` variables and the command line (`--set`, `--fail-on`, `coverage --min`); a violation is
  a configuration error naming the option, its origin and the policy.
- `profiles:` holds named partial configurations that `--profile <name>` or `INSPECTRA_PROFILE`
  applies above the project's own configuration and below environment variables and the command line;
  profiles of the bases and the project merge, policies bind them, and they cannot set `extends`,
  `policy` or `profiles`. `config validate` checks every profile and lists them as `profiles` in its
  JSON, `config show` records the selected one as `profile`. `check`, `format`, `lint`, `coverage`,
  `api check|dump` and `changelog check` take `--profile` as well.
- Text values and list elements can refer to environment variables: `${env:NAME}`,
  `${env:NAME:-default}`, and `$${` for a literal `${`. An unset variable without a default is a
  configuration error. `config show` prints the reference instead of the resolved value and marks it
  with `"interpolated": true`; policies check the resolved value. Library: `ConfigEntry.template` and
  `ConfigEntry.shown`.
- `policy.forbid_ignore_of: [critical]` keeps findings of these severities reported whatever ignores
  them: `ignore` rules of any layer, `--ignore` and the baseline. A finding an ignore matched carries
  the attribute `ignoreForbidden`.
- `inspectra config fetch` downloads and verifies remote bases for offline runs and `build_runner`;
  every command fetches missing bases first. `config show --explain` names the base and line of each
  value, `config show -f json` adds `layers` and `file`, and `config lint` reports
  `CONFIG_PUBSPEC_SECTION_IGNORED`. The JSON Schema describes `extends` and `policy`.
- Library: `ConfigLayer`, `ConfigLayerKind`, `ConfigLayerStack`, `ConfigBaseReference`,
  `ConfigPolicy`, `ConfigStrictness`, `InspectraConfig.fromLayers`, `ConfigEntry.file`,
  `ConfigRecorder.layers`, `InspectraConfigException.file`, `NetworkConfig.withResolvedPaths`, and
  `cacheRoot`/`packageRoot` parameters of `loadConfig` and `InspectraConfig.fromSources`,
  `ConfigPolicy.forbidIgnoreOf`, `InspectraConfig.forbiddenIgnoreSeverities`,
  `Finding.withAttributes` and `ConfigLayerKind.profile`.

### Semantic versioning from the API dump

- `inspectra api semver [--from <revision>]` compares the API dump committed at the last release tag
  (`changelog.tag_prefix`, read with `git show`) with the API of the current code, classifies every
  change as breaking or additive with a reason, and checks that the `version` of `pubspec.yaml` makes
  the required step: major for breaking changes, minor for additions, with Dart's rule before 1.0.0;
  a pre-release counts as its release. Removed declarations and members, changed signatures, types,
  default and constant values, added enum values and new abstract members are breaking; new
  declarations, deprecations and optional parameters of members nobody can override are additive.
- Findings `SEMVER_VIOLATION` (high, `pubspec.yaml`) and, with `changelog.enabled`,
  `SEMVER_UNDECLARED_BREAKING` (medium) when no commit since the release announces a breaking change.
  Without a release tag, a dump at the release or a version the check is skipped and exits with `0`.
- `api.semver: true` adds the step "API semver" to `check` and the section "Semantic versioning"
  (`--skip semver`) to `report`.
- Library: `checkSemver`, `evaluateSemver`, `SemverResult`, `classifyApiChanges`, `ApiChange`,
  `ApiChangeKind`, `ApiSurface`, `ApiDeclaration`, `ApiConfig.semver`, and the Git types `GitHistory`
  (with `show` and `hasCommits`), `GitCommit`, `ReleaseTag`, `ConventionalCommit` and `VersionBump`.

### Workspace policy

- The `workspace_policy:` section states the rules of a pub workspace at its root: `align_versions`
  (`off`, `compatible`, `exact`), `require_membership`, `same_sdk`, `forbid_cycles`,
  `include_dev_dependencies` and architecture `layers` with `packages` globs, `may_depend_on`,
  `isolated` and `forbidden_dependencies`, collected across configuration layers.
- Findings of the new source `workspace`: `WORKSPACE_MEMBER_MISSING`, `WORKSPACE_RESOLUTION_MISSING`,
  `WORKSPACE_VERSION_MISMATCH`, `WORKSPACE_SDK_MISMATCH`, `DEPENDENCY_CYCLE`, `LAYER_VIOLATION`,
  `FORBIDDEN_DEPENDENCY` and `LAYER_UNASSIGNED`. `deps -r` applies them at a workspace root, `check`
  as the step "Workspace policy", `report` in its dependencies section.
- `inspectra graph [directory] [-f text|dot|mermaid|json] [--include-dev] [--external]` draws the
  dependencies between the packages of a workspace, grouped by layer.
- `inspectra workspace affected --since <revision> [-f text|json]` lists the packages the changes
  since a Git revision affect, with every package depending on them; `deps -r --changed-since
  <revision>` checks only those.
- Library: `WorkspacePolicyConfig`, `WorkspaceLayer`, `VersionAlignment`,
  `InspectraConfig.workspacePolicy`, `FindingSource.workspace` and `GitHistory.changedFiles`.

### Developer experience

- `inspectra explain [RULE_ID] [-f text|markdown|json]` explains a rule offline - source, default
  severity, what it reports, why it matters and how to resolve it - from a catalog of every fixed rule
  id, or lists them all; advisory ids point to OSV.dev, a misspelled id gets the closest rule. The new
  Rule reference in the documentation lists every rule.
- `inspectra doctor [--offline] [-f json]` checks the configuration, the Dart and Flutter SDKs against
  the pubspec and `.fvmrc`, Git, Trivy, proxy, CA bundle, the reachability of OSV.dev, the registry
  and the Trivy releases, the token of a private registry and the cache, and exits with `1` when a
  check failed.
- `inspectra hook run` runs the checks of the new `hook.checks` (`audit`, `typosquat`, `deps`,
  `format`, `style`; default `[audit, typosquat]`) on the files staged for the commit, the dependency
  and style checks on the staged content. The pre-commit hook now calls it; `inspectra hook install`
  updates an installed hook.
- Library: `HookConfig`, `HookCheck`, `InspectraConfig.hook`, and `GitHistory.stagedFiles` and
  `stagedContent`.

### Changed

- `deps -r` at the root of a pub workspace checks the packages its `workspace:` list names instead of
  every `pubspec.yaml` below it, so a standalone `example/` package is no longer included. `scan -r`
  now also checks the pubspecs of workspace members, which share the root lockfile.
- `ANY_VERSION` and `WILDCARD_VERSION` no longer report dependencies on packages of the same pub
  workspace, which pub resolves to the workspace's own copy.

### Fixed

- A list or mapping where the configuration expects another kind of value, such as
  `style.rules: [no_else]`, is reported as a configuration error instead of crashing with exit code `70`.
- `trivy.executable` is a known option again while `INSPECTRA_TRIVY` is set: the key in the
  configuration file no longer fails as an unknown option, and `--trivy-executable` or
  `--set trivy.executable=…` now wins over `INSPECTRA_TRIVY` as the command line should.
- Git runs in the C locale, so a translated Git no longer breaks `api semver`, `changelog` and the
  semver step of `check`: an empty repository or an unknown revision failed with exit code `69` instead
  of being recognised. `ProcessRunner.run` takes an `environment` for this.

## 1.0.0

### Package quality gates

- Trivy scans for secrets, dependency licenses, dependency vulnerabilities and a plain filesystem
  scan, configurable per scan and runnable from `build_runner` or the `inspectra` command line.
- Public API dump of every public library, written by the `inspectra:api` builder and checked with
  `build_runner build --only-check` or `inspectra api check`; constants and `const` primary
  constructors are recorded and changes are shown as a unified diff.
- Coverage gate on top of `package:coverage` with an optional line coverage threshold; files marked
  `// coverage:ignore-file` are not listed as untested.
- Format check (`dart format`) and lint check (`dart analyze`, `fail_on: error|warning|info|none`)
  with `--fix`, as the first steps of `check`, and as `build_runner` builders.
- A strict lint preset, `package:inspectra/lints/strict.yaml`.
- Style check (`inspectra style`, a step of `check`, the `inspectra:style` builder) with rules no lint
  covers: `license_header` from a template with `{year}`, `public_docs`, `private_docs`,
  `one_type_per_file`, `one_public_type_per_file`, `file_named_after_type`, `no_comments`,
  `no_else`, `no_default_case` and `no_wildcard_case`; the presets `none`, `recommended` (fits
  Flutter's widget-plus-private-`State` files) and `strict`, per-rule switches,
  `// inspectra: ignore-style` and `ignore-style-file` comments, and text, JSON, Markdown and SARIF
  output.
- Custom style rules: `package:inspectra/style.dart` with `StyleRule`, `StyleFile`, `StyleReporter`
  and `StyleChecker`; the files of `style.custom_rules` are run by a generated program through
  `dart run`, so they work with the compiled executable as well.
- Writerside documentation in `docs/`, published to GitHub Pages.

### Changelog

- `inspectra changelog generate` writes the section of the next release from the Conventional Commits
  since the latest release tag, in the Keep a Changelog layout: breaking changes first, then Added,
  Changed, Deprecated, Removed, Fixed and Security, with commit and comparison links. It suggests the
  next semantic version, drops commits reverted within the release, and with `--write` adds the section
  to `CHANGELOG.md` without touching existing sections. `--from`, `--to`, `--release`, `--date`.
- `inspectra changelog check`, also part of `check` with `changelog.enabled`, validates the changelog
  and fails when the version of `pubspec.yaml` is not documented.
- `inspectra changelog notes [version]` prints the section of a release; the release workflow uses it
  as the description of the GitHub release.
- The `changelog:` configuration section: `enabled`, `file`, `tag_prefix`, `types`, `unconventional`,
  `repository`, `commit_url`, `compare_url`; `checkChangelog` in the library API.

### Supply-chain security

The supply-chain commands, with stable names, flags, rule ids, JSON fields and the exit codes `0`,
`1` and `64`:

- `scan`, the default command: OSV.dev audit, pubspec rules, typosquatting, dependency confusion
  and a Trivy filesystem scan in one report, with `--recursive` for monorepos and pub workspaces.
- `audit`, `inspect`, `trust [version]`, `typosquat`, `add [--dev] [--force] [--dry-run]`, `hook`.
- Output formats `json` (versioned), `sarif` (GitHub code scanning) and `markdown`; `--output`,
  `--fail-on`, `--min-severity`, `--ignore`, `--exit-zero`, `--offline`, `--quiet`, `--verbose`,
  `--color`.
- Ignore rules with mandatory reason, optional package scope and expiry date.
- Proxy, custom CA bundle, `PUB_HOSTED_URL`, OSV mirror, retries with back-off and `Retry-After`,
  response size limits and an OSV advisory cache.

Full OSV records with pagination, CVSS v3/v2 scoring and per-range fix versions; checksum verified,
in-memory package inspection without zip-slip or decompression bombs; the archive and pubspec
scanners; the pub.dev trust endpoints of the requested version; code point based Unicode scanning;
exact URL host matching; typosquat detection with few false positives; `add` installs exactly the
inspected version and works with Flutter on Windows.

### Trivy provisioning

- Trivy is taken from `trivy.executable` / `INSPECTRA_TRIVY`, the `PATH`, package manager
  directories or Inspectra's cache, or downloaded for Linux, macOS and Windows when the download host
  is reachable, with mandatory SHA-256 verification against the release checksums and atomic
  installation. `mode`, `version` (`latest` included), `download`, `use_installed`, mirrors and the
  database repository are configurable. `inspectra trivy --install` and `--where`; `--where`
  never downloads.
- `--offline` and `network.offline` keep Trivy offline as well: every scan, including the builders,
  starts it with `--skip-db-update --offline-scan`.

### Configuration and command line

- One configuration, in the `inspectra:` section of `pubspec.yaml` or in `inspectra.yaml`, with
  strict validation of every key; configuration errors name the key and, for YAML syntax errors, the
  line and column.
- Every option can be overridden with `INSPECTRA_*` environment variables and `--set key=value`.
- Exit codes follow `sysexits.h`: `65` for invalid input or configuration, `69` for unavailable
  services and tools, `70` for internal errors.
