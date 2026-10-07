import QtQuick
import qs.Commons
import qs.Ui
import "Logic.js" as Logic

// Filter picker: Off plus every filter, one active at a time.
Panel {
  id: root
  moduleName: "nejcc.color-assist"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null

  readonly property var options: [{ id: Logic.OFF, label: "Off", hint: "Back to the previous shader" }].concat(Logic.FILTERS)
  readonly property string current: service ? service.filter : Logic.OFF
  property int cursor: 0

  function indexOf(id) {
    for (var i = 0; i < options.length; i++) if (options[i].id === id) return i
    return 0
  }

  function choose(i) {
    if (service && i >= 0 && i < options.length) service.select(options[i].id)
  }

  onOpenedChanged: if (root.opened) root.cursor = root.indexOf(root.current)

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened && root.anchorItem !== null
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        var n = root.options.length
        root.cursor = (root.cursor + (dy || dx) + n) % n
      }
      onActivateRequested: root.choose(root.cursor)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(6)

        PanelSectionHeader {
          text: "COLOR ASSIST"
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Text {
          visible: !root.service
          width: parent.width
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          text: "The Color Assist service is not running. Re-enable the plugin."
          color: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Repeater {
          model: root.options

          Button {
            required property var modelData
            required property int index
            width: column.width
            leftAlign: true
            iconText: root.current === modelData.id ? "\u{F043E}" : "\u{F043D}"
            text: modelData.label + "  ·  " + modelData.hint
            fontSize: Style.font.bodySmall
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            bordered: true
            active: root.current === modelData.id
            hasCursor: root.cursor === index
            enabled: root.service !== null
            onClicked: root.choose(index)
            onHovered: function(h) { if (h) root.cursor = index }
          }
        }
      }
    }
  }
}
