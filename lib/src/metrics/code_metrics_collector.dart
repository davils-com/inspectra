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

import 'package:inspectra/src/metrics/code_metrics.dart';
import 'package:inspectra/src/metrics/dart_line_counter.dart';
import 'package:inspectra/src/metrics/line_counts.dart';
import 'package:inspectra/src/util/files.dart';
import 'package:path/path.dart' as p;

/// The directories that hold no sources of the project.
const codeMetricsExclude = <String>[
  '**/.dart_tool/**',
  '**/build/**',
  '.*/**',
  '**/.*/**',
];

/// The suffixes of files written by code generators.
const generatedSuffixes = <String>[
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
  '.specia.dart',
  '.gr.dart',
  '.config.dart',
  '.pb.dart',
  '.pbenum.dart',
  '.pbjson.dart',
  '.pbserver.dart',
];

/// Counts the lines of every Dart file below [root], leaving out tool
/// caches, build output, hidden directories and the globs [exclude], and
/// telling generated files apart by their suffix.
///
/// Returns the metrics with paths relative to [root].
CodeMetrics collectCodeMetrics(
  String root, {
  List<String> exclude = const <String>[],
}) {
  final files = <(String, LineCounts)>[];
  final generated = <(String, LineCounts)>[];
  for (final String path in listFiles(
    root,
    const <String>['**.dart'],
    <String>[...codeMetricsExclude, ...exclude],
  )) {
    final LineCounts lines = countDartLines(
      File(p.join(root, path)).readAsStringSync(),
    );
    final bool isGenerated = generatedSuffixes.any(path.endsWith);
    (isGenerated ? generated : files).add((path, lines));
  }
  return CodeMetrics(files: files, generated: generated);
}
