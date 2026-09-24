# Whistlepig Matrix Rust SDK

This local package is the Element X 26.08.25 SDK wrapper with one private API:
`Room.stateEventsRaw(eventType:)`. Sticker packs need raw `m.room.image_pack`
state events, which the upstream wrapper does not yet expose.

The generated Swift bindings are tracked. The XCFramework is deliberately ignored:
it is a large build product and must not enter Whistlepig Git history or LFS.

After a fresh clone, build it with:

```sh
zsh Tools/Scripts/build-whistlepig-matrix-sdk.sh
```

The script checks out the Matrix Rust SDK revision pinned by Element X,
applies `Tools/Patches/matrix-sdk-ffi-state-events.patch`, and writes the
framework into `Artifacts/MatrixSDKFFI.xcframework`.
