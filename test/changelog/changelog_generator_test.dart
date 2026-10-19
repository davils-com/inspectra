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
import 'package:inspectra/src/changelog/changelog_changes.dart';
import 'package:inspectra/src/changelog/changelog_entry.dart';
import 'package:inspectra/src/changelog/changelog_generator.dart';
import 'package:inspectra/src/changelog/changelog_release.dart';
import 'package:inspectra/src/changelog/changelog_writer.dart';
import 'package:test/test.dart';

import '../support/fake_git.dart';
import '../support/fixture.dart';

/// Tests generating and writing releases.
void main() {
  /// Creates a generator for a package at [packageVersion] whose history
  /// is [git].
  ChangelogGenerator generator(
    FakeGit git, {
    String? packageVersion,
    ChangelogConfig config = const ChangelogConfig(),
  }) => ChangelogGenerator(
    history: GitHistory(processRunner: git.runner, workingDirectory: '.'),
    config: config,
    packageVersion: packageVersion,
  );

  /// Creates commits from [messages], newest first.
  List<GitCommit> commits(List<String> messages) => <GitCommit>[
    for (var index = 0; index < messages.length; index++)
      GitCommit(hash: hashOf(index + 1), message: messages[index]),
  ];

  group('ChangelogGenerator', () {
    test('suggests the next version since the latest tag', () async {
      final git = FakeGit(
        tags: <String>['v1.0.0', 'v1.1.0'],
        logs: <String, List<GitCommit>>{
          'v1.1.0..HEAD': commits(<String>['feat: a', 'fix: b']),
        },
      );
      final ChangelogRelease release = await generator(
        git,
        packageVersion: '1.1.0',
      ).generate(date: '2026-10-04');
      expect(release.version, '1.2.0');
      expect(release.tag, 'v1.2.0');
      expect(release.previousTag, 'v1.1.0');
      expect(release.changes.bump, VersionBump.minor);
      expect(release.changes.length, 2);
    });

    test('keeps a higher version of pubspec.yaml', () async {
      final git = FakeGit(
        tags: <String>['v1.0.0'],
        logs: <String, List<GitCommit>>{
          'v1.0.0..HEAD': commits(<String>['fix: a']),
        },
      );
      final ChangelogRelease release = await generator(
        git,
        packageVersion: '2.0.0',
      ).generate(date: '2026-10-04');
      expect(release.version, '2.0.0');
    });

    test('releases the pubspec.yaml version first', () async {
      final git = FakeGit(
        logs: <String, List<GitCommit>>{
          'main': commits(<String>['feat: a']),
        },
      );
      final ChangelogRelease release = await generator(
        git,
        packageVersion: '0.1.0',
        config: const ChangelogConfig(tagPrefix: ''),
      ).generate(date: '2026-10-04', to: 'main');
      expect(release.version, '0.1.0');
      expect(release.tag, '0.1.0');
      expect(release.previousTag, isNull);
    });

    test('starts at a given revision and takes a given version', () async {
      final git = FakeGit(
        tags: <String>['v3.0.0'],
        logs: <String, List<GitCommit>>{
          'v1.0.0..HEAD': commits(<String>['fix: a']),
          'abc1234..HEAD': commits(<String>['fix: b']),
        },
      );
      final ChangelogRelease fromTag = await generator(git)
          .generate(date: '2026-10-04', from: 'v1.0.0');
      expect(fromTag.version, '1.0.1');
      expect(fromTag.previousTag, 'v1.0.0');
      final ChangelogRelease fromCommit = await generator(git)
          .generate(date: '2026-10-04', from: 'abc1234', release: 'v4.0.0');
      expect(fromCommit.version, '4.0.0');
      expect(fromCommit.previousTag, 'abc1234');
      final ChangelogRelease counted = await generator(
        git,
        packageVersion: '1.0.0',
      ).generate(date: '2026-10-04', from: 'abc1234');
      expect(counted.version, '3.0.1');
    });

    test('suggests a patch when nothing is listed', () async {
      final git = FakeGit(
        tags: <String>['v1.0.0'],
        logs: <String, List<GitCommit>>{
          'v1.0.0..HEAD': commits(<String>['docs: a']),
        },
      );
      final ChangelogRelease release = await generator(git)
          .generate(date: '2026-10-04');
      expect(release.changes.isEmpty, isTrue);
      expect(release.version, '1.0.1');
    });

    test('rejects invalid versions and missing version sources', () {
      final git = FakeGit(
        logs: <String, List<GitCommit>>{'HEAD': const <GitCommit>[]},
      );
      expect(
        () => generator(git).generate(date: '2026-10-04', release: '1.0'),
        throwsA(isA<InvalidUsageException>()),
      );
      expect(
        () => generator(git).generate(date: '2026-10-04'),
        throwsA(
          isA<InvalidUsageException>().having(
            (error) => error.message,
            'message',
            contains('--release'),
          ),
        ),
      );
      expect(
        () => generator(
          git,
          packageVersion: 'invalid',
        ).generate(date: '2026-10-04'),
        throwsA(isA<InvalidUsageException>()),
      );
    });
  });

  group('ChangelogWriter', () {
    final directory = Fixture<Directory>();

    setUp(
      () => directory.value = Directory.systemTemp.createTempSync('writer_'),
    );
    tearDown(() => directory.value.deleteSync(recursive: true));

    const release = ChangelogRelease(
      version: '1.1.0',
      date: '2026-10-04',
      tag: 'v1.1.0',
      changes: ChangelogChanges(
        sections: <ChangelogSection, List<ChangelogEntry>>{},
        breaking: <ChangelogEntry>[],
        bump: null,
      ),
    );

    test('creates the changelog with the introduction', () {
      final path = '${directory.value.path}/docs/CHANGELOG.md';
      const ChangelogWriter().write(path, release, '## 1.1.0\n\n- x\n');
      expect(
        File(path).readAsStringSync(),
        allOf(startsWith('# Changelog\n'), endsWith('\n## 1.1.0\n\n- x\n')),
      );
    });

    test('refuses to document a version twice', () {
      final path = '${directory.value.path}/CHANGELOG.md';
      File(path).writeAsStringSync('## [1.1.0]\n\n- old\n');
      expect(
        () => const ChangelogWriter().write(path, release, '## 1.1.0\n'),
        throwsA(isA<InvalidUsageException>()),
      );
      expect(File(path).readAsStringSync(), '## [1.1.0]\n\n- old\n');
    });

    test('reports files it cannot write', () {
      final path = '${directory.value.path}/CHANGELOG.md';
      Directory(path).createSync();
      expect(
        () => const ChangelogWriter().write(path, release, '## 1.1.0\n'),
        throwsA(isA<UnavailableException>()),
      );
    });
  });
}
