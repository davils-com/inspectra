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
import 'dart:typed_data';

import 'package:inspectra/src/archive/archive_entry_kind.dart';

/// One entry of an archive, held entirely in memory.
///
/// Inspectra never extracts package archives to disk. Scanners operate on
/// these in-memory entries, which removes the whole class of path traversal
/// ("zip slip") vulnerabilities from the inspection pipeline.
final class ArchiveEntry {
  /// Creates an entry.
  ///
  /// [name] is the raw entry name as stored in the archive, [kind] its type,
  /// [mode] its POSIX permission bits, [linkTarget] the target of links and
  /// [bytes] the content of regular files.
  ArchiveEntry({
    required this.name,
    required this.kind,
    required this.bytes,
    this.mode = 0,
    this.linkTarget,
  }) : path = _normalise(name),
       isText = kind == ArchiveEntryKind.file && !_hasNul(bytes);

  /// The raw entry name exactly as stored in the archive.
  final String name;

  /// The entry type.
  final ArchiveEntryKind kind;

  /// The POSIX mode bits.
  final int mode;

  /// The link target of symbolic and hard links.
  final String? linkTarget;

  /// The content of a regular file; empty for every other kind.
  final Uint8List bytes;

  /// The entry name with backslashes turned into slashes and leading `./`
  /// segments removed, used for display and matching.
  final String path;

  /// The content decoded as UTF-8 on first use, once [text] is read.
  String? _text;

  /// The content decoded as UTF-8, replacing malformed sequences so that a
  /// binary or mis-encoded file can never abort a scan.
  String get text => _text ??= utf8.decode(bytes, allowMalformed: true);

  /// Whether this entry is a regular file.
  bool get isFile => kind == ArchiveEntryKind.file;

  /// The number of leading bytes inspected by [isText].
  static const _textProbeLength = 8192;

  /// Whether this entry is a regular file that looks like text.
  ///
  /// A file containing a NUL byte within its first 8 KiB is treated as
  /// binary (images, fonts, WebAssembly, executables); text scanners skip
  /// it because arbitrary bytes decode to arbitrary "characters".
  final bool isText;

  /// The file name without its directories.
  String get baseName => path.split('/').last;

  /// Whether the first [_textProbeLength] bytes of [bytes] hold a NUL byte.
  ///
  /// Returns `true` for content that looks binary.
  static bool _hasNul(Uint8List bytes) {
    final int probed = bytes.length < _textProbeLength
        ? bytes.length
        : _textProbeLength;
    return bytes.take(probed).contains(0);
  }

  /// Normalises [raw] for display without resolving `..` segments, so that
  /// traversal attempts stay visible to the archive scanner.
  ///
  /// Returns the normalised name.
  static String _normalise(String raw) {
    final String slashed = raw.replaceAll(r'\', '/');
    return slashed.replaceFirst(RegExp(r'^(\./)+'), '');
  }
}
