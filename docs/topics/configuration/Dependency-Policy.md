# Dependency policy

<primary-label ref="cli"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="since-2-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Organisation-wide rules for the dependencies of every package: denied and allowed packages, registries, upper bounds, constraint style, SDK minimums, publishing, justified overrides, lockfile hygiene, unused and outdated dependencies, with automatic fixes.</link-summary>

<card-summary>Denied packages, approved registries, upper bounds, constraint style, SDK minimums, publish_to, justified overrides, lockfile hygiene, unused and outdated dependencies - checked by deps, scan and check, fixed by deps --fix.</card-summary>

<tldr>
<p><b>Enable</b>: <code>dependency_policy: { enabled: true, … }</code>, then configure the rules you want</p>
<p><b>Check</b>: <code>dart run %package% deps</code> - offline, fast; <code>-r</code> for every package of a workspace; <code>--online</code> for outdated dependencies</p>
<p><b>Fix</b>: <code>dart run %package% deps --fix</code> keeps comments and formatting</p>
<p><b>Also in</b>: <code>scan</code> and <code>check</code></p>
</tldr>

Rules for dependencies usually live in a wiki page, a spreadsheet of approved packages and review comments: no
abandoned packages, only the internal registry, no unbounded constraints, test packages out of the runtime
dependencies. And the most expensive mistake costs one command: an internal package without `publish_to: none` is
uploaded to pub.dev by `dart pub publish`. The dependency policy turns these rules into configuration that every
package checks the same way, locally, in the pre-merge pipeline and in the nightly scan.

## Enabling the policy {id="enable"}

```yaml
inspectra:
  dependency_policy:
    enabled: true
    denied:
      - name: http_parser_legacy
        reason: Unmaintained since 2023.
        replacement: http
    allowed_hosts: [https://pub.acme.corp, https://pub.dev]
    require_upper_bound: true
    min_sdk: 3.6.0
    dev_only: [mockito, build_runner, lints, test]
    require_publish_to: true
    published_packages: [acme_public_sdk]
    lockfile_in_sync: true
```

Every rule is off until it is configured, and nothing is checked until `enabled` is set, so updating %product% never
adds findings on its own. The findings are of the source `pubspec` and behave like every other finding: `ignore`
rules with a reason, the [baseline](Baseline.md) (scope `scan`), `--fail-on`, and JSON, SARIF and Markdown output.

## Rules {id="rules"}

| Rule | Severity | Configured by | Reported when | `--fix` |
|:--|:--|:--|:--|:--|
| `DENIED_PACKAGE` | high | `denied` | A denied package is declared, or pulled in transitively according to `pubspec.lock` | - |
| `PACKAGE_NOT_ALLOWED` | high | `allowed` | A hosted dependency is not on the allowed list | - |
| `DISALLOWED_HOST` | high | `allowed_hosts`, `allowed_git_hosts` | A package comes from another registry or Git host, directly or transitively | - |
| `MISSING_UPPER_BOUND` | medium | `require_upper_bound` | A hosted constraint has no upper bound, such as `>=1.2.0` | `^1.2.0` |
| `SDK_BELOW_POLICY` | medium | `min_sdk`, `min_flutter` | `environment.sdk` or `environment.flutter` allows an SDK below the minimum | - |
| `DEV_ONLY_DEPENDENCY` | medium | `dev_only` | A development package is listed under `dependencies` | moved to `dev_dependencies` |
| `MISSING_PUBLISH_TO` | medium | `require_publish_to` | A package has no `publish_to` and is not one of `published_packages` | `publish_to: none` |
| `MISSING_METADATA` | low | `required_metadata` | A publishable package lacks `description`, `repository`, `homepage`, `issue_tracker`, `documentation` or `topics` | - |
| `LOCKFILE_OUT_OF_SYNC` | high | `lockfile_in_sync` | A direct dependency is missing from `pubspec.lock`, locked outside its constraint, or removed but still locked | - |
| `MISSING_CHECKSUM` | medium | `lockfile_checksums` | A hosted package of `pubspec.lock` has no `sha256` | - |
| `UNUSED_DEPENDENCY` | low | `check_imports` | No file of `lib/` or `bin/` imports a dependency; the finding says when only tests use it | - |
| `DEV_DEPENDENCY_IN_LIB` | high | `check_imports` | `lib/` or `bin/` imports a development dependency, which the package's users do not get | - |
| `CONSTRAINT_STYLE` | low | `constraint_style` | A hosted constraint is not written as a caret (`^1.2.0`), a range (`>=1.2.0 <2.0.0`) or an exact version (`1.2.3`), as configured | caret and range, when the versions stay the same |
| `UNJUSTIFIED_OVERRIDE` | medium | `overrides.require_reason` | A `dependency_overrides` entry has no entry in `overrides.allowed`, or its `expires` date has passed | - |
| `LOCKFILE_POLICY` | medium | `lockfile_policy` | `pubspec.lock` is committed against the policy, or not committed although it should be | - |
| `OUTDATED_MAJOR` | medium | `max_major_behind` | A direct dependency is more breaking releases behind its latest release than allowed; needs the registry | - |
| `LIBYEAR_EXCEEDED` | medium | `max_libyear` | The dependencies add up to more libyears than allowed; needs the registry | - |

Hosted dependencies without a `hosted:` URL come from `network.pub_hosted_url`, which defaults to `PUB_HOSTED_URL`.
`https://pub.dev` and `https://pub.dartlang.org` count as the same registry. The lockfile rules run for the package
the lockfile belongs to, so the members of a pub workspace do not report the root lockfile once each.

The import rules parse the Dart files without resolving them, so no `dart pub get` is needed. Imports, exports and
conditional imports count; nested packages such as an `example/` package with a `pubspec.yaml` of its own are left
out. Packages that are used without an import, such as `cupertino_icons` through its font, go into `unused_allow`.

### Overrides with a reason {id="overrides"}

```yaml
dependency_policy:
  enabled: true
  overrides:
    require_reason: true
    allowed:
      - name: intl
        reason: Flutter 3.27 pins intl 0.19; remove with Flutter 3.29.
        expires: 2027-01-31
```

An override replaces the version every package agreed on, so it should be rare, explained and temporary. With
`require_reason`, every entry of `dependency_overrides` needs an entry in `overrides.allowed` with a `reason`, and an
optional `expires` date after which it is reported again. A justified override also drops the built-in
`DEPENDENCY_OVERRIDE` finding for that package, with or without `require_reason`. Like `denied`, the list collects the
entries of every [configuration layer](Configuration-Inheritance.md).

### Committed lockfiles {id="lockfile-policy"}

`lockfile_policy: auto` asks applications - packages with `publish_to: none` - to commit `pubspec.lock`, so that every
build resolves the versions that were tested, and packages that can be published not to, because their users resolve
them with their own lockfile. `committed` and `ignored` ask the same of every package. The rule asks Git which files it
tracks, `deps` and `check` apply it, and outside a Git repository it is skipped. Workspace members share the root's
lockfile and are not checked.

### Outdated dependencies {id="outdated"}

```yaml
dependency_policy:
  enabled: true
  max_major_behind: 1      # at most one breaking release behind
  max_libyear: 10          # at most ten years behind, added up
  libyear_scope: direct    # or all, to count transitive packages
```

`max_major_behind` counts the breaking releases between the version in `pubspec.lock` and the latest stable release:
majors from 1.0.0 on, minors before it, as caret constraints do; retracted versions and pre-releases do not count.
`max_libyear` adds up, for every counted package, the time between the release of the locked version and the latest
one - the libyear metric. Both need the version listings of the registry, so `deps` checks them only with `--online`;
`check` and `report` check them unless the network is off. Packages from pub.dev are looked up in
`network.pub_hosted_url`, others in their own registry, and the listings are cached for a day. Without the network, `deps`
says that the rules were not checked and reports `outdatedChecked: false` in its JSON; a registry that cannot be queried
fails the command with `69`.

## Checking {id="deps"}

```bash
dart run %package% deps            # the package in the current directory
dart run %package% deps -r         # every package below it, workspace members included
dart run %package% deps -f sarif -o deps.sarif
dart run %package% deps --online   # also max_major_behind and max_libyear
```

`deps` runs the built-in pubspec rules - unconstrained versions, Git branches, plain HTTP sources, overrides, old SDK
constraints - and the policy, without any network access unless `--online` asks for the rules that need the registry.
It is fast enough for a pre-commit hook. `scan` applies the policy to the packages it scans, but not
`lockfile_policy` and the outdated rules, and `check` runs it as the step "Dependency policy" while `enabled` is set.

## Fixing {id="fix"}

```bash
dart run %package% deps --fix
```

`--fix` applies the rules a tool can decide: it bounds constraints with a caret (`>=1.2.0` becomes `^1.2.0`), rewrites
constraints in the `constraint_style` when that keeps the versions they allow (`^1.2.0` and `>=1.2.0 <2.0.0` into
each other, an exact version into either), moves the packages of `dev_only` to `dev_dependencies`, and adds
`publish_to: none` below the package name. The file is
edited, not rewritten: comments, order, quoting and the layout of every other key stay as they are. Each change is
listed, and the remaining findings are reported as without `--fix`. Running it again changes nothing.

```text
✔ Fixed pubspec.yaml: http: >=1.2.0 -> ^1.2.0
✔ Fixed pubspec.yaml: mockito: dependencies -> dev_dependencies
✔ Fixed pubspec.yaml: publish_to: none
[HIGH]     The package left_pad is denied  (DENIED_PACKAGE)  pubspec.yaml:9
    Unmaintained. Use string_padding instead.
```

Denied packages, registries, SDK minimums and lockfiles need a decision or `dart pub get` and are never changed.

## Configuration {id="configuration"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | bool | `false` | Apply the policy in `scan`, `deps` and `check` |
| `denied` | list | `[]` | Entries with `name`, `reason` (required) and `replacement` |
| `allowed` | list | `[]` | When not empty, the only hosted packages that may be declared |
| `allowed_hosts` | list | `[]` | When not empty, the only registries; pub.dev is `https://pub.dev` |
| `allowed_git_hosts` | list | `[]` | When not empty, the only Git hosts, such as `git.acme.corp` |
| `require_upper_bound` | bool | `false` | Every hosted constraint needs an upper bound |
| `min_sdk`, `min_flutter` | version | unset | The lowest SDK the `environment` constraints may allow |
| `dev_only` | list | `[]` | Packages that belong in `dev_dependencies` |
| `require_publish_to` | bool | `false` | Every package needs `publish_to` |
| `published_packages` | list | `[]` | Packages meant for pub.dev, which need no `publish_to` |
| `required_metadata` | list | `[]` | Fields a publishable package must declare |
| `lockfile_in_sync` | bool | `false` | `pubspec.lock` must match the direct dependencies |
| `lockfile_checksums` | bool | `false` | Every hosted package of `pubspec.lock` needs a `sha256` |
| `check_imports` | bool | `false` | Report unused dependencies and development dependencies used by `lib/` |
| `unused_allow` | list | `[cupertino_icons]` | Packages never reported as unused |
| `constraint_style` | choice | `any` | `caret`, `range` or `pinned`: how hosted constraints are written |
| `overrides.require_reason` | bool | `false` | Every dependency override needs an entry in `overrides.allowed` |
| `overrides.allowed` | list | `[]` | Entries with `name`, `reason` (required) and `expires` |
| `lockfile_policy` | choice | `any` | `committed`, `ignored`, or `auto`: applications commit `pubspec.lock`, publishable packages do not |
| `max_major_behind` | number | unset | The most breaking releases a direct dependency may be behind |
| `max_libyear` | number | unset | The most libyears the dependencies may add up to |
| `libyear_scope` | choice | `direct` | `all` to count transitive packages towards `max_libyear` |

Shared across an organisation, the section lives in a [base configuration](Configuration-Inheritance.md) that every
repository extends; a policy can lock its switches, and `max_major_behind` and `max_libyear` may only be lowered.

<seealso>
    <category ref="config">
        <a href="Configuration-Reference.md#dependency_policy">Configuration reference</a>
        <a href="Baseline.md">Baseline</a>
        <a href="Configuration-Tools.md">Configuration tools</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#deps">deps</a>
    </category>
    <category ref="external">
        <a href="https://dart.dev/tools/pub/dependencies">Package dependencies</a>
        <a href="https://dart.dev/tools/pub/pubspec#publish_to">publish_to</a>
    </category>
</seealso>
