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

    readonly property bool timerRunning: active && timerRemaining > 0

    // Timer presets shown in the popup
    readonly property var presets: [
        { label: "5m",  seconds: 300,   icon: Qt.resolvedUrl("../icons/timer-short.svg")    },
        { label: "15m", seconds: 900,   icon: Qt.resolvedUrl("../icons/timer-short.svg")    },
        { label: "30m", seconds: 1800,  icon: Qt.resolvedUrl("../icons/timer-medium.svg")   },
        { label: "1h",  seconds: 3600,  icon: Qt.resolvedUrl("../icons/timer-medium.svg")   },
        { label: "2h",  seconds: 7200,  icon: Qt.resolvedUrl("../icons/timer-long.svg")     },
        { label: "∞",   seconds: 0,     icon: Qt.resolvedUrl("../icons/timer-infinite.svg") },
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

    // ── Tooltip ───────────────────────────────────────────────────────────────

    toolTipMainText: "Theobromine"
    toolTipSubText: {
        if (!active)           return "Click to activate caffeine mode"
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

        Layout.minimumWidth:  Kirigami.Units.gridUnit * 15
        Layout.maximumWidth:  Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: implicitHeight
        spacing: Kirigami.Units.smallSpacing

        // ── Header ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Image {
                width:  Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
                source: root.active ? root.iconOn : root.iconOff
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                opacity: root.active ? 1.0 : 0.55
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: root.active ? "Caffeine mode active" : "Caffeine mode inactive"
                font.bold: true
                elide: Text.ElideRight
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
            text: "Deactivate"
            icon.name: "process-stop"
            onClicked: root.deactivate()
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ── Preset label ──────────────────────────────────────────────────────
        PlasmaComponents3.Label {
            text: root.active ? "Restart for:" : "Activate for:"
            opacity: 0.7
        }

        // ── Preset buttons ────────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing:    Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.presets
                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: modelData.label
                    icon.source: modelData.icon
                    // Highlight the currently active timer preset
                    highlighted: root.timerRunning
                        && modelData.seconds > 0
                        && Math.abs(root.timerRemaining - modelData.seconds) < 5
                    onClicked: root.activateWithTimer(modelData.seconds)
                }
            }
        }

        // spacer so the popup doesn't look cramped at the bottom
        Item { Layout.fillHeight: true; height: Kirigami.Units.smallSpacing }
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
