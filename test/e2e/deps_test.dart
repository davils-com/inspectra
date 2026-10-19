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

/// Runs `inspectra deps` and the dependency policy of `scan` and `check`
/// in-process.
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

  /// Creates a project with [files] whose services point at the fake
  /// server.
  TestHarness project(Map<String, String> files) {
    final harness = TestHarness.withFiles(
      files,
      environment: <String, String>{
        'INSPECTRA_NETWORK_OSV_URL': server.value.baseUrl,
        'INSPECTRA_NETWORK_PUB_HOSTED_URL': server.value.baseUrl,
        'INSPECTRA_NETWORK_MAX_ATTEMPTS': '1',
      },
    );
    harnesses.add(harness);
    return harness;
  }

  /// Runs [arguments] in [harness] with fresh output buffers.
  ///
  /// Returns the exit code.
  Future<int> run(TestHarness harness, List<String> arguments) {
    (harness.context.out as StringBuffer).clear();
    (harness.context.err as StringBuffer).clear();
    return harness.run(arguments);
  }

  /// Returns the rule ids of the findings of the JSON report in [harness].
  List<Object?> rules(TestHarness harness) {
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    return <Object?>[
      for (final Object? finding in report['findings']! as List<Object?>)
        (finding! as Map<String, Object?>)['ruleId'],
    ];
  }

  const policy = '''
inspectra:
  dependency_policy:
    enabled: true
    require_upper_bound: true
    dev_only: [mockito]
    require_publish_to: true
''';

  const app = '''
name: app # the app
environment:
  sdk: ^3.6.0
dependencies:
  # networking
  http: ">=1.2.0"
  mockito: ^5.4.0
$policy''';

  test('the pubspec rules run without a policy and without network', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: app\ndependencies:\n  http: any\n',
    });
    expect(await run(harness, <String>['deps', '-f', 'json']), 1);
    expect(rules(harness), <Object?>['ANY_VERSION']);
    final TestHarness clean = project(<String, String>{
      'pubspec.yaml': 'name: app\ndependencies:\n  http: ^1.2.0\n',
    });
    expect(await run(clean, <String>['deps']), 0);
    expect(clean.out, contains('follow the rules'));
  });

  test('reports the policy and fixes what can be fixed', () async {
    final TestHarness harness = project(<String, String>{'pubspec.yaml': app});
    expect(await run(harness, <String>['deps', '-f', 'json']), 1);
    expect(rules(harness), <Object?>[
      'MISSING_UPPER_BOUND',
      'DEV_ONLY_DEPENDENCY',
      'MISSING_PUBLISH_TO',
    ]);
    expect(
      await run(harness, <String>['deps', '--fix', '-f', 'json']),
      0,
      reason: harness.out,
    );
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report['fixed'], <String>[
      'pubspec.yaml: http: >=1.2.0 -> ^1.2.0',
      'pubspec.yaml: mockito: dependencies -> dev_dependencies',
      'pubspec.yaml: publish_to: none',
    ]);
    final String fixed = File('${harness.workingDirectory}/pubspec.yaml')
        .readAsStringSync();
    expect(fixed, startsWith('name: app # the app\npublish_to: none\n'));
    expect(fixed, contains('  # networking\n  http: ^1.2.0\n'));
    expect(fixed, contains('dev_dependencies:\n  mockito: ^5.4.0\n'));
    expect(await run(harness, <String>['deps', '--fix']), 0);
    expect(harness.out, isNot(contains('Fixed')));
  });

  test('--fix without a policy changes nothing and says so', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: app\n',
    });
    expect(await run(harness, <String>['deps', '--fix']), 0);
    expect(harness.err, contains('Nothing to fix'));
  });

  test('checks the members of a workspace with -r', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml':
          'name: root\npublish_to: none\nworkspace: [pkgs/core]\n$policy',
      'pkgs/core/pubspec.yaml':
          'name: core\nresolution: workspace\n'
          'dependencies:\n  collection: ">=1.0.0"\n',
    });
    expect(await run(harness, <String>['deps', '-f', 'json']), 0);
    expect(await run(harness, <String>['deps', '-r', '-f', 'json']), 1);
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report['pubspecs'], <String>[
      'pkgs/core/pubspec.yaml',
      'pubspec.yaml',
    ]);
    expect(rules(harness), <Object?>[
      'MISSING_UPPER_BOUND',
      'MISSING_PUBLISH_TO',
    ]);
  });

  test('ignore rules and the baseline apply', () async {
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml':
          '''
name: app
publish_to: none
dependencies:
  http: ">=1.2.0"
  mockito: ^5.4.0
$policy
  ignore:
    - id: DEV_ONLY_DEPENDENCY
      reason: Generated mocks ship with the package.
      expires: 2027-01-31
''',
      'inspectra-baseline.json': jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'entries': <Object?>[
          <String, Object?>{
            'scope': 'scan',
            'source': 'pubspec',
            'rule': 'MISSING_UPPER_BOUND',
            'package': 'http',
            'path': 'pubspec.yaml',
            'count': 1,
            'severity': 'medium',
            'title': 'recorded',
          },
        ],
      }),
    });
    expect(
      await run(harness, <String>['deps', '-f', 'json']),
      0,
      reason: harness.out,
    );
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report['suppressed'], 1);
    expect(report['baselined'], 1);
  });

  test('a missing pubspec is an input error', () async {
    final TestHarness harness = project(<String, String>{'README.md': '# x'});
    expect(await run(harness, <String>['deps']), 65);
    expect(harness.err, contains('No pubspec.yaml found'));
  });

  test('scan and check apply the policy', () async {
    server.value.on(
      'POST',
      '/v1/querybatch',
      FakeResponse.json(<String, Object?>{
        'results': <Object?>[<String, Object?>{}],
      }),
    );
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': app,
      'pubspec.lock': '''
packages:
  http:
    dependency: "direct main"
    description: {name: http, sha256: aa, url: "https://pub.dev"}
    source: hosted
    version: "1.2.0"
''',
    });
    expect(
      await run(harness, <String>[
        'scan',
        '--trivy-mode',
        'disabled',
        '-f',
        'json',
      ]),
      1,
      reason: harness.err,
    );
    expect(
      rules(harness),
      containsAll(<String>[
        'MISSING_UPPER_BOUND',
        'DEV_ONLY_DEPENDENCY',
        'MISSING_PUBLISH_TO',
      ]),
    );
    expect(await run(harness, <String>['check']), 1);
    expect(harness.out, contains('Dependency policy: '));
    expect(harness.out, contains('(MISSING_PUBLISH_TO)'));
  });

  test('--online checks how far the dependencies are behind', () async {
    server.value.on(
      'GET',
      '/api/packages/http',
      FakeResponse.json(<String, Object?>{
        'name': 'http',
        'latest': <String, Object?>{'version': '3.0.0'},
        'versions': <Object?>[
          <String, Object?>{
            'version': '1.2.0',
            'published': '2023-10-01T00:00:00Z',
          },
          <String, Object?>{
            'version': '2.0.0',
            'published': '2024-10-01T00:00:00Z',
          },
          <String, Object?>{
            'version': '3.0.0',
            'published': '2025-10-01T00:00:00Z',
          },
        ],
      }),
    );
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml':
          'name: app\npublish_to: none\ndependencies:\n  http: ^1.2.0\n'
          'inspectra:\n  dependency_policy:\n    enabled: true\n'
          '    max_major_behind: 1\n    max_libyear: 1\n',
      'pubspec.lock': '''
packages:
  http:
    dependency: "direct main"
    description: {name: http, sha256: aa, url: "https://pub.dev"}
    source: hosted
    version: "1.2.0"
''',
    });
    expect(await run(harness, <String>['deps', '-f', 'json']), 0);
    final offline = jsonDecode(harness.out) as Map<String, Object?>;
    expect(offline['outdatedChecked'], isFalse);
    expect(await run(harness, <String>['deps']), 0);
    expect(harness.out, contains('run "inspectra deps --online"'));
    expect(
      await run(harness, <String>['deps', '--online', '-f', 'json']),
      1,
      reason: harness.err,
    );
    expect(rules(harness), <Object?>['OUTDATED_MAJOR', 'LIBYEAR_EXCEEDED']);
    final online = jsonDecode(harness.out) as Map<String, Object?>;
    expect(online['outdatedChecked'], isTrue);
    expect(online['libyears'], closeTo(2.0, 0.01));
    expect(server.value.requests, hasLength(1));
    expect(await run(harness, <String>['deps', '--online']), 1);
    expect(
      server.value.requests,
      hasLength(1),
      reason: 'served from the cache',
    );
    expect(harness.out, contains('2.0 libyears'));
    expect(await run(harness, <String>['check']), 1);
    expect(harness.out, contains('(OUTDATED_MAJOR)'));
    expect(await run(harness, <String>['deps', '--online', '--offline']), 0);
    expect(harness.err, contains('--online has no effect'));
  });

  test('justified overrides and the lockfile policy', () async {
    final git = FakeProcessRunner(
      (executable, arguments) => ProcessOutcome(
        exitCode: 0,
        stdout: arguments.contains('ls-files') ? 'pubspec.yaml\u0000' : '',
        stderr: '',
      ),
    );
    final harness = TestHarness.withFiles(
      <String, String>{
        'pubspec.yaml': '''
name: app
publish_to: none
dependency_overrides:
  intl: 0.19.0
  meta: 1.15.0
inspectra:
  dependency_policy:
    enabled: true
    lockfile_policy: auto
    overrides:
      require_reason: true
      allowed:
        - name: intl
          reason: Flutter pins an older intl.
''',
      },
      environment: <String, String>{
        'INSPECTRA_NETWORK_OSV_URL': server.value.baseUrl,
        'INSPECTRA_NETWORK_PUB_HOSTED_URL': server.value.baseUrl,
      },
      processRunner: git,
    );
    harnesses.add(harness);
    expect(await run(harness, <String>['deps', '-f', 'json']), 1);
    expect(rules(harness), <Object?>[
      'DEPENDENCY_OVERRIDE',
      'UNJUSTIFIED_OVERRIDE',
      'LOCKFILE_POLICY',
    ]);
    expect(git.calls.single, startsWith('git ls-files'));
  });

  test('scan -r checks workspace members against the root lockfile', () async {
    server.value.on(
      'POST',
      '/v1/querybatch',
      FakeResponse.json(<String, Object?>{
        'results': <Object?>[<String, Object?>{}],
      }),
    );
    final TestHarness harness = project(<String, String>{
      'pubspec.yaml': 'name: root\nworkspace: [pkgs/app, pkgs/core]\n',
      'pubspec.lock': '''
packages:
  http:
    dependency: "direct main"
    description: {name: http, sha256: aa, url: "https://pub.dev"}
    source: hosted
    version: "1.2.0"
''',
      'pkgs/app/pubspec.yaml':
          'name: app\nresolution: workspace\n'
          'dependencies:\n  core: any\n  http: any\n',
      'pkgs/core/pubspec.yaml': 'name: core\nresolution: workspace\n',
    });
    expect(
      await run(harness, <String>[
        'scan',
        '-r',
        '--trivy-mode',
        'disabled',
        '-f',
        'json',
      ]),
      1,
      reason: harness.err,
    );
    final report = jsonDecode(harness.out) as Map<String, Object?>;
    expect(report['pubspecs'], <String>[
      'pubspec.yaml',
      'pkgs/app/pubspec.yaml',
      'pkgs/core/pubspec.yaml',
    ]);
    final List<Map<String, Object?>> findings =
        (report['findings']! as List<Object?>).cast<Map<String, Object?>>();
    expect(
      findings.map((finding) => '${finding['ruleId']} ${finding['package']}'),
      <String>['ANY_VERSION http'],
    );
  });
}
