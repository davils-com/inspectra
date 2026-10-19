# Rule reference

<primary-label ref="cli"/>
<secondary-label ref="no-network"/>
<secondary-label ref="since-1-1"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Every rule %product% reports, with its source, its default severity and what it reports; inspectra explain prints the details of one.</link-summary>

<card-summary>Every rule id with source, severity and what it reports; inspectra explain RULE_ID for the details.</card-summary>

```bash
dart run %package% explain MISSING_UPPER_BOUND     # why it matters and how to resolve it
dart run %package% explain -f markdown             # this list
```

`inspectra explain` works offline. It finds a rule in any case, points advisory ids such as `GHSA-…` or `CVE-…` to
OSV.dev, and suggests the closest rule for a misspelled id. Advisories of the OSV.dev audit, the rules of Trivy and the
diagnostics of `dart analyze` carry ids of their own and are not listed here. A rule's severity can be suppressed with
`ignore` rules, and a policy can forbid ignoring severities with
[`forbid_ignore_of`](Configuration-Inheritance.md#policy).

## Pubspec rules and dependency policy {id="pubspec"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `ANY_VERSION` | high | A dependency accepts every version ("any") |
| `CONSTRAINT_STYLE` | low | A hosted constraint is not written in the configured style |
| `DENIED_PACKAGE` | high | A denied package is declared or pulled in transitively |
| `DEPENDENCY_OVERRIDE` | medium | A dependency_overrides entry replaces normal version resolution |
| `DEV_DEPENDENCY_IN_LIB` | high | lib/ or bin/ imports a development dependency |
| `DEV_ONLY_DEPENDENCY` | medium | A development package is a runtime dependency |
| `DISALLOWED_HOST` | high | A package comes from a registry or Git host that is not allowed |
| `GIT_BRANCH_REF` | high | A Git dependency follows a branch |
| `GIT_IP_ADDRESS` | critical | A Git dependency is fetched from a bare IP address |
| `INSECURE_URL` | high | A dependency source uses plain HTTP |
| `LIBYEAR_EXCEEDED` | medium | The dependencies are too many libyears behind |
| `LOCKFILE_OUT_OF_SYNC` | high | pubspec.lock does not match pubspec.yaml |
| `LOCKFILE_POLICY` | medium | pubspec.lock is committed against the policy |
| `MISSING_CHECKSUM` | medium | A hosted package of pubspec.lock has no checksum |
| `MISSING_METADATA` | low | A publishable package lacks a metadata field |
| `MISSING_PUBLISH_TO` | medium | The package can be published to pub.dev by accident |
| `MISSING_UPPER_BOUND` | medium | A hosted constraint has no upper bound |
| `OLD_SDK_CONSTRAINT` | low | The SDK constraint allows very old Dart versions |
| `OUTDATED_MAJOR` | medium | A direct dependency is too many breaking releases behind |
| `PACKAGE_NOT_ALLOWED` | high | A hosted dependency is not on the allowed list |
| `PATH_DEPENDENCY` | medium | A dependency comes from a local path |
| `SDK_BELOW_POLICY` | medium | The SDK constraint allows SDKs below the policy minimum |
| `SUSPICIOUS_GIT_HOST` | critical | A Git dependency comes from an unusual host |
| `UNJUSTIFIED_OVERRIDE` | medium | A dependency override has no valid justification |
| `UNUSED_DEPENDENCY` | low | A dependency is never imported |
| `WILDCARD_VERSION` | high | A dependency accepts every version ("*") |

## Workspace policy {id="workspace"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `DEPENDENCY_CYCLE` | high | Packages of the workspace depend on each other in a cycle |
| `FORBIDDEN_DEPENDENCY` | high | A package depends on a package its layer forbids |
| `LAYER_UNASSIGNED` | low | A package belongs to no layer |
| `LAYER_VIOLATION` | high | A package depends on a layer it may not use |
| `WORKSPACE_MEMBER_MISSING` | high | A workspace entry names no package, or a package is not listed |
| `WORKSPACE_RESOLUTION_MISSING` | high | A listed package is not resolved by the workspace |
| `WORKSPACE_SDK_MISMATCH` | medium | A package has another SDK constraint than the root |
| `WORKSPACE_VERSION_MISMATCH` | medium | The packages constrain a dependency differently |

## Typosquatting {id="typosquat"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `LEVENSHTEIN_1` | critical | The name is one edit away from a popular package |
| `LEVENSHTEIN_2` | high | The name is two edits away from a popular package |
| `PREFIX_DART_PUB` | high | The name adds a dart_ or pub_ prefix to a popular package |
| `PREFIX_FLUTTER` | high | The name adds a flutter_ prefix to a popular package |
| `SUFFIX_FLUTTER` | high | The name adds a _flutter suffix to a popular package |
| `SUSPICIOUS_SUFFIX` | medium | The name adds a suspicious suffix to a popular package |

## Dependency confusion {id="confusion"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `DEPENDENCY_CONFUSION` | high | An internal package name also exists on pub.dev |
| `SUSPICIOUS_VERSION` | medium | A public package claims a suspiciously high version |

## Trust assessment {id="trust"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `DISCONTINUED` | high | The package is discontinued |
| `FRESH_PACKAGE` | critical | The package was published only days ago |
| `FRESH_RELEASE` | critical | The version was released only hours ago |
| `LOW_DOWNLOADS` | medium | The package has very few downloads |
| `LOW_LIKES` | medium | The package has very few likes |
| `LOW_QUALITY_SCORE` | medium | The package has a low pub points score |
| `RETRACTED_VERSION` | high | The version was retracted by its publisher |
| `UNVERIFIED_PUBLISHER` | high | The package has no verified publisher |
| `YOUNG_PACKAGE` | medium | The package is only weeks old |

## Source inspection: patterns {id="regex"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `BACKDOOR_PATTERNS` | critical | Backdoor or reverse-shell pattern |
| `BASE64_EVAL` | high | Base64-decoded data used with dynamic code execution |
| `CHAR_CODE_CONCAT` | medium | String construction from concatenated char codes |
| `CRYPTO_MINING` | critical | Cryptomining-related keyword |
| `DATA_EXFIL` | high | Stored data potentially sent to external URL |
| `DOWNLOAD_AND_EXECUTE` | critical | Downloads a script and pipes it into a shell |
| `DYNAMIC_LIBRARY` | high | Dynamic native library loading |
| `ENCODED_POWERSHELL` | high | Runs a Base64 encoded PowerShell command |
| `HARDCODED_URL` | high | URL hardcoded to unknown domain |
| `HEX_ENCODING` | medium | Hex-encoded byte sequence (≥4 consecutive bytes) |
| `ISOLATE_SPAWN_URI` | high | Remote code loading via Isolate.spawnUri |
| `PROCESS_RUN` | critical | OS process execution |
| `RAW_SOCKET` | high | Raw socket usage (may be legitimate — verify context) |
| `SENSITIVE_FILE_ACCESS` | high | Access to sensitive system path |
| `SHELL_INJECTION` | critical | Direct shell invocation |
| `UNICODE_ESCAPE` | medium | Multiple consecutive unicode escapes (possible obfuscation) |

## Source inspection: Unicode {id="unicode"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `BIDI_OVERRIDE` | critical | The source contains bidirectional control characters |
| `HOMOGLYPH` | high | An identifier mixes scripts that look alike |
| `PUA_CARRIER` | critical | The source contains private use characters |
| `TAG_CHARACTER` | critical | The source contains Unicode tag characters |
| `ZERO_WIDTH` | high | The source contains zero-width characters |

## Source inspection: entropy {id="entropy"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `HIGH_ENTROPY_STRING` | medium | A string literal looks random |

## Source inspection: archive {id="archive"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `ABSOLUTE_PATH` | critical | An archive entry has an absolute path |
| `BUILD_HOOK` | medium | The package has a build hook |
| `CASE_COLLISION` | medium | Two archive entries differ only in case |
| `DUPLICATE_ENTRY` | high | The archive contains the same path twice |
| `HIDDEN_EXECUTABLE` | high | The archive contains a hidden executable |
| `LINK_ENTRY` | high | The archive contains a symbolic or hard link |
| `MALFORMED_PUBSPEC` | high | The published pubspec.yaml cannot be read |
| `NATIVE_BINARY` | medium | The archive contains a native binary |
| `OVERLONG_NAME` | high | An archive entry has an overlong name |
| `PATH_TRAVERSAL` | critical | An archive entry escapes the package directory |
| `SETUID_BIT` | high | An archive entry has the setuid or setgid bit |
| `SPECIAL_FILE` | high | The archive contains a device file or pipe |

## Configuration lint {id="config"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `CONFIG_BASELINE_UNBOUNDED` | low | The baseline may cover findings of any severity |
| `CONFIG_DEPRECATED_OPTION` | low | The configuration uses the old name of a renamed option |
| `CONFIG_GATE_NOT_FAILING` | low | An enabled check never fails |
| `CONFIG_IGNORE_EXPIRED` | medium | An ignore rule has expired |
| `CONFIG_IGNORE_WITHOUT_EXPIRY` | low | An ignore rule has no expiry date |
| `CONFIG_INSECURE_URL` | high | A service URL of the configuration uses plain HTTP |
| `CONFIG_MIN_SEVERITY` | low | min_severity hides findings from every report |
| `CONFIG_NO_COVERAGE_THRESHOLD` | low | The coverage gate has no threshold |
| `CONFIG_PUBSPEC_SECTION_IGNORED` | medium | The inspectra: section of pubspec.yaml is ignored |
| `CONFIG_TRIVY_DISABLED` | medium | trivy.mode is disabled |
| `CONFIG_UNKNOWN_VARIABLE` | medium | An INSPECTRA_* variable names no option |
| `CONFIG_UNPINNED_TRIVY` | medium | trivy.version is latest |

## Package quality gates {id="quality"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `API_CHANGED` | medium | The public API differs from the committed dump |
| `API_DUMP_MISSING` | medium | The public API dump is missing |
| `CHANGELOG_PROBLEM` | medium | The changelog is malformed or misses the version |
| `COVERAGE_BELOW_THRESHOLD` | medium | Line coverage is below the threshold |
| `SEMVER_UNDECLARED_BREAKING` | medium | A breaking API change is not announced in a commit |
| `SEMVER_VIOLATION` | high | The version does not make the step the API changes need |
| `UNFORMATTED` | low | A file is not formatted with dart format |

## Style rules {id="style"}

| Rule | Severity | Reports |
|:--|:--|:--|
| `file_named_after_type` | low | A file declaring one top level type, or one public type next to private ones, is named after it in snake case. |
| `license_header` | low | Every file starts with the license header of ${header.source}. |
| `no_comments` | low | No comments except /// documentation and the license header. |
| `no_default_case` | low | No default case in switch statements: handle every case explicitly. |
| `no_else` | low | No else branch: return early or split the collection element. |
| `no_late` | low | No late variables: initialise every variable where it is declared. |
| `no_platform_imports` | low | No platform library under lib/ outside a variant of a conditional import. |
| `no_wildcard_case` | low | No wildcard case in switch statements and expressions: handle every case explicitly. |
| `one_public_type_per_file` | low |  |
| `one_type_per_file` | low |  |
| `private_docs` | low | Every private declaration has a /// documentation comment. |
| `public_docs` | low | Every public declaration has a /// documentation comment. |

<seealso>
    <category ref="reference">
        <a href="CLI-Reference.md#explain">explain</a>
    </category>
    <category ref="config">
        <a href="Dependency-Policy.md">Dependency policy</a>
        <a href="Workspace-Policy.md">Workspace policy</a>
        <a href="Configuration-Tools.md#lint">config lint</a>
    </category>
</seealso>
