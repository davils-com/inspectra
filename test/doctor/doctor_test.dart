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

import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_process_runner.dart';
import '../support/fixture.dart';
import '../support/test_harness.dart';

/// Tests `inspectra doctor`.
void main() {
  final server = Fixture<FakeHttpServer>();
  final harnesses = <TestHarness>[];

  setUp(() async => server.value = await FakeHttpServer.start());
  tearDown(() async {
    await server.value.close();
    for (final harness in harnesses) {
      harness.dispose();
    }
    harnesses.clear();
  });

  /// Answers the tool calls of the doctor: [dart] for `dart --version`,
  /// [git] for `git --version`, and `flutter` and `trivy` as missing.
  FakeProcessRunner tools({String dart = '3.7.2', String? git = '2.43.0'}) =>
      FakeProcessRunner((executable, arguments) {
        final bool isDart =
            arguments.length == 1 &&
            arguments.first == '--version' &&
            !executable.endsWith('git');
        if (isDart) {
          return ProcessOutcome(
            exitCode: 0,
            stdout: 'Dart SDK version: $dart (stable) on "linux_x64"\n',
            stderr: '',
          );
        }
        if (executable == 'git' && git != null) {
          return ProcessOutcome(
            exitCode: 0,
            stdout: 'git version $git\n',
            stderr: '',
          );
        }
        return const ProcessOutcome(exitCode: 127, stdout: '', stderr: '');
      });

  /// Creates a project with [files] whose services point at the fake
  /// server, with the [processRunner].
  TestHarness project(
    Map<String, String> files,
    FakeProcessRunner processRunner, {
    String? registry,
  }) {
    final harness = TestHarness.withFiles(
      files,
      environment: <String, String>{
        'INSPECTRA_NETWORK_OSV_URL': server.value.baseUrl,
        'INSPECTRA_NETWORK_PUB_HOSTED_URL': registry ?? server.value.baseUrl,
        'INSPECTRA_NETWORK_MAX_ATTEMPTS': '1',
        'INSPECTRA_NETWORK_TIMEOUT': '2s',
      },
      processRunner: processRunner,
    );
    harnesses.add(harness);
    return harness;
  }

  /// Returns the status of every check of the JSON report in [harness].
  Map<String, String> statuses(TestHarness harness) {
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    final List<Map<String, Object?>> checks =
        (report['checks']! as List<Object?>).cast<Map<String, Object?>>();
    return <String, String>{
      for (final check in checks) '${check['name']}': '${check['status']}',
    };
  }

  test('reports a healthy project', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: app\nenvironment:\n  sdk: ^3.6.0\n',
      'inspectra.yaml': 'trivy:\n  mode: disabled\n',
    }, tools());
    expect(
      await harness.run(<String>['doctor', '-f', 'json']),
      0,
      reason: harness.out,
    );
    expect(statuses(harness), <String, String>{
      'Configuration': 'ok',
      'Dart SDK': 'ok',
      'Git': 'ok',
      'Trivy': 'skipped',
      'Proxy': 'ok',
      'OSV.dev': 'ok',
      'Package registry': 'ok',
      'Pub token': 'warn',
      'Cache': 'ok',
    });
  });

  test('reports what is broken, also a broken configuration', () async {
    final TestHarness harness = project(
      <String, String>{
        'pubspec.yaml':
            'name: app\nenvironment:\n  sdk: ^3.8.0\n'
            '  flutter: ">=3.29.0"\n',
        'inspectra.yaml': 'fail_on: often\n',
        '.fvmrc': '{"flutter": "3.29.2"}',
      },
      tools(git: null),
      registry: 'http://127.0.0.1:1',
    );
    expect(await harness.run(<String>['doctor']), 1);
    final String out = harness.out;
    expect(out, contains('✘ Configuration'));
    expect(out, contains('3.7.2 does not satisfy environment.sdk ^3.8.0.'));
    expect(out, contains('✘ Flutter SDK'));
    expect(out, contains('! Git                git is not installed'));
    expect(out, contains('! Trivy'));
    expect(out, contains('✘ Package registry'));
    expect(out, contains('check(s) failed.'));
    final TestHarness offline = project(<String, String>{
      'pubspec.yaml': 'name: app\n',
    }, tools());
    expect(
      await offline.run(<String>['doctor', '--offline', '-f', 'json']),
      0,
      reason: offline.out,
    );
    expect(statuses(offline)['Network'], 'skipped');
    expect(statuses(offline).containsKey('OSV.dev'), isFalse);
  });
}
