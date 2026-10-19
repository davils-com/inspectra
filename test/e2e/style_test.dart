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

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../support/test_harness.dart';

/// Runs `inspectra style` and the style step of `check` in-process.
void main() {
  final harnesses = <TestHarness>[];

  tearDown(() {
    for (final harness in harnesses) {
      harness.dispose();
    }
    harnesses.clear();
  });

  /// Creates a package with the `style:` section [style] and [files].
  TestHarness project(String style, Map<String, String> files) {
    final harness = TestHarness.withFiles(<String, String>{
      'pubspec.yaml': 'name: demo\ninspectra:\n  style:\n$style',
      ...files,
    });
    harnesses.add(harness);
    return harness;
  }

  const clean = '''
// Copyright 2026 Demo

/// A greeter.
final class Greeter {
  /// Creates a greeter.
  const Greeter();
}
''';

  const dirty = '''
class Other {
  int f(bool a) {
    if (a) {
      return 1;
    } else {
      return 2;
    }
  }
}
''';

  test('passes a clean package', () async {
    final TestHarness harness = project(
      '    preset: strict\n    license_header: tool/header.txt\n',
      <String, String>{
        'tool/header.txt': '// Copyright {year} Demo\n',
        'lib/greeter.dart': clean,
      },
    );
    expect(await harness.run(<String>['style']), 0, reason: harness.err);
    expect(harness.out, 'Style: all 1 file(s) follow the 10 rule(s).\n');
    final report = File(
      '${harness.workingDirectory}/.dart_tool/inspectra/style.json',
    );
    expect(report.existsSync(), isTrue);
  });

  test('fails with every violation and reports JSON and SARIF', () async {
    final TestHarness harness = project(
      '    preset: strict\n',
      <String, String>{'lib/greeter.dart': dirty},
    );
    expect(await harness.run(<String>['style']), 1);
    expect(
      harness.out,
      allOf(
        contains(
          'lib/greeter.dart:1:1: The file declaring Other must be named '
          'other.dart. [file_named_after_type]',
        ),
        contains('[no_else]'),
        contains('[public_docs]'),
      ),
    );
    expect(await harness.run(<String>['style', '--exit-zero']), 0);
    expect(await harness.run(<String>['style', '-f', 'json']), 1);
    final json = jsonDecode(
      harness.out.substring(harness.out.indexOf('{\n')),
    ) as Map<String, Object?>;
    expect(json['command'], 'style');
    expect(json['check'], 'style');
    expect(json['violations'], isNotEmpty);
    expect(json['findings'], isNotEmpty);
    expect(
      await harness.run(<String>['style', '-f', 'sarif', '-o', 'style.sarif']),
      1,
    );
    expect(
      File('${harness.workingDirectory}/style.sarif').readAsStringSync(),
      contains('"maintainability"'),
    );
  });

  test('honours fail_on_findings, rules and --set', () async {
    final TestHarness harness = project(
      '    preset: none\n    fail_on_findings: false\n'
      '    rules: {no_else: true}\n',
      <String, String>{'lib/other.dart': dirty},
    );
    expect(await harness.run(<String>['style']), 0);
    expect(harness.out, contains('(not failing)'));
    expect(
      await harness.run(<String>[
        'style',
        '--set',
        'style.rules.no_else=false',
      ]),
      0,
    );
    expect(harness.out, endsWith('follow the 0 rule(s).\n'));
  });

  test('exits with 65 for a missing header template or rule file', () async {
    final TestHarness header = project(
      '    license_header: tool/missing.txt\n',
      <String, String>{'lib/greeter.dart': clean},
    );
    expect(await header.run(<String>['style']), 65);
    expect(header.err, contains('tool/missing.txt'));
    final TestHarness rules = project(
      '    enabled: true\n    custom_rules: [tool/missing.dart]\n',
      <String, String>{'lib/greeter.dart': clean},
    );
    expect(await rules.run(<String>['style']), 65);
    expect(await rules.run(<String>['check']), 65);
  });

  test('runs as part of check when enabled', () async {
    final TestHarness harness = project(
      '    enabled: true\n    preset: strict\n',
      <String, String>{'lib/other.dart': dirty},
    );
    expect(await harness.run(<String>['check']), 1);
    expect(harness.out, contains('Style: '));
  });
}
