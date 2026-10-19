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

@Tags(['analyzer'])
library;

import 'dart:convert';

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/changelog/conventional_commit_parser.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../support/fake_git.dart';
import '../support/fixture.dart';
import '../support/fixtures.dart';

/// Tests checking the version against the API changes since a release.
void main() {
  const base = 'library package:a/a.dart\n\nclass A {\n  void a();\n}\n';
  const added =
      'library package:a/a.dart\n\nclass A {\n  void a();\n}\n\nint b();\n';
  const removed = 'library package:a/a.dart\n\nclass A {}\n';

  /// Compares [after] with [base] at release [released] and the declared
  /// [declared] version, with the subjects of [commits] since the release.
  SemverResult evaluate(
    String after,
    String released,
    String declared, {
    List<String>? commits,
  }) => evaluateSemver(
    before: base,
    after: after,
    baseline: 'v$released',
    baselineVersion: Version.parse(released),
    version: Version.parse(declared),
    commits: commits == null
        ? null
        : <ConventionalCommit>[
            for (final String subject in commits)
              const ConventionalCommitParser().parse(
                GitCommit(hash: hashOf(1), message: subject),
              ),
          ],
    dumpPath: 'api/a.api',
  );

  group('evaluateSemver', () {
    test('requires nothing without changes', () {
      final SemverResult result = evaluate(base, '1.0.0', '1.0.0');
      expect(result.changes, isEmpty);
      expect(result.bump, isNull);
      expect(result.required, isNull);
      expect(result.failed, isFalse);
      expect(result.findings, isEmpty);
      expect(
        result.render(),
        'API semver: 0 change(s) since v1.0.0 (1.0.0).\n'
        'No version is required; pubspec.yaml declares 1.0.0.',
      );
    });

    test('requires a minor version for additions', () {
      final SemverResult low = evaluate(added, '1.0.0', '1.0.1');
      expect(low.bump, VersionBump.minor);
      expect(low.required, Version(1, 1, 0));
      expect(low.violated, isTrue);
      expect(low.findings.single.ruleId, 'SEMVER_VIOLATION');
      expect(low.findings.single.severity, Severity.high);
      expect(low.findings.single.location?.path, 'pubspec.yaml');
      expect(
        low.findings.single.description,
        contains('set the version to 1.1.0'),
      );
      expect(
        low.render(),
        contains('  + additive  b: The declaration was added.'),
      );
      expect(
        low.render(),
        contains('pubspec.yaml declares 1.0.1, which is too low.'),
      );
      expect(evaluate(added, '1.0.0', '1.1.0').failed, isFalse);
      expect(evaluate(added, '1.0.0', '2.0.0').failed, isFalse);
    });

    test('requires a major version for breaking changes', () {
      final SemverResult result = evaluate(removed, '1.2.0', '1.3.0');
      expect(result.bump, VersionBump.major);
      expect(result.required, Version(2, 0, 0));
      expect(result.failed, isTrue);
      expect(
        result.render(),
        contains('  - breaking  A.a: The member was removed.'),
      );
      expect(
        result.render(),
        contains('major change: version 2.0.0 or higher'),
      );
    });

    test('counts a pre-release as the release it leads to', () {
      expect(evaluate(removed, '1.2.0', '2.0.0-dev.1').failed, isFalse);
      expect(evaluate(removed, '1.2.0', '1.9.0-dev.1').failed, isTrue);
    });

    test('follows the 0.x rule before 1.0.0', () {
      expect(evaluate(removed, '0.3.0', '0.3.1').required, Version(0, 4, 0));
      expect(evaluate(removed, '0.3.0', '0.4.0').failed, isFalse);
      expect(evaluate(added, '0.3.0', '0.3.1').failed, isFalse);
      expect(evaluate(added, '0.3.0', '0.3.0').required, Version(0, 3, 1));
    });

    test('asks for a commit that announces a breaking change', () {
      final SemverResult silent = evaluate(
        removed,
        '1.0.0',
        '2.0.0',
        commits: <String>['fix: drop A.a'],
      );
      expect(silent.violated, isFalse);
      expect(silent.undeclaredBreaking, isTrue);
      expect(silent.failed, isTrue);
      expect(silent.findings.single.ruleId, 'SEMVER_UNDECLARED_BREAKING');
      expect(silent.findings.single.severity, Severity.medium);
      expect(silent.findings.single.location?.path, 'api/a.api');
      expect(silent.render(), contains('No commit since v1.0.0 is marked'));
      expect(
        evaluate(
          removed,
          '1.0.0',
          '2.0.0',
          commits: <String>['fix!: drop A.a'],
        ).failed,
        isFalse,
      );
      expect(
        evaluate(
          added,
          '1.0.0',
          '1.1.0',
          commits: <String>['feat: b'],
        ).undeclaredBreaking,
        isFalse,
      );
    });

    test('requires nothing when the baseline has no version', () {
      final SemverResult result = evaluateSemver(
        before: base,
        after: removed,
        baseline: 'abc1234',
        baselineVersion: null,
        version: Version(1, 0, 0),
      );
      expect(result.required, isNull);
      expect(result.failed, isFalse);
      expect(result.render(), contains('since abc1234.'));
    });

    test('serializes the result', () {
      expect(evaluate(added, '1.0.0', '1.0.1').toJson(), <String, Object?>{
        'check': 'semver',
        'failed': true,
        'baseline': 'v1.0.0',
        'baselineVersion': '1.0.0',
        'version': '1.0.1',
        'bump': 'minor',
        'required': '1.1.0',
        'undeclaredBreaking': false,
        'changes': <Object?>[
          <String, Object?>{
            'kind': 'additive',
            'library': 'package:a/a.dart',
            'declaration': 'b',
            'reason': 'The declaration was added.',
            'after': 'int b();',
          },
        ],
      });
      const skipped = SemverResult.skipped('no release yet.');
      expect(skipped.render(), 'API semver: skipped, no release yet.');
      expect(skipped.failed, isFalse);
      expect(skipped.toJson(), <String, Object?>{
        'check': 'semver',
        'failed': false,
        'skipped': 'no release yet.',
        'undeclaredBreaking': false,
        'changes': <Object?>[],
      });
    });
  });

  group('checkSemver', () {
    final root = Fixture<String>();
    final released = Fixture<String>();

    /// The configuration, with the changelog check when [changelog] is
    /// `true`.
    InspectraConfig config({bool changelog = false}) => InspectraConfig.parse(
      loadYaml('changelog:\n  enabled: $changelog\n'),
      packageName: 'app',
    );

    /// Checks the package against [git], or against [from].
    Future<SemverResult> check(
      FakeGit git, {
      String? from,
      bool changelog = false,
    }) => checkSemver(
      config(changelog: changelog),
      root.value,
      GitHistory(processRunner: git.runner, workingDirectory: root.value),
      from: from,
    );

    setUp(() async {
      root.value = temporaryDirectory();
      writeFile(root.value, 'pubspec.yaml', 'name: app\nversion: 1.0.1\n');
      writeFile(
        root.value,
        '.dart_tool/package_config.json',
        jsonEncode(<String, Object?>{
          'configVersion': 2,
          'packages': <Object?>[
            <String, Object?>{
              'name': 'app',
              'rootUri': '../',
              'packageUri': 'lib/',
              'languageVersion': '3.0',
            },
          ],
        }),
      );
      writeFile(
        root.value,
        'lib/app.dart',
        'class Shape {\n  double area() => 0;\n}\n',
      );
      released.value = await renderPackageApi(config(), root.value);
      writeFile(
        root.value,
        'lib/app.dart',
        'class Shape {\n  double area() => 0;\n}\n\nint sides() => 4;\n',
      );
    });

    test('compares with the dump at the last release tag', () async {
      final SemverResult result = await check(
        FakeGit(
          tags: <String>['v0.9.0', 'v1.0.0'],
          files: <String, String>{'v1.0.0:api/app.api': released.value},
        ),
      );
      expect(result.baseline, 'v1.0.0');
      expect(result.baselineVersion, Version(1, 0, 0));
      expect(result.changes.single.subject, 'sides');
      expect(result.required, Version(1, 1, 0));
      expect(result.violated, isTrue);
      expect(result.dumpPath, 'api/app.api');
    });

    test('compares with the revision given with --from', () async {
      final git = FakeGit(
        tags: <String>['v1.0.0'],
        files: <String, String>{'v0.9.0:api/app.api': released.value},
      );
      final SemverResult result = await check(git, from: 'v0.9.0');
      expect(result.baseline, 'v0.9.0');
      expect(result.baselineVersion, Version(0, 9, 0));
      expect(result.required, Version(0, 9, 1));
      expect(result.failed, isFalse);
      expect(git.runner.calls, isNot(contains(contains(' tag '))));
      await expectLater(
        check(git, from: 'nope'),
        throwsA(isA<InvalidUsageException>()),
      );
    });

    test('checks that a breaking change is announced', () async {
      writeFile(root.value, 'lib/app.dart', 'class Shape {}\n');
      writeFile(root.value, 'pubspec.yaml', 'name: app\nversion: 2.0.0\n');
      final SemverResult result = await check(
        FakeGit(
          tags: <String>['v1.0.0'],
          files: <String, String>{'v1.0.0:api/app.api': released.value},
          logs: <String, List<GitCommit>>{
            'v1.0.0..HEAD': <GitCommit>[
              GitCommit(hash: hashOf(1), message: 'refactor: drop area'),
            ],
          },
        ),
        changelog: true,
      );
      expect(result.violated, isFalse);
      expect(result.undeclaredBreaking, isTrue);
    });

    test('is skipped without a version, a release or a dump', () async {
      final git = FakeGit(
        tags: <String>['v1.0.0'],
        files: <String, String>{'v1.0.0:api/app.api': released.value},
      );
      expect(
        (await check(FakeGit())).skipped,
        startsWith('no release tag with the prefix "v" yet'),
      );
      expect(
        (await check(FakeGit(empty: true))).skipped,
        startsWith('no release tag'),
      );
      expect(
        (await check(FakeGit(tags: <String>['v1.0.0']))).skipped,
        startsWith('v1.0.0 has no API dump at api/app.api'),
      );
      writeFile(root.value, 'pubspec.yaml', 'name: app\n');
      expect(
        (await check(git)).skipped,
        'pubspec.yaml declares no version to check.',
      );
    });
  });
}
