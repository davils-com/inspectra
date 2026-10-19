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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/config/config_base_cache.dart';
import 'package:inspectra/src/config/config_layers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixture.dart';
import '../support/fixtures.dart';

/// Tests configuration inheritance: layered values, resolving bases and
/// policies.
void main() {
  final root = Fixture<String>();

  setUp(() {
    root.value = temporaryDirectory();
    writeFile(root.value, 'app/pubspec.yaml', 'name: app\n');
  });

  /// Writes [files] below the temporary directory.
  void write(Map<String, String> files) {
    for (final MapEntry<String, String> file in files.entries) {
      writeFile(root.value, file.key, file.value);
    }
  }

  /// Makes the package `acme` in `acme/` a dependency of `app`.
  void acmePackage(String config) {
    write(<String, String>{
      'acme/lib/inspectra.yaml': config,
      'app/.dart_tool/package_config.json':
          '{"configVersion": 2, "packages": [{"name": "acme", '
          '"rootUri": "../../acme", "packageUri": "lib/"}]}',
    });
  }

  /// Loads the configuration of `app` with the command line values [cli]
  /// and the environment variables [environment].
  ///
  /// Returns the configuration.
  InspectraConfig load({
    Map<String, String> cli = const <String, String>{},
    Map<String, String> environment = const <String, String>{},
    ConfigRecorder? recorder,
    String? configFile,
  }) => loadConfig(
    p.join(root.value, 'app'),
    overrides: ConfigOverrides(cli: cli, environment: Environment(environment)),
    recorder: recorder,
    configFile: configFile,
    cacheRoot: p.join(root.value, 'cache'),
  );

  /// Returns a matcher for the configuration error whose text contains
  /// every one of [parts].
  Matcher fails(List<String> parts) => throwsA(
    isA<InspectraConfigException>().having(
      (error) => '$error',
      'message',
      allOf(<Matcher>[for (final String part in parts) contains(part)]),
    ),
  );

  group('layers', () {
    test('a project overrides its bases key by key', () {
      write(<String, String>{
        'base.yaml':
            'fail_on: high\n'
            'format:\n  enabled: true\n  include: ["lib/**.dart"]\n'
            'coverage:\n  enabled: true\n  min_line_coverage: 70\n'
            'trivy:\n  version: 0.70.0\n',
        'app/inspectra.yaml':
            'extends: ../base.yaml\n'
            'format:\n  include: ["bin/**.dart"]\n'
            'coverage:\n  min_line_coverage: 80\n'
            'trivy:\n  version: ~\n',
      });
      final InspectraConfig config = load();
      expect(config.failOn, Severity.high);
      expect(config.format.enabled, isTrue);
      expect(config.format.include, <String>['bin/**.dart']);
      expect(config.coverage.enabled, isTrue);
      expect(config.coverage.minLineCoverage, 80);
      expect(
        config.trivy.version,
        InspectraConfig.defaults('app').trivy.version,
      );
    });

    test('a key with + adds to the list of the lower layers', () {
      write(<String, String>{
        'base.yaml':
            'dependency_policy:\n  dev_only: [mockito]\n'
            'coverage:\n  report_on+: [bin]\n'
            'trivy:\n  filesystem:\n    scanners: [secret]\n',
        'app/inspectra.yaml':
            'extends: ../base.yaml\n'
            'dependency_policy:\n  dev_only+: [build_runner]\n'
            'trivy:\n  filesystem:\n    scanners+: [license]\n',
      });
      final recorder = ConfigRecorder();
      final InspectraConfig config = load(recorder: recorder);
      expect(config.dependencyPolicy.devOnly, <String>[
        'mockito',
        'build_runner',
      ]);
      expect(config.coverage.reportOn, <String>['lib', 'bin']);
      expect(recorder['dependency_policy.dev_only']?.line, 3);
      expect(recorder['dependency_policy.dev_only']?.file, isNull);
      expect(
        load(cli: <String, String>{'dependency_policy.dev_only': 'lints'})
            .dependencyPolicy
            .devOnly,
        <String>['lints'],
      );
      write(<String, String>{
        'app/inspectra.yaml':
            'extends: ../base.yaml\n'
            'dependency_policy:\n  dev_only: [a]\n  dev_only+: [b]\n',
      });
      expect(load, fails(<String>['dev_only+', 'not both']));
      write(<String, String>{
        'app/inspectra.yaml': 'dependency_policy:\n  dev_only+: b\n',
      });
      expect(load, fails(<String>['dependency_policy.dev_only+', 'a list']));
      write(<String, String>{'app/inspectra.yaml': 'fail_on+: [high]\n'});
      expect(load, fails(<String>['"fail_on+"', 'unknown option']));
    });

    test('ignore and denied collect the entries of every layer', () {
      write(<String, String>{
        'base.yaml':
            'ignore:\n  - id: GHSA-base\n    reason: Accepted.\n'
            'dependency_policy:\n  denied:\n'
            '    - name: left_pad\n      reason: Unmaintained.\n'
            'style:\n  rules:\n    no_else: true\n',
        'app/inspectra.yaml':
            'extends: ../base.yaml\n'
            'ignore:\n  - id: GHSA-app\n    reason: Not reachable.\n'
            'dependency_policy:\n  denied:\n'
            '    - name: right_pad\n      reason: Insecure.\n',
      });
      final InspectraConfig config = load();
      expect(config.ignore.map((rule) => rule.id), <String>[
        'GHSA-base',
        'GHSA-app',
      ]);
      expect(
        config.dependencyPolicy.denied.map((entry) => entry.name),
        <String>['left_pad', 'right_pad'],
      );
    });

    test('records the base and line of every value', () {
      write(<String, String>{
        'base.yaml': 'extends: policy/base.yaml\nfail_on: high\n',
        'policy/base.yaml': 'lint:\n  fail_on: warning\n',
        'app/inspectra.yaml': 'extends: ../base.yaml\nmin_severity: low\n',
      });
      final recorder = ConfigRecorder();
      load(recorder: recorder);
      expect(recorder.source, 'inspectra.yaml');
      expect(recorder.layers.map((layer) => layer.label), <String>[
        '../policy/base.yaml',
        '../base.yaml',
        'inspectra.yaml',
      ]);
      expect(recorder.layers.map((layer) => layer.kind), <ConfigLayerKind>[
        ConfigLayerKind.file,
        ConfigLayerKind.file,
        ConfigLayerKind.project,
      ]);
      final ConfigEntry? lint = recorder['lint.fail_on'];
      expect(lint?.file, '../policy/base.yaml');
      expect(lint?.line, 2);
      expect(recorder['fail_on']?.file, '../base.yaml');
      expect(recorder['min_severity']?.file, isNull);
      expect(recorder['min_severity']?.line, 2);
      expect(recorder['fail_on']?.toJson()['file'], '../base.yaml');
    });

    test('errors in a base name the base', () {
      write(<String, String>{
        'base.yaml': 'format:\n  enabeld: true\n',
        'app/inspectra.yaml': 'extends: ../base.yaml\n',
      });
      expect(
        load,
        fails(<String>['format.enabeld', 'in ../base.yaml', 'enabled']),
      );
      write(<String, String>{'base.yaml': 'fail_on: often\n'});
      expect(load, fails(<String>['"fail_on" in ../base.yaml', 'often']));
      write(<String, String>{'base.yaml': 'ignore:\n  - id: X\n'});
      expect(load, fails(<String>['ignore[0]', 'in ../base.yaml']));
    });

    test('a package label is no file path, also on Windows', () {
      expect(
        () => loadConfigYaml('a: [', 'package:acme/inspectra.yaml'),
        fails(<String>['package:acme/inspectra.yaml', 'line 1']),
      );
      acmePackage('fail_on: [\n');
      write(<String, String>{
        'app/inspectra.yaml': 'extends: package:acme/inspectra.yaml\n',
      });
      expect(load, fails(<String>['package:acme/inspectra.yaml', 'line ']));
      acmePackage('fail_on: high\n');
      expect(load().failOn, Severity.high);
    });

    test('files named in a package base resolve in the package', () {
      acmePackage('style:\n  license_header: header.txt\n');
      write(<String, String>{
        'acme/lib/header.txt': '// Acme\n',
        'app/inspectra.yaml': 'extends: package:acme/inspectra.yaml\n',
      });
      expect(
        load().style.licenseHeader,
        p.join(root.value, 'acme', 'lib', 'header.txt'),
      );
      write(<String, String>{
        'app/inspectra.yaml':
            'extends: package:acme/inspectra.yaml\n'
            'style:\n  license_header: tool/header.txt\n',
      });
      expect(load().style.licenseHeader, 'tool/header.txt');
    });

    test('bases resolve relative to the file that names them', () {
      write(<String, String>{
        'shared/a.yaml': 'extends: b.yaml\nfail_on: high\n',
        'shared/b.yaml': 'fail_on: low\nmin_severity: medium\n',
        'app/config/ci.yaml': 'extends: ../../shared/a.yaml\n',
      });
      final InspectraConfig config = load(configFile: 'config/ci.yaml');
      expect(config.failOn, Severity.high);
      expect(config.minSeverity, Severity.medium);
    });

    test('later bases of a list win over earlier ones', () {
      write(<String, String>{
        'one.yaml': 'fail_on: high\nmin_severity: low\n',
        'two.yaml': 'fail_on: medium\n',
        'app/pubspec.yaml':
            'name: app\ninspectra:\n  extends: [../one.yaml, ../two.yaml]\n',
      });
      final InspectraConfig config = load();
      expect(config.failOn, Severity.medium);
      expect(config.minSeverity, Severity.low);
    });
  });

  group('resolving bases', () {
    test('rejects missing files, packages and cycles', () {
      write(<String, String>{'app/inspectra.yaml': 'extends: nope.yaml\n'});
      expect(load, fails(<String>['the base nope.yaml does not exist']));
      write(<String, String>{
        'app/inspectra.yaml': 'extends: package:acme/inspectra.yaml\n',
      });
      expect(load, fails(<String>['run "dart pub get"']));
      acmePackage('fail_on: high\n');
      write(<String, String>{
        'app/inspectra.yaml': 'extends: package:other/inspectra.yaml\n',
      });
      expect(load, fails(<String>['the package other', 'not a dependency']));
      write(<String, String>{
        'a.yaml': 'extends: b.yaml\n',
        'b.yaml': 'extends: a.yaml\n',
        'app/inspectra.yaml': 'extends: ../a.yaml\n',
      });
      expect(load, fails(<String>['cycle']));
    });

    test('limits how deep bases nest', () {
      for (var level = 0; level < 10; level++) {
        write(<String, String>{
          'chain/$level.yaml': 'extends: ${level + 1}.yaml\n',
        });
      }
      write(<String, String>{
        'chain/10.yaml': 'fail_on: high\n',
        'app/inspectra.yaml': 'extends: ../chain/0.yaml\n',
      });
      expect(load, fails(<String>['more than 8 levels']));
    });

    test('rejects malformed references', () {
      final cases = <String, String>{
        'extends: https://acme.corp/a.yaml\n': 'needs a SHA-256 pin',
        'extends:\n  - url: http://acme.corp/a.yaml\n    sha256: '
                '${'a' * 64}\n':
            'expected an https URL',
        'extends:\n  - url: https://acme.corp/a.yaml\n    sha256: abc\n':
            '64 hexadecimal digits',
        'extends:\n  - url: https://acme.corp/a.yaml\n    pin: x\n':
            'extends[0].pin',
        'extends: package:acme\n': 'expected package:<name>/<path>',
        'extends: [1]\n': 'expected a path',
      };
      for (final MapEntry<String, String> entry in cases.entries) {
        write(<String, String>{'app/inspectra.yaml': entry.key});
        expect(load, fails(<String>[entry.value]), reason: entry.key);
      }
    });

    test('reads remote bases from the cache only', () {
      const text = 'fail_on: critical\n';
      final String sha = ConfigBaseCache.digestOf(text.codeUnits);
      write(<String, String>{
        'app/inspectra.yaml':
            'extends:\n  - url: https://acme.corp/base.yaml\n'
            '    sha256: $sha\n',
      });
      expect(load, fails(<String>['not in the cache', 'config fetch']));
      ConfigBaseCache(p.join(root.value, 'cache')).write(sha, text.codeUnits);
      expect(load().failOn, Severity.critical);
      writeFile(root.value, 'cache/config/$sha.yaml', 'fail_on: low\n');
      expect(load, fails(<String>['not in the cache']));
    });

    test('a remote base cannot name relative files', () {
      const text = 'extends: local.yaml\n';
      final String sha = ConfigBaseCache.digestOf(text.codeUnits);
      ConfigBaseCache(p.join(root.value, 'cache')).write(sha, text.codeUnits);
      write(<String, String>{
        'app/inspectra.yaml':
            'extends:\n  - url: https://acme.corp/base.yaml\n'
            '    sha256: $sha\n',
      });
      expect(load, fails(<String>['cannot extend the relative path']));
      const header = 'style:\n  license_header: header.txt\n';
      final String headerSha = ConfigBaseCache.digestOf(header.codeUnits);
      ConfigBaseCache(p.join(root.value, 'cache'))
          .write(headerSha, header.codeUnits);
      write(<String, String>{
        'app/inspectra.yaml':
            'extends:\n  - url: https://acme.corp/base.yaml\n'
            '    sha256: $headerSha\n',
      });
      expect(load, fails(<String>['cannot name a relative file']));
    });
  });

  group('policies', () {
    setUp(
      () => acmePackage(
        'policy:\n'
        '  locked: [trivy.secret.enabled, style.preset]\n'
        '  minimum:\n'
        '    coverage.min_line_coverage: 70\n'
        '    fail_on: high\n'
        '    lint.fail_on: warning\n'
        '    trivy.mode: auto\n'
        '    format.enabled: true\n'
        'coverage:\n  min_line_coverage: 75\n'
        'fail_on: medium\n'
        'lint:\n  fail_on: warning\n'
        'format:\n  enabled: true\n',
      ),
    );

    /// Writes the project's configuration [yaml] below the policy.
    void project(String yaml) => write(<String, String>{
      'app/inspectra.yaml': 'extends: package:acme/inspectra.yaml\n$yaml',
    });

    test('allows the same or stricter values', () {
      project(
        'coverage:\n  min_line_coverage: 90\n'
        'fail_on: low\n'
        'lint:\n  fail_on: info\n'
        'trivy:\n  mode: required\n  secret:\n    enabled: true\n',
      );
      expect(load().coverage.minLineCoverage, 90);
      expect(
        load(cli: <String, String>{'fail_on': 'unknown'}).failOn,
        Severity.unknown,
      );
    });

    test('rejects locked values changed by any layer above', () {
      project('trivy:\n  secret:\n    enabled: false\n');
      expect(
        load,
        fails(<String>[
          '"trivy.secret.enabled"',
          'locked to true by package:acme/inspectra.yaml',
          'got false from inspectra.yaml:4',
        ]),
      );
      project('');
      expect(
        () => load(
          environment: <String, String>{
            'INSPECTRA_TRIVY_SECRET_ENABLED': 'false',
          },
        ),
        fails(<String>['environment variable INSPECTRA_TRIVY_SECRET_ENABLED']),
      );
      expect(
        () => load(cli: <String, String>{'style.preset': 'strict'}),
        fails(<String>['"style.preset"', 'the command line']),
      );
    });

    test('rejects values below a minimum', () {
      final cases = <String, String>{
        'coverage.min_line_coverage': '50',
        'fail_on': 'critical',
        'lint.fail_on': 'error',
        'trivy.mode': 'disabled',
        'format.enabled': 'false',
      };
      project('');
      for (final MapEntry<String, String> entry in cases.entries) {
        expect(
          () => load(cli: <String, String>{entry.key: entry.value}),
          fails(<String>[
            '"${entry.key}"',
            'is below the minimum',
            'set by package:acme/inspectra.yaml',
          ]),
          reason: entry.key,
        );
      }
      project('coverage:\n  min_line_coverage: ~\n');
      expect(load, fails(<String>['unset (the default)', 'inspectra.yaml']));
    });

    test('collects the severities no ignore may hide from every policy', () {
      acmePackage('policy:\n  forbid_ignore_of: [CRITICAL]\n');
      write(<String, String>{
        'app/inspectra.yaml':
            'extends: package:acme/inspectra.yaml\n'
            'policy:\n  forbid_ignore_of: [high]\n',
      });
      expect(load().forbiddenIgnoreSeverities, <Severity>{
        Severity.critical,
        Severity.high,
      });
    });

    test('a value from an environment reference is bound like any other', () {
      project('fail_on: \${env:FAIL_ON}\n');
      expect(
        () => load(environment: <String, String>{'FAIL_ON': 'critical'}),
        fails(<String>['"critical"', 'is below the minimum "high"']),
      );
      expect(
        load(environment: <String, String>{'FAIL_ON': 'low'}).failOn,
        Severity.low,
      );
    });

    test('a policy of the project binds the environment and command line', () {
      write(<String, String>{
        'app/inspectra.yaml':
            'policy:\n  minimum:\n    fail_on: medium\nfail_on: medium\n',
      });
      expect(load().failOn, Severity.medium);
      expect(
        () => load(cli: <String, String>{'fail_on': 'high'}),
        fails(<String>['set by inspectra.yaml']),
      );
    });

    test('rejects malformed policies', () {
      final cases = <String, String>{
        'policy:\n  locked: [fail_onn]\n': 'Did you mean "fail_on"?',
        'policy:\n  locked: [ignore]\n': 'cannot be locked',
        'policy:\n  minimum:\n    network.offline: true\n': 'lock it instead',
        'policy:\n  minimum:\n    fail_on: often\n': 'no value of fail_on',
        'policy:\n  minimum:\n    trivy.version: 1\n': 'lock it instead',
        'policy:\n  forbid: [x]\n': 'policy.forbid',
        'policy: [x]\n': 'expected a mapping with locked, minimum and',
        'policy:\n  forbid_ignore_of: critical\n':
            'expected a list of severities',
        'policy:\n  forbid_ignore_of: [fatal]\n': '"fatal" is no severity',
        'policy:\n  locked: x\n': 'expected a list of dotted option names',
        'policy:\n  minimum: [x]\n': 'expected a mapping from dotted option',
      };
      for (final MapEntry<String, String> entry in cases.entries) {
        write(<String, String>{'app/inspectra.yaml': entry.key});
        expect(load, fails(<String>[entry.value]), reason: entry.key);
      }
    });
  });

  group('profiles', () {
    test('a selected profile wins over the files but not the command line', () {
      write(<String, String>{
        'base.yaml':
            'fail_on: high\n'
            'profiles:\n  ci:\n    coverage:\n      min_line_coverage: 60\n',
        'app/inspectra.yaml':
            'extends: ../base.yaml\n'
            'coverage:\n  enabled: true\n  min_line_coverage: 50\n'
            'profiles:\n'
            '  ci:\n    fail_on: low\n    network:\n      offline: true\n'
            '  local:\n    fail_on: critical\n',
      });
      expect(load().failOn, Severity.high);
      expect(load().coverage.minLineCoverage, 50);
      final recorder = ConfigRecorder();
      final InspectraConfig ci = load(
        cli: <String, String>{'profile': 'ci'},
        recorder: recorder,
      );
      expect(ci.failOn, Severity.low);
      expect(ci.network.offline, isTrue);
      expect(ci.coverage.minLineCoverage, 60);
      expect(ci.coverage.enabled, isTrue);
      expect(recorder['fail_on']?.file, 'profile ci of inspectra.yaml');
      expect(recorder['fail_on']?.line, 7);
      expect(recorder['profile']?.value, 'ci');
      expect(recorder['profile']?.origin, ConfigOrigin.commandLine);
      expect(
        load(environment: <String, String>{'INSPECTRA_PROFILE': 'local'})
            .failOn,
        Severity.critical,
      );
      expect(
        load(cli: <String, String>{'profile': 'ci', 'fail_on': 'medium'})
            .failOn,
        Severity.medium,
      );
    });

    test('a policy binds the profiles of every layer', () {
      acmePackage(
        'policy:\n  locked: [trivy.secret.enabled]\n'
        'trivy:\n  secret:\n    enabled: true\n',
      );
      write(<String, String>{
        'app/inspectra.yaml':
            'extends: package:acme/inspectra.yaml\n'
            'profiles:\n  fast:\n    trivy:\n      secret:\n'
            '        enabled: false\n',
      });
      expect(load().trivy.secret.enabled, isTrue);
      expect(
        () => load(cli: <String, String>{'profile': 'fast'}),
        fails(<String>[
          '"trivy.secret.enabled"',
          'got false from profile fast of inspectra.yaml:6',
        ]),
      );
    });

    test('rejects unknown and malformed profiles', () {
      write(<String, String>{
        'app/inspectra.yaml': 'profiles:\n  ci:\n    fail_on: low\n',
      });
      expect(
        () => load(cli: <String, String>{'profile': 'cl'}),
        fails(<String>['unknown profile "cl"', 'Did you mean "ci"?']),
      );
      final cases = <String, String>{
        'fail_on: low\n': 'no configuration defines the profile "ci"',
        'profiles: [ci]\n': 'expected a mapping from profile names',
        'profiles:\n  ci: [x]\n': '"profiles.ci": expected a mapping',
        'profiles:\n  ci:\n    extends: ../base.yaml\n':
            'a profile cannot set extends',
        'profiles:\n  ci:\n    fail_onn: low\n': 'Did you mean "fail_on"?',
      };
      for (final MapEntry<String, String> entry in cases.entries) {
        write(<String, String>{'app/inspectra.yaml': entry.key});
        expect(
          () => load(cli: <String, String>{'profile': 'ci'}),
          fails(<String>[entry.value]),
          reason: entry.key,
        );
      }
    });
  });

  test('every strictness order ranks unset as the weakest', () {
    expect(
      ConfigStrictness.of('coverage.min_line_coverage'),
      ConfigStrictness.higherNumber,
    );
    expect(
      ConfigStrictness.of('baseline.max_severity'),
      ConfigStrictness.severityThreshold,
    );
    expect(
      ConfigStrictness.of('trivy.secret.fail_on_findings'),
      ConfigStrictness.enabledFlag,
    );
    expect(
      ConfigStrictness.of('style.rules.no_else'),
      ConfigStrictness.enabledFlag,
    );
    expect(
      ConfigStrictness.of('dependency_policy.check_imports'),
      ConfigStrictness.enabledFlag,
    );
    expect(ConfigStrictness.of('baseline.enabled'), isNull);
    expect(ConfigStrictness.of('trivy.version'), isNull);
    expect(ConfigStrictness.higherNumber.rankOf(null), double.negativeInfinity);
    expect(ConfigStrictness.higherNumber.rankOf('70'), 70);
    expect(ConfigStrictness.enabledFlag.rankOf(null), isNull);
    expect(ConfigStrictness.enabledFlag.rankOf('yes'), isNull);
    expect(
      ConfigStrictness.severityThreshold.rankOf('LOW'),
      greaterThan(ConfigStrictness.severityThreshold.rankOf('high')!),
    );
    expect(
      ConfigStrictness.lintLevel.rankOf('info'),
      greaterThan(ConfigStrictness.lintLevel.rankOf('none')!),
    );
    expect(ConfigStrictness.trivyMode.rankOf('sometimes'), isNull);
  });
}
