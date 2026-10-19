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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/style/style_host.dart';
import 'package:inspectra/style.dart';
import 'package:test/test.dart';

import '../support/fixture.dart';
import '../support/named_rule.dart';
import '../support/no_print_rule.dart';

/// Tests the program that runs custom rules.
void main() {
  final root = Fixture<Directory>();

  setUp(() => root.value = Directory.systemTemp.createTempSync('style_host_'));
  tearDown(() => root.value.deleteSync(recursive: true));

  /// Writes a request for [files] with the [disabled] rules and runs
  /// [rules] in-process.
  Future<Map<String, Object?>> host(
    List<StyleRule> rules, {
    List<String> files = const <String>['lib/a.dart'],
    List<String> disabled = const <String>[],
  }) async {
    final request = File('${root.value.path}/request.json');
    final answer = File('${root.value.path}/answer.json');
    request.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'root': root.value.path,
        'files': files,
        'disabled': disabled,
        'output': answer.path,
      }),
    );
    await runStyleHost(<String>[request.path], rules);
    return jsonDecode(answer.readAsStringSync()) as Map<String, Object?>;
  }

  setUp(() {
    File('${root.value.path}/lib/a.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("void f() {\n  print('x');\n}\n");
  });

  test('runs the rules that are on and lists every rule', () async {
    final Map<String, Object?> answer = await host(
      <StyleRule>[const NoPrintRule(), const NamedRule('quiet')],
      disabled: const <String>['quiet'],
    );
    expect(answer['rules'], <Object?>[
      <String, Object?>{'id': 'no_print', 'description': 'No print.'},
      <String, Object?>{'id': 'quiet', 'description': 'Quiet.'},
    ]);
    final violations = answer['violations']! as List<Object?>;
    final violation = StyleViolation.fromJson(violations.single);
    expect('$violation', 'lib/a.dart:2:3: Use a logger. [no_print]');
  });

  test('rejects invalid, duplicate and built-in rule ids', () async {
    expect(
      (await host(<StyleRule>[const NamedRule('NoPrint')]))['error'],
      contains('not lower snake case'),
    );
    expect(
      (await host(<StyleRule>[
        const NamedRule('a'),
        const NamedRule('a'),
      ]))['error'],
      contains('used more than once'),
    );
    expect(
      (await host(<StyleRule>[const NamedRule('no_else')]))['error'],
      contains('built-in rule'),
    );
  });

  test('generates a program importing every rule file', () {
    expect(
      StyleHost.hostProgram(<String>['tool/style_rules.dart', r'lib\x.dart']),
      allOf(
        contains("import 'package:inspectra/style.dart';"),
        contains("import '../../../tool/style_rules.dart' as rules0;"),
        contains("import '../../../lib/x.dart' as rules1;"),
        contains('...rules0.styleRules,'),
        contains('...rules1.styleRules,'),
      ),
    );
  });

  test('reports missing rule files before running anything', () {
    expect(
      StyleHost(root.value.path).run(
        ruleFiles: const <String>['tool/missing.dart'],
        files: const <String>[],
        disabled: const <String>{},
      ),
      throwsA(
        isA<InvalidInputException>().having(
          (error) => error.message,
          'message',
          contains('tool/missing.dart'),
        ),
      ),
    );
  });
}
