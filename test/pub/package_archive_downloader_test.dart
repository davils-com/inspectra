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

import 'dart:typed_data';

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/pub/package_archive_downloader.dart';
import 'package:inspectra/src/pub/pub_version.dart';
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';

/// Tests archive host validation and integrity checks.
void main() {
  final server = Fixture<FakeHttpServer>();

  setUp(() async => server.value = await FakeHttpServer.start());
  tearDown(() => server.value.close());

  /// Creates a downloader for the fake repository.
  PackageArchiveDownloader downloader() => PackageArchiveDownloader(
    transport: HttpTransport(
      config: const NetworkConfig(maxAttempts: 1),
      environment: const Environment(<String, String>{}),
    ),
    repositoryUrl: server.value.baseUrl,
    maxBytes: 1024,
  );

  test('refuses archives announced on foreign hosts', () {
    expect(
      downloader().download(
        'x',
        const PubVersion(
          version: '1.0.0',
          archiveUrl: 'https://evil.example.net/x.tar.gz',
        ),
      ),
      throwsA(isA<UnavailableException>()),
    );
  });

  test('refuses missing archives and HTTP errors', () {
    expect(
      downloader().download('x', const PubVersion(version: '1.0.0')),
      throwsA(isA<UnavailableException>()),
    );
    expect(
      downloader().download(
        'x',
        PubVersion(
          version: '1.0.0',
          archiveUrl: '${server.value.baseUrl}/missing',
        ),
      ),
      throwsA(isA<UnavailableException>()),
    );
  });

  test('accepts archives without a published checksum', () async {
    server.value.on('GET', '/a.tar.gz', FakeResponse.text('bytes'));
    final Uint8List bytes = await downloader().download(
      'x',
      PubVersion(
        version: '1.0.0',
        archiveUrl: '${server.value.baseUrl}/a.tar.gz',
      ),
    );
    expect(bytes, hasLength(5));
  });
}
