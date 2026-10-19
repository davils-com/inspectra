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

import 'package:inspectra/src/dashboard/report_projects.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixtures.dart';

/// Tests the discovery of the projects of `report --recursive`.
void main() {
  test('finds every package below the folder in the order of the tree', () {
    final String root = temporaryDirectory();
    for (final path in <String>[
      'app',
      'tools-x',
      'tools',
      'tools/member_b',
      'tools/member_a',
      'tools/nested/deep/leaf',
    ]) {
      writeFile(root, '$path/pubspec.yaml', 'name: ${p.basename(path)}\n');
    }
    expect(
      findReportProjects(root).map((path) => p.relative(path, from: root)),
      <String>[
        'app',
        'tools',
        p.join('tools', 'member_a'),
        p.join('tools', 'member_b'),
        p.join('tools', 'nested', 'deep', 'leaf'),
        'tools-x',
      ],
    );
  });

  test('includes the folder itself when it is a package', () {
    final String root = temporaryDirectory();
    writeFile(root, 'pubspec.yaml', 'name: root\n');
    writeFile(root, 'member/pubspec.yaml', 'name: member\n');
    expect(findReportProjects(root), <String>[root, p.join(root, 'member')]);
  });

  test('skips tool caches, build output, coverage and hidden folders', () {
    final String root = temporaryDirectory();
    writeFile(root, 'app/pubspec.yaml', 'name: app\n');
    for (final path in <String>[
      'app/.dart_tool/pub/x',
      'app/build/web',
      'app/coverage/report',
      '.git/modules/sub',
      'node_modules/x',
      'ios/Pods/x',
    ]) {
      writeFile(root, '$path/pubspec.yaml', 'name: hidden\n');
    }
    expect(findReportProjects(root), <String>[p.join(root, 'app')]);
  });

  test('finds nothing in a folder without packages', () {
    expect(findReportProjects(temporaryDirectory()), isEmpty);
  });
}
