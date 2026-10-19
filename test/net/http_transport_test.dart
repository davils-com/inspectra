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
import 'package:inspectra/src/net/http_result.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';

/// Tests the HTTP transport against a loopback server.
void main() {
  final server = Fixture<FakeHttpServer>();
  final sleeps = Fixture<List<Duration>>();

  setUp(() async {
    server.value = await FakeHttpServer.start();
    sleeps.value = <Duration>[];
  });
  tearDown(() => server.value.close());

  /// Creates a transport with the given [offline] mode.
  HttpTransport transport({bool offline = false}) => HttpTransport(
    config: NetworkConfig(
      offline: offline,
      retryBaseDelay: const Duration(milliseconds: 10),
    ),
    environment: const Environment(<String, String>{}),
    sleep: (delay) async => sleeps.value.add(delay),
  );

  test('retries transient failures and returns the final response', () async {
    var calls = 0;
    server.value.onDynamic('GET', '/flaky', (_) {
      calls++;
      return calls < 3
          ? const FakeResponse(
              503,
              headers: <String, String>{'retry-after': '2'},
            )
          : FakeResponse.text('ok');
    });
    final HttpResult result = await transport().get(
      Uri.parse('${server.value.baseUrl}/flaky'),
    );
    expect(result.statusCode, 200);
    expect(result.text, 'ok');
    expect(sleeps.value, <Duration>[
      const Duration(seconds: 2),
      const Duration(seconds: 2),
    ]);
  });

  test('returns the last retryable response when attempts run out', () async {
    server.value.on('GET', '/down', const FakeResponse(503));
    final HttpResult result = await transport().get(
      Uri.parse('${server.value.baseUrl}/down'),
    );
    expect(result.statusCode, 503);
    expect(sleeps.value, hasLength(2));
  });

  test('does not retry client errors', () async {
    final HttpResult result = await transport().get(
      Uri.parse('${server.value.baseUrl}/missing'),
    );
    expect(result.isNotFound, isTrue);
    expect(sleeps.value, isEmpty);
  });

  test('rejects responses larger than the limit', () {
    server.value.on('GET', '/big', FakeResponse.text('x' * 100));
    expect(
      () => transport().get(
        Uri.parse('${server.value.baseUrl}/big'),
        maxBytes: 10,
      ),
      throwsA(isA<UnavailableException>()),
    );
  });

  test('never connects in offline mode', () async {
    expect(
      () => transport(offline: true).get(Uri.parse(server.value.baseUrl)),
      throwsA(isA<UnavailableException>()),
    );
    expect(
      await transport(offline: true)
          .probe(Uri.parse(server.value.baseUrl), const Duration(seconds: 1)),
      isFalse,
    );
    expect(server.value.requests, isEmpty);
  });

  test('probe treats any HTTP answer as reachable', () async {
    final bool reachable = await transport().probe(
      Uri.parse('${server.value.baseUrl}/'),
      const Duration(seconds: 2),
    );
    expect(reachable, isTrue);
  });

  test('reports unreachable hosts after all attempts', () async {
    final int port = Uri.parse(server.value.baseUrl).port;
    await server.value.close();
    expect(
      () => transport().get(Uri.parse('http://127.0.0.1:$port/')),
      throwsA(isA<UnavailableException>()),
    );
  });
}
