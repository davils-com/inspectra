# Baseline

<primary-label ref="cli"/>
<secondary-label ref="no-network"/>
<secondary-label ref="since-2-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Adopt %product% in an existing code base: record today's findings once, fail only on new ones and shrink the baseline as findings are fixed.</link-summary>

<card-summary>Record the existing findings in a committed baseline file, so that only new findings fail, and prune the fixed ones.</card-summary>

<tldr>
<p><b>Record</b>: <code>dart run %package% baseline create</code>, then commit <code>inspectra-baseline.json</code></p>
<p><b>Prune</b>: <code>dart run %package% baseline prune</code> removes what was fixed and never adds anything</p>
<p><b>Applies to</b>: <code>scan</code>, <code>audit</code>, <code>typosquat</code>, <code>trivy</code>, <code>lint</code>, <code>style</code>, <code>check</code> and the builders</p>
<p><b>Switch off</b>: <code>--set baseline.enabled=false</code> or <code>INSPECTRA_BASELINE_ENABLED=false</code></p>
</tldr>

A new gate on a code base that is years old reports hundreds of findings on its first run. Nobody can fix them in one
go, so the gate is switched off again, and the next finding slips through unnoticed. A baseline turns the gate on
without that wall: it records the findings that exist today, the checks stop reporting them, and every finding that is
added afterwards fails as before. As findings are fixed, `baseline prune` removes them, so the baseline only ever
shrinks.

A baseline is not an exception list. A documented exception with a reason and an expiry date belongs into
[`ignore`](Configuration-Reference.md#ignore); a baseline is the debt you have not looked at yet.

## Recording the baseline {id="create"}

```bash
dart run %package% baseline create
git add inspectra-baseline.json
```

`baseline create` runs every scope and writes the baseline file. By default these are `scan` and, when they are enabled
in the configuration, `lint`, `style` and `trivy`. `--only` selects scopes, and recording one scope leaves the entries of
the others untouched:

```bash
dart run %package% baseline create --only style,lint
```

| Scope | What it records | Applied by |
|---|---|---|
| `scan` | The findings of `scan`: OSV.dev advisories, pubspec rules, typosquatting, dependency confusion, Trivy | `scan`, `audit`, `typosquat`, `trivy` without scan names |
| `lint` | The diagnostics of `dart analyze` | `lint`, `check`, the `inspectra:lint` builder |
| `style` | The violations of the style check | `style`, `check`, the `inspectra:style` builder |
| `trivy` | The findings of the configured Trivy scans, per scan | `trivy`, `check`, the Trivy builders |

Ignore rules and `min_severity` apply before anything is recorded, so a suppressed finding never enters the baseline.
`inspect`, `add` and `trust` judge packages you do not own yet and never use the baseline.

A scope that cannot run completely fails the command with exit code `69` before the file is written: when OSV.dev is
unreachable, in `--offline` mode, when `dart analyze` fails or Trivy is unavailable. An incomplete run never replaces or
shrinks the baseline. A part that is skipped by design keeps its entries: the Trivy findings of `scan` when Trivy did
not run, the dependency confusion findings offline, a Trivy scan that was skipped.

## How findings are matched {id="matching"}

An entry identifies findings by their scope, source, rule, package and file, deliberately **without line number and
package version**. Moving code, adding lines above a finding or upgrading a dependency does not make a recorded finding
new. Each entry counts how often its finding occurred:

```json
{
  "schemaVersion": 1,
  "entries": [
    {
      "scope": "style",
      "source": "style",
      "rule": "no_else",
      "path": "lib/legacy/parser.dart",
      "count": 3,
      "severity": "low",
      "title": "No else: return early instead."
    }
  ]
}
```

With three recorded `no_else` violations in `parser.dart`, a fourth one fails: the first three, in the order of their
lines, are covered, and the last one is reported as new. The file is written sorted and without timestamps, so every
change to it is a small, reviewable diff.

Findings more severe than `baseline.max_severity` are never covered. With `max_severity: high`, a `CRITICAL` advisory
fails even when the baseline lists it.

## Reports {id="reports"}

A check that applied a baseline says so:

```text
Style: 1 violation(s) in 1 of 412 file(s).
  lib/feature/new_screen.dart:41:5: No else: return early instead. [no_else]
  318 finding(s) covered by the baseline.
  2 baseline entries are fixed; run "inspectra baseline prune".
```

The JSON results of `lint`, `style` and the Trivy scans carry `"baseline": {"covered": 318, "stale": 2}`; the JSON
reports of `scan` and `audit` have a `baselined` count next to `suppressed`. A package without a baseline file gets
exactly the output it got before.

## Pruning fixed findings {id="prune"}

```bash
dart run %package% baseline prune
```

`baseline prune` runs the scopes like `create`, lowers every count to the number of findings that still occur and
removes the entries that no longer occur. It never adds an entry, so a new finding cannot sneak into the baseline
through a prune.

A check reports entries whose findings are gone as **stale**. With `baseline.fail_on_stale: true` they fail the check,
which enforces a strict ratchet in CI: whoever fixes a recorded finding also prunes it.

## Configuration {id="configuration"}

```yaml
inspectra:
  baseline:
    enabled: true                    # apply the baseline file when it exists
    file: inspectra-baseline.json    # relative to the package root
    # max_severity: high             # never cover CRITICAL findings
    fail_on_stale: false             # fail while fixed findings are still recorded
```

| Key | Type | Default | Description |
|---|---|---|---|
| `enabled` | bool | `true` | Apply the baseline file when it exists |
| `file` | string | `inspectra-baseline.json` | The baseline file, relative to the package root |
| `max_severity` | severity | unset | Findings more severe than this are never covered |
| `fail_on_stale` | bool | `false` | Fail a check while recorded findings have been fixed |

A malformed baseline file is an input error with exit code `65`; it is never ignored silently. The builders read the
baseline file from disk; list it under `targets.$default.sources` in `build.yaml` if editing it should rerun them
([Build sources](Build-Sources.md)).

<seealso>
    <category ref="config">
        <a href="Configuration-Reference.md">Configuration reference</a>
        <a href="Build-Sources.md">Build sources</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#baseline-create">baseline create</a>
        <a href="CLI-Reference.md#baseline-prune">baseline prune</a>
    </category>
    <category ref="operations">
        <a href="CI-Integration.md">CI integration</a>
    </category>
</seealso>
