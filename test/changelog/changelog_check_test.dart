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
import 'package:inspectra/src/changelog/changelog_check.dart';
import 'package:inspectra/src/changelog/changelog_document.dart';
import 'package:test/test.dart';

import '../support/fixture.dart';

/// Tests validating changelogs.
void main() {
  final directory = Fixture<Directory>();

  setUp(
    () => directory.value = Directory.systemTemp.createTempSync('changelog_'),
  );
  tearDown(() => directory.value.deleteSync(recursive: true));

  /// Writes the package files and checks the changelog.
  ChangelogCheckResult check({String? changelog, String version = '1.1.0'}) {
    File('${directory.value.path}/pubspec.yaml')
        .writeAsStringSync('name: demo\nversion: $version\n');
    if (changelog != null) {
      File('${directory.value.path}/CHANGELOG.md').writeAsStringSync(changelog);
    }
    return checkChangelog(
      InspectraConfig.defaults('demo'),
      directory.value.path,
    );
  }

  /// Returns the messages of the problems of [result].
  List<String> messages(ChangelogCheckResult result) => <String>[
    for (final ChangelogProblem problem in result.problems) problem.message,
  ];

  test('passes for a well-formed changelog with the package version', () {
    final ChangelogCheckResult result = check(
      changelog:
          '# Changelog\n\n## Unreleased\n\n## 1.1.0 - 2026-10-04\n\n- b\n\n'
          '## [1.0.0]\n\n- a\n',
    );
    expect(result.failed, isFalse);
    expect(
      result.render(),
      'CHANGELOG.md is well-formed and documents version 1.1.0.',
    );
  });

  test('reports a missing changelog', () {
    final ChangelogCheckResult result = check();
    expect(messages(result), <String>['The changelog does not exist.']);
    expect(result.render(), contains('inspectra changelog generate --write'));
  });

  test('reports every malformed heading', () {
    const notAHeading =
        '"## Notes" is not a release heading. Use "## 1.2.3 - YYYY-MM-DD", '
        '"## 1.2.3" or "## Unreleased".';
    const outOfOrder =
        'Version 1.0.1 is listed below the lower version 1.0.0; list the '
        'newest release first.';
    final ChangelogCheckResult result = check(
      changelog:
          '## 1.1.0 - 2026-02-30\n\n- x\n\n'
          '## Unreleased\n\n'
          '## Notes\n\n'
          '## 1.0\n\n'
          '## 1.0.0\n\n- a\n\n'
          '## 1.0.0\n\n- b\n\n'
          '## 1.0.1\n\n- c\n',
    );
    expect(messages(result), <String>[
      '"2026-02-30" is not a date in the form YYYY-MM-DD.',
      'The "Unreleased" section must come first.',
      notAHeading,
      '"1.0" is not a semantic version such as 1.2.3.',
      'Version 1.0.0 is listed more than once.',
      outOfOrder,
    ]);
    expect(result.problems.first.line, 1);
    expect(result.render(), contains('CHANGELOG.md:1: "2026-02-30"'));
    expect(result.render(), startsWith('CHANGELOG.md has 6 problem(s):'));
  });

  test('requires a section with text for the package version', () {
    const missing =
        'Version 1.1.0 of pubspec.yaml has no section. Add one before '
        'releasing it.';
    expect(messages(check(changelog: '## 1.0.0\n\n- a\n')), <String>[missing]);
    final ChangelogCheckResult empty = check(
      changelog: '## 1.1.0\n\n[1.1.0]: https://x\n## 1.0.0\n\n- a\n',
    );
    expect(messages(empty), <String>['The section of version 1.1.0 is empty.']);
    expect(empty.render(), contains('CHANGELOG.md:1: '));
  });

  test('checks only the format of packages without a version', () {
    File('${directory.value.path}/CHANGELOG.md')
        .writeAsStringSync('# Changelog\n');
    final ChangelogCheckResult withoutPubspec = checkChangelog(
      InspectraConfig.defaults('demo'),
      directory.value.path,
    );
    expect(withoutPubspec.version, isNull);
    expect(withoutPubspec.render(), 'CHANGELOG.md is well-formed.');
  });

  test('validates documents without a file', () {
    final List<ChangelogProblem> problems = validateChangelog(
      ChangelogDocument.parse('## 2.0.0\n\n- x\n'),
      version: null,
    );
    expect(problems, isEmpty);
  });
}
