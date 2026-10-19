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

import 'package:inspectra/src/coverage/coverage_gate.dart';

/// The result of a coverage run.
class CoverageReport {
  /// Creates a report.
  CoverageReport({
    required List<FileCoverage> files,
    required this.untested,
    required this.lcovPath,
    required this.minLineCoverage,
    this.browserOnly = const <String>[],
  }) : files = List.unmodifiable(
         files..sort((a, b) => a.path.compareTo(b.path)),
       );

  /// The covered files, sorted by path.
  final List<FileCoverage> files;

  /// Files below `report_on` that no test loaded, relative to the package root.
  ///
  /// The VM only reports coverage for libraries a test imported, so these are
  /// not part of [percent]: import them from a test to have them counted.
  final List<String> untested;

  /// Files below `report_on` that only a browser run of `coverage.merge`
  /// loaded, relative to the package root.
  ///
  /// A browser reports only the lines that ran, so the share of these files
  /// is unknown and they are not part of [percent]: load them from a test on
  /// the VM to have them counted.
  final List<String> browserOnly;

  /// The written `lcov.info`.
  final String lcovPath;

  /// The configured threshold in percent, if any.
  final double? minLineCoverage;

  /// The number of executable lines in all [files].
  int get linesFound => files.fold(0, (sum, file) => sum + file.linesFound);

  /// The number of executable lines that ran.
  int get linesHit => files.fold(0, (sum, file) => sum + file.linesHit);

  /// The total line coverage in percent.
  double get percent => linesFound == 0 ? 100 : linesHit * 100 / linesFound;

  /// Whether the coverage is below the threshold.
  bool get failed => minLineCoverage != null && percent < minLineCoverage!;

  /// A readable summary for the console.
  String render() {
    final int width = files.fold(
      4,
      (max, file) => file.path.length > max ? file.path.length : max,
    );
    final buffer = StringBuffer();
    for (final FileCoverage file in files) {
      buffer.writeln(
        '  ${file.path.padRight(width)}  ${_percent(file.percent).padLeft(7)}  (${file.linesHit}/${file.linesFound})',
      );
    }
    buffer.writeln(
      '  ${'Total'.padRight(width)}  ${_percent(percent).padLeft(7)}  ($linesHit/$linesFound)',
    );
    if (untested.isNotEmpty) {
      buffer.writeln(
        '\n  ${untested.length} file(s) were not loaded by any test and are '
        'not counted:',
      );
      for (final String path in untested) {
        buffer.writeln('    $path');
      }
    }
    if (browserOnly.isNotEmpty) {
      buffer.writeln(
        '\n  ${browserOnly.length} file(s) were only loaded in a browser, '
        'whose coverage lacks the lines that did not run, and are not '
        'counted:',
      );
      for (final String path in browserOnly) {
        buffer.writeln('    $path');
      }
    }
    buffer.writeln('\n  Report: $lcovPath');
    final double? threshold = minLineCoverage;
    if (threshold != null) {
      final verdict = failed ? 'is below' : 'meets';
      buffer.write(
        '  Line coverage ${_percent(percent)} $verdict the required '
        '${_percent(threshold)}.',
      );
    }
    return buffer.toString().trimRight();
  }

  /// Formats [value] as a percentage with two decimals, such as `91.20%`.
  static String _percent(double value) => '${value.toStringAsFixed(2)}%';
}
