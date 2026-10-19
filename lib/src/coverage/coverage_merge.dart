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

import 'package:coverage/coverage.dart';
import 'package:inspectra/src/coverage/coverage_hits.dart';

/// Merges the hits of several test runs into one hit map per file.
///
/// The complete runs, such as those on the VM, define which lines a file
/// has; their hits add up. An incomplete run, such as one in a browser,
/// only adds hits to lines a complete run knows, since the lines it maps
/// back from JavaScript do not always match the executable lines of the
/// VM. A file that no complete run loaded is left out of the hit maps and
/// returned in `incompleteOnly`, because its lines without hits are
/// unknown.
///
/// Returns the merged hit maps keyed by absolute path, and the sorted paths
/// of the files only incomplete runs loaded.
({Map<String, HitMap> files, List<String> incompleteOnly}) mergeCoverageHits(
  List<CoverageHits> runs,
) {
  final merged = <String, HitMap>{};
  for (final CoverageHits run in runs.where((run) => run.complete)) {
    merged.merge(<String, HitMap>{
      for (final MapEntry(key: path, value: hits) in run.files.entries)
        path: _copy(hits),
    });
  }
  final incompleteOnly = <String>{};
  for (final CoverageHits run in runs.where((run) => !run.complete)) {
    for (final MapEntry(key: path, value: hits) in run.files.entries) {
      final HitMap? known = merged[path];
      if (known == null) {
        incompleteOnly.add(path);
        continue;
      }
      final Map<int, int> lines = known.lineHits;
      for (final MapEntry(key: line, value: count) in hits.lineHits.entries) {
        final int? current = lines[line];
        if (current != null) {
          lines[line] = current + count;
        }
      }
    }
  }
  return (files: merged, incompleteOnly: incompleteOnly.toList()..sort());
}

/// Copies [hits], so that merging never changes the hit maps of a run.
///
/// Returns the copy.
HitMap _copy(HitMap hits) => HitMap(
  Map<int, int>.of(hits.lineHits),
  _copyOf(hits.funcHits),
  _copyOf(hits.funcNames),
  _copyOf(hits.branchHits),
);

/// Copies [map], if there is one.
///
/// Returns the copy, or `null` for no map.
Map<K, V>? _copyOf<K, V>(Map<K, V>? map) =>
    map == null ? null : Map<K, V>.of(map);
