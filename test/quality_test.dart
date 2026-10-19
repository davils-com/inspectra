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

import 'dart:io';

import 'package:inspectra/inspectra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fixture.dart';
import 'support/fixtures.dart';

/// A Dart file that `dart format` leaves unchanged.
const _formatted = 'void main() {\n  print(1);\n}\n';

/// A Dart file that `dart format` would change.
const _unformatted = 'void  main( ) {print(1);}\n';

/// Tests the format and lint checks against temporary packages.
void main() {
  group('configuration', () {
    test('format and lint are off by default', () {
      final config = InspectraConfig.defaults('app');

      expect(config.format.enabled, isFalse);
      expect(config.format.runOnBuild, isFalse);
      expect(config.format.include, ['**.dart']);
      expect(config.format.exclude, contains('**.g.dart'));
      expect(config.format.pageWidth, isNull);
      expect(config.lint.enabled, isFalse);
      expect(config.lint.failOn, LintLevel.info);
    });

    test('reads every option', () {
      final config = InspectraConfig.parse({
        'format': {'enabled': true, 'run_on_build': true, 'page_width': 120},
        'lint': {'enabled': true, 'fail_on': 'warning'},
      }, packageName: 'app');

      expect(config.format.pageWidth, 120);
      expect(config.format.runOnBuild, isTrue);
      expect(config.lint.failOn, LintLevel.warning);
    });

    test('rejects an unknown lint level', () {
      expect(
        () => InspectraConfig.parse({
          'lint': {'fail_on': 'hint'},
        }, packageName: 'app'),
        throwsA(
          isA<InspectraConfigException>().having(
            (error) => error.path,
            'path',
            'lint.fail_on',
          ),
        ),
      );
    });

    test('rejects a page width that is not a positive whole number', () {
      expect(
        () => InspectraConfig.parse({
          'format': {'page_width': 80.5},
        }, packageName: 'app'),
        throwsA(isA<InspectraConfigException>()),
      );
    });
  });

  group('parseAnalyzerOutput', () {
    test('reads severity, code, position and message', () {
      final List<LintIssue> issues = parseAnalyzerOutput(
        'ERROR|COMPILE_TIME_ERROR|INVALID_ASSIGNMENT|/pkg/lib/a.dart|3|11|3|'
            "A value of type 'String' can't be assigned.\n"
            'INFO|LINT|PREFER_SINGLE_QUOTES|/pkg/lib/b.dart|2|5|7|Unnecessary use of '
            'double quotes.\n',
        '/pkg',
      );

      expect(issues, hasLength(2));
      expect(issues.first.severity, LintLevel.error);
      expect(issues.first.type, 'COMPILE_TIME_ERROR');
      expect(issues.first.code, 'invalid_assignment');
      expect(issues.first.path, 'lib/a.dart');
      expect(issues.first.line, 3);
      expect(issues.first.column, 11);
      expect(issues.last.severity, LintLevel.info);
      expect(issues.last.code, 'prefer_single_quotes');
    });

    test('unescapes pipes and backslashes in the message', () {
      final List<LintIssue> issues = parseAnalyzerOutput(
        r'WARNING|HINT|SOME_HINT|/pkg/lib/a.dart|1|1|1|Use a\|b or c\\d.',
        '/pkg',
      );

      expect(issues.single.message, r'Use a|b or c\d.');
    });

    test('ignores lines that are not diagnostics', () {
      expect(
        parseAnalyzerOutput('Analyzing pkg...\nNo issues found!\n', '/pkg'),
        isEmpty,
      );
    });
  });

  group('LintResult', () {
    LintIssue issue(LintLevel severity) => LintIssue(
      severity: severity,
      type: 'LINT',
      code: 'some_rule',
      path: 'lib/a.dart',
      line: 1,
      column: 1,
      message: 'Message.',
    );

    test('fails from the configured level up', () {
      final List<LintIssue> issues = [
        issue(LintLevel.warning),
        issue(LintLevel.info),
      ];

      expect(LintResult(issues: issues, failOn: LintLevel.info).failed, isTrue);
      expect(
        LintResult(issues: issues, failOn: LintLevel.warning).failed,
        isTrue,
      );
      expect(
        LintResult(issues: issues, failOn: LintLevel.error).failed,
        isFalse,
      );
      expect(
        LintResult(issues: issues, failOn: LintLevel.none).failed,
        isFalse,
      );
    });

    test('renders errors first, with their position', () {
      final String rendered = LintResult(
        issues: [issue(LintLevel.info), issue(LintLevel.error)],
        failOn: LintLevel.error,
      ).render();

      expect(
        rendered,
        startsWith(
          'Lint: 2 issue(s) - 1 error(s), 0 warning(s), 1 info(s).\n'
          '  [ERROR] lib/a.dart:1:1: some_rule - Message.',
        ),
      );
    });

    test('reports a clean analysis', () {
      expect(
        LintResult(issues: const [], failOn: LintLevel.info).render(),
        'Lint: no issues found.',
      );
    });
  });

  group('checkFormat', () {
    final root = Fixture<String>();
    final config = Fixture<FormatConfig>();

    setUp(() {
      root.value = temporaryDirectory();
      config.value = InspectraConfig.defaults('app').format;
      writeFile(root.value, 'lib/good.dart', _formatted);
      writeFile(root.value, 'lib/bad.dart', _unformatted);
    });

    test('reports the files that are not formatted', () async {
      final FormatResult result = await checkFormat(
        config: config.value,
        packageRoot: root.value,
        files: ['lib/bad.dart', 'lib/good.dart'],
      );

      expect(result.checked, 2);
      expect(result.unformatted, ['lib/bad.dart']);
      expect(result.failed, isTrue);
      expect(result.render(), contains('1 of 2 file(s) are not formatted.'));
      expect(
        File(p.join(root.value, 'lib/bad.dart')).readAsStringSync(),
        _unformatted,
      );
    });

    test('formats the files with fix', () async {
      final FormatResult result = await checkFormat(
        config: config.value,
        packageRoot: root.value,
        files: ['lib/bad.dart', 'lib/good.dart'],
        fix: true,
      );

      expect(result.fixed, isTrue);
      expect(result.failed, isFalse);
      expect(result.unformatted, ['lib/bad.dart']);
      expect(
        File(p.join(root.value, 'lib/bad.dart')).readAsStringSync(),
        _formatted,
      );
    });

    test('honours an explicit page width', () async {
      writeFile(
        root.value,
        'lib/long.dart',
        "void main() => print('a string long enough for forty columns');\n",
      );
      final FormatConfig narrow = InspectraConfig.parse({
        'format': {'page_width': 40},
      }, packageName: 'app').format;

      final FormatResult result = await checkFormat(
        config: narrow,
        packageRoot: root.value,
        files: ['lib/long.dart'],
      );

      expect(result.unformatted, ['lib/long.dart']);
    });

    test('explains a file that does not parse', () async {
      writeFile(root.value, 'lib/broken.dart', 'void main( {');

      await expectLater(
        checkFormat(
          config: config.value,
          packageRoot: root.value,
          files: ['lib/broken.dart'],
        ),
        throwsA(isA<DartToolException>()),
      );
    });
  });

  test('runLint reports the diagnostics of the package', () async {
    final String root = temporaryDirectory();
    writeFile(root, 'pubspec.yaml', 'name: app\nenvironment:\n  sdk: ^3.0.0\n');
    writeFile(
      root,
      'analysis_options.yaml',
      'linter:\n  rules:\n    - prefer_single_quotes\n',
    );
    writeFile(root, 'lib/app.dart', 'const greeting = "hello";\n');

    final LintResult result = await runLint(
      config: InspectraConfig.parse({
        'lint': {'enabled': true},
      }, packageName: 'app').lint,
      packageRoot: root,
    );

    expect(result.issues.single.code, 'prefer_single_quotes');
    expect(result.issues.single.path, 'lib/app.dart');
    expect(result.failed, isTrue);
  }, tags: ['slow']);
}
