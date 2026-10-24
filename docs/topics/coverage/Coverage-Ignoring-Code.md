# Ignoring code

<primary-label ref="cli"/>
<secondary-label ref="cli-only"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Leaving lines, blocks and files out of the coverage measurement.</link-summary>

<card-summary>coverage:ignore-line, ignore-start/end and ignore-file, and when to use exclude instead.</card-summary>

Some code is not worth testing: defensive branches that cannot happen, `toString` methods for debugging, platform
glue. `package:coverage` understands three comments that leave such code out, and %product% applies them.

## The comments

<tabs group="ignore">
    <tab title="One line" group-key="line">
        <code-block lang="dart"><![CDATA[
int _private() => 0; // coverage:ignore-line
]]></code-block>
        <p>The line the comment is on is not counted.</p>
    </tab>
    <tab title="A block" group-key="block">
        <code-block lang="dart"><![CDATA[
// coverage:ignore-start
@override
String toString() {
  return 'Calculator(precision: $precision)';
}
// coverage:ignore-end
]]></code-block>
        <p>Every line from the start comment to the end comment is not counted.</p>
    </tab>
    <tab title="A file" group-key="file">
        <code-block lang="dart"><![CDATA[
// coverage:ignore-file
library;

void main() => runApp(const App());
]]></code-block>
        <p>The whole file is not counted, and it is not listed among the files no test loaded.</p>
    </tab>
</tabs>

An example, measured with `dart run %package% coverage`:

<compare first-title="Without comments" second-title="With comments">
<code-block lang="text">
  lib/src/calc.dart   40.00%  (2/5)
</code-block>
<code-block lang="text">
  lib/src/calc.dart  100.00%  (2/2)
</code-block>
</compare>

The three lines of `cube`, wrapped in `ignore-start` and `ignore-end`, and the private helper marked with
`ignore-line`, are gone from both the count and `lcov.info`.

## Comments or exclude

| Situation | Use |
|:--|:--|
| A few lines inside an otherwise tested file | `// coverage:ignore-line` or a block |
| One handwritten file that is not testable, such as `main.dart` of an app | `// coverage:ignore-file` |
| A whole category of files, typically generated code | `coverage.exclude` globs |
| A directory, such as `lib/src/generated/` | `coverage.exclude` |

Generated files cannot carry comments you write - they are overwritten - so `exclude` is the way for them. The
defaults already exclude `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` and `*.specia.dart`.

<warning>
Every ignore comment raises the reported coverage without testing anything. Keep them rare and say why next to each
one: <code>// coverage:ignore-line - unreachable, guarded by the parser</code>.
</warning>

## Flutter

With `runner: flutter`, the ignore comments are applied by Flutter's own coverage collection, as far as the Flutter
version supports them; %product% reads Flutter's `lcov.info` as it is. See [Flutter](Coverage-Flutter.md).

<seealso>
    <category ref="coverage">
        <a href="Coverage-Overview.md">Coverage</a>
        <a href="Coverage-Configuration.md#exclude">exclude</a>
    </category>
    <category ref="external">
        <a href="https://pub.dev/packages/coverage#ignore-lines-from-coverage">package:coverage ignore comments</a>
    </category>
</seealso>
