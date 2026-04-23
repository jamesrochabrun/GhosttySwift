# GhosttySwiftPermissive

Fresh Swift Package wrapper around upstream [Ghostty](https://github.com/ghostty-org/ghostty),
implemented from permissive sources only.

This repo is intentionally separate from the earlier derivative prototype. The
current scope is the first clean milestone:

- package scaffold
- upstream Ghostty build script
- bundled `share/ghostty` resources
- one AppKit surface
- one SwiftUI wrapper
- one sample app that renders a real shell prompt
- keyboard forwarding
- mouse forwarding
- clipboard integration

Not in scope yet:

- tabs or sessions
- splits
- persistence

## Provenance Rules

- Implementation references: upstream Ghostty C API, upstream Ghostty macOS sources,
  Ghostty's Swift xcframework example, Apple AppKit/SwiftUI APIs, and behavioral
  requirements re-derived from first principles.
- Non-reference sources: the earlier local `GhosttySwift` repo and local `supacode`.

## Build

From the repo root:

```sh
Scripts/build-ghostty.sh
swift build
Scripts/run-sample.sh
```

`Scripts/build-ghostty.sh` compiles upstream Ghostty into
`Frameworks/GhosttyKit.xcframework` and copies Ghostty's `share/ghostty`
resources into the SwiftPM target bundle.

`Scripts/run-sample.sh` wraps the sample executable in a `.app` bundle so it
activates as a regular macOS app.

## Third-Party Code

- `ThirdParty/ghostty/` is upstream Ghostty under the MIT license and tracked as a git submodule.
- `GhosttyKit.xcframework` is built locally from that upstream source and is
  intentionally ignored by git.
