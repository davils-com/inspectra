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

import 'package:inspectra/src/config/config_suggestion.dart';
import 'package:inspectra/src/config/inspectra_config_exception.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// A further test run whose coverage is merged into the report, an entry of
/// `coverage.merge`, such as the tests of a preset or of a browser.
final class CoverageRun {
  /// Creates the run [name], which passes [testArguments] to the runner.
  const CoverageRun({required this.name, this.testArguments = const []});

  /// Parses one [entry] of the list at [path].
  ///
  /// Returns the run.
  ///
  /// Throws an [InspectraConfigException] for a malformed entry.
  factory CoverageRun._fromEntry(Object? entry, String path) {
    if (entry is! Map) {
      throw InspectraConfigException(
        path,
        'expected a mapping with name and test_arguments.',
      );
    }
    const allowed = <String>{'name', 'test_arguments'};
    final Iterable<Object?> unknown = entry.keys.where(
      (key) => !allowed.contains('$key'),
    );
    if (unknown.isNotEmpty) {
      throw InspectraConfigException(
        '$path.${unknown.first}',
        'unknown option.${didYouMean('${unknown.first}', allowed)} Known '
            'options here: ${allowed.join(', ')}.',
      );
    }
    final Object? name = entry['name'];
    final bool validName = name is String && _namePattern.hasMatch(name);
    if (!validName) {
      throw InspectraConfigException(
        '$path.name',
        'expected a name of lower case letters, digits, - and _, such as '
            'chrome; it names the directory of the raw coverage.',
      );
    }
    return CoverageRun(
      name: name,
      testArguments: _arguments(
        entry['test_arguments'],
        '$path.test_arguments',
      ),
    );
  }

  /// Reads the `merge` list of the `coverage` section in [yaml]; every layer
  /// of the configuration adds its entries.
  ///
  /// Returns the runs, empty when the list is absent.
  ///
  /// Throws an [InspectraConfigException] for malformed entries, unknown
  /// keys, and two runs of the same name.
  static List<CoverageRun> listFromYaml(YamlReader yaml) {
    final runs = <CoverageRun>[];
    for (final (Object? raw, String path, String? file)
        in yaml.structuredLayers('merge', fallback: const <Object?>[])) {
      if (raw == null) {
        continue;
      }
      if (raw is! List) {
        throw InspectraConfigException(
          path,
          'expected a list of runs with name and test_arguments.',
          file: file,
        );
      }
      for (var index = 0; index < raw.length; index++) {
        final at = '$path[$index]';
        final CoverageRun run;
        try {
          run = CoverageRun._fromEntry(raw[index], at);
        } on InspectraConfigException catch (error) {
          throw InspectraConfigException(
            error.path,
            error.message,
            file: file ?? error.file,
          );
        }
        if (runs.any((known) => known.name == run.name)) {
          throw InspectraConfigException(
            '$at.name',
            'the run ${run.name} is defined twice.',
            file: file,
          );
        }
        runs.add(run);
      }
    }
    return List<CoverageRun>.unmodifiable(runs);
  }

  /// The name of the run, which also names the directory of its raw
  /// coverage below `<output_directory>/merge/`.
  final String name;

  /// The arguments passed to the runner after Inspectra's own, such as
  /// `['--platform', 'chrome']`.
  final List<String> testArguments;

  /// What a run name may consist of, since it names a directory.
  static final _namePattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

  /// Reads the list of arguments at [path].
  ///
  /// Returns the arguments, empty when [value] is absent.
  ///
  /// Throws an [InspectraConfigException] when it is no list of texts or
  /// numbers.
  static List<String> _arguments(Object? value, String path) {
    if (value == null) {
      return const <String>[];
    }
    final bool valid =
        value is List &&
        value.every((item) => (item is String && item != '') || item is num);
    if (!valid) {
      throw InspectraConfigException(path, 'expected a list of arguments.');
    }
    return List<String>.unmodifiable(value.map((item) => '$item'));
  }
}
