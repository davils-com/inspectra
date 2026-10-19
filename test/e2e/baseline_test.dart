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

import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';
import '../support/test_harness.dart';

/// Runs `inspectra baseline` and the checks that apply the baseline
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

  /// Creates a harness for a package with [files] whose services point at
  /// the fake server.
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

  /// Reads the baseline file of [harness].
  ///
  /// Returns the decoded file.
  Map<String, Object?> baselineOf(TestHarness harness) => jsonDecode(
    File('${harness.workingDirectory}/inspectra-baseline.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;

  /// Writes [content] to [path] in the package of [harness].
  void write(TestHarness harness, String path, String content) =>
      File('${harness.workingDirectory}/$path').writeAsStringSync(content);

  group('style', () {
    const pubspec =
        'name: demo\ninspectra:\n  style:\n    enabled: true\n'
        '    rules: {no_else: true}\n';

    /// A function with one `else` after [padding] empty lines.
    String withElse(String name, {int padding = 0}) =>
        '${'\n' * padding}int $name(bool a) {\n  if (a) {\n    return 1;\n'
        '  } else {\n    return 2;\n  }\n}\n';

    test('records, covers, reports new and prunes fixed violations', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'lib/a.dart': withElse('f'),
      });
      expect(await run(harness, <String>['style']), 1);

      expect(
        await run(harness, <String>['baseline', 'create', '--only', 'style']),
        0,
        reason: harness.err,
      );
      expect(harness.out, contains('1 finding(s) recorded'));
      final entry =
          (baselineOf(harness)['entries']! as List<Object?>).single!
              as Map<String, Object?>;
      expect(entry['rule'], 'no_else');
      expect(entry['path'], 'lib/a.dart');

      expect(await run(harness, <String>['style']), 0, reason: harness.out);
      expect(harness.out, contains('1 finding(s) covered by the baseline'));

      write(harness, 'lib/a.dart', withElse('f', padding: 5) + withElse('g'));
      expect(await run(harness, <String>['style', '-f', 'json']), 1);
      final json = jsonDecode(harness.out) as Map<String, Object?>;
      expect(json['findings'], hasLength(1));
      expect(json['baseline'], <String, Object?>{'covered': 1, 'stale': 0});

      write(harness, 'lib/a.dart', 'int f(bool a) => a ? 1 : 2;\n');
      expect(await run(harness, <String>['style']), 0);
      expect(harness.out, contains('1 baseline entry is fixed'));
      expect(
        await run(harness, <String>[
          'style',
          '--set',
          'baseline.fail_on_stale=true',
        ]),
        1,
      );

      expect(
        await run(harness, <String>[
          'baseline',
          'prune',
          '--only',
          'style',
          '-f',
          'json',
        ]),
        0,
      );
      final report = jsonDecode(harness.out) as Map<String, Object?>;
      expect(report['command'], 'baseline prune');
      expect(report['changed'], isTrue);
      expect(report['scopes'], <Object?>[
        <String, Object?>{'scope': 'style', 'before': 1, 'after': 0},
      ]);
      expect(baselineOf(harness)['entries'], isEmpty);
    });

    test('check applies the baseline, which can be switched off', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'lib/a.dart': withElse('f'),
      });
      expect(await run(harness, <String>['check']), 1);
      expect(
        await run(harness, <String>['baseline', 'create', '--only', 'style']),
        0,
      );
      expect(await run(harness, <String>['check']), 0, reason: harness.out);
      expect(harness.out, contains('covered by the baseline'));
      expect(
        await run(harness, <String>[
          'style',
          '--set',
          'baseline.enabled=false',
        ]),
        1,
      );
    });

    test('a second create leaves the unchanged file alone', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'lib/a.dart': withElse('f'),
      });
      await run(harness, <String>['baseline', 'create', '--only', 'style']);
      expect(
        await run(harness, <String>['baseline', 'create', '--only', 'style']),
        0,
      );
      expect(harness.out, contains('unchanged'));
    });

    test('a malformed baseline fails with 65', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.yaml': pubspec,
        'lib/a.dart': withElse('f'),
        'inspectra-baseline.json': '{"schemaVersion": 1}',
      });
      expect(await run(harness, <String>['style']), 65);
      expect(harness.err, contains('"entries" list'));
      expect(await run(harness, <String>['check']), 65);
    });
  });

  group('scan', () {
    const lockfile = '''
packages:
  http:
    dependency: "direct main"
    description: {name: http, url: "https://pub.dev"}
    source: hosted
    version: "0.13.0"
''';

    /// Answers the OSV batch query with [vulnerable] advisories.
    void serve({required bool vulnerable}) {
      server.value
        ..on(
          'POST',
          '/v1/querybatch',
          FakeResponse.json(<String, Object?>{
            'results': <Object?>[
              <String, Object?>{
                if (vulnerable)
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
            'summary': 'http is vulnerable',
            'affected': <Object?>[
              <String, Object?>{
                'package': <String, Object?>{
                  'name': 'http',
                  'ecosystem': 'Pub',
                },
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

    test('audit and scan leave out recorded advisories', () async {
      serve(vulnerable: true);
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
      });
      expect(await run(harness, <String>['audit']), 1);
      expect(
        await run(harness, <String>[
          'baseline',
          'create',
          '--only',
          'scan',
          '--trivy-mode',
          'disabled',
        ]),
        0,
        reason: harness.err,
      );
      final entry =
          (baselineOf(harness)['entries']! as List<Object?>).single!
              as Map<String, Object?>;
      expect(entry, containsPair('package', 'http'));
      expect(entry, containsPair('rule', 'GHSA-1'));
      expect(entry.containsKey('version'), isFalse);

      expect(await run(harness, <String>['audit', '-f', 'json']), 0);
      final audit = jsonDecode(harness.out) as Map<String, Object?>;
      expect(audit['baselined'], 1);
      expect(audit['totalVulnerabilities'], 0);
      expect(
        await run(harness, <String>['scan', '--trivy-mode', 'disabled']),
        0,
      );
      expect(harness.out, contains('1 covered by the baseline'));
      expect(
        await run(harness, <String>[
          'audit',
          '--set',
          'baseline.enabled=false',
        ]),
        1,
      );
    });

    test('create runs scan and the enabled checks by default', () async {
      serve(vulnerable: true);
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
        'pubspec.yaml':
            'name: demo\ninspectra:\n  trivy:\n    mode: disabled\n'
            '  style:\n    enabled: true\n    rules: {no_else: true}\n',
        'lib/a.dart':
            'int f(bool a) {\n  if (a) {\n    return 1;\n  } '
            'else {\n    return 2;\n  }\n}\n',
      });
      expect(
        await run(harness, <String>['baseline', 'create', '-f', 'json']),
        0,
        reason: harness.err,
      );
      final report = jsonDecode(harness.out) as Map<String, Object?>;
      expect(report['total'], 2);
      expect(report['scopes'], <Object?>[
        <String, Object?>{'scope': 'scan', 'before': 0, 'after': 1},
        <String, Object?>{'scope': 'style', 'before': 0, 'after': 1},
      ]);
      expect(await run(harness, <String>['scan']), 0, reason: harness.out);
      expect(await run(harness, <String>['typosquat']), 0);
    });

    test('an incomplete run writes nothing', () async {
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
      });
      expect(
        await run(harness, <String>[
          'baseline',
          'create',
          '--only',
          'scan',
          '--offline',
        ]),
        69,
      );
      final file = File('${harness.workingDirectory}/inspectra-baseline.json');
      expect(file.existsSync(), isFalse);
    });

    test('prune keeps the entries of a Trivy that did not run', () async {
      serve(vulnerable: false);
      final TestHarness harness = project(<String, String>{
        'pubspec.lock': lockfile,
        'inspectra-baseline.json': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'entries': <Object?>[
            for (final source in <String>['osv', 'trivy'])
              <String, Object?>{
                'scope': 'scan',
                'source': source,
                'rule': 'GHSA-1',
                'package': 'http',
                'path': 'pubspec.lock',
                'count': 1,
                'severity': 'medium',
                'title': 'advisory',
              },
          ],
        }),
      });
      expect(
        await run(harness, <String>[
          'baseline',
          'prune',
          '--only',
          'scan',
          '--trivy-mode',
          'disabled',
        ]),
        0,
        reason: harness.err,
      );
      final entries = baselineOf(harness)['entries']! as List<Object?>;
      expect(entries.map((entry) => (entry! as Map)['source']), <String>[
        'trivy',
      ]);
    });
  });
}
