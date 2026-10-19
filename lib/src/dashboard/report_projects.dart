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

import 'package:inspectra/src/pub/project_discovery.dart';
import 'package:path/path.dart' as p;

/// Directory names below which `report --recursive` looks for no project,
/// besides the hidden directories, build output and vendored dependencies
/// that every recursive search skips.
const _skippedDirectories = <String>{'coverage'};

/// Finds the projects of `report --recursive`: every directory at or below
/// [root] with a `pubspec.yaml`, members of pub workspaces and nested
/// workspaces included. Hidden directories such as `.dart_tool` and `.git`,
/// `build`, `coverage`, `node_modules`, `Pods` and `ephemeral` are skipped.
///
/// Returns the absolute directories in the order of the tree: sorted by
/// their path segments, so that a workspace root directly precedes its
/// members.
List<String> findReportProjects(String root) {
  final String base = p.normalize(p.absolute(root));
  final projects = <String>[
    for (final String pubspec in ProjectDiscovery(
      base,
    ).find('pubspec.yaml', recursive: true))
      if (!p
          .split(p.relative(p.dirname(pubspec), from: base))
          .any(_skippedDirectories.contains))
        p.dirname(pubspec),
  ];
  return projects..sort(_byTree);
}

/// Compares the directories [a] and [b] segment by segment.
///
/// Returns a negative number when [a] comes first, a positive one when [b]
/// does and zero for the same directory.
int _byTree(String a, String b) {
  final List<String> left = p.split(a);
  final List<String> right = p.split(b);
  final int shared = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < shared; index++) {
    final int order = left[index].compareTo(right[index]);
    if (order != 0) {
      return order;
    }
  }
  return left.length.compareTo(right.length);
}
