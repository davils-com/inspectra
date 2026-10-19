/*
 * Copyright 2026 Davils
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/// Runs custom style rules through the generated host program, in a real
/// package that depends on this checkout of Inspectra.
@Tags(['slow'])
library;

import 'dart:io';

import 'package:inspectra/src/util/dart_tool.dart';
import 'package:test/test.dart';

import '../support/fixture.dart';
import '../support/test_harness.dart';

/// Tests custom rules end to end.
void main() {
  final root = Fixture<Directory>();

  setUpAll(() async {
    root.value = Directory.systemTemp.createTempSync('style_custom_');
    final String inspectra = Directory.current.absolute.path.replaceAll(
      r'\',
      '/',
    );
    _write(root.value, 'pubspec.yaml', '''
name: demo
environment:
  sdk: ^3.13.4
dev_dependencies:
  analyzer: any
  inspectra:
    path: $inspectra
inspectra:
  style:
    preset: none
    custom_rules: [tool/style_rules.dart]
''');
    _write(root.value, 'tool/style_rules.dart', _rules);
    _write(root.value, 'lib/demo.dart', '''
void greet() {
  print('hello');
  print('ignored'); // inspectra: ignore-style no_print
}
''');
    final ProcessResult result = await runDart(<String>[
      'pub',
      'get',
      '--offline',
    ], workingDirectory: root.value.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  tearDownAll(() => root.value.deleteSync(recursive: true));

  /// Runs `inspectra style` with [arguments] in the package.
  Future<(int, TestHarness)> style(List<String> arguments) async {
    final harness = TestHarness(workingDirectory: root.value.path);
    final int code = await harness.run(<String>['style', ...arguments]);
    return (code, harness);
  }

  test('reports the violations of custom rules', () async {
    final (int code, TestHarness harness) = await style(const <String>[]);
    expect(code, 1, reason: harness.err);
    expect(
      harness.out,
      contains('lib/demo.dart:2:3: Use a logger instead of print. [no_print]'),
    );
    expect(harness.out, isNot(contains('demo.dart:3')));
    expect(harness.out, contains('Style: 1 violation(s)'));
  });

  test('switches custom rules off and rejects unknown ones', () async {
    final (int off, TestHarness quiet) = await style(const <String>[
      '--set',
      'style.rules.no_print=false',
    ]);
    expect(off, 0, reason: quiet.err);
    expect(quiet.out, contains('follow the 0 rule(s)'));
    _write(
      root.value,
      'inspectra.yaml',
      'style:\n  custom_rules: [tool/style_rules.dart]\n'
          '  rules: {no_printing: false}\n',
    );
    final (int unknown, TestHarness typo) = await style(const <String>[]);
    File('${root.value.path}/inspectra.yaml').deleteSync();
    expect(unknown, 65);
    expect(typo.err, contains('style.rules.no_printing'));
  });

  test('explains rule files that do not compile', () async {
    _write(root.value, 'tool/broken_rules.dart', 'final rules = 1;\n');
    final (int code, TestHarness harness) = await style(const <String>[
      '--set',
      'style.custom_rules=tool/broken_rules.dart',
    ]);
    expect(code, 65);
    expect(harness.err, contains('styleRules'));
  });
}

/// Writes [content] to the file [path] below [root].
void _write(Directory root, String path, String content) {
  File('${root.path}/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);
}

/// A custom rule file that reports calls of `print`.
const _rules = '''
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:inspectra/style.dart';

final styleRules = <StyleRule>[const NoPrintRule()];

final class NoPrintRule extends StyleRule {
  const NoPrintRule();

  @override
  String get id => 'no_print';

  @override
  String get description => 'Use a logger instead of print.';

  @override
  void check(StyleFile file, StyleReporter reporter) =>
      file.unit.accept(_PrintFinder(reporter));
}

final class _PrintFinder extends RecursiveAstVisitor<void> {
  _PrintFinder(this.reporter);

  final StyleReporter reporter;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == 'print') {
      reporter.reportAt(node, 'Use a logger instead of print.');
    }
    super.visitMethodInvocation(node);
  }
}
''';
