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

/// Checks semantic versioning against a real Git repository.
///
/// Skipped when Git is not installed.
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

import '../support/fixture.dart';
import '../support/test_harness.dart';

/// Whether Git is installed; the test is skipped otherwise.
final bool _gitInstalled = () {
  try {
    return Process.runSync('git', <String>['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

/// Tests `api semver` and the semver step of `check` with real Git.
void main() {
  final directory = Fixture<Directory>();
  final harness = Fixture<TestHarness>();

  setUp(() {
    directory.value = Directory.systemTemp.createTempSync('semver_');
    harness.value = TestHarness(
      workingDirectory: directory.value.path,
      processRunner: const SystemProcessRunner(),
    );
  });
  tearDown(() => directory.value.deleteSync(recursive: true));

  /// Runs `git` with [arguments] in the repository.
  void git(List<String> arguments) {
    final ProcessResult result = Process.runSync('git', <String>[
      '-c',
      'user.name=Inspectra',
      '-c',
      'user.email=inspectra@example.com',
      '-c',
      'commit.gpgsign=false',
      '-c',
      'tag.gpgsign=false',
      ...arguments,
    ], workingDirectory: directory.value.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  /// Writes [content] to [path] in the repository.
  void write(String path, String content) =>
      File('${directory.value.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);

  /// Runs the command line with [arguments] and clears the output first.
  Future<int> run(List<String> arguments) {
    (harness.value.context.out as StringBuffer).clear();
    (harness.value.context.err as StringBuffer).clear();
    return harness.value.run(arguments);
  }

  test('compares the API with the dump of the last release', () async {
    write('pubspec.yaml', 'name: shapes\nversion: 1.0.0\n');
    write(
      'inspectra.yaml',
      'api:\n  enabled: true\n  semver: true\nchangelog:\n  enabled: true\n',
    );
    write(
      '.dart_tool/package_config.json',
      jsonEncode(<String, Object?>{
        'configVersion': 2,
        'packages': <Object?>[
          <String, Object?>{
            'name': 'shapes',
            'rootUri': '../',
            'packageUri': 'lib/',
            'languageVersion': '3.0',
          },
        ],
      }),
    );
    write('.gitignore', '.dart_tool/\n');
    write(
      'lib/shapes.dart',
      'abstract class Shape {\n  double area();\n}\n\nenum Color { red }\n',
    );
    git(<String>['init', '-q']);
    expect(await run(<String>['api', 'semver']), 0, reason: harness.value.err);
    expect(harness.value.out, contains('skipped, no release tag'));

    git(<String>['add', '.']);
    git(<String>['commit', '-q', '-m', 'feat: shapes']);
    git(<String>['tag', 'v0.1.0']);
    expect(await run(<String>['api', 'semver']), 0, reason: harness.value.err);
    expect(harness.value.out, contains('v0.1.0 has no API dump'));

    expect(await run(<String>['api', 'dump']), 0, reason: harness.value.err);
    git(<String>['add', '.']);
    git(<String>['commit', '-q', '-m', 'chore: record the API']);
    git(<String>['tag', 'v1.0.0']);
    expect(await run(<String>['api', 'semver']), 0, reason: harness.value.err);
    expect(harness.value.out, contains('0 change(s) since v1.0.0 (1.0.0)'));

    write(
      'lib/shapes.dart',
      'abstract class Shape {\n  double area();\n}\n\n'
          'enum Color { red, blue }\n',
    );
    git(<String>['commit', '-q', '-am', 'feat: add blue']);
    expect(await run(<String>['api', 'semver']), 1);
    expect(
      harness.value.out,
      contains('  - breaking  Color.blue: The enum value'),
    );
    expect(harness.value.out, contains('version 2.0.0 or higher is required'));
    expect(harness.value.out, contains('No commit since v1.0.0 is marked'));
    expect(await run(<String>['check']), 1);
    expect(harness.value.out, contains('API semver: 1 change(s) since v1.0.0'));
    expect(
      await run(<String>[
        'report',
        '--skip',
        'scan,deps,codebase,config,format,lint,style,trivy,coverage',
      ]),
      1,
    );
    expect(harness.value.out, contains('[FAILED]  Semantic versioning'));

    write('pubspec.yaml', 'name: shapes\nversion: 2.0.0-dev.1\n');
    git(<String>['commit', '-q', '-am', 'feat!: release 2.0.0']);
    expect(await run(<String>['api', 'semver', '-f', 'json']), 0);
    final json = jsonDecode(harness.value.out) as Map<String, Object?>;
    expect(json['required'], '2.0.0');
    expect(json['failed'], isFalse);

    expect(await run(<String>['api', 'semver', '--from', 'v0.1.0']), 0);
    expect(harness.value.out, contains('v0.1.0 has no API dump'));
    expect(await run(<String>['api', 'semver', '--from', 'v9.9.9']), 64);
    expect(harness.value.err, contains('Git cannot resolve'));
  }, skip: _gitInstalled ? null : 'Git is not installed.');
}
