# Doctor

<primary-label ref="cli"/>
<secondary-label ref="since-2-0"/>

<show-structure for="chapter" depth="2"/>

<link-summary>inspectra doctor checks what Inspectra needs on a machine and in a project: the configuration, the Dart and Flutter SDKs, Git, Trivy, proxy, CA bundle, registry token, network and cache.</link-summary>

<card-summary>One command for the usual support tickets in corporate networks: SDK versions, Git, Trivy, proxy, CA bundle, registry token, reachability and cache.</card-summary>

```bash
dart run %package% doctor
dart run %package% doctor --offline -f json
```

Most problems with %product% in a company network are not bugs but the environment: an SDK older than the package
needs, a proxy without the company CA, a private registry without a token, a cache directory that cannot be written.
`doctor` checks all of them at once and says what to do:

```text
✔ Configuration      inspectra.yaml with 1 base(s) is valid.
✔ Dart SDK           3.7.2 satisfies environment.sdk ^3.6.0.
! Flutter SDK        3.27.1 is installed, but .fvmrc pins 3.29.2; run "fvm use".
✔ Git                2.43.0.
! Trivy              not installed; 0.75.0 is downloaded on first use while online.
✔ Proxy              http://proxy.acme.corp:3128.
✔ CA bundle          /repo/certs/acme-root.pem loads.
✔ OSV.dev            https://api.osv.dev is reachable.
✘ Package registry   https://pub.acme.corp is not reachable; check the proxy, the CA bundle and the firewall.
! Pub token          dart pub has no token for pub.acme.corp; run "dart pub token add https://pub.acme.corp".
✔ Cache              /home/dev/.cache/inspectra is writable.
1 check(s) failed.
```

| Check | Looks at |
|:--|:--|
| Configuration | Loads the configuration with its bases and policies; a broken configuration is a failed check, not a crash |
| Dart SDK | `dart --version` against `environment.sdk` |
| Flutter SDK | For Flutter packages: `flutter --version --machine` against `environment.flutter`, and the version `.fvmrc` pins |
| Git | Installed, and at least 2.15 |
| Trivy | The executable `trivy.executable`, the cache or the `PATH` provide, unless `trivy.mode` is `disabled` |
| Proxy, CA bundle | `network.proxy` or `HTTPS_PROXY` (credentials hidden), and whether `network.ca_certificates` loads |
| OSV.dev, Package registry, Trivy releases | One `HEAD` request each, unless `--offline` or `network.offline` |
| Pub token | For a private `network.pub_hosted_url`: whether `dart pub token list` names its host |
| Cache | Whether the cache directory, `INSPECTRA_CACHE_DIR` or the platform's, can be written |

`doctor` reads the `INSPECTRA_*` variables like every command. `-f json` writes `healthy` and `checks` with `name`,
`status` (`ok`, `warn`, `fail`, `skipped`) and `detail`. It exits with `1` when a check failed, otherwise with `0`;
warnings do not fail.

<seealso>
    <category ref="operations">
        <a href="Troubleshooting.md">Troubleshooting</a>
        <a href="CI-Integration.md">CI integration</a>
    </category>
    <category ref="reference">
        <a href="CLI-Reference.md#doctor">doctor</a>
    </category>
</seealso>
