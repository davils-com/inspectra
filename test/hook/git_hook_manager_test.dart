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
import 'package:inspectra/src/hook/git_hook_manager.dart';
import 'package:inspectra/src/hook/pre_commit_script.dart';
import 'package:test/test.dart';

import '../support/fake_process_runner.dart';
import '../support/fixture.dart';

/// Tests installing and removing the pre-commit hook.
void main() {
  final directory = Fixture<Directory>();

  setUp(() => directory.value = Directory.systemTemp.createTempSync('hook_'));
  tearDown(() => directory.value.deleteSync(recursive: true));

  /// Creates a manager whose `git rev-parse` answers [gitPath].
  GitHookManager manager({String gitPath = '.git/hooks/pre-commit'}) =>
      GitHookManager(
        processRunner: FakeProcessRunner(
          (executable, arguments) => ProcessOutcome(
            exitCode: gitPath.isEmpty ? 128 : 0,
            stdout: '$gitPath\n',
            stderr: '',
          ),
        ),
        workingDirectory: directory.value.path,
        host: HostPlatform.current(),
      );

  test('installs, updates and removes its own hook', () async {
    final (String path, bool existed) = await manager().install();
    expect(existed, isFalse);
    expect(File(path).readAsStringSync(), contains(PreCommitScript.marker));
    final (_, bool existedAgain) = await manager().install();
    expect(existedAgain, isTrue);
    expect(await manager().remove(), path);
    expect(File(path).existsSync(), isFalse);
    expect(await manager().remove(), isNull);
  });

  test('honours the path reported by git, e.g. core.hooksPath', () async {
    final (String path, _) = await manager(gitPath: 'custom/hooks/pre-commit')
        .install();
    expect(
      path,
      endsWith(
        'custom${Platform.pathSeparator}hooks'
        '${Platform.pathSeparator}pre-commit',
      ),
    );
  });

  test('never touches a foreign hook', () async {
    File('${directory.value.path}/.git/hooks/pre-commit')
      ..createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\nmy-hook');
    expect(manager().install, throwsA(isA<InvalidUsageException>()));
    expect(await manager().remove(), isNull);
  });

  test('fails outside of a repository', () {
    expect(
      manager(gitPath: '').hookPath,
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('the script contains no else and hands over to hook run', () {
    expect(PreCommitScript.content, isNot(contains('else')));
    expect(PreCommitScript.content, contains(r'exec $INSPECTRA hook run'));
    expect(PreCommitScript.content, contains('dart run inspectra'));
    expect(PreCommitScript.content, startsWith('#!/bin/sh\n'));
  });
}
