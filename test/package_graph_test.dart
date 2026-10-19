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

import 'dart:convert';
import 'dart:io';

import 'package:inspectra/inspectra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fixture.dart';
import 'support/fixtures.dart';

/// Tests the dependency graph built from a resolved package.
void main() {
  final root = Fixture<String>();

  setUp(() {
    root.value = temporaryDirectory();
    writeResolvedPackage(
      root.value,
      dependencies: ['http'],
      devDependencies: ['test'],
      packages: [
        const FakePackage('http', dependencies: ['meta']),
        const FakePackage('meta'),
        const FakePackage('test', dependencies: ['meta', 'matcher']),
        const FakePackage('matcher'),
        const FakePackage('local', source: 'path'),
      ],
    );
  });

  test('follows dependencies but not dev_dependencies', () async {
    final PackageGraph graph = await PackageGraph.load(
      p.join(root.value, 'app'),
    );

    expect(graph.reachable(includeDev: false), {'http', 'meta'});
  });

  test('includes dev_dependencies on request', () async {
    final PackageGraph graph = await PackageGraph.load(
      p.join(root.value, 'app'),
    );

    expect(graph.reachable(includeDev: true), {
      'http',
      'meta',
      'test',
      'matcher',
    });
  });

  test('knows where each package lives', () async {
    final PackageGraph graph = await PackageGraph.load(
      p.join(root.value, 'app'),
    );

    expect(graph.directoryOf('http'), p.join(root.value, 'cache', 'http'));
    expect(graph.directoryOf('missing'), isNull);
  });

  test('narrows the lock file to the given packages', () async {
    final PackageGraph graph = await PackageGraph.load(
      p.join(root.value, 'app'),
    );
    final retained =
        jsonDecode(graph.lock.retain({'meta', 'http'})) as Map<String, Object?>;

    expect((retained['packages']! as Map).keys, ['http', 'meta']);
    expect(
      PubspecLock.parse(graph.lock.retain({'meta'})).packages['meta']!.version,
      '1.0.0',
    );
  });

  test('tells external packages from path packages', () async {
    final PubspecLock lock = (await PackageGraph.load(
      p.join(root.value, 'app'),
    )).lock;

    expect(lock.packages['http']!.isExternal, isTrue);
    expect(lock.packages['local']!.isExternal, isFalse);
    expect(lock.packages['test']!.version, '1.0.0');
  });

  test('asks for "dart pub get" when the package is not resolved', () async {
    final String unresolved = temporaryDirectory();
    writeFile(unresolved, 'pubspec.yaml', 'name: unresolved\n');

    await expectLater(
      PackageGraph.load(unresolved),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          contains('dart pub get'),
        ),
      ),
    );
  });
}
