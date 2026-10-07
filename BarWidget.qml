import QtQuick
import qs.Commons
import qs.Ui

// Bar icon for Color Assist. Left click opens the filter panel; middle or
// right click toggles the last used filter. State lives in Service.qml.
BarWidget {
  id: root
  moduleName: "nejcc.color-assist"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("nejcc.color-assist") : null
  readonly property bool active: service ? service.active : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = button
    target.hostWidget = root
    target.service = root.service
  }

  // Shape contract for shell summon/hide/toggle routing.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onServiceChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.active ? "\u{F0208}" : "\u{F0209}"
    active: root.active
    useActiveColor: false
    dimmed: !root.active
    tooltipText: !root.service
      ? "Color Assist: service not running"
      : "Color Assist: " + root.service.label
    onPressed: function(b) {
      if (b === Qt.MiddleButton || b === Qt.RightButton) {
        if (root.service) root.service.toggle()
      } else if (panelLoader.item) {
        panelLoader.item.toggle()
      }
    }
  }
}
