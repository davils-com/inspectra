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

import 'package:coverage/coverage.dart';
import 'package:inspectra/inspectra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Tests the further runs of `coverage.merge`: their configuration, how
/// their hits are merged, how the report shows them, and a real merged run.
void main() {
  group('coverage.merge', () {
    test('is empty by default', () {
      expect(InspectraConfig.defaults('demo').coverage.merge, isEmpty);
    });

    test('reads every run with its arguments', () {
      final config = InspectraConfig.parse({
        'coverage': {
          'merge': [
            {
              'name': 'native',
              'test_arguments': ['-P', 'native'],
            },
            {
              'name': 'chrome',
              'test_arguments': ['--platform', 'chrome', '--concurrency', 2],
            },
            {'name': 'all'},
          ],
        },
      }, packageName: 'demo');

      final List<CoverageRun> runs = config.coverage.merge;
      expect(runs.map((run) => run.name), ['native', 'chrome', 'all']);
      expect(runs[0].testArguments, ['-P', 'native']);
      expect(runs[1].testArguments, [
        '--platform',
        'chrome',
        '--concurrency',
        '2',
      ]);
      expect(runs[2].testArguments, isEmpty);
    });

    test('adds the runs of every layer', () {
      final String root = temporaryDirectory();
      writeFile(root, 'base.yaml', 'coverage:\n  merge:\n    - name: native\n');
      writeFile(
        root,
        'pubspec.yaml',
        'name: demo\ninspectra:\n  extends: base.yaml\n  coverage:\n'
            '    merge:\n      - name: chrome\n',
      );

      final InspectraConfig config = loadConfig(root);

      expect(config.coverage.merge.map((run) => run.name), [
        'native',
        'chrome',
      ]);
    });

    test('rejects anything but a list of runs', () {
      expect(_rejection('chrome').path, 'coverage.merge');
      expect(_rejection(['chrome']).path, 'coverage.merge[0]');
    });

    test('rejects a run without a usable name', () {
      expect(_rejection([<String, Object?>{}]).path, 'coverage.merge[0].name');
      expect(
        _rejection([
          {'name': '../up'},
        ]).path,
        'coverage.merge[0].name',
      );
      expect(
        _rejection([
          {'name': 'Chrome'},
        ]).path,
        'coverage.merge[0].name',
      );
    });

    test('rejects malformed arguments', () {
      expect(
        _rejection([
          {'name': 'chrome', 'test_arguments': '--platform chrome'},
        ]).path,
        'coverage.merge[0].test_arguments',
      );
      expect(
        _rejection([
          {
            'name': 'chrome',
            'test_arguments': [''],
          },
        ]).path,
        'coverage.merge[0].test_arguments',
      );
    });

    test('rejects an unknown option and suggests the known one', () {
      final InspectraConfigException error = _rejection([
        {'name': 'chrome', 'test_argument': <String>[]},
      ]);

      expect(error.path, 'coverage.merge[0].test_argument');
      expect(error.message, contains('test_arguments'));
    });

    test('rejects two runs of the same name', () {
      expect(
        _rejection([
          {'name': 'chrome'},
          {'name': 'chrome'},
        ]).path,
        'coverage.merge[1].name',
      );
    });
  });

  group('mergeCoverageHits', () {
    test('adds up the hits of complete runs and keeps every line', () {
      final ({Map<String, HitMap> files, List<String> incompleteOnly}) merged =
          mergeCoverageHits([
            CoverageHits({
              '/p/lib/a.dart': HitMap({1: 1, 2: 0}),
            }, complete: true),
            CoverageHits({
              '/p/lib/a.dart': HitMap({2: 3, 3: 0}),
              '/p/lib/b.dart': HitMap({5: 1}),
            }, complete: true),
          ]);

      expect(merged.files['/p/lib/a.dart']?.lineHits, {1: 1, 2: 3, 3: 0});
      expect(merged.files['/p/lib/b.dart']?.lineHits, {5: 1});
      expect(merged.incompleteOnly, isEmpty);
    });

    test('counts the hits of an incomplete run only on known lines', () {
      final ({Map<String, HitMap> files, List<String> incompleteOnly}) merged =
          mergeCoverageHits([
            CoverageHits({
              '/p/lib/a.dart': HitMap({2: 0, 4: 0, 6: 1}),
            }, complete: true),
            CoverageHits({
              '/p/lib/a.dart': HitMap({2: 1, 5: 1, 6: 2}),
            }, complete: false),
          ]);

      expect(merged.files['/p/lib/a.dart']?.lineHits, {2: 1, 4: 0, 6: 3});
    });

    test('lists the files only an incomplete run loaded, sorted', () {
      final ({Map<String, HitMap> files, List<String> incompleteOnly}) merged =
          mergeCoverageHits([
            CoverageHits({
              '/p/lib/z_web.dart': HitMap({1: 1}),
              '/p/lib/a_web.dart': HitMap({1: 1}),
            }, complete: false),
            CoverageHits({
              '/p/lib/a.dart': HitMap({1: 1}),
            }, complete: true),
            CoverageHits({
              '/p/lib/a_web.dart': HitMap({2: 1}),
            }, complete: false),
          ]);

      expect(merged.files.keys, ['/p/lib/a.dart']);
      expect(merged.incompleteOnly, ['/p/lib/a_web.dart', '/p/lib/z_web.dart']);
    });

    test('leaves the hit maps of the runs unchanged', () {
      final first = HitMap({1: 1});
      final second = HitMap({1: 2});

      mergeCoverageHits([
        CoverageHits({'/p/lib/a.dart': first}, complete: true),
        CoverageHits({'/p/lib/a.dart': second}, complete: true),
        CoverageHits({
          '/p/lib/a.dart': HitMap({1: 5}),
        }, complete: false),
      ]);

      expect(first.lineHits, {1: 1});
      expect(second.lineHits, {1: 2});
    });
  });

  group('CoverageReport', () {
    test('lists the files only a browser loaded apart', () {
      final report = CoverageReport(
        files: [const FileCoverage('lib/a.dart', 4, 4)],
        untested: const [],
        browserOnly: const ['lib/src/fetch_web.dart'],
        lcovPath: 'coverage/lcov.info',
        minLineCoverage: null,
      );

      expect(report.percent, 100);
      expect(
        report.render(),
        allOf(
          contains('1 file(s) were only loaded in a browser'),
          contains('lib/src/fetch_web.dart'),
        ),
      );
    });

    test('says nothing about browsers without such files', () {
      final report = CoverageReport(
        files: [const FileCoverage('lib/a.dart', 4, 4)],
        untested: const [],
        lcovPath: 'coverage/lcov.info',
        minLineCoverage: null,
      );

      expect(report.browserOnly, isEmpty);
      expect(report.render(), isNot(contains('browser')));
    });
  });

  test('runCoverage merges the hits of a further run', () async {
    final String root = temporaryDirectory();
    writeFile(
      root,
      'pubspec.yaml',
      'name: demo\nenvironment:\n  sdk: ^3.0.0\n'
          'dev_dependencies:\n  test: any\n',
    );
    writeFile(
      root,
      'lib/demo.dart',
      'int twice(int value) {\n  return value * 2;\n}\n\n'
          'int thrice(int value) {\n  return value * 3;\n}\n',
    );
    writeFile(
      root,
      'test/twice_test.dart',
      "import 'package:demo/demo.dart';\n"
          "import 'package:test/test.dart';\n\n"
          "void main() => test('twice', () => expect(twice(2), 4));\n",
    );
    writeFile(
      root,
      'test/thrice_test.dart',
      "@Tags(['extra'])\nlibrary;\n\n"
          "import 'package:demo/demo.dart';\n"
          "import 'package:test/test.dart';\n\n"
          "void main() => test('thrice', () => expect(thrice(2), 6));\n",
    );
    writeFile(root, 'dart_test.yaml', 'tags:\n  extra:\n');
    final ProcessResult resolved = await Process.run(
      Platform.resolvedExecutable,
      ['pub', 'get', '--offline'],
      workingDirectory: root,
    );
    expect(resolved.exitCode, 0, reason: '${resolved.stderr}');
    final config = InspectraConfig.parse({
      'coverage': {
        'enabled': true,
        'test_arguments': ['--exclude-tags', 'extra'],
        'merge': [
          {
            'name': 'extra',
            'test_arguments': ['--tags', 'extra'],
          },
        ],
      },
    }, packageName: 'demo');

    final CoverageReport report = await runCoverage(config.coverage, root);

    expect(report.files.single.path, 'lib/demo.dart');
    expect(report.files.single.linesHit, report.files.single.linesFound);
    expect(report.browserOnly, isEmpty);
    expect(
      Directory(p.join(root, 'coverage', 'merge', 'extra')).existsSync(),
      isTrue,
    );
  }, tags: ['slow']);

  test('runCoverage skips the empty report of a suite a tag skips', () async {
    final String root = temporaryDirectory();
    writeFile(
      root,
      'pubspec.yaml',
      'name: demo\nenvironment:\n  sdk: ^3.0.0\n'
          'dev_dependencies:\n  test: any\n',
    );
    writeFile(
      root,
      'lib/demo.dart',
      'int twice(int value) {\n  return value * 2;\n}\n\n'
          'int thrice(int value) {\n  return value * 3;\n}\n',
    );
    writeFile(
      root,
      'test/twice_test.dart',
      "import 'package:demo/demo.dart';\n"
          "import 'package:test/test.dart';\n\n"
          "void main() => test('twice', () => expect(twice(2), 4));\n",
    );
    writeFile(
      root,
      'test/thrice_test.dart',
      "@Tags(['extra'])\nlibrary;\n\n"
          "import 'package:demo/demo.dart';\n"
          "import 'package:test/test.dart';\n\n"
          "void main() => test('thrice', () => expect(thrice(2), 6));\n",
    );
    writeFile(
      root,
      'dart_test.yaml',
      'tags:\n  extra:\n    skip: Runs in the extra run only.\n',
    );
    final ProcessResult resolved = await Process.run(
      Platform.resolvedExecutable,
      ['pub', 'get', '--offline'],
      workingDirectory: root,
    );
    expect(resolved.exitCode, 0, reason: '${resolved.stderr}');
    final config = InspectraConfig.parse({
      'coverage': {
        'enabled': true,
        'merge': [
          {
            'name': 'extra',
            'test_arguments': ['--tags', 'extra', '--run-skipped'],
          },
        ],
      },
    }, packageName: 'demo');

    final CoverageReport report = await runCoverage(config.coverage, root);

    expect(report.files.single.path, 'lib/demo.dart');
    expect(report.files.single.linesHit, report.files.single.linesFound);
    expect(report.browserOnly, isEmpty);
    expect(
      Directory(p.join(root, 'coverage', 'merge', 'extra')).existsSync(),
      isTrue,
    );
  }, tags: ['slow']);
}

/// Parses a configuration whose `coverage.merge` is [merge].
///
/// Returns the error the parse failed with.
///
/// Throws a [StateError] when the configuration was accepted.
InspectraConfigException _rejection(Object? merge) {
  try {
    InspectraConfig.parse({
      'coverage': {'merge': merge},
    }, packageName: 'demo');
  } on InspectraConfigException catch (error) {
    return error;
  }
  throw StateError('the configuration was accepted');
}
