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
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/osv/osv_cache.dart';
import 'package:inspectra/src/osv/osv_client.dart';
import 'package:inspectra/src/osv/osv_vulnerability.dart';
import 'package:inspectra/src/pub/lockfile_entry.dart';
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';

/// Tests the two step OSV protocol, pagination and caching.
void main() {
  final server = Fixture<FakeHttpServer>();
  final cacheDirectory = Fixture<Directory>();

  setUp(() async {
    server.value = await FakeHttpServer.start();
    cacheDirectory.value = Directory.systemTemp.createTempSync('osv_cache_');
  });
  tearDown(() async {
    await server.value.close();
    cacheDirectory.value.deleteSync(recursive: true);
  });

  /// Creates a client against the fake server.
  OsvClient client() => OsvClient(
    transport: HttpTransport(
      config: const NetworkConfig(),
      environment: const Environment(<String, String>{}),
    ),
    baseUrl: server.value.baseUrl,
    cache: OsvCache(cacheDirectory.value.path),
  );

  const http = LockfileEntry(
    name: 'http',
    version: '0.13.0',
    source: 'hosted',
    dependency: 'direct main',
  );
  const path = LockfileEntry(
    name: 'path',
    version: '1.0.0',
    source: 'hosted',
    dependency: 'transitive',
  );

  test('follows page tokens and fetches full records once', () async {
    server.value
      ..onDynamic('POST', '/v1/querybatch', (body) {
        final queries = (jsonDecode(body) as Map)['queries'] as List;
        final first = queries.first as Map;
        if (first['page_token'] == 'next') {
          return FakeResponse.json(<String, Object?>{
            'results': <Object?>[
              <String, Object?>{
                'vulns': <Object?>[
                  <String, Object?>{'id': 'GHSA-B', 'modified': 'm2'},
                ],
              },
            ],
          });
        }
        return FakeResponse.json(<String, Object?>{
          'results': <Object?>[
            <String, Object?>{
              'vulns': <Object?>[
                <String, Object?>{'id': 'GHSA-A', 'modified': 'm1'},
              ],
              'next_page_token': 'next',
            },
            <String, Object?>{},
          ],
        });
      })
      ..on(
        'GET',
        '/v1/vulns/GHSA-A',
        FakeResponse.json(<String, Object?>{
          'id': 'GHSA-A',
          'modified': 'm1',
          'summary': 'First',
        }),
      )
      ..on(
        'GET',
        '/v1/vulns/GHSA-B',
        FakeResponse.json(<String, Object?>{
          'id': 'GHSA-B',
          'modified': 'm2',
          'summary': 'Second',
        }),
      );
    final Map<LockfileEntry, List<OsvVulnerability>> result = await client()
        .query(<LockfileEntry>[http, path]);
    expect(result[http]!.map((v) => v.id), <String>['GHSA-A', 'GHSA-B']);
    expect(result[path], isEmpty);
    server.value.requests.clear();
    await client().query(<LockfileEntry>[http, path]);
    expect(server.value.requests.where((r) => r.startsWith('GET')), isEmpty);
  });

  test('reports OSV outages as unavailable', () {
    server.value.on('POST', '/v1/querybatch', const FakeResponse(400));
    expect(
      () => client().query(<LockfileEntry>[http]),
      throwsA(isA<UnavailableException>()),
    );
  });
}
