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

import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_process_runner.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';
import '../support/test_harness.dart';

/// Checks the human readable output of every command.
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

  /// Creates a harness whose services point at the fake server.
  TestHarness project(
    Map<String, String> files, {
    ProcessRunner? processRunner,
  }) {
    final harness = TestHarness.withFiles(
      files,
      environment: <String, String>{
        'INSPECTRA_NETWORK_OSV_URL': server.value.baseUrl,
        'INSPECTRA_NETWORK_PUB_HOSTED_URL': server.value.baseUrl,
        'INSPECTRA_NETWORK_MAX_ATTEMPTS': '1',
      },
      processRunner: processRunner,
    );
    harnesses.add(harness);
    return harness;
  }

  test('trust prints the assessment and verdict', () async {
    server.value
      ..on(
        'GET',
        '/api/packages/young',
        FakeResponse.json(<String, Object?>{
          'name': 'young',
          'latest': <String, Object?>{'version': '1.0.0'},
          'versions': <Object?>[
            <String, Object?>{
              'version': '1.0.0',
              'published': '2026-09-28T00:00:00Z',
            },
          ],
        }),
      )
      ..on(
        'GET',
        '/api/packages/young/score',
        FakeResponse.json(<String, Object?>{
          'grantedPoints': 10,
          'maxPoints': 160,
          'likeCount': 1,
          'downloadCount30Days': 3,
        }),
      );
    final TestHarness harness = project(const <String, String>{});
    final int code = await harness.run(<String>['trust', 'young', '1.0.0']);
    expect(code, 1);
    expect(harness.out, contains('Verdict: NOT TRUSTED'));
    expect(harness.out, contains('FRESH_PACKAGE'));
    expect(harness.out, contains('LOW_QUALITY_SCORE'));
    expect(harness.out, contains('none (unverified)'));
  });

  test('scan prints every section and the Trivy status', () async {
    server.value
      ..on(
        'POST',
        '/v1/querybatch',
        FakeResponse.json(<String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'vulns': <Object?>[
                <String, Object?>{'id': 'GHSA-1', 'modified': 'm'},
              ],
            },
          ],
        }),
      )
      ..on(
        'GET',
        '/v1/vulns/GHSA-1',
        FakeResponse.json(<String, Object?>{
          'id': 'GHSA-1',
          'modified': 'm',
          'summary': 'Bad thing',
          'database_specific': <String, Object?>{'severity': 'HIGH'},
          'affected': <Object?>[
            <String, Object?>{
              'package': <String, Object?>{'name': 'http', 'ecosystem': 'Pub'},
              'ranges': <Object?>[
                <String, Object?>{
                  'type': 'SEMVER',
                  'events': <Object?>[
                    <String, Object?>{'introduced': '0'},
                    <String, Object?>{'fixed': '1.0.0'},
                  ],
                },
              ],
            },
          ],
        }),
      );
    final trivy = FakeProcessRunner((executable, arguments) {
      if (arguments.contains('--version')) {
        return const ProcessOutcome(
          exitCode: 0,
          stdout: '{"Version":"0.75.0"}',
          stderr: '',
        );
      }
      return ProcessOutcome(
        exitCode: 0,
        stdout: jsonEncode(<String, Object?>{
          'Results': <Object?>[
            <String, Object?>{
              'Target': 'Dockerfile',
              'Misconfigurations': <Object?>[
                <String, Object?>{
                  'ID': 'DS002',
                  'Status': 'FAIL',
                  'Severity': 'HIGH',
                  'Title': 'Image user should not be root',
                },
              ],
              'Licenses': <Object?>[
                <String, Object?>{
                  'Name': 'GPL-3.0',
                  'Category': 'restricted',
                  'Severity': 'HIGH',
                },
              ],
              'Secrets': <Object?>[
                <String, Object?>{'RuleID': 'k', 'Severity': 'CRITICAL'},
              ],
            },
          ],
        }),
        stderr: '',
      );
    });
    final TestHarness harness = project(<String, String>{
      'packages/app/pubspec.lock': '''
packages:
  http:
    dependency: "direct main"
    description: {name: http, url: "https://pub.dev"}
    source: hosted
    version: "0.13.0"
''',
      'packages/app/pubspec.yaml':
          'name: app\nenvironment:\n  sdk: ^3.5.0\ndependencies:\n'
          '  http: any\n',
    }, processRunner: trivy);
    final int code = await harness.run(<String>[
      '-r',
      '--trivy-executable',
      'trivy',
      '--ignore',
      'k',
    ]);
    expect(code, 1);
    final String out = harness.out;
    expect(out, contains('Known vulnerabilities (1)'));
    expect(out, contains('Fix: upgrade to 1.0.0'));
    expect(out, contains('Supply chain'));
    expect(out, contains('Misconfigurations (1)'));
    expect(out, contains('Licenses (1)'));
    expect(out, isNot(contains('Secrets')));
    expect(out, contains('1 suppressed by ignore rules'));
    expect(out, contains('Trivy 0.75.0 (configured)'));
  });

  test('scan explains a missing lockfile', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: x\n',
    });
    expect(await harness.run(<String>['scan', '--offline']), 65);
    expect(harness.err, contains('dart pub get'));
  });

  test('trivy prints findings and where it found Trivy', () async {
    final trivy = FakeProcessRunner((executable, arguments) {
      if (arguments.contains('--version')) {
        return const ProcessOutcome(
          exitCode: 0,
          stdout: 'Version: 0.75.0',
          stderr: '',
        );
      }
      return const ProcessOutcome(
        exitCode: 0,
        stdout:
            '{"Results":[{"Target":"a","Secrets":[{"RuleID":"x",'
            '"Severity":"LOW","Title":"Token"}]}]}',
        stderr: '',
      );
    });
    final TestHarness harness = project(
      const <String, String>{},
      processRunner: trivy,
    );
    expect(
      await harness.run(<String>['trivy', '--trivy-executable', 'trivy']),
      1,
    );
    expect(harness.out, contains('Trivy findings: 1 (1 low)'));
    expect(
      await harness.run(<String>[
        'trivy',
        '--where',
        '--trivy-executable',
        'trivy',
      ]),
      0,
    );
    expect(harness.out, contains('(configured)'));
  });

  test('trivy stays offline with --offline', () async {
    final trivy = FakeProcessRunner((executable, arguments) {
      if (arguments.contains('--version')) {
        return const ProcessOutcome(
          exitCode: 0,
          stdout: 'Version: 0.75.0',
          stderr: '',
        );
      }
      return const ProcessOutcome(
        exitCode: 0,
        stdout: '{"Results":[]}',
        stderr: '',
      );
    });
    final TestHarness harness = project(
      const <String, String>{},
      processRunner: trivy,
    );
    expect(
      await harness.run(<String>[
        'trivy',
        '--offline',
        '--trivy-executable',
        'trivy',
      ]),
      0,
    );
    final String scan = trivy.calls.singleWhere(
      (call) => call.contains(' fs '),
    );
    expect(scan, contains('--skip-db-update'));
    expect(scan, contains('--offline-scan'));
  });

  test('typosquat prints a clean result', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: a\ndependencies:\n  http: ^1.0.0\n',
    });
    expect(await harness.run(<String>['typosquat', '--offline']), 0);
    expect(harness.out, contains('No typosquatting or confusion'));
    expect(harness.out, contains('skipped (offline mode)'));
  });

  test('expired ignore rules are reported', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: a\ndependencies:\n  http: ^1.0.0\n',
      'inspectra.yaml':
          'ignore:\n  - id: X\n    reason: Old.\n'
          '    expires: 2020-01-01\n',
    });
    expect(await harness.run(<String>['typosquat', '--offline', '-q']), 0);
    expect(harness.err, contains('expired on 2020-01-01'));
  });

  test('--output reports where the file was written', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: a\ndependencies:\n  http: ^1.0.0\n',
    });
    expect(
      await harness.run(<String>[
        'typosquat',
        '--offline',
        '-f',
        'markdown',
        '-o',
        'r.md',
      ]),
      0,
    );
    expect(harness.err, contains('Report written to r.md'));
    expect(
      File('${harness.workingDirectory}/r.md').readAsStringSync(),
      contains('No findings'),
    );
  });
}
