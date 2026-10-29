import QtQuick
import Quickshell
import qs.Commons as Commons
import qs.Ui

// Bar button: left-click drags a region or picks a window, right-click takes
// the monitor, middle-click copies a region without saving it.
BarWidget {
  id: root
  moduleName: "anonb3ll.cropshot"

  readonly property string script: decodeURIComponent(String(Qt.resolvedUrl("bin/cropshot")).replace(/^file:\/\//, ""))

  function capture(args) {
    Quickshell.execDetached([root.script].concat(args))
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰹑"
    tooltipText: strings.t("bar.tooltip")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.capture(["screen"])
      else if (b === Qt.MiddleButton) root.capture(["region", "--clipboard"])
      else root.capture(["region"])
    }
  }
}
