#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_directory=${script_directory:h:h}
sdk_directory=${WHISTLEPIG_MATRIX_RUST_SDK_DIRECTORY:-"${TMPDIR%/}/whistlepig-matrix-rust-sdk"}
sdk_revision=1d1c0cbbd8f903a079dd07a9ca6a71449da01f1c
patch_file=${repository_directory}/Tools/Patches/matrix-sdk-ffi-state-events.patch
package_directory=${repository_directory}/Components/WhistlepigMatrixRustSDK

if [[ ! -d ${sdk_directory}/.git ]]; then
    git clone https://github.com/matrix-org/matrix-rust-sdk.git ${sdk_directory}
fi

git -C ${sdk_directory} fetch --depth=1 origin ${sdk_revision}
git -C ${sdk_directory} checkout --detach ${sdk_revision}

if ! git -C ${sdk_directory} apply --reverse --check ${patch_file} >/dev/null 2>&1; then
    git -C ${sdk_directory} apply ${patch_file}
fi

unset SDKROOT
RUSTC="${WHISTLEPIG_RUSTC:-$(rustup which --toolchain stable rustc)}" \
    cargo run -p xtask -- swift build-framework --release \
    --target aarch64-apple-ios \
    --target aarch64-apple-ios-sim \
    --target x86_64-apple-ios

mkdir -p ${package_directory}/Artifacts
ditto ${sdk_directory}/bindings/apple/generated/MatrixSDKFFI.xcframework ${package_directory}/Artifacts/MatrixSDKFFI.xcframework
ditto ${sdk_directory}/bindings/apple/generated/swift ${package_directory}/Sources/MatrixRustSDK
