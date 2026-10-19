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

/// Generates a changelog from a real Git repository.
///
/// Skipped when Git is not installed.
@Tags(['slow'])
library;

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

/// Tests `changelog generate --write` against a real repository.
void main() {
  final directory = Fixture<Directory>();

  setUp(() => directory.value = Directory.systemTemp.createTempSync('git_'));
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

  /// Returns the object name of `HEAD`.
  String head() =>
      (Process.runSync('git', const <String>[
                'rev-parse',
                'HEAD',
              ], workingDirectory: directory.value.path).stdout
              as String)
          .trim();

  /// Commits [message] with an empty change.
  void commit(String message) =>
      git(<String>['commit', '--allow-empty', '-q', '-m', message]);

  test('writes the release of the commits since the last tag', () async {
    File('${directory.value.path}/pubspec.yaml')
        .writeAsStringSync('name: demo\nversion: 1.0.0\n');
    git(<String>['init', '-q']);
    commit('feat: first feature');
    git(<String>['tag', 'v1.0.0']);
    commit('fix(cli): handle\u001b[31m escapes');
    commit('feat!: rename the command\n\nBREAKING CHANGE: use "new".');
    commit('docs: explain the change');
    commit('fix: temporary workaround');
    commit(
      'Revert "fix: temporary workaround"\n\nThis reverts commit ${head()}.',
    );
    final harness = TestHarness(
      workingDirectory: directory.value.path,
      processRunner: const SystemProcessRunner(),
    );
    final int code = await harness.run(<String>[
      'changelog',
      'generate',
      '--write',
      '--date',
      '2026-10-04',
    ]);
    expect(code, 0, reason: harness.err);
    final String changelog = File('${directory.value.path}/CHANGELOG.md')
        .readAsStringSync();
    expect(changelog, startsWith('# Changelog\n'));
    expect(changelog, contains('## 2.0.0 - 2026-10-04'));
    expect(changelog, contains('### Breaking changes\n\n- rename the command'));
    expect(changelog, contains('  use "new".'));
    expect(changelog, contains(r'**cli:** handle\u{001B}[31m escapes'));
    expect(changelog, isNot(contains('first feature')));
    expect(changelog, isNot(contains('explain')));
    expect(changelog, isNot(contains('workaround')));
    expect(await harness.run(<String>['changelog', 'notes', '2.0.0']), 0);
  }, skip: _gitInstalled ? null : 'Git is not installed.');
}
