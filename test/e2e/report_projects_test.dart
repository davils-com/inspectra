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

/// Runs `inspectra report` across a folder of several projects in-process.
void main() {
  final harnesses = <TestHarness>[];

  tearDown(() {
    for (final harness in harnesses) {
      harness.dispose();
    }
    harnesses.clear();
  });

  const dirty = '''
int f(bool a) {
  if (a) {
    return 1;
  } else {
    return 2;
  }
}
''';

  /// Creates a folder without a pubspec of its own holding the package
  /// `app` with a style finding, the pub workspace `ws` with its member
  /// `ws/member`, packages in skipped folders and [files].
  TestHarness folder([Map<String, String> files = const <String, String>{}]) {
    final harness = TestHarness.withFiles(<String, String>{
      'app/pubspec.yaml':
          'name: app\nversion: 1.0.0\npublish_to: none\n'
          'inspectra:\n  style:\n    enabled: true\n'
          '    rules:\n      no_else: true\n',
      'app/lib/app.dart': dirty,
      'app/.dart_tool/cache/pubspec.yaml': 'name: cached\n',
      'app/build/out/pubspec.yaml': 'name: built\n',
      'coverage/pubspec.yaml': 'name: measured\n',
      'ws/pubspec.yaml': 'name: ws\npublish_to: none\nworkspace:\n  - member\n',
      'ws/tool/run.dart': 'void main() {}\n',
      'ws/member/pubspec.yaml':
          'name: member\nversion: 2.0.0\npublish_to: none\n'
          'resolution: workspace\n',
      'ws/member/lib/member.dart': 'int f() => 1;\n',
      ...files,
    });
    harnesses.add(harness);
    return harness;
  }

  /// Returns the JSON document at [path] in the folder of [harness].
  Map<String, Object?> json(TestHarness harness, String path) =>
      jsonDecode(File('${harness.workingDirectory}/$path').readAsStringSync())
          as Map<String, Object?>;

  /// Returns the projects of the multi-project [report] by their path.
  Map<String, Map<String, Object?>> projects(Map<String, Object?> report) =>
      <String, Map<String, Object?>>{
        for (final Object? project in report['projects']! as List<Object?>)
          if (project case {'path': final String path})
            path: project as Map<String, Object?>,
      };

  test('reports every project below a folder without a pubspec', () async {
    final TestHarness harness = folder();
    final int code = await harness.run(<String>[
      'report',
      '--skip',
      'scan',
      '-f',
      'html',
      '-o',
      'out/report.html',
      '--also',
      'json=out/report.json',
      '--also',
      'junit=out/junit.xml',
    ]);
    expect(code, 1, reason: harness.err);
    final Map<String, Object?> report = json(harness, 'out/report.json');
    expect(report['command'], 'report');
    expect(report['status'], 'failed');
    final Map<String, Map<String, Object?>> byPath = projects(report);
    expect(byPath.keys, <String>['app', 'ws', 'ws/member']);
    expect(byPath['app']?['project'], 'app 1.0.0');
    expect(byPath['app']?['status'], 'failed');
    expect(byPath['ws/member']?['status'], 'passed');
    final Object? codebase =
        (byPath['ws']!['sections']! as List<Object?>).first;
    expect(codebase, containsPair('id', 'codebase'));
    final areas = <Object?>[
      if (codebase case {'details': {'areas': final List<Object?> listed}})
        for (final Object? area in listed)
          if (area case {'name': final Object? name}) name,
    ];
    expect(areas, <Object?>['tool']);
    final findings = report['findings']! as List<Object?>;
    expect(findings.first, containsPair('file', 'app/lib/app.dart'));
    final String html = File('${harness.workingDirectory}/out/report.html')
        .readAsStringSync();
    expect(html, contains('id="project-ws-member"'));
    expect(html, contains('app/lib/app.dart'));
    expect(harness.err, contains('Reporting ws/member (3 of 3)'));
    expect(
      File('${harness.workingDirectory}/out/junit.xml').readAsStringSync(),
      contains('app · Style'),
    );
  });

  test('prints one line per project', () async {
    final TestHarness harness = folder();
    expect(await harness.run(<String>['report', '--skip', 'scan']), 1);
    expect(harness.out, contains('[FAILED]  app'));
    expect(harness.out, contains('    [FAILED]  Style'));
    expect(harness.out, contains('[PASSED]  ws/member'));
    expect(harness.out, contains('in 3 project(s).'));
  });

  test('warns about the configuration of each project', () async {
    final TestHarness harness = folder(<String, String>{
      'ws/member/inspectra.yaml':
          'ignore:\n  - id: X\n    reason: Old.\n    expires: 2020-01-01\n',
    });
    await harness.run(<String>['report', '--skip', 'scan', '-q']);
    expect(
      harness.err,
      contains('ws/member: The ignore rule for X expired on 2020-01-01'),
    );
  });

  test('--recursive includes a package folder and its members', () async {
    final TestHarness harness = folder(<String, String>{
      'pubspec.yaml': 'name: top\npublish_to: none\n',
    });
    expect(
      await harness.run(<String>['report', '--skip', 'scan', '-f', 'json']),
      0,
      reason: harness.err,
    );
    expect((jsonDecode(harness.out) as Map<String, Object?>)['project'], 'top');
    (harness.context.out as StringBuffer).clear();
    expect(
      await harness.run(<String>[
        'report',
        '-r',
        '--skip',
        'scan',
        '-f',
        'json',
      ]),
      1,
    );
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(projects(report).keys, <String>['.', 'app', 'ws', 'ws/member']);
    expect(projects(report)['.']?['project'], 'top');
  });

  test('--no-recursive reports the folder itself', () async {
    final TestHarness harness = folder();
    await harness.run(<String>[
      'report',
      '--no-recursive',
      '--skip',
      'scan',
      '-f',
      'json',
    ]);
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report, contains('sections'));
    expect(report, isNot(contains('projects')));
  });

  test(
    'a project that cannot be configured does not stop the others',
    () async {
      final TestHarness harness = folder(<String, String>{
        'broken/pubspec.yaml': 'name: broken\ninspectra:\n  fail_on: nope\n',
      });
      final int code = await harness.run(<String>[
        'report',
        '--skip',
        'scan',
        '-f',
        'json',
        '-o',
        'report.json',
      ]);
      expect(code, 69);
      expect(
        harness.err,
        contains('The report is incomplete: Configuration of broken'),
      );
      final Map<String, Map<String, Object?>> byPath = projects(
        json(harness, 'report.json'),
      );
      expect(byPath.keys, <String>['app', 'broken', 'ws', 'ws/member']);
      expect(byPath['broken']?['status'], 'error');
      expect(byPath['ws/member']?['status'], 'passed');
    },
  );

  test('rejects --recursive with --merge or without projects', () async {
    final TestHarness harness = folder();
    expect(
      await harness.run(<String>['report', '-r', '--merge', 'a.json']),
      64,
    );
    expect(harness.err, contains('cannot be combined with --merge'));
    final empty = TestHarness.withFiles(<String, String>{'README.md': '#\n'});
    harnesses.add(empty);
    expect(await empty.run(<String>['report', '--recursive']), 65);
    expect(empty.err, contains('No Dart package with a pubspec.yaml found'));
  });
}
