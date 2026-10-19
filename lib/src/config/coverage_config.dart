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

import 'package:inspectra/src/config/coverage_run.dart';
import 'package:inspectra/src/config/coverage_runner.dart';
import 'package:inspectra/src/config/generated_files.dart';
import 'package:inspectra/src/config/yaml_reader.dart';

/// The test coverage gate, the `coverage:` section.
final class CoverageConfig {
  /// Creates the coverage settings.
  const CoverageConfig({
    required this.enabled,
    required this.runner,
    required this.outputDirectory,
    required this.reportOn,
    required this.exclude,
    required this.minLineCoverage,
    required this.testArguments,
    this.merge = const <CoverageRun>[],
  });

  /// Reads the settings from the `coverage:` section in [yaml].
  ///
  /// Returns the settings.
  ///
  /// Throws an `InspectraConfigException` for unknown keys or invalid
  /// values.
  factory CoverageConfig.fromYaml(YamlReader yaml) {
    final config = CoverageConfig(
      enabled: yaml.boolean('enabled', fallback: false),
      runner: yaml.choice('runner', <String, CoverageRunner>{
        for (final runner in CoverageRunner.values) runner.name: runner,
      }, fallback: CoverageRunner.dart),
      outputDirectory: yaml.string('output_directory', fallback: 'coverage'),
      reportOn: yaml.strings('report_on', fallback: const ['lib']),
      exclude: yaml.strings('exclude', fallback: generatedFiles),
      minLineCoverage: yaml.optionalNumber(
        'min_line_coverage',
        min: 0,
        max: 100,
      ),
      testArguments: yaml.strings('test_arguments', fallback: const []),
      merge: CoverageRun.listFromYaml(yaml),
    );
    yaml.ensureFullyRead();
    return config;
  }

  /// Whether the coverage command does anything. Off by default.
  final bool enabled;

  /// Which test runner collects the coverage.
  final CoverageRunner runner;

  /// Where the raw coverage and `lcov.info` are written.
  final String outputDirectory;

  /// Directories whose files are reported, relative to the package root.
  final List<String> reportOn;

  /// Globs of files left out of the report, relative to the package root.
  final List<String> exclude;

  /// The line coverage in percent below which the gate fails.
  ///
  /// Unset by default on purpose: measure first, then set a threshold.
  final double? minLineCoverage;

  /// Extra arguments passed to the test runner, for example
  /// `['--exclude-tags', 'slow']`.
  final List<String> testArguments;

  /// Further test runs whose coverage is merged into the report, such as
  /// the tests of a preset or of a browser; empty by default.
  ///
  /// A run on the VM counts like the main run. A browser only reports the
  /// lines it ran, so its hits count only for lines the VM knows; a file
  /// that only a browser loaded is listed apart and not counted.
  final List<CoverageRun> merge;
}
