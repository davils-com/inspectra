# Style check

<primary-label ref="builder"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="no-network"/>
<secondary-label ref="since-1-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>House rules the analyzer has no lint for - license headers, one type per file, documented code, no else - plus rules you write yourself.</link-summary>

<card-summary>Built-in structural rules with presets, inline exceptions, SARIF output and custom rules in Dart.</card-summary>

<tldr>
<p><b>Enable</b>: <code>style: { enabled: true, preset: recommended }</code></p>
<p><b>Check</b>: <code>dart run %package% style</code>, also part of <code>check</code> and the <code>inspectra:style</code> builder</p>
<p><b>Presets</b>: <code>none</code>, <code>recommended</code> (default), <code>strict</code></p>
<p><b>Your own rules</b>: <a href="Style-Custom-Rules.md">custom rules</a> in Dart</p>
</tldr>

The [lint check](Lint-Check.md) enforces the analyzer's rules. Some rules that teams agree on have no lint: every
file starts with the license header, a file holds one type and is named after it, private code is documented too,
there is no `else` and no `default` case. Usually they live in a review checklist or in a script of the repository.
The style check makes them part of %product%: configured in the same file, run by the same command, the same builder
and the same CI step as the other checks, and reported in text, JSON, Markdown and SARIF.

%product% holds itself to the `strict` preset; before, the same rules were a script in its repository.

## Configuration

```yaml
inspectra:
  style:
    enabled: true                            # default false
    run_on_build: false                      # default
    fail_on_findings: true                   # default
    preset: recommended                      # none, recommended or strict
    rules:                                   # switch single rules on or off
      no_else: true
      public_docs: false
    license_header: tool/license_header.txt  # unset: no header rule
    custom_rules: [tool/style_rules.dart]    # your own rules
    include: ['**.dart']
    exclude: ['**/.dart_tool/**', '**/build/**', '**.g.dart', '**.freezed.dart', '**.mocks.dart', '**.specia.dart']
```

| Key | Default | Description |
|:--|:--|:--|
| `enabled` | `false` | Whether `check` runs the style check. `dart run %package% style` runs it regardless. |
| `run_on_build` | `false` | Whether `build_runner build` runs it. |
| `fail_on_findings` | `true` | Whether violations fail the check; otherwise they are only reported. |
| `preset` | `recommended` | The built-in rules that run. See [Presets](#presets). |
| `rules` | `{}` | Rule ids mapped to `true` or `false`, built-in and custom; they win over the preset. |
| `license_header` | unset | The [header template](#license-header). Without one, `license_header` does not run. |
| `custom_rules` | `[]` | Dart files with [your own rules](Style-Custom-Rules.md). |
| `include`, `exclude` | as for the format check | Globs of the checked files, relative to the package root. Setting one replaces its default. |

## Presets {id="presets"}

| Rule | `none` | `recommended` | `strict` |
|:--|:-:|:-:|:-:|
| [`license_header`](#rule-license-header) | | ✓ | ✓ |
| [`one_public_type_per_file`](#rule-one-public-type-per-file) | | ✓ | |
| [`file_named_after_type`](#rule-file-named-after-type) | | ✓ | ✓ |
| [`one_type_per_file`](#rule-one-type-per-file) | | | ✓ |
| [`public_docs`](#rule-public-docs) | | | ✓ |
| [`private_docs`](#rule-private-docs) | | | ✓ |
| [`no_comments`](#rule-no-comments) | | | ✓ |
| [`no_else`](#rule-no-else) | | | ✓ |
| [`no_default_case`](#rule-no-default-case) | | | ✓ |
| [`no_wildcard_case`](#rule-no-wildcard-case) | | | ✓ |
| [`no_late`](#rule-no-late) | | | ✓ |
| [`no_platform_imports`](#rule-no-platform-imports) | | | |
| [`no_material`](#rule-no-material) | | | |
| [`no_wall_clock`](#rule-no-wall-clock) | | | |

`recommended` is meant for every package, Flutter apps included: a widget and its private `State` share a file, and
documentation of the public API is left to the analyzer lint `public_member_api_docs`. `strict` is a house style -
the one %product% follows itself - with one type per file including private ones and documentation everywhere.
`one_public_type_per_file` is not part of `strict`, since `one_type_per_file` already covers it.

`no_platform_imports` is part of no preset, since a command line tool imports `dart:io` by nature;
`rules: {no_platform_imports: true}` switches it on for a library that runs on every platform.
`no_material` is for a Flutter design system of its own, and `no_wall_clock` for code that takes its time from an
injected clock; neither fits every package, so both are switched on one by one as well.

`license_header` runs only when `license_header` names a template. Custom rules run in every preset unless `rules`
switches them off. To start small, take `preset: none` and switch rules on one by one.

## Rules

<deflist type="wide">
    <def title="license_header" id="rule-license-header">
        Every file starts with the header of the <a href="#license-header">template</a>. Reported on line 1.
    </def>
    <def title="public_docs" id="rule-public-docs">
        Every public class, mixin, enum and enum value, extension, extension type, typedef, top level function and
        variable, constructor, method, getter, setter, operator and field has a <code>///</code> comment. Unlike
        the lint <code>public_member_api_docs</code>, it also covers files under <code>lib/src</code>,
        <code>bin</code>, <code>test</code> and <code>tool</code>.
    </def>
    <def title="private_docs" id="rule-private-docs">
        The same for private declarations: names starting with <code>_</code>, members of private types and of
        unnamed extensions. Local functions and variables never need documentation.
    </def>
    <def title="one_type_per_file" id="rule-one-type-per-file">
        A file declares at most one class, mixin, enum, extension, extension type or typedef. A sealed class and its
        direct subtypes count as one, since the language requires them to share a library. Functions and variables
        are not counted.
    </def>
    <def title="one_public_type_per_file" id="rule-one-public-type-per-file">
        A file declares at most one public type; private helpers may live next to it, such as the
        <code>State</code> of a <code>StatefulWidget</code>. A sealed class and its direct subtypes count as one.
    </def>
    <def title="file_named_after_type" id="rule-file-named-after-type">
        A file with one type, or with one public type next to private ones, is named after it in snake case:
        <code>UserRepository</code> in <code>user_repository.dart</code>, <code>HTTPClient</code> in
        <code>http_client.dart</code>. <code>part of</code> files are exempt.
    </def>
    <def title="no_comments" id="rule-no-comments">
        No comments except <code>///</code> documentation and the license header; without a template, a block
        comment at the very start of the file counts as the header. <code>// ignore:</code> and
        <code>// inspectra: ignore-style</code> are comments as well, so this rule leaves exceptions to
        <code>exclude</code>.
    </def>
    <def title="no_else" id="rule-no-else">
        No <code>else</code> in <code>if</code> statements and collection <code>if</code> elements: return early, or
        write two elements.
    </def>
    <def title="no_default_case" id="rule-no-default-case">
        No <code>default</code> in <code>switch</code> statements, so that a new enum value or subtype is a compile
        error until every switch handles it.
    </def>
    <def title="no_wildcard_case" id="rule-no-wildcard-case">
        No <code>_</code> case in <code>switch</code> statements and expressions - the pattern form of
        <code>default</code>.
    </def>
    <def title="no_late" id="rule-no-late">
        No <code>late</code> field, top level or local variable, so that no read can fail with a
        <code>LateInitializationError</code>: initialise a variable where it is declared or in an initialiser
        list, or make the deferred value explicit. A variable merely named <code>late</code> is not reported.
    </def>
    <def title="no_platform_imports" id="rule-no-platform-imports">
        Nothing under <code>lib/</code> imports or exports a platform library - <code>dart:io</code>,
        <code>dart:ffi</code>, <code>dart:isolate</code>, <code>dart:html</code>, <code>dart:js_interop</code> and
        the other libraries that exist on some platforms only - except a variant a conditional import chooses, a
        file whose name ends in <code>_io</code>, <code>_native</code> or <code>_web</code>.
        <code>dart:mirrors</code> is refused everywhere. Files outside <code>lib/</code> are not checked.
    </def>
    <def title="no_material" id="rule-no-material">
        No file imports or exports <code>package:flutter/material.dart</code>,
        <code>package:flutter/cupertino.dart</code> or a library under <code>package:flutter/src/material/</code> or
        <code>package:flutter/src/cupertino/</code>, tests and tools included. A design system of its own is built on
        <code>package:flutter/widgets.dart</code> and the libraries below it; a single Material widget brings a
        second theme that its own theme does not reach.
    </def>
    <def title="no_wall_clock" id="rule-no-wall-clock">
        No <code>DateTime.now()</code>, called or torn off, with or without an import prefix or <code>new</code>, in
        any file: time comes from an injected clock, so that a test decides what time it is. The tree is not
        resolved, so a class of the package that is itself named <code>DateTime</code> is reported too.
    </def>
</deflist>

## The license header {id="license-header"}

`license_header` names a text file of the package that holds the header exactly as it must appear:

```text
/*
 * Copyright {year} Acme Corporation
 *
 * SPDX-License-Identifier: Apache-2.0
 */
```

- `{year}` matches any four digit year and a range such as `2020-2026`, so the template does not change every year.
- Line endings and trailing white space are ignored; everything else must match.
- A file may start with a `#!` line, for scripts under `bin/`, and a byte order mark before the header.
- A missing template is an error (`65`), not a silently skipped rule.

## Exceptions in the code {id="ignore"}

```dart
// inspectra: ignore-style no_else
if (cached) { return value; } else { return load(); }

final legacy = <int>[if (a) 1 else 2]; // inspectra: ignore-style no_else

// inspectra: ignore-style-file public_docs, one_type_per_file
```

- On a line of its own, the comment covers the next line; at the end of a line, that line.
- `ignore-style-file` covers the whole file, wherever it stands.
- Rules are always named; several are separated by commas. There is no "ignore everything".

Exceptions for whole directories belong in `exclude`. With `no_comments` on - as in `strict` - an ignore comment is a
violation itself, so `exclude` is the only way out.

## Existing violations {id="baseline"}

To introduce the check into a code base with many violations, record them once with
`dart run inspectra baseline create --only style` and commit `inspectra-baseline.json`: `style`, `check` and the
builder then fail only on new violations, while a moved violation stays covered. See [Baseline](Baseline.md).

## Running it

<tabs group="run">
    <tab title="Command line" group-key="cli">
        <code-block lang="bash"><![CDATA[
dart run inspectra style                         # check
dart run inspectra style -f sarif -o style.sarif # for GitHub code scanning
dart run inspectra check                         # includes it when style.enabled
]]></code-block>
    </tab>
    <tab title="build_runner" group-key="build">
        <code-block lang="yaml"><![CDATA[
inspectra:
  style:
    enabled: true
    run_on_build: true
]]></code-block>
        <code-block lang="bash"><![CDATA[
dart run build_runner build
]]></code-block>
    </tab>
</tabs>

The builder reads the checked files and the header template through `build_runner`, so it reruns exactly when one of
them changes, and writes `inspectra/style.json` to the artifact tree.

### Output

```text
Style: 3 violation(s) in 2 of 41 file(s).
  lib/src/cache.dart:12:5: No else: return early instead. [no_else]
  lib/src/cache.dart:30:1: One public type per file: move CacheEntry out of the file that declares Cache. [one_public_type_per_file]
  lib/src/http.dart:1:1: The file must start with the license header of tool/license_header.txt. [license_header]
Fix them, or suppress a single line with "// inspectra: ignore-style <rule>".
```

Each line has the form `file:line:column: message [rule]`, which editors and CI logs link to. The command line also
writes `.dart_tool/inspectra/style.json`:

```json
{
  "check": "style",
  "failed": true,
  "checked": 41,
  "rules": ["license_header", "one_public_type_per_file", "file_named_after_type"],
  "violations": [
    { "rule": "no_else", "path": "lib/src/cache.dart", "line": 12, "column": 5, "message": "No else: return early instead." }
  ]
}
```

`-f json` prints the same with the report envelope and the violations as `findings` of the source `style`. In SARIF,
style findings are tagged `maintainability` and carry no security severity, so GitHub code scanning shows them as
quality annotations, not as security alerts.

| Result | Exit code |
|:--|:--|
| No violation, or `fail_on_findings: false` | `0` |
| Violations | `1` (`0` with `--exit-zero`) |
| A missing header template or custom rule file, custom rules that do not compile, an unknown rule in `rules` | `65` |
| `dart` cannot be started for custom rules | `69` |

<seealso>
    <category ref="quality">
        <a href="Style-Custom-Rules.md">Custom style rules</a>
        <a href="Lint-Check.md">Lint check</a>
        <a href="Lint-Preset.md">Lint preset</a>
        <a href="Format-Check.md">Format check</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#style">Command line reference</a>
        <a href="Configuration-Reference.md#style">Configuration reference</a>
    </category>
</seealso>
