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
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/host/cpu_architecture.dart';
import 'package:inspectra/src/host/operating_system.dart';
import 'package:inspectra/src/io/executable_resolver.dart';
import 'package:inspectra/src/net/http_transport.dart';
import 'package:inspectra/src/trivy/trivy_installer.dart';
import 'package:inspectra/src/trivy/trivy_locator.dart';
import 'package:inspectra/src/trivy/trivy_origin.dart';
import 'package:inspectra/src/trivy/trivy_provision.dart';
import 'package:inspectra/src/trivy/trivy_provisioner.dart';
import 'package:test/test.dart';

import '../support/archive_fixtures.dart';
import '../support/fake_http_server.dart';
import '../support/fake_process_runner.dart';
import '../support/fake_response.dart';
import '../support/fixture.dart';

/// Tests how Trivy is located, resolved and downloaded.
void main() {
  const linux = HostPlatform(OperatingSystem.linux, CpuArchitecture.x64);
  final server = Fixture<FakeHttpServer>();
  final directory = Fixture<Directory>();
  final runner = Fixture<FakeProcessRunner>();

  setUp(() async {
    server.value = await FakeHttpServer.start();
    directory.value = Directory.systemTemp.createTempSync('trivy_');
    runner.value = FakeProcessRunner((executable, arguments) {
      if (executable == 'chmod') {
        return const ProcessOutcome(exitCode: 0, stdout: '', stderr: '');
      }
      final version = executable.contains('0.99.0') ? '0.99.0' : '0.75.0';
      return ProcessOutcome(
        exitCode: 0,
        stdout: jsonEncode(<String, Object?>{'Version': version}),
        stderr: '',
      );
    });
  });
  tearDown(() async {
    await server.value.close();
    directory.value.deleteSync(recursive: true);
  });

  /// Creates a provisioner for [config]; [path] is the `PATH` and
  /// [offline] the network mode.
  TrivyProvisioner provisioner(
    TrivyConfig config, {
    String path = '',
    bool offline = false,
  }) {
    final transport = HttpTransport(
      config: NetworkConfig(offline: offline, maxAttempts: 1),
      environment: const Environment(<String, String>{}),
    );
    final environment = Environment(<String, String>{'PATH': path});
    return TrivyProvisioner(
      config: config,
      locator: TrivyLocator(
        resolver: ExecutableResolver(environment: environment, host: linux),
        processRunner: runner.value,
        environment: environment,
        installRoot: '${directory.value.path}/cache',
        binaryName: 'trivy',
        searchDirectories: const <String>[],
      ),
      installer: TrivyInstaller(
        transport: transport,
        processRunner: runner.value,
        host: linux,
      ),
      transport: transport,
      host: linux,
    );
  }

  /// Serves a release of [version] whose checksum file lists [checksum],
  /// or the real checksum when it is `null`.
  void serveRelease(String version, {String? checksum}) {
    final Uint8List archive = buildBinaryTarGz(<String, List<int>>{
      'trivy': utf8.encode('#!/bin/sh\necho trivy'),
      'README.md': utf8.encode('readme'),
    });
    final name = 'trivy_${version}_Linux-64bit.tar.gz';
    final String sum = checksum ?? sha256.convert(archive).toString();
    server.value
      ..on(
        'GET',
        '/releases/download/v$version/$name',
        FakeResponse(200, body: archive),
      )
      ..on(
        'GET',
        '/releases/download/v$version/trivy_${version}_checksums.txt',
        FakeResponse.text('$sum  $name\n0000  other.tar.gz\n'),
      );
  }

  /// A configuration pointing the download URLs at the fake server.
  TrivyConfig config({
    String version = '0.75.0',
    bool download = true,
    bool useInstalled = true,
    TrivyMode mode = TrivyMode.auto,
    String? executable,
  }) => TrivyConfig(
    mode: mode,
    version: version,
    download: download,
    useInstalled: useInstalled,
    executable: executable,
    downloadBaseUrl: '${server.value.baseUrl}/releases/download',
    latestReleaseUrl: '${server.value.baseUrl}/releases/latest',
  );

  /// Provisions with a no-op status callback.
  Future<TrivyProvision> run(TrivyProvisioner subject) =>
      subject.provision(onStatus: (_) {});

  test('is unavailable when disabled', () async {
    final TrivyProvision result = await run(
      provisioner(config(mode: TrivyMode.disabled)),
    );
    expect(result, isA<TrivyUnavailable>());
    expect(runner.value.calls, isEmpty);
  });

  test('uses the configured executable only', () async {
    final TrivyProvision result = await run(
      provisioner(config(executable: '/opt/trivy')),
    );
    expect(
      result,
      isA<TrivyAvailable>().having(
        (r) => r.origin,
        'origin',
        TrivyOrigin.configured,
      ),
    );
  });

  test('uses an installed Trivy from the PATH', skip: _windowsSkip, () async {
    final bin = Directory('${directory.value.path}/bin')..createSync();
    final file = File('${bin.path}/trivy')..writeAsStringSync('x');
    if (!Platform.isWindows) {
      Process.runSync('chmod', <String>['755', file.path]);
    }
    final TrivyProvision result = await run(
      provisioner(config(), path: bin.path),
    );
    expect(
      result,
      isA<TrivyAvailable>()
          .having((r) => r.origin, 'origin', TrivyOrigin.installed)
          .having((r) => r.version, 'version', '0.75.0'),
    );
  });

  test('does not download when downloading is disabled', () async {
    final TrivyProvision result = await run(
      provisioner(config(download: false)),
    );
    expect(
      result,
      isA<TrivyUnavailable>().having(
        (r) => r.reason,
        'reason',
        contains('download'),
      ),
    );
    expect(server.value.requests, isEmpty);
  });

  test('never probes or downloads without allowDownload', () async {
    serveRelease('0.75.0');
    final TrivyProvision result = await provisioner(config())
        .provision(onStatus: (_) {}, allowDownload: false);
    expect(
      result,
      isA<TrivyUnavailable>().having(
        (r) => r.reason,
        'reason',
        contains('trivy --install'),
      ),
    );
    expect(server.value.requests, isEmpty);
  });

  test('does not touch the network in offline mode', () async {
    final TrivyProvision result = await run(
      provisioner(config(), offline: true),
    );
    expect(result, isA<TrivyUnavailable>());
    expect(server.value.requests, isEmpty);
  });

  test('skips the download when the host is unreachable', () async {
    final int port = Uri.parse(server.value.baseUrl).port;
    await server.value.close();
    final unreachable = TrivyConfig(
      downloadBaseUrl: 'http://127.0.0.1:$port/releases/download',
    );
    final TrivyProvision result = await run(provisioner(unreachable));
    expect(
      result,
      isA<TrivyUnavailable>().having(
        (r) => r.reason,
        'reason',
        contains('not reachable'),
      ),
    );
  });

  test('downloads, verifies and caches the pinned version', () async {
    serveRelease('0.75.0');
    final TrivyProvision first = await run(provisioner(config()));
    expect(
      first,
      isA<TrivyAvailable>().having(
        (r) => r.origin,
        'origin',
        TrivyOrigin.downloaded,
      ),
    );
    final installed = File('${directory.value.path}/cache/0.75.0/trivy');
    expect(installed.readAsStringSync(), contains('echo trivy'));
    final TrivyProvision second = await run(provisioner(config()));
    expect(
      second,
      isA<TrivyAvailable>().having(
        (r) => r.origin,
        'origin',
        TrivyOrigin.cached,
      ),
    );
  });

  test('never installs an archive with a wrong checksum', () async {
    serveRelease('0.75.0', checksum: 'deadbeef');
    final TrivyProvision result = await run(provisioner(config()));
    expect(
      result,
      isA<TrivyUnavailable>().having(
        (r) => r.reason,
        'reason',
        contains('checksum'),
      ),
    );
    expect(
      File('${directory.value.path}/cache/0.75.0/trivy').existsSync(),
      isFalse,
    );
  });

  test('resolves latest through the release redirect', () async {
    server.value.on(
      'GET',
      '/releases/latest',
      const FakeResponse(
        302,
        headers: {'location': '/aquasecurity/trivy/releases/tag/v0.99.0'},
      ),
    );
    serveRelease('0.99.0');
    final TrivyProvision result = await run(
      provisioner(config(version: 'latest')),
    );
    expect(
      result,
      isA<TrivyAvailable>().having((r) => r.version, 'version', '0.99.0'),
    );
  });

  test(
    'enforces the pinned version when installed ones are not accepted',
    skip: _windowsSkip,
    () async {
      final bin = Directory('${directory.value.path}/bin')..createSync();
      final file = File('${bin.path}/trivy')..writeAsStringSync('x');
      if (!Platform.isWindows) {
        Process.runSync('chmod', <String>['755', file.path]);
      }
      serveRelease('0.99.0');
      final TrivyProvision result = await run(
        provisioner(
          config(version: '0.99.0', useInstalled: false),
          path: bin.path,
        ),
      );
      expect(
        result,
        isA<TrivyAvailable>().having(
          (r) => r.origin,
          'origin',
          TrivyOrigin.downloaded,
        ),
      );
    },
  );

  test('parses both version output formats', () {
    expect(TrivyLocator.parseVersion('{"Version":"v0.75.0"}'), '0.75.0');
    expect(TrivyLocator.parseVersion('Version: 0.74.1\nDB...'), '0.74.1');
    expect(TrivyLocator.parseVersion('garbage'), isNull);
  });

  test('falls back to the newest cached version for latest offline', () async {
    for (final version in <String>['0.9.0', '0.75.0', '0.10.0']) {
      File('${directory.value.path}/cache/$version/trivy')
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
    }
    final TrivyProvision result = await run(
      provisioner(config(version: 'latest'), offline: true),
    );
    expect(
      result,
      isA<TrivyAvailable>()
          .having((r) => r.origin, 'origin', TrivyOrigin.cached)
          .having((r) => r.version, 'version', '0.75.0'),
    );
  });
}

/// The PATH of these tests uses POSIX separators, so they do not run on
/// Windows; the Windows lookup rules are covered by the resolver tests.
final Object _windowsSkip = Platform.isWindows ? 'POSIX PATH semantics' : false;
