import Darwin
import GhosttyKit

let info = ghostty_info()
guard info.build_mode == GHOSTTY_BUILD_MODE_RELEASE_FAST else {
  fputs(
    "ERROR: libghostty is not a ReleaseFast build (mode: \(info.build_mode.rawValue))\n",
    stderr
  )
  exit(EXIT_FAILURE)
}
