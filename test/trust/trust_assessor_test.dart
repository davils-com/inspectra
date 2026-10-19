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

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/pub/pub_repository_client.dart';
import 'package:inspectra/src/trust/trust_assessor.dart';
import 'package:inspectra/src/trust/trust_info.dart';
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';

/// Tests the trust assessment against a fake pub repository.
void main() {
  final server = Fixture<FakeHttpServer>();

  setUp(() async => server.value = await FakeHttpServer.start());
  tearDown(() => server.value.close());

  /// Creates an assessor evaluated at 2026-10-01.
  TrustAssessor assessor() => TrustAssessor(
    repository: PubRepositoryClient(
      transport: HttpTransport(
        config: const NetworkConfig(),
        environment: const Environment(<String, String>{}),
      ),
      baseUrl: server.value.baseUrl,
    ),
    thresholds: const TrustThresholds(),
    clock: Clock(() => DateTime.utc(2026, 10)),
  );

  /// Serves a package listing with versions published at [dates].
  void serve(String name, Map<String, String> dates, {bool retracted = false}) {
    server.value.on(
      'GET',
      '/api/packages/$name',
      FakeResponse.json(<String, Object?>{
        'name': name,
        'latest': <String, Object?>{'version': dates.keys.last},
        'versions': <Object?>[
          for (final entry in dates.entries)
            <String, Object?>{
              'version': entry.key,
              'published': entry.value,
              'retracted': retracted,
            },
        ],
      }),
    );
  }

  test('trusts an established package of a verified publisher', () async {
    serve('good', <String, String>{
      '1.0.0': '2020-01-01T00:00:00Z',
      '2.0.0': '2026-01-01T00:00:00Z',
    });
    server.value
      ..on(
        'GET',
        '/api/packages/good/score',
        FakeResponse.json(<String, Object?>{
          'grantedPoints': 160,
          'maxPoints': 160,
          'likeCount': 500,
          'downloadCount30Days': 100000,
        }),
      )
      ..on(
        'GET',
        '/api/packages/good/publisher',
        FakeResponse.json(<String, Object?>{'publisherId': 'dart.dev'}),
      );
    final TrustInfo? info = await assessor().assessByName('good');
    expect(info!.findings, isEmpty);
    expect(info.createdAt, DateTime.utc(2020));
    expect(info.isVerifiedPublisher, isTrue);
  });

  test('flags fresh, retracted and unverified packages', () async {
    serve('fresh', <String, String>{
      '0.0.1': '2026-09-30T20:00:00Z',
    }, retracted: true);
    server.value.on(
      'GET',
      '/api/packages/fresh/options',
      FakeResponse.json(<String, Object?>{'isDiscontinued': true}),
    );
    final TrustInfo? info = await assessor().assessByName('fresh');
    final Set<String> rules = info!.findings.map((f) => f.ruleId).toSet();
    expect(
      rules,
      containsAll(<String>[
        'FRESH_PACKAGE',
        'FRESH_RELEASE',
        'RETRACTED_VERSION',
        'DISCONTINUED',
        'UNVERIFIED_PUBLISHER',
      ]),
    );
  });

  test('assesses the requested version, not the latest', () async {
    serve('pkg', <String, String>{
      '1.0.0': '2024-01-01T00:00:00Z',
      '2.0.0': '2026-09-30T23:00:00Z',
    });
    final TrustInfo? old = await assessor().assessByName(
      'pkg',
      version: '1.0.0',
    );
    expect(
      old!.findings.map((f) => f.ruleId),
      isNot(contains('FRESH_RELEASE')),
    );
    expect(
      () => assessor().assessByName('pkg', version: '9.9.9'),
      throwsA(isA<InvalidUsageException>()),
    );
  });

  test('returns null for unknown packages', () async {
    expect(await assessor().assessByName('missing'), isNull);
  });
}
