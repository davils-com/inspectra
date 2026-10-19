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

import 'package:inspectra/src/config/config_base_cache.dart';
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';
import '../support/test_harness.dart';

/// Runs configuration inheritance through the command line.
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

  const policy = '''
policy:
  locked: [trivy.secret.enabled]
  minimum:
    coverage.min_line_coverage: 70
fail_on: high
coverage:
  min_line_coverage: 75
style:
  enabled: true
  license_header: header.txt
  rules:
    license_header: true
''';

  /// Creates a project that extends the package `acme` with [inspectra]
  /// as its configuration, plus [files].
  TestHarness project(
    String inspectra, [
    Map<String, String> files = const <String, String>{},
  ]) {
    final harness = TestHarness.withFiles(<String, String>{
      'pubspec.yaml': 'name: app\n',
      'inspectra.yaml': inspectra,
      'vendor/acme/lib/inspectra.yaml': policy,
      'vendor/acme/lib/header.txt': '// Copyright {year} Acme\n',
      '.dart_tool/package_config.json':
          '{"configVersion": 2, "packages": [{"name": "acme", '
          '"rootUri": "../vendor/acme", "packageUri": "lib/"}]}',
      ...files,
    });
    harnesses.add(harness);
    return harness;
  }

  const extendsAcme = 'extends: package:acme/inspectra.yaml\n';

  test('config show explains which base each value comes from', () async {
    final TestHarness harness = project('${extendsAcme}min_severity: low\n');
    expect(
      await harness.run(<String>['config', 'show', '--explain']),
      0,
      reason: harness.err,
    );
    expect(
      harness.out,
      matches(RegExp(r'fail_on: high +# package:acme/inspectra\.yaml:5')),
    );
    expect(
      harness.out,
      contains('inspectra.yaml, 1 base(s) and its overrides'),
    );
    (harness.context.out as StringBuffer).clear();
    expect(await harness.run(<String>['config', 'show', '-f', 'json']), 0);
    final json = jsonDecode(harness.out) as Map<String, Object?>;
    expect(json['layers'], <Object?>[
      <String, Object?>{
        'label': 'package:acme/inspectra.yaml',
        'kind': 'package',
      },
      <String, Object?>{'label': 'inspectra.yaml', 'kind': 'project'},
    ]);
  });

  test(
    'a policy binds the project, the environment and the command line',
    () async {
      final TestHarness weak = project(
        '${extendsAcme}coverage:\n  min_line_coverage: 50\n',
      );
      expect(await weak.run(<String>['config', 'validate']), 65);
      expect(weak.err, contains('is below the minimum 70 set by package:acme'));
      final TestHarness harness = project(extendsAcme);
      expect(await harness.run(<String>['config', 'validate']), 0);
      expect(
        await harness.run(<String>[
          'config',
          'validate',
          '--set',
          'trivy.secret.enabled=false',
        ]),
        65,
      );
      expect(harness.err, contains('locked to true by package:acme'));
      expect(await harness.run(<String>['coverage', '--min', '50']), 65);
      expect(harness.err, contains('50.0 (the command line) is below'));
    },
  );

  test('a base can ship the license header', () async {
    final TestHarness harness = project(extendsAcme, <String, String>{
      'lib/a.dart': '// Copyright 2026 Acme\nvoid main() {}\n',
      'lib/b.dart': 'void main() {}\n',
    });
    expect(await harness.run(<String>['style']), 1);
    expect(harness.out, contains('lib/b.dart'));
    expect(harness.out, isNot(contains('lib/a.dart')));
  });

  test('config fetch downloads remote bases for offline use', () async {
    const remote = 'min_severity: medium\n';
    server.value.on('GET', '/base.yaml', FakeResponse.text(remote));
    final String sha = ConfigBaseCache.digestOf(utf8.encode(remote));
    final TestHarness harness = project(
      'extends:\n  - url: ${server.value.baseUrl}/base.yaml\n    sha256: $sha\n',
    );
    expect(await harness.run(<String>['config', 'fetch', '--offline']), 69);
    expect(harness.err, contains('offline'));
    expect(
      await harness.run(<String>['config', 'fetch']),
      0,
      reason: harness.err,
    );
    expect(harness.out, contains('(remote, downloaded)'));
    expect(harness.out, contains('1 base(s) ready, 1 downloaded.'));
    expect(
      await harness.run(<String>[
        'config',
        'show',
        '--offline',
        '--only-changed',
        '--explain',
      ]),
      0,
    );
    expect(harness.out, contains('min_severity: medium'));
    expect(server.value.requests, hasLength(1));
  });

  test('config lint warns about a pubspec section that is ignored', () async {
    final TestHarness harness = project(extendsAcme, <String, String>{
      'pubspec.yaml': 'name: app\ninspectra:\n  fail_on: low\n',
    });
    expect(
      await harness.run(<String>['config', 'lint', '-f', 'json']),
      0,
      reason: harness.err,
    );
    expect(harness.out, contains('CONFIG_PUBSPEC_SECTION_IGNORED'));
  });

  test('--profile selects a profile for every command', () async {
    final TestHarness harness = project(
      '${extendsAcme}profiles:\n  ci:\n    min_severity: medium\n',
    );
    expect(
      await harness.run(<String>[
        'config',
        'show',
        '--profile',
        'ci',
        '--explain',
        '--only-changed',
      ]),
      0,
      reason: harness.err,
    );
    expect(
      harness.out,
      matches(RegExp(r'min_severity: medium +# profile ci of inspectra\.yaml')),
    );
    expect(harness.out, contains('profile: ci'));
    expect(
      await harness.run(<String>['config', 'show', '--profile', 'cd']),
      65,
    );
    expect(harness.err, contains('Did you mean "ci"?'));
    expect(await harness.run(<String>['format', '--profile', 'cd']), 65);
  });
}
