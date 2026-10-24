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

import 'package:glob/glob.dart';
import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/config/generated_files.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../support/fixtures.dart';

/// Tests the generated files that the format check, the style check and the
/// coverage gate leave out by default.
void main() {
  test('the generated files cover the common code generators and Specia', () {
    expect(generatedFiles, <String>[
      '**.g.dart',
      '**.freezed.dart',
      '**.mocks.dart',
      '**.specia.dart',
    ]);
  });

  test('the format, style and coverage defaults leave them out', () {
    final config = InspectraConfig.defaults('app');
    expect(config.format.exclude, containsAll(generatedFiles));
    expect(config.style.exclude, containsAll(generatedFiles));
    expect(config.coverage.exclude, generatedFiles);
  });

  test('the default exclude skips every library Specia writes', () {
    final String root = temporaryDirectory();
    for (final kind in <String>['model', 'api', 'client', 'ext']) {
      writeFile(root, 'lib/src/pets.$kind.specia.dart', 'var a = 1;\n');
    }
    writeFile(root, 'lib/specia.dart', 'var b = 1;\n');
    writeFile(root, 'lib/src/specia_dart.dart', 'var c = 1;\n');
    expect(
      listFiles(root, FormatConfig.defaultInclude, FormatConfig.defaultExclude),
      <String>['lib/specia.dart', 'lib/src/specia_dart.dart'],
    );
  });

  test('the coverage globs match a Specia library in any directory', () {
    final List<Glob> globs = [
      for (final pattern in generatedFiles) Glob(pattern, context: p.posix),
    ];

    /// Returns whether one of the generated file globs matches [path].
    bool isExcluded(String path) => globs.any((glob) => glob.matches(path));
    expect(isExcluded('lib/pets.client.specia.dart'), isTrue);
    expect(isExcluded('lib/src/api/pets.model.specia.dart'), isTrue);
    expect(isExcluded('lib/src/specia.dart'), isFalse);
  });

  test('the entropy scan skips Specia libraries too', () {
    expect(InspectConfig.defaultEntropyExcludes, contains('.specia.dart'));
  });

  test('the lint preset still analyzes the libraries Specia writes', () {
    final yaml =
        loadYaml(File('lib/lints/strict.yaml').readAsStringSync()) as YamlMap;
    final analyzer = yaml['analyzer'] as YamlMap;
    final List<String> excluded = (analyzer['exclude'] as YamlList)
        .cast<String>();
    expect(excluded, isNot(contains(matches('specia'))));
    expect(excluded, contains('**/*.g.dart'));
  });
}
