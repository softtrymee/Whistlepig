# Whistlepig

Whistlepig is a private, personal iOS Matrix client forked from [Element X iOS](https://github.com/element-hq/element-x-ios). It uses SwiftUI and the Matrix Rust SDK, and targets iOS 18.5 and later.

This is not an Element-supported distribution. Its initial goals are a reliable private build signed with an Apple Personal Team and Matrix sticker support based on `m.sticker`, `m.room.image_pack`, and `m.image_pack.rooms`.

## Development

Install the upstream development tools and generate the Xcode project:

```sh
swift run tools setup-project
```

Open `ElementX.xcodeproj` in Xcode. For a connected iPhone, select your Personal Team under **Signing & Capabilities**. No Apple Developer Program membership, APNs, or Sygnal configuration is required for the initial development workflow.

For a Simulator-only build:

```sh
xcodebuild -project ElementX.xcodeproj -scheme ElementX \
  -sdk iphonesimulator -configuration Debug build
```

Detailed fork, signing, and rebase guidance is in [docs/PRIVATE_FORK.md](docs/PRIVATE_FORK.md).

## Upstream maintenance

`origin` is the private Gitea repository and `upstream` is the Element X repository. This fork starts from `release/26.08.4`; keep private changes focused and rebase them onto future upstream release tags when needed.

Git LFS snapshot assets are intentionally not mirrored to Gitea yet. Clone with `GIT_LFS_SKIP_SMUDGE=1` unless snapshot tests are required.

## Copyright & license

Copyright (c) 2025 - 2026 Element Creations Ltd.
Copyright (c) 2022 - 2025 New Vector Ltd.

This software is dual licensed by Element Creations Ltd (Element). It can be used either:

(1) for free under the terms of the GNU Affero General Public License (as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version); OR

(2) under the terms of a paid-for Element Commercial License agreement between you and Element (the terms of which may vary depending on what you and Element have agreed to).

Unless required by applicable law or agreed to in writing, software distributed under the Licenses is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licenses for the specific language governing permissions and limitations under the Licenses.
