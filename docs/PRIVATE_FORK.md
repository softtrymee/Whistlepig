# Whistlepig private-fork workflow

Whistlepig is a personal fork of Element X iOS. Its private additions should be
small, self-contained commits so that `main` can be rebased onto Element X
release tags without carrying a large, long-lived merge conflict.

## Branches and remotes

- `origin` is the private Gitea repository.
- `upstream` is `https://github.com/element-hq/element-x-ios.git`.
- `main` starts from an Element X release tag. It contains only fork identity,
  developer documentation, and completed personal features.
- Create a short-lived `feature/<name>` branch for every feature. Rebase it on
  `main` before merging it back with a fast-forward or a small focused commit.

To advance to a newer Element X release:

```sh
git fetch --tags upstream
git switch main
git rebase --rebase-merges release/<version>
git push --force-with-lease origin main
```

Use `git log --oneline release/<version>..main` to review the private patch
stack before rebasing. Never edit `ElementX.xcodeproj` by hand: change the
XcodeGen YAML files and include their regenerated project changes with the
source configuration change.

## Local development without the Apple Developer Program

The committed configuration uses this fork's Personal Team. Open
`ElementX.xcodeproj` and let Xcode manage signing. If the fork moves to another
Apple Account, replace `DEVELOPMENT_TEAM` in `app.yml` with that account's Team
ID before building for a device.

The Personal Team is suitable for local development and a directly connected
test iPhone. Provisioning and installed builds expire regularly; no APNs,
Sygnal credentials, provisioning profiles, or Apple certificates are stored in
this repository.

The current fork identity is:

| Setting | Value |
| --- | --- |
| Display name | `Whistlepig` |
| Bundle identifier | `me.softtryme.whistlepig` |
| App group | `group.me.softtryme.whistlepig` |

If a Personal Team does not permit an entitlement required by an extension,
keep the Simulator baseline working and resolve the exact signing error in
Xcode before removing or weakening an entitlement. Do not configure APNs or
Sygnal until the feature work is complete and an Apple Developer Program
membership is deliberately added.

## Build commands

```sh
swift run tools setup-project
xcodebuild -project ElementX.xcodeproj -scheme ElementX \
  -sdk iphonesimulator -configuration Debug build
```

The first command installs the officially required developer tools and invokes
XcodeGen. Keep signing enabled for Simulator builds: Element X uses the
Keychain during launch, and disabling signing removes the required simulated
entitlements. For a device run, use Xcode with the configured Personal Team.

## Sticker feature boundary

Sticker work lives in focused feature commits after the baseline compiles. It
must reuse the existing timeline sticker renderer, understand room image-pack
state (`m.room.image_pack` and `m.image_pack.rooms`), and send `m.sticker`.
Avoid changes to Matrix Rust SDK vendoring or generated project files unless an
upstream API forces one.
