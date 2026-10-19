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

@TestOn('posix')
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inspectra/builder.dart';
import 'package:inspectra/src/builders/trivy_builder.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';
import 'support/fixtures.dart';

/// A Trivy report with one critical secret in `lib/a.dart`.
const Map<String, List<Map<String, Object>>> _secretReport = {
  'Results': [
    {
      'Target': 'lib/a.dart',
      'Class': 'secret',
      'Secrets': [
        {
          'RuleID': 'github-pat',
          'Severity': 'CRITICAL',
          'Title': 'GitHub Personal Access Token',
          'StartLine': 1,
        },
      ],
    },
  ],
};

/// A pubspec that enables Trivy with [executable], followed by [extra].
String _pubspec(String executable, {String extra = ''}) =>
    '''
name: a
inspectra:
  trivy:
    enabled: true
    executable: $executable
$extra''';

/// Tests the Trivy builders against a fake Trivy executable.
void main() {
  final directory = Fixture<String>();

  setUp(() => directory.value = temporaryDirectory());

  test(
    'runs the secret scan on the build sources and fails on findings',
    () async {
      final trivy = FakeTrivy(directory.value, report: _secretReport);

      final TestBuilderResult result = await testBuilder(
        TrivyBuilder.secret(inPackage: (_) => true),
        {
          'a|pubspec.yaml': _pubspec(trivy.executable),
          'a|lib/a.dart': 'const token = "...";',
          'a|lib/b.txt': 'other',
        },
        rootPackage: 'a',
        outputs: {
          'a|inspectra/trivy/secret.json': decodedMatches(
            contains('"failed": true'),
          ),
        },
      );

      expect(result.succeeded, isFalse);
      expect(trivy.scannedFiles, containsAll(['lib/a.dart', 'pubspec.yaml']));
      expect(trivy.scannedFiles, isNot(contains('lib/b.txt')));
    },
  );

  test('skips build outputs that are not files of the package', () async {
    final trivy = FakeTrivy(directory.value);

    await testBuilder(
      TrivyBuilder.secret(inPackage: (id) => id.path != 'lib/generated.dart'),
      {
        'a|pubspec.yaml': _pubspec(trivy.executable),
        'a|lib/a.dart': 'void main() {}',
        'a|lib/generated.dart': 'void generated() {}',
      },
      rootPackage: 'a',
      outputs: {'a|inspectra/trivy/secret.json': anything},
    );

    expect(trivy.scannedFiles, contains('lib/a.dart'));
    expect(trivy.scannedFiles, isNot(contains('lib/generated.dart')));
  });

  test('only warns when findings do not fail the scan', () async {
    final trivy = FakeTrivy(directory.value, report: _secretReport);

    final TestBuilderResult result = await testBuilder(
      TrivyBuilder.secret(inPackage: (_) => true),
      {
        'a|pubspec.yaml': _pubspec(
          trivy.executable,
          extra: '    secret:\n      fail_on_findings: false\n',
        ),
        'a|lib/a.dart': 'const token = "...";',
      },
      rootPackage: 'a',
      outputs: {
        'a|inspectra/trivy/secret.json': decodedMatches(
          contains('"failed": false'),
        ),
      },
    );

    expect(result.succeeded, isTrue);
  });

  test('skips scans that do not run on build', () async {
    final trivy = FakeTrivy(directory.value);

    await testBuilder(
      vulnerabilityScanBuilder(BuilderOptions.empty),
      {
        'a|pubspec.yaml': _pubspec(trivy.executable),
        'a|pubspec.lock': 'packages: {}\n',
      },
      rootPackage: 'a',
      outputs: {},
    );
  });

  test(
    'scans the lock file when the vulnerability scan runs on build',
    () async {
      final trivy = FakeTrivy(directory.value);

      await testBuilder(
        vulnerabilityScanBuilder(BuilderOptions.empty),
        {
          'a|pubspec.yaml': _pubspec(
            trivy.executable,
            extra: '    vulnerability:\n      run_on_build: true\n',
          ),
          'a|pubspec.lock': 'packages: {}\n',
        },
        rootPackage: 'a',
        outputs: {
          'a|inspectra/trivy/vulnerability.json': decodedMatches(
            contains('"findings": []'),
          ),
        },
      );

      expect(trivy.scannedLock, 'packages: {}\n');
    },
  );

  test('fails when Trivy itself fails', () async {
    final trivy = FakeTrivy(directory.value, exitCode: 2);

    final TestBuilderResult result = await testBuilder(
      TrivyBuilder.secret(inPackage: (_) => true),
      {
        'a|pubspec.yaml': _pubspec(trivy.executable),
        'a|lib/a.dart': 'void main() {}',
      },
      rootPackage: 'a',
      outputs: {},
    );

    expect(result.succeeded, isFalse);
  });

  test('does nothing while Trivy is disabled', () async {
    await testBuilder(
      TrivyBuilder.secret(inPackage: (_) => true),
      {'a|pubspec.yaml': 'name: a\n', 'a|lib/a.dart': 'void main() {}'},
      rootPackage: 'a',
      outputs: {},
    );
  });
}
