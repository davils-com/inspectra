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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/config/config_base_cache.dart';
import 'package:inspectra/src/config/config_base_fetch.dart';
import 'package:inspectra/src/config/config_fetch_outcome.dart';
import 'package:inspectra/src/config/config_layers.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';
import '../support/fixtures.dart';

/// Tests downloading the remote bases of a configuration.
void main() {
  final server = Fixture<FakeHttpServer>();
  final root = Fixture<String>();

  setUp(() async {
    server.value = await FakeHttpServer.start();
    root.value = temporaryDirectory();
  });
  tearDown(() => server.value.close());

  /// Returns the pinned `extends` entry of [path] on the server serving
  /// [text].
  String base(String path, String text) {
    server.value.on('GET', path, FakeResponse.text(text));
    final String sha = ConfigBaseCache.digestOf(utf8.encode(text));
    return '  - url: ${server.value.baseUrl}$path\n    sha256: $sha\n';
  }

  /// Fetches the bases of the project configuration [yaml], offline when
  /// [offline] is set.
  ///
  /// Returns the outcome.
  Future<ConfigFetchOutcome> fetch(String yaml, {bool offline = false}) async {
    final transport = HttpTransport(
      config: NetworkConfig(offline: offline, maxAttempts: 1),
      environment: const Environment(<String, String>{}),
      sleep: (_) async {},
    );
    try {
      return await fetchConfigBases(
        projectConfigLayer(
          pubspecYaml: null,
          configFile: yaml,
          directory: root.value,
        ),
        packageRoot: root.value,
        cacheRoot: p.join(root.value, 'cache'),
        transport: transport,
      );
    } finally {
      transport.close();
    }
  }

  test('downloads, verifies and caches bases, also of remote bases', () async {
    final String inner = base('/inner.yaml', 'min_severity: low\n');
    final String outer = base(
      '/outer.yaml',
      'extends:\n${inner}fail_on: high\n',
    );
    final yaml = 'extends:\n$outer';
    final ConfigFetchOutcome first = await fetch(yaml);
    expect(first.downloaded.map((base) => base.url.path), <String>[
      '/outer.yaml',
      '/inner.yaml',
    ]);
    expect(first.stack.layers.map((layer) => layer.kind), <ConfigLayerKind>[
      ConfigLayerKind.remote,
      ConfigLayerKind.remote,
      ConfigLayerKind.project,
    ]);
    expect(server.value.requests, hasLength(2));
    final ConfigFetchOutcome again = await fetch(yaml, offline: true);
    expect(again.downloaded, isEmpty);
    expect(server.value.requests, hasLength(2));
    final config = InspectraConfig.fromLayers(again.stack, packageName: 'app');
    expect(config.failOn, Severity.high);
    expect(config.minSeverity, Severity.low);
  });

  test('rejects content that does not match its pin', () async {
    server.value.on('GET', '/base.yaml', FakeResponse.text('fail_on: low\n'));
    final yaml =
        'extends:\n  - url: ${server.value.baseUrl}/base.yaml\n'
        '    sha256: ${'a' * 64}\n';
    await expectLater(
      fetch(yaml),
      throwsA(
        isA<InvalidInputException>().having(
          (error) => error.message,
          'message',
          contains('but extends pins'),
        ),
      ),
    );
    expect(ConfigBaseCache(p.join(root.value, 'cache')).read('a' * 64), isNull);
  });

  test('fails as unavailable when a base cannot be downloaded', () async {
    final String missing = base('/gone.yaml', 'fail_on: low\n');
    server.value.on('GET', '/gone.yaml', const FakeResponse(404));
    await expectLater(
      fetch('extends:\n$missing'),
      throwsA(
        isA<UnavailableException>().having(
          (error) => error.message,
          'message',
          contains('HTTP 404'),
        ),
      ),
    );
    await expectLater(
      fetch('extends:\n$missing', offline: true),
      throwsA(isA<UnavailableException>()),
    );
  });

  test('needs no connection without remote bases', () async {
    writeFile(root.value, 'base.yaml', 'fail_on: high\n');
    final ConfigFetchOutcome outcome = await fetch(
      'extends: base.yaml\n',
      offline: true,
    );
    expect(outcome.stack.bases.single.label, 'base.yaml');
    expect(server.value.requests, isEmpty);
  });
}
