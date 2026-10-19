# Workspace policy

<primary-label ref="cli"/>
<secondary-label ref="no-network"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="since-2-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Rules for the packages of a pub workspace: membership, aligned versions, SDK constraints, dependency cycles and the layers of the architecture, plus the dependency graph and the packages a change affects.</link-summary>

<card-summary>Membership, aligned versions, cycles and architecture layers of a pub workspace - checked by deps -r and check; graph and workspace affected for reviews and CI.</card-summary>

<tldr>
<p><b>Enable</b>: <code>workspace_policy: { enabled: true, layers: [...] }</code> at the workspace root</p>
<p><b>Check</b>: <code>dart run %package% deps -r</code>, or the step "Workspace policy" of <code>check</code></p>
<p><b>Draw</b>: <code>dart run %package% graph -f mermaid</code></p>
<p><b>CI</b>: <code>dart run %package% workspace affected --since origin/main</code></p>
</tldr>

A monorepo grows the same way everywhere: forty packages, twelve different constraints of `http`, a feature package
that imports another feature, a domain package that suddenly needs Flutter, and a pipeline that tests everything for
every change. The workspace policy states the rules of a [pub workspace](https://dart.dev/tools/pub/workspaces) once,
in the configuration of its root, and checks them on every change.

## Enabling the policy {id="enable"}

```yaml
# inspectra.yaml at the workspace root
workspace_policy:
  enabled: true
  align_versions: exact
  same_sdk: true
  layers:
    - name: app
      packages: [apps/*]
    - name: feature
      packages: [features/*]
      may_depend_on: [domain, core]
      isolated: true
    - name: domain
      packages: [packages/domain_*]
      may_depend_on: [core]
      forbidden_dependencies: [flutter]
    - name: core
      packages: [packages/core]
      may_depend_on: []
```

The workspace is read from the `workspace:` list of the root `pubspec.yaml`, with globs and nested workspaces; only
pub workspaces are supported. `deps -r` at the root applies the policy next to the pubspec rules and the
[dependency policy](Dependency-Policy.md), `check` runs it as the step "Workspace policy", and `report` adds its findings
to the dependencies section. Findings are of the source `workspace` and behave like every other finding: `ignore`
rules, the [baseline](Baseline.md), `--fail-on`, SARIF.

## Rules {id="rules"}

| Rule | Severity | Configured by | Reported when |
|:--|:--|:--|:--|
| `WORKSPACE_MEMBER_MISSING` | high | `require_membership` | A `workspace:` entry names no directory with a `pubspec.yaml`, or a package below the root declares `resolution: workspace` without being listed |
| `WORKSPACE_RESOLUTION_MISSING` | high | `require_membership` | A listed package lacks `resolution: workspace` |
| `WORKSPACE_VERSION_MISMATCH` | medium | `align_versions` | `compatible`: the constraints of an external package allow no common version; `exact`: a package writes another constraint than most do, with that one as the fix |
| `WORKSPACE_SDK_MISMATCH` | medium | `same_sdk` | A package's `environment.sdk` differs from the root's |
| `DEPENDENCY_CYCLE` | high | `forbid_cycles` | Packages depend on each other in a cycle |
| `LAYER_VIOLATION` | high | `layers` | A package depends on a layer its `may_depend_on` does not list, or on a package of its own `isolated` layer |
| `FORBIDDEN_DEPENDENCY` | high | `layers` | A package depends on one of its layer's `forbidden_dependencies`, such as `flutter` in a pure Dart layer |
| `LAYER_UNASSIGNED` | low | `layers` | A package matches no layer |

A package belongs to the first layer whose `packages` glob matches its directory relative to the root. Without
`may_depend_on`, a layer may depend on every layer; `may_depend_on: []` allows none but its own. Dependencies between
packages count from `dependencies`, and from `dev_dependencies` too with `include_dev_dependencies`. The built-in rules
`ANY_VERSION` and `WILDCARD_VERSION` do not apply to the packages of the same workspace, which pub always resolves to
the workspace's own copy.

## The dependency graph {id="graph"}

```bash
dart run %package% graph                  # one line per package
dart run %package% graph -f mermaid       # for a README or a pull request
dart run %package% graph -f dot | dot -Tsvg > graph.svg
dart run %package% graph --external -f json
```

`graph` draws the packages of the workspace and their dependencies, grouped by layer; `--include-dev` adds
`dev_dependencies` and `--external` the packages outside the workspace, drawn dashed. In a single package it lists the
direct dependencies. It needs no `dart pub get`.

## Only what a change affects {id="affected"}

```bash
dart run %package% workspace affected --since origin/main
dart run %package% workspace affected --since origin/main -f json
dart run %package% deps -r --changed-since origin/main
```

`workspace affected` asks Git which files changed since the revision, committed or not, and lists the packages that
contain them and every package depending on them, one directory per line - ready for a CI matrix. A change of the root
`pubspec.yaml`, `pubspec.lock`, `inspectra.yaml` or `analysis_options.yaml` affects every package. `--no-include-dev`
leaves out packages that use a changed package only for development. `deps -r --changed-since` checks only the
affected packages; the workspace rules always look at the whole workspace.

## Configuration {id="configuration"}

| Key | Type | Default | Description |
|:--|:--|:--|:--|
| `enabled` | bool | `false` | Apply the policy in `deps -r`, `check` and `report` |
| `align_versions` | choice | `compatible` | `off`, `compatible` or `exact` |
| `require_membership` | bool | `true` | Listed entries exist, members are resolved by the workspace, nothing is left out |
| `same_sdk` | bool | `false` | Every package has the root's SDK constraint |
| `forbid_cycles` | bool | `true` | Report dependency cycles |
| `include_dev_dependencies` | bool | `false` | `dev_dependencies` count for cycles and layers |
| `layers` | list | `[]` | Entries with `name`, `packages` (globs), `may_depend_on`, `isolated` and `forbidden_dependencies` |

Like `denied`, the layers of every [configuration layer](Configuration-Inheritance.md) add up, so an organisation can
ship a standard architecture in its policy package.

<seealso>
    <category ref="config">
        <a href="Dependency-Policy.md">Dependency policy</a>
        <a href="Configuration-Reference.md">Configuration reference</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#graph">graph</a>
        <a href="CLI-Reference.md#workspace-affected">workspace affected</a>
    </category>
    <category ref="external">
        <a href="https://dart.dev/tools/pub/workspaces">Pub workspaces</a>
    </category>
</seealso>
