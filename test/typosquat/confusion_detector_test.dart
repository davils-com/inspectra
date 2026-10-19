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
import 'package:inspectra/src/pub/dependency_kind.dart';
import 'package:inspectra/src/pub/dependency_spec.dart';
import 'package:inspectra/src/pub/pub_repository_client.dart';
import 'package:inspectra/src/typosquat/confusion_detector.dart';
import 'package:test/test.dart';

import '../support/fake_http_server.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';

/// Tests dependency confusion detection.
void main() {
  final server = Fixture<FakeHttpServer>();

  setUp(() async => server.value = await FakeHttpServer.start());
  tearDown(() => server.value.close());

  /// Serves a public package [name] whose latest version is [latest].
  void serve(String name, String latest) {
    server.value.on(
      'GET',
      '/api/packages/$name',
      FakeResponse.json(<String, Object?>{
        'name': name,
        'latest': <String, Object?>{'version': latest},
        'versions': <Object?>[
          <String, Object?>{'version': latest},
        ],
      }),
    );
  }

  /// Analyses [dependencies] against the fake public repository.
  Future<List<String>> analyze(Map<String, DependencySpec> dependencies) async {
    final detector = ConfusionDetector(
      publicRepository: PubRepositoryClient(
        transport: HttpTransport(
          config: const NetworkConfig(),
          environment: const Environment(<String, String>{}),
        ),
        baseUrl: server.value.baseUrl,
      ),
      concurrency: 2,
      mirrorUrl: server.value.baseUrl,
    );
    final List<Finding> findings = await detector.analyze(
      dependencies,
      locate: (_) => const SourceLocation('pubspec.yaml'),
    );
    return findings.map((f) => '${f.packageName}:${f.ruleId}').toList();
  }

  test('flags private packages whose name exists publicly', () async {
    serve('corp_auth', '1.0.0');
    expect(
      await analyze(<String, DependencySpec>{
        'corp_auth': const DependencySpec(
          kind: DependencyKind.hosted,
          hostedUrl: 'https://pub.corp.example',
        ),
        'corp_only': const DependencySpec(
          kind: DependencyKind.hosted,
          hostedUrl: 'https://pub.corp.example',
        ),
      }),
      <String>['corp_auth:DEPENDENCY_CONFUSION'],
    );
  });

  test('flags inflated public versions only', () async {
    serve('inflated', '99.0.0');
    serve('normal', '3.1.0');
    expect(
      await analyze(<String, DependencySpec>{
        'inflated': const DependencySpec(kind: DependencyKind.hosted),
        'normal': const DependencySpec(kind: DependencyKind.hosted),
        'local': const DependencySpec(kind: DependencyKind.path, path: '.'),
      }),
      <String>['inflated:SUSPICIOUS_VERSION'],
    );
  });
}
