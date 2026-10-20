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
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:inspectra/src/style/style_reporter.dart';

/// Finds every call and tear-off of `DateTime.now`.
///
/// The tree is not resolved, so `DateTime.now` is recognised by its names,
/// with or without an import prefix: `DateTime.now()`,
/// `core.DateTime.now()`, `new DateTime.now()` and the tear-off
/// `DateTime.now`.
final class WallClockVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor reporting to [reporter].
  WallClockVisitor(this.reporter);

  /// Receives the violations.
  final StyleReporter reporter;

  /// The message of every violation.
  static const _message =
      'No DateTime.now(): read the time from an injected clock, so that a '
      'test decides what time it is.';

  /// Reports `DateTime.now()` and `prefix.DateTime.now()`.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final now = node.methodName.name == 'now';
    if (now && _namesDateTime(node.target)) {
      reporter.reportAt(node, _message);
    }
    super.visitMethodInvocation(node);
  }

  /// Reports `new DateTime.now()` and `new prefix.DateTime.now()`.
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_createsNow(node.constructorName)) {
      reporter.reportAt(node, _message);
    }
    super.visitInstanceCreationExpression(node);
  }

  /// Reports the tear-off `DateTime.now`.
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final bool tearOff =
        node.prefix.name == 'DateTime' && node.identifier.name == 'now';
    if (tearOff) {
      reporter.reportAt(node, _message);
    }
    super.visitPrefixedIdentifier(node);
  }

  /// Reports the tear-off `prefix.DateTime.now`.
  @override
  void visitPropertyAccess(PropertyAccess node) {
    final now = node.propertyName.name == 'now';
    if (now && _namesDateTime(node.target)) {
      reporter.reportAt(node, _message);
    }
    super.visitPropertyAccess(node);
  }

  /// Whether [constructor] is `DateTime.now` or `prefix.DateTime.now`.
  ///
  /// Without resolution `new DateTime.now()` reads as the type `now` with
  /// the import prefix `DateTime`, and `new core.DateTime.now()` as the
  /// constructor `now` of the type `DateTime`.
  ///
  /// Returns `true` when it is.
  bool _createsNow(ConstructorName constructor) {
    final NamedType type = constructor.type;
    if (constructor.name?.name == 'now') {
      return type.name.lexeme == 'DateTime';
    }
    final prefixed = type.importPrefix?.name.lexeme == 'DateTime';
    return prefixed && type.name.lexeme == 'now';
  }

  /// Whether [target] is `DateTime` or `prefix.DateTime`.
  ///
  /// Returns `true` when it is.
  bool _namesDateTime(Expression? target) {
    if (target is SimpleIdentifier) {
      return target.name == 'DateTime';
    }
    if (target is PrefixedIdentifier) {
      return target.identifier.name == 'DateTime';
    }
    return false;
  }
}
