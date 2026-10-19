# Semantic versioning

<primary-label ref="cli"/>
<secondary-label ref="opt-in"/>
<secondary-label ref="no-network"/>
<secondary-label ref="since-2-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>Compare the public API with the dump committed at the last release, classify every change as breaking or additive, and require a version in pubspec.yaml that matches.</link-summary>

<card-summary>api semver: the API dump at the last release tag against the current code, and the version the changes require.</card-summary>

<tldr>
<p><b>Run</b>: <code>dart run %package% api semver</code>, or <code>--from v1.2.0</code> for another revision</p>
<p><b>In check and report</b>: <code>api: { semver: true }</code></p>
<p><b>Needs</b>: Git, a release tag such as <code>v1.2.0</code>, and the API dump committed at that tag</p>
<p><b>Findings</b>: <code>SEMVER_VIOLATION</code> (high), <code>SEMVER_UNDECLARED_BREAKING</code> (medium)</p>
</tldr>

Internal packages often break their API in a minor or patch release, and only the builds of their consumers notice.
The committed [API dump](API-Overview.md) already records what consumers can use; `api semver` compares the dump as
it was at the last release with the API of the current code, decides for every change whether it breaks consumers,
and checks that the `version` in `pubspec.yaml` makes at least the step those changes require.

```text
API semver: 3 change(s) since v1.4.0 (1.4.0).
  - breaking  Shape.area: The member was removed.
  - breaking  Color.blue: The enum value was added; switch statements over the enum without a default case no longer compile.
  + additive  Circle.Circle: Only optional parameters were added.
major change: version 2.0.0 or higher is required; pubspec.yaml declares 1.5.0, which is too low.
```

## How it works

1. **The release**: the highest tag with the prefix `changelog.tag_prefix` (default `v`) that is reachable from
   `HEAD`, the same tag `changelog generate` starts from. `--from <revision>` compares with any other tag, branch or
   commit instead.
2. **The API at the release**: the dump file `api.output` as committed at that revision, read with `git show`. There
   is no checkout and no `pub get`.
3. **The API now**: rendered from the code, exactly as `api dump` would write it. The committed dump does not need to
   be up to date; `api check` covers that.
4. **The changes**: every library, declaration, member and enum value that was removed, added or changed, each with a
   reason.
5. **The version**: breaking changes require the next major version, additive changes the next minor version, and
   no changes nothing. Before 1.0.0 the steps follow Dart's convention: breaking changes require the next minor
   version and additive changes the next patch version.

A pre-release counts as the release it leads to: `2.0.0-dev.1` satisfies a required `2.0.0`, so the version can be
raised as soon as the first breaking change lands.

## Which changes break consumers {id="classification"}

| Change | Classified as |
|:--|:--|
| A library, declaration or member removed | breaking |
| An enum value removed or **added** | breaking; an added value breaks `switch` statements without a default case |
| A type declaration changed: modifiers such as `final` or `sealed`, type parameters, supertypes | breaking |
| A signature changed: a type, the return type, a required parameter, a default value | breaking |
| A constant's value changed | breaking; constant expressions and `switch` patterns use it |
| An `abstract` member added, or any member of an `interface` class | breaking; implementers must add it |
| Only optional parameters added to a top-level function, a constructor, a static member, an extension member, or a member of a `final` or `sealed` class or an enum | additive |
| Only optional parameters added to a member that subclasses can override | breaking; overrides no longer match |
| A library, declaration or member added | additive |
| `@Deprecated` added or removed | additive |

The comparison works on the dump, so it sees what the dump records: signatures, not behaviour. A changed
implementation behind an unchanged signature is not a change here.

## The findings

<deflist type="medium">
    <def title="SEMVER_VIOLATION (high)">
        The version in <code>pubspec.yaml</code> is lower than the changes require. The location is
        <code>pubspec.yaml</code>; the description names the required version.
    </def>
    <def title="SEMVER_UNDECLARED_BREAKING (medium)">
        Only with <code>changelog.enabled</code>: the API breaks consumers, but no commit since the release is marked
        as a breaking change with <code>!</code> or a <code>BREAKING CHANGE</code> footer, so the generated changelog
        would not mention it.
    </def>
</deflist>

Both fail the command (exit code `1`) at the default `fail_on` threshold. `-f json`, `sarif`, `junit` and the other
[report formats](Reports.md) work as for every other command; the JSON lists every change with `kind`, `library`,
`declaration`, `member`, `reason`, `before` and `after`, plus `baseline`, `version`, `bump` and `required`.

## When it is skipped

The check reports *skipped* with the reason and exits with `0` when there is nothing to compare with:

- there is no release tag yet, or the repository has no commit yet,
- the revision has no API dump at `api.output`; record it with `api dump` and commit it before tagging,
- `pubspec.yaml` declares no `version`.

Outside a Git repository, and for a `--from` revision Git does not know, it exits with `64`; without Git with `69`.

## In check and report

```yaml
inspectra:
  api:
    semver: true
```

With `api.semver: true`, `dart run %package% check` runs the step "API semver" after the API check, and
`dart run %package% report` adds the section "Semantic versioning" with the changes, the required version and the
findings. `api semver` itself always runs when called. `api.semver` does not need `api.enabled`, but the dump must be
committed at each release, which `api.enabled` keeps up to date.

<warning>
CI checkouts are shallow by default and fetch no tags, so there is no release to compare with. Fetch the whole
history, for example with <code>fetch-depth: 0</code> in <code>actions/checkout</code>. The command warns when it
runs in a shallow clone. See <a href="CI-Integration.md">CI integration</a>.
</warning>

## Release workflow

<procedure title="Release with a checked version" id="release-workflow_1">
    <step>
        <p>Keep the dump current: <code>dart run build_runner build</code> or <code>dart run %package% api dump</code>,
        and commit it with the code.</p>
    </step>
    <step>
        <p>Before the release, run <code>dart run %package% api semver</code> and set the version it requires, or
        <code>dart run %package% changelog generate --write</code>, which picks the version from the commits.</p>
    </step>
    <step>
        <p>Tag the release commit, for example <code>git tag v2.0.0</code>. The dump committed at that tag is what the
        next release is compared with.</p>
    </step>
</procedure>

<seealso>
    <category ref="api">
        <a href="API-Overview.md">Public API validation</a>
        <a href="API-Workflow.md">Workflow</a>
        <a href="API-Configuration.md">Configuration</a>
    </category>
    <category ref="release">
        <a href="Changelog-Releasing.md">Releasing</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#api-semver">CLI reference</a>
    </category>
    <category ref="external">
        <a href="https://semver.org/">Semantic Versioning</a>
        <a href="https://dart.dev/tools/pub/versioning">Package versioning</a>
    </category>
</seealso>
