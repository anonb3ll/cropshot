import QtQuick
import Quickshell
import qs.Commons

// Lets keybindings reach cropshot through the running shell:
//   o.bind("ALT + SHIFT + 4", "Cropped screenshot", { ipc = "cropshot.region" })
// Each call starts the bundled bin/cropshot as a detached process.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string script: decodeURIComponent(String(Qt.resolvedUrl("bin/cropshot")).replace(/^file:\/\//, ""))

  function capture(args) {
    Quickshell.execDetached([root.script].concat(args))
  }

  ShellIpc {
    target: "cropshot"

    function region(): void {
      root.capture(["region"])
    }

    function window(): void {
      root.capture(["window"])
    }

    function screen(): void {
      root.capture(["screen"])
    }

    function clipboard(): void {
      root.capture(["region", "--clipboard"])
    }
  }
}
