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
import 'package:inspectra/src/workspace/package_dependency_graph.dart';
import 'package:inspectra/src/workspace/workspace.dart';
import 'package:inspectra/src/workspace/workspace_policy.dart';
import 'package:test/test.dart';

import '../support/fixture.dart';
import '../support/fixtures.dart';

/// Tests reading a pub workspace and its policy.
void main() {
  final root = Fixture<String>();

  /// Writes [files] below the workspace root.
  void write(Map<String, String> files) {
    for (final MapEntry(key: path, value: content) in files.entries) {
      writeFile(root.value, path, content);
    }
  }

  /// A member pubspec named [name] with the [dependencies] section text.
  String member(String name, [String dependencies = '']) =>
      'name: $name\nresolution: workspace\nenvironment:\n  sdk: ^3.6.0\n'
      '${dependencies.isEmpty ? '' : 'dependencies:\n$dependencies'}';

  setUp(() {
    root.value = temporaryDirectory();
    write(<String, String>{
      'pubspec.yaml':
          'name: root\npublish_to: none\nenvironment:\n  sdk: ^3.6.0\n'
          'workspace:\n  - apps/shop\n  - features/*\n  - packages/core\n',
      'apps/shop/pubspec.yaml': member(
        'shop',
        '  cart: any\n  core: any\n  http: ^1.2.0\n',
      ),
      'features/cart/pubspec.yaml': member(
        'cart',
        '  core: any\n  search: any\n  http: ^1.1.0\n',
      ),
      'features/search/pubspec.yaml': member('search', '  core: any\n'),
      'packages/core/pubspec.yaml': member(
        'core',
        '  flutter:\n    sdk: flutter\n',
      ),
      'example/pubspec.yaml': 'name: example\n',
    });
  });

  test('reads the members, globs and nested files', () {
    final Workspace? workspace = Workspace.load(root.value);
    expect(
      workspace?.members.map((member) => '${member.name} ${member.path}'),
      <String>[
        'root .',
        'shop apps/shop',
        'cart features/cart',
        'search features/search',
        'core packages/core',
      ],
    );
    expect(workspace?.memberOf('features/cart/lib/cart.dart').name, 'cart');
    expect(workspace?.memberOf('README.md').name, 'root');
    expect(workspace?.memberOf('features/cartography/x').name, 'root');
    expect(Workspace.load('${root.value}/apps/shop'), isNull);
  });

  test('the graph finds dependents and cycles', () {
    final graph = PackageDependencyGraph.of(Workspace.load(root.value)!);
    expect(graph.edges['shop'], <String>['cart', 'core']);
    expect(graph.withDependents(<String>{'search'}), <String>{
      'search',
      'cart',
      'shop',
    });
    expect(graph.cycles(), isEmpty);
    const cyclic = PackageDependencyGraph(<String, List<String>>{
      'a': <String>['b'],
      'b': <String>['c'],
      'c': <String>['a'],
      'd': <String>['d'],
      'e': <String>['a'],
    });
    expect(cyclic.cycles(), <List<String>>[
      <String>['a', 'b', 'c'],
      <String>['d'],
    ]);
  });

  /// Checks the workspace with [config].
  ///
  /// Returns `ruleId package` of every finding.
  List<String> check(WorkspacePolicyConfig config) => <String>[
    for (final Finding finding in WorkspacePolicy(
      config,
    ).check(Workspace.load(root.value)!))
      '${finding.ruleId} ${finding.packageName ?? finding.location?.path}',
  ];

  test('reports membership, versions and the SDK', () {
    write(<String, String>{
      'pubspec.yaml':
          'name: root\nenvironment:\n  sdk: ^3.7.0\n'
          'workspace: [apps/shop, features/*, packages/core, gone]\n',
      'packages/core/pubspec.yaml':
          'name: core\nenvironment:\n  sdk: ^3.6.0\n'
          'dependencies:\n  http: ^2.0.0\n',
      'orphan/pubspec.yaml': member('orphan'),
    });
    final List<String> findings = check(
      const WorkspacePolicyConfig(enabled: true, sameSdk: true),
    );
    expect(findings, <String>[
      'WORKSPACE_MEMBER_MISSING pubspec.yaml',
      'WORKSPACE_MEMBER_MISSING orphan/pubspec.yaml',
      'WORKSPACE_RESOLUTION_MISSING core',
      'WORKSPACE_VERSION_MISMATCH http',
      'WORKSPACE_SDK_MISMATCH shop',
      'WORKSPACE_SDK_MISMATCH cart',
      'WORKSPACE_SDK_MISMATCH search',
      'WORKSPACE_SDK_MISMATCH core',
    ]);
    final List<String> exact = check(
      const WorkspacePolicyConfig(
        alignVersions: VersionAlignment.exact,
        requireMembership: false,
      ),
    );
    expect(exact, <String>[
      'WORKSPACE_VERSION_MISMATCH http',
      'WORKSPACE_VERSION_MISMATCH http',
    ]);
    const policy = WorkspacePolicy(
      WorkspacePolicyConfig(alignVersions: VersionAlignment.exact),
    );
    final Finding first = policy
        .check(Workspace.load(root.value)!)
        .firstWhere(
          (finding) => finding.ruleId == 'WORKSPACE_VERSION_MISMATCH',
        );
    expect(first.source, FindingSource.workspace);
    expect(first.description, contains('Declared:'));
    expect(first.attributes['fix'], '^1.1.0');
  });

  test('reports cycles and the layers of the architecture', () {
    write(<String, String>{
      'packages/core/pubspec.yaml': member(
        'core',
        '  flutter:\n    sdk: flutter\n  shop: any\n',
      ),
    });
    const config = WorkspacePolicyConfig(
      layers: <WorkspaceLayer>[
        WorkspaceLayer(name: 'app', packages: <String>['apps/*']),
        WorkspaceLayer(
          name: 'feature',
          packages: <String>['features/*'],
          mayDependOn: <String>['core'],
          isolated: true,
        ),
        WorkspaceLayer(
          name: 'core',
          packages: <String>['packages/core'],
          mayDependOn: <String>[],
          forbiddenDependencies: <String>['flutter'],
        ),
      ],
    );
    expect(check(config), <String>[
      'DEPENDENCY_CYCLE cart',
      'LAYER_VIOLATION search',
      'FORBIDDEN_DEPENDENCY flutter',
      'LAYER_VIOLATION shop',
    ]);
    write(<String, String>{'packages/core/pubspec.yaml': member('core')});
    expect(
      check(
        const WorkspacePolicyConfig(
          layers: <WorkspaceLayer>[
            WorkspaceLayer(name: 'app', packages: <String>['apps/*']),
          ],
        ),
      ),
      <String>[
        'LAYER_UNASSIGNED cart',
        'LAYER_UNASSIGNED search',
        'LAYER_UNASSIGNED core',
      ],
    );
  });

  test('reads the workspace policy from the configuration', () {
    final WorkspacePolicyConfig config = InspectraConfig.parse(
      <String, Object?>{
        'workspace_policy': <String, Object?>{
          'enabled': true,
          'align_versions': 'exact',
          'layers': <Object?>[
            <String, Object?>{
              'name': 'feature',
              'packages': <String>['features/*'],
              'may_depend_on': <String>['core'],
              'isolated': true,
            },
            <String, Object?>{
              'name': 'core',
              'packages': <String>['packages/*'],
              'forbidden_dependencies': <String>['flutter'],
            },
          ],
        },
      },
      packageName: 'root',
    ).workspacePolicy;
    expect(config.alignVersions, VersionAlignment.exact);
    expect(config.layers.first.contains('features/cart'), isTrue);
    expect(config.layers.first.contains('apps/shop'), isFalse);
    expect(config.layers.last.mayDependOn, isNull);
    expect(
      () => InspectraConfig.parse(<String, Object?>{
        'workspace_policy': <String, Object?>{
          'layers': <Object?>[
            <String, Object?>{
              'name': 'feature',
              'packages': <String>['features/*'],
              'may_depend_on': <String>['cor'],
            },
          ],
        },
      }, packageName: 'root'),
      throwsA(
        isA<InspectraConfigException>().having(
          (error) => error.message,
          'message',
          contains('cor, which is no layer'),
        ),
      ),
    );
  });
}
