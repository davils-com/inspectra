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

import 'package:inspectra/src/metrics/line_counts.dart';

/// Details of a report section beyond its findings, rendered by the HTML
/// report.
sealed class SectionDetails {
  /// Creates details.
  const SectionDetails();

  /// Serializes the details for the JSON report.
  ///
  /// Returns the JSON object, empty for [NoDetails].
  Map<String, Object?> toJson();
}

/// A section without further details.
final class NoDetails extends SectionDetails {
  /// Creates the absence of details.
  const NoDetails();

  /// Returns an empty JSON object.
  @override
  Map<String, Object?> toJson() => const <String, Object?>{};
}

/// The line coverage of every file, for the coverage section.
final class CoverageDetails extends SectionDetails {
  /// Creates the coverage of [files], with the [untested] files that no
  /// test loaded, the [browserOnly] files only a browser loaded, the total
  /// [percent] and the required [minimum], if any.
  const CoverageDetails({
    required this.files,
    required this.untested,
    required this.percent,
    this.browserOnly = const <String>[],
    this.minimum,
  });

  /// One entry per file: its path, the lines found and the lines hit.
  final List<(String, int, int)> files;

  /// The files no test loaded.
  final List<String> untested;

  /// The files only a browser run loaded, whose coverage is unknown.
  final List<String> browserOnly;

  /// The line coverage of all files, from 0 to 100.
  final double percent;

  /// The required line coverage, or `null` without a threshold.
  final double? minimum;

  /// Serializes the details.
  ///
  /// Returns the JSON object.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'percent': percent,
    'minimum': ?minimum,
    'files': <Map<String, Object?>>[
      for (final (path, found, hit) in files)
        <String, Object?>{'path': path, 'linesFound': found, 'linesHit': hit},
    ],
    'untested': untested,
    if (browserOnly.isNotEmpty) 'browserOnly': browserOnly,
  };
}

/// A unified diff, for the public API section.
final class DiffDetails extends SectionDetails {
  /// Creates the details of the unified [diff].
  const DiffDetails(this.diff);

  /// The unified diff.
  final String diff;

  /// Serializes the details.
  ///
  /// Returns the JSON object.
  @override
  Map<String, Object?> toJson() => <String, Object?>{'diff': diff};
}

/// The size of the code base, for the codebase section.
final class CodebaseDetails extends SectionDetails {
  /// Creates the details of the [areas] of a code base, its [largest]
  /// files and the [generatedFiles] with [generatedLines].
  const CodebaseDetails({
    required this.areas,
    required this.largest,
    this.generatedFiles = 0,
    this.generatedLines = 0,
  });

  /// One entry per top-level directory: its name, its number of files and
  /// its lines.
  final List<(String, int, LineCounts)> areas;

  /// The files with the most lines of code and their lines.
  final List<(String, LineCounts)> largest;

  /// The number of generated files, which [areas] leave out.
  final int generatedFiles;

  /// The lines of the generated files.
  final int generatedLines;

  /// The lines of all areas.
  LineCounts get total =>
      areas.fold(const LineCounts(), (sum, area) => sum + area.$3);

  /// The number of files of all areas.
  int get files => areas.fold(0, (sum, area) => sum + area.$2);

  /// Serializes the details.
  ///
  /// Returns the JSON object.
  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'areas': <Map<String, Object?>>[
      for (final (String name, int files, LineCounts lines) in areas)
        <String, Object?>{'name': name, 'files': files, ...lines.toJson()},
    ],
    'largest': <Map<String, Object?>>[
      for (final (String path, LineCounts lines) in largest)
        <String, Object?>{'path': path, ...lines.toJson()},
    ],
    'generated': <String, Object?>{
      'files': generatedFiles,
      'lines': generatedLines,
    },
  };
}
