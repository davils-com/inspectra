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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:inspectra/src/style/style_reporter.dart';

/// Finds the `late` modifier of fields, top level and local variables.
final class LateVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor reporting to [reporter].
  LateVisitor(this.reporter);

  /// Receives the violations.
  final StyleReporter reporter;

  /// Reports the `late` of a variable declaration.
  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    final Token? keyword = node.lateKeyword;
    if (keyword != null) {
      reporter.reportAt(
        keyword,
        'No late: initialise the variable where it is declared, in an '
        'initialiser list, or make the deferred value explicit.',
      );
    }
    super.visitVariableDeclarationList(node);
  }
}
