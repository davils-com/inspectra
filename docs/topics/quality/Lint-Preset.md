# Lint preset

<primary-label ref="config"/>
<secondary-label ref="opt-in"/>

<show-structure for="chapter,procedure" depth="2"/>

<link-summary>package:inspectra/lints/strict.yaml: strict analysis for Dart and Flutter in one line.</link-summary>

<card-summary>A strict, curated rule set you include with one line and adjust like any analysis options.</card-summary>

<tldr>
<p><b>Use</b>: <code>include: package:inspectra/lints/strict.yaml</code></p>
<p><b>Contains</b>: strict language modes, stricter severities, about 200 lint rules, page width 80</p>
<p><b>Adjust</b>: override anything below the include</p>
</tldr>

%product% ships the analysis configuration its own repository uses as a preset. It is the strict end of the spectrum: every rule that catches a bug or an inconsistency, and the formatting
rules that keep a code base uniform.

## Using it

```yaml
# analysis_options.yaml
include: package:inspectra/lints/strict.yaml
```

That needs %product% as a dependency, which it already is as a dev dependency. Then enable the
[lint check](Lint-Check.md) to enforce it:

```yaml
# pubspec.yaml
inspectra:
  lint:
    enabled: true
```

<note>
The preset is an ordinary <tooltip term="analysis options">analysis options</tooltip> file. Your IDE, <code>dart
analyze</code>, <code>dart fix</code> and the lint check all read it the same way - %product% is not needed to apply it,
only to enforce it.
</note>

## What it contains

<deflist type="medium">
    <def title="Strict language modes">
        <code>strict-casts</code>, <code>strict-inference</code> and <code>strict-raw-types</code>: no implicit
        downcasts from <code>dynamic</code>, no inference that silently falls back to <code>dynamic</code>, no raw
        generic types.
    </def>
    <def title="Stricter severities">
        <code>missing_required_param</code>, <code>missing_return</code>, <code>dead_code</code>,
        <code>invalid_annotation_target</code>, <code>unused_import</code>, <code>unused_local_variable</code>,
        <code>unused_element</code> and <code>unused_field</code> are errors, not warnings or hints.
    </def>
    <def title="Generated code excluded">
        <code>**/*.g.dart</code>, <code>**/*.freezed.dart</code> and <code>**/*.mocks.dart</code> are not analyzed.
        <code>**/*.specia.dart</code> is analyzed on purpose: Specia writes lint clean code, so its output is held
        to the preset, while the format check, the style check and the coverage gate leave it out.
    </def>
    <def title="Formatter">
        <code>page_width: 80</code>, which the <a href="Format-Check.md">format check</a> and <code>dart format</code>
        pick up through the include.
    </def>
    <def title="About 200 lint rules">
        Grouped below. The full list is in
        <a href="%repo%/blob/main/lib/lints/strict.yaml">lib/lints/strict.yaml</a>.
    </def>
</deflist>

### The rules, by intent

| Intent | Examples |
|:--|:--|
| Async correctness | `unawaited_futures`, `discarded_futures`, `avoid_slow_async_io`, `cancel_subscriptions`, `close_sinks` |
| Type safety | `avoid_dynamic_calls`, `cast_nullable_to_non_nullable`, `null_check_on_nullable_type_parameter`, `unsafe_variance` |
| Explicit types where they help | `specify_nonobvious_local_variable_types`, `specify_nonobvious_property_types`, `strict_top_level_inference` |
| No noise where they do not | `omit_obvious_local_variable_types`, `omit_obvious_property_types`, `unnecessary_*` |
| Immutability | `prefer_final_locals`, `prefer_final_fields`, `prefer_final_in_for_each`, `prefer_const_constructors` |
| Readable control flow | `always_put_control_body_on_new_line`, `curly_braces_in_flow_control_structures`, `prefer_expression_function_bodies` |
| Consistent style | `prefer_single_quotes`, `require_trailing_commas`, `lines_longer_than_80_chars`, `directives_ordering` |
| Imports | `always_use_package_imports`, `implementation_imports`, `depend_on_referenced_packages` |
| API hygiene | `library_private_types_in_public_api`, `avoid_positional_boolean_parameters`, `provide_deprecation_message` |
| Flutter | `use_build_context_synchronously`, `use_key_in_widget_constructors`, `sized_box_for_whitespace`, `use_colored_box` |
| No debugging leftovers | `avoid_print`, `unreachable_from_main` |

Rules that only apply to Flutter code are silent in plain Dart packages, so one preset serves both.

## Adjusting it

Everything below the `include` overrides the preset:

```yaml
include: package:inspectra/lints/strict.yaml

formatter:
  page_width: 100

analyzer:
  exclude:
    - lib/src/generated/**

linter:
  rules:
    avoid_print: false                  # a command-line tool prints
    lines_longer_than_80_chars: false   # we format at 100
    public_member_api_docs: true        # and document every public API
```

<warning>
A <code>rules:</code> section written as a list replaces nothing - it adds rules. To turn a rule of the preset off,
use the map form, <code>rule_name: false</code>, as above. A section cannot mix both forms.
</warning>

## Adopting it in an existing package

A strict preset on a code base that grew without it reports hundreds of issues at once. Adopt it in steps:

<procedure title="Introduce the preset" id="adopt">
    <step>
        <p>Include the preset and see where you stand:</p>
        <code-block lang="bash"><![CDATA[
dart run inspectra lint
]]></code-block>
    </step>
    <step>
        <p>Let the analyzer fix what it can, in its own commit:</p>
        <code-block lang="bash"><![CDATA[
dart run inspectra lint --fix
dart run inspectra format --fix
]]></code-block>
    </step>
    <step>
        <p>Gate on errors and warnings first, and work through the infos:</p>
        <code-block lang="yaml"><![CDATA[
inspectra:
  lint:
    enabled: true
    fail_on: warning
]]></code-block>
    </step>
    <step>
        <p>Turn off the rules you decide against, with <code>rule_name: false</code>.</p>
    </step>
    <step>
        <p>Switch to <code>fail_on: info</code> once the infos are gone.</p>
    </step>
</procedure>

<seealso>
    <category ref="quality">
        <a href="Lint-Check.md">Lint check</a>
        <a href="Format-Check.md">Format check</a>
    </category>
    <category ref="operations">
        <a href="Inspectra-On-Itself.md">Inspectra on itself</a>
    </category>
    <category ref="external">
        <a href="https://dart.dev/tools/analysis">Customizing static analysis</a>
        <a href="https://dart.dev/tools/linter-rules">Linter rules</a>
    </category>
</seealso>
