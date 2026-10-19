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

import 'package:inspectra/src/pub/project_discovery.dart';
import 'package:inspectra/src/util/display_path.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fixture.dart';

/// Tests lockfile discovery in monorepos and display paths.
void main() {
  final root = Fixture<Directory>();

  setUp(() {
    root.value = Directory.systemTemp.createTempSync('discovery_');
    for (final path in <String>[
      'pubspec.lock',
      'packages/a/pubspec.lock',
      'packages/b/pubspec.lock',
      'packages/b/build/x/pubspec.lock',
      '.dart_tool/x/pubspec.lock',
      'node_modules/y/pubspec.lock',
    ]) {
      File('${root.value.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
    }
  });
  tearDown(() => root.value.deleteSync(recursive: true));

  test('finds only the root lockfile without recursion', () {
    final List<String> found = ProjectDiscovery(root.value.path)
        .find('pubspec.lock', recursive: false);
    expect(found.map((f) => displayPath(f, root.value.path)), <String>[
      'pubspec.lock',
    ]);
  });

  test('skips build output, tool caches and vendored folders', () {
    final List<String> found = ProjectDiscovery(root.value.path)
        .find('pubspec.lock', recursive: true);
    expect(found.map((f) => displayPath(f, root.value.path)), <String>[
      'packages/a/pubspec.lock',
      'packages/b/pubspec.lock',
      'pubspec.lock',
    ]);
  });

  test('displayPath keeps outside paths absolute and uses slashes', () {
    expect(displayPath(root.value.path, root.value.path), '.');
    final String outside = p.join(
      p.rootPrefix(p.absolute(root.value.path)),
      'elsewhere',
      'x',
    );
    expect(
      displayPath(outside, root.value.path),
      outside.replaceAll(r'\', '/'),
    );
  });
}
