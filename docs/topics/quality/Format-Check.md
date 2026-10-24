# Format check

<primary-label ref="builder"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="no-network"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Checking, or fixing, the formatting of every Dart file with dart format.</link-summary>

<card-summary>dart format as a gate: on build, on the command line and in check, with --fix to apply.</card-summary>

<tldr>
<p><b>Enable</b>: <code>format: { enabled: true }</code></p>
<p><b>Check</b>: <code>dart run %package% format</code> · <b>Fix</b>: <code>dart run %package% format --fix</code></p>
<p><b>On build</b>: <code>format.run_on_build: true</code></p>
<p><b>Uses</b>: <code>dart format</code>, the formatter of the Dart SDK</p>
</tldr>

Unformatted code is noise in every diff and a reason for review comments nobody should have to write. The format
check runs the SDK's own formatter, `dart format`, over the package and fails when a file is not formatted - the same
result as `dart format --output=none --set-exit-if-changed .`, with generated code left out, a readable report, and a
place in `build_runner` and `inspectra check`.

## Configuration

```yaml
inspectra:
  format:
    enabled: true                # default false
    run_on_build: false          # default
    fail_on_findings: true       # default
    include: ['**.dart']         # default
    exclude: ['**/.dart_tool/**', '**/build/**', '**.g.dart', '**.freezed.dart', '**.mocks.dart', '**.specia.dart']
    # page_width: 100            # default: from analysis_options.yaml, else 80
```

| Key | Default | Description |
|:--|:--|:--|
| `enabled` | `false` | Whether `check` runs the format check. `dart run %package% format` runs it regardless. |
| `run_on_build` | `false` | Whether `build_runner build` runs it. |
| `fail_on_findings` | `true` | Whether an unformatted file fails the build or the command. |
| `include` | `['**.dart']` | Globs of the files to check, relative to the package root. |
| `exclude` | tool caches, build output, generated code | Globs of files never checked. Replaces the default when set. |
| `page_width` | unset | The line length, from 1 to 1000. Unset: `formatter: page_width` of `analysis_options.yaml`, and 80 without one. |

### Why generated code is excluded

Code generators format their own output, often with their own settings. A `.g.dart` file that differs from your page
width is the generator's choice, and reformatting it would be undone by the next build. The defaults therefore leave
out `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` and `*.specia.dart`, like the coverage gate and the style check do.

### Page width and style

`dart format` runs in the package root, so it uses the same settings as when you run it by hand:

- the page width from the `formatter:` section of the <tooltip term="analysis options">analysis options</tooltip> -
  also when it comes from an included file such as the [lint preset](Lint-Preset.md),
- the formatting style of the package's language version: the "tall" style for language version 3.7 and later.

`page_width` overrides the analysis options for the check only. Prefer setting it in `analysis_options.yaml`, so that
your editor's formatter agrees:

```yaml
# analysis_options.yaml
formatter:
  page_width: 100
```

## Running it

<tabs group="run">
    <tab title="Command line" group-key="cli">
        <code-block lang="bash"><![CDATA[
dart run inspectra format          # check
dart run inspectra format --fix    # format the files in place
dart run inspectra check           # includes the check when format.enabled
]]></code-block>
    </tab>
    <tab title="build_runner" group-key="build">
        <code-block lang="yaml"><![CDATA[
inspectra:
  format:
    enabled: true
    run_on_build: true
]]></code-block>
        <code-block lang="bash"><![CDATA[
dart run build_runner build
]]></code-block>
    </tab>
</tabs>

### Output

```text
Format: 1 of 3 file(s) are not formatted.
  lib/b.dart
Run "dart run inspectra format --fix" or "dart format ." to fix them.
```

```text
Format: all 40 file(s) are formatted.
```

With `--fix`, the files are formatted and listed; the command does not fail:

```text
Format: formatted 1 of 3 file(s).
  lib/b.dart
```

The command line writes `.dart_tool/inspectra/format.json`:

```json
{
  "check": "format",
  "failed": true,
  "fixed": false,
  "checked": 3,
  "unformatted": ["lib/b.dart"]
}
```

## On build

With `run_on_build: true`, the `inspectra:format` builder checks the formatting on every `build_runner build`:

- It declares `.dart` as a required input, so `build_runner` runs it **after every builder that generates Dart code**.
  It checks the package as the build leaves it.
- It reads every checked file through the build step, so it reruns only when one of them changes.
- It checks files of the package only; outputs other builders keep in the build cache, such as test bootstraps, are
  skipped.
- An unformatted file is a `SEVERE` log entry and fails the build; with `fail_on_findings: false`, a warning.

```text
E inspectra:format on $package$:
  Format: 1 of 41 file(s) are not formatted.
    lib/src/new_feature.dart
  Run "dart run inspectra format --fix" or "dart format ." to fix them.
```

<tip>
On build, the check catches an unformatted file before it is committed. With format-on-save in the editor it never
fires; when it does, the editor was not set up - which is worth knowing.
</tip>

## Errors

A file `dart format` cannot parse is not a formatting finding but an error: the command exits with `69` and prints the
formatter's message, and the builder logs it as `SEVERE`. Fix the syntax error first; the [lint check](Lint-Check.md)
reports it with its position.

<seealso>
    <category ref="quality">
        <a href="Lint-Check.md">Lint check</a>
        <a href="Lint-Preset.md">Lint preset</a>
    </category>
    <category ref="config">
        <a href="Configuration-Reference.md#format">Configuration reference</a>
    </category>
    <category ref="external">
        <a href="https://dart.dev/tools/dart-format">dart format</a>
    </category>
</seealso>
