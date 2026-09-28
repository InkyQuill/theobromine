import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── State ─────────────────────────────────────────────────────────────────

    property bool active: false

    // Seconds remaining; 0 means "infinite / no timer"
    property int timerRemaining: 0
    property int customHours: 0
    property int customMinutes: 45

    readonly property bool timerRunning: active && timerRemaining > 0
    readonly property int customDuration: customHours * 3600 + customMinutes * 60

    // Timer presets shown in the popup
    readonly property var presets: [
        { label: "5 min",  seconds: 300,   icon: Qt.resolvedUrl("../icons/timer-short.svg")  },
        { label: "15 min", seconds: 900,   icon: Qt.resolvedUrl("../icons/timer-short.svg")  },
        { label: "30 min", seconds: 1800,  icon: Qt.resolvedUrl("../icons/timer-medium.svg") },
        { label: "1 hour", seconds: 3600,  icon: Qt.resolvedUrl("../icons/timer-medium.svg") },
        { label: "2 hours", seconds: 7200, icon: Qt.resolvedUrl("../icons/timer-long.svg")   },
    ]

    // Dark-theme detection: pick SVG variant based on background luminance
    readonly property bool isDark: {
        var c = Kirigami.Theme.backgroundColor
        return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) < 0.5
    }
    readonly property url iconOn:  isDark
        ? Qt.resolvedUrl("../icons/theobromine-on-dark.svg")
        : Qt.resolvedUrl("../icons/theobromine-on-light.svg")
    readonly property url iconOff: isDark
        ? Qt.resolvedUrl("../icons/theobromine-off-dark.svg")
        : Qt.resolvedUrl("../icons/theobromine-off-light.svg")

    // Absolute path to the inhibitor daemon script
    readonly property string scriptPath: {
        var url = Qt.resolvedUrl("../scripts/inhibit.py").toString()
        return url.replace(/^file:\/\//, "")
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    // Compact display: show hours+minutes when >= 1 h, else minutes+seconds
    function formatCompact(secs) {
        if (secs <= 0) return ""
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        if (h > 0)
            return h + "h " + (m < 10 ? "0" : "") + m + "m"
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // Full countdown for the popup header
    function formatFull(secs) {
        if (secs <= 0) return ""
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function formatDuration(secs) {
        if (secs <= 0) return "No time limit"
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        if (h > 0 && m > 0) return h + " h " + m + " min"
        if (h > 0) return h + (h === 1 ? " hour" : " hours")
        return m + " min"
    }

    // ── Tooltip ───────────────────────────────────────────────────────────────

    toolTipMainText: "Theobromine"
    toolTipSubText: {
        if (!active)           return "Ready to prevent sleep and screen lock"
        if (timerRunning)      return "Active — " + formatFull(timerRemaining) + " remaining"
        return "Active — no time limit"
    }

    // ── DataSources ───────────────────────────────────────────────────────────

    P5Support.DataSource {
        id: statusChecker
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            root.active = ((data["stdout"] || "").trim() === "running")
            // If the daemon died while a timer was running, clear the timer too
            if (!root.active) root.timerRemaining = 0
        }
    }

    P5Support.DataSource {
        id: cmdRunner
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => { disconnectSource(sourceName) }
    }

    // ── Countdown tick ────────────────────────────────────────────────────────

    Timer {
        id: countdown
        interval: 1000
        running: root.timerRunning
        repeat: true
        onTriggered: {
            root.timerRemaining = Math.max(0, root.timerRemaining - 1)
            if (root.timerRemaining === 0)
                root.deactivate()
        }
    }

    // Watchdog: detect unexpected daemon death every 30 s
    Timer {
        interval: 30000
        running: root.active
        repeat: true
        onTriggered: root.checkStatus()
    }

    // ── Compact representation ────────────────────────────────────────────────

    compactRepresentation: Item {
        // Expand horizontally to fit the countdown text when it's visible
        readonly property bool showTime: root.timerRunning
        Layout.minimumWidth:  Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Layout.preferredWidth: showTime
            ? iconItem.width + timeLabel.implicitWidth + Kirigami.Units.smallSpacing * 3
            : Kirigami.Units.iconSizes.medium
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium

        Behavior on Layout.preferredWidth {
            NumberAnimation { duration: 150 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }

        Row {
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Image {
                id: iconItem
                width:  Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
                source: root.active ? root.iconOn : root.iconOff
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                opacity: root.active ? 1.0 : 0.55
            }

            PlasmaComponents3.Label {
                id: timeLabel
                visible: root.timerRunning
                text: root.formatCompact(root.timerRemaining)
                // Shrink font slightly so it fits in the panel at default height
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.textColor
                verticalAlignment: Text.AlignVCenter
                height: iconItem.height
            }
        }
    }

    // ── Full representation (popup) ───────────────────────────────────────────

    fullRepresentation: ColumnLayout {
        id: popup

        Layout.minimumWidth:  Kirigami.Units.gridUnit * 18
        Layout.maximumWidth:  Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: implicitHeight
        spacing: Kirigami.Units.largeSpacing

        // ── Header ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Image {
                width:  Kirigami.Units.iconSizes.large
                height: Kirigami.Units.iconSizes.large
                source: root.active ? root.iconOn : root.iconOff
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                opacity: root.active ? 1.0 : 0.55
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.active ? "Keeping this session awake" : "Ready when you are"
                    font.bold: true
                    elide: Text.ElideRight
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.active
                        ? (root.timerRunning
                            ? root.formatFull(root.timerRemaining) + " remaining"
                            : "No time limit")
                        : "Sleep and screen lock are allowed"
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
        }

        // ── Countdown display (only when a timer is running) ──────────────────
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            visible: root.timerRunning
            text: root.formatFull(root.timerRemaining)
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 2.5
            font.features: { "tnum": 1 }
            horizontalAlignment: Text.AlignHCenter
            color: Kirigami.Theme.textColor
        }

        // ── Deactivate button (only when active) ──────────────────────────────
        PlasmaComponents3.Button {
            Layout.fillWidth: true
            visible: root.active
            text: "Stop keeping awake"
            icon.name: "process-stop"
            onClicked: root.deactivate()
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ── Preset buttons ────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: root.active ? "Restart timer" : "Start a timer"
                opacity: 0.7
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing:    Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.presets
                    PlasmaComponents3.Button {
                        Layout.fillWidth: true
                        text: modelData.label
                        icon.source: modelData.icon
                        highlighted: root.timerRunning
                            && Math.abs(root.timerRemaining - modelData.seconds) < 5
                        onClicked: root.activateWithTimer(modelData.seconds)
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ── Custom timer ──────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: "Custom duration"
                    opacity: 0.7
                }

                PlasmaComponents3.Label {
                    text: root.formatDuration(root.customDuration)
                    opacity: 0.7
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.SpinBox {
                    Layout.fillWidth: true
                    from: 0
                    to: 99
                    value: root.customHours
                    editable: true
                    textFromValue: function(value, locale) { return value + " h" }
                    valueFromText: function(text, locale) {
                        var parsed = parseInt(text, 10)
                        return isNaN(parsed) ? 0 : Math.max(from, Math.min(to, parsed))
                    }
                    onValueModified: root.customHours = value
                }

                PlasmaComponents3.SpinBox {
                    Layout.fillWidth: true
                    from: 0
                    to: 59
                    value: root.customMinutes
                    editable: true
                    textFromValue: function(value, locale) { return value + " min" }
                    valueFromText: function(text, locale) {
                        var parsed = parseInt(text, 10)
                        return isNaN(parsed) ? 0 : Math.max(from, Math.min(to, parsed))
                    }
                    onValueModified: root.customMinutes = value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: root.active ? "Restart custom" : "Start custom"
                    icon.name: "chronometer-start"
                    enabled: root.customDuration > 0
                    onClicked: root.activateWithTimer(root.customDuration)
                }

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: "No limit"
                    icon.source: Qt.resolvedUrl("../icons/timer-infinite.svg")
                    highlighted: root.active && !root.timerRunning
                    onClicked: root.activateWithTimer(0)
                }
            }
        }
    }

    // ── Logic ─────────────────────────────────────────────────────────────────

    function activateWithTimer(seconds) {
        if (!root.active) {
            cmdRunner.connectSource(
                "bash -c 'nohup python3 \"" + root.scriptPath + "\" >/dev/null 2>&1 &'"
            )
        }
        root.active = true
        root.timerRemaining = seconds   // 0 = infinite
    }

    function deactivate() {
        cmdRunner.connectSource(
            "bash -c 'if [ -f /tmp/theobromine.pid ]; then" +
            "  kill \"$(cat /tmp/theobromine.pid)\" 2>/dev/null;" +
            "  rm -f /tmp/theobromine.pid;" +
            "fi'"
        )
        root.active = false
        root.timerRemaining = 0
    }

    function checkStatus() {
        statusChecker.connectSource(
            "bash -c 'test -f /tmp/theobromine.pid" +
            "  && kill -0 \"$(cat /tmp/theobromine.pid)\" 2>/dev/null" +
            "  && echo running || echo stopped'"
        )
    }

    Component.onCompleted: checkStatus()
}
