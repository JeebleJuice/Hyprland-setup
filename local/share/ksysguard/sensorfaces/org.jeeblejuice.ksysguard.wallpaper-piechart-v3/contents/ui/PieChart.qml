/*
    SPDX-FileCopyrightText: 2019 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2019 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2019 Arjen Hiemstra <ahiemstra@heimr.nl>
    SPDX-FileCopyrightText: 2019 Kai Uwe Broulik <kde@broulik.de>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtCore
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.faces as Faces

import org.kde.quickcharts as Charts
import org.kde.quickcharts.controls as ChartControls


ChartControls.PieChartControl {
    id: chart

    property color wallpaperAccent: "#3daee9"
    property bool accentRequestPending: false

    function refreshWallpaperAccent() {
        if (chart.accentRequestPending) {
            return;
        }

        const request = new XMLHttpRequest();
        chart.accentRequestPending = true;
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            chart.accentRequestPending = false;
            const accent = request.responseText.trim();
            if ((request.status === 0 || request.status === 200)
                    && /^#[0-9a-fA-F]{6}$/.test(accent)) {
                chart.wallpaperAccent = accent;

                // The Overview gauges each have one high-priority sensor.
                // Update the controller map too, so the live value is saved.
                if (root.controller.highPrioritySensorIds.length === 1) {
                    const colors = {};
                    colors[root.controller.highPrioritySensorIds[0]] = accent;
                    root.controller.sensorColors = colors;
                }
            }
        };
        request.open("GET", "file://" + StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.cache/glass-system-monitor-accent", true);
        request.send();
    }

    Timer {
        interval: 400
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: chart.refreshWallpaperAccent()
    }

    property alias headingSensor: sensor.sensorId
    property alias sensors: sensorsModel.sensors
    property alias sensorsModel: sensorsModel

    property int updateRateLimit

    Layout.minimumHeight: root.formFactor == Faces.SensorFace.Vertical ? width : Kirigami.Units.gridUnit

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    readonly property real rangeFrom: root.controller.faceConfiguration.rangeFrom *
                                      root.controller.faceConfiguration.rangeFromMultiplier

    readonly property real rangeTo: root.controller.faceConfiguration.rangeTo *
                                    root.controller.faceConfiguration.rangeToMultiplier

    chart.smoothEnds: root.controller.faceConfiguration.smoothEnds
    chart.fromAngle: root.controller.faceConfiguration.fromAngle
    chart.toAngle: root.controller.faceConfiguration.toAngle
    chart.thickness: Kirigami.Units.largeSpacing

    range {
        from: chart.rangeFrom
        to: chart.rangeTo
        automatic: root.controller.faceConfiguration.rangeAuto
    }

    chart.backgroundColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)

    valueSources: Charts.ModelSource {
        model: Sensors.SensorDataModel {
            id: sensorsModel
            sensors: root.controller.highPrioritySensorIds
            updateRateLimit: chart.updateRateLimit
            sensorLabels: root.controller.sensorLabels
        }
        roleName: "Value"
        indexColumns: true
    }
    chart.nameSource: Charts.ModelSource {
        roleName: "Name";
        model: valueSources[0].model;
        indexColumns: true
    }
    chart.shortNameSource: Charts.ModelSource {
        roleName: "ShortName";
        model: valueSources[0].model;
        indexColumns: true
    }
    chart.colorSource: Charts.SingleValueSource {
        value: chart.wallpaperAccent
    }

    Sensors.Sensor {
        id: sensor
        sensorId: root.controller.totalSensors.length > 0 ? root.controller.totalSensors[0] : ""
        updateRateLimit: chart.updateRateLimit
    }

    UsedTotalDisplay {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width

        usedSensor: root.controller.totalSensors.length > 0 ? root.controller.totalSensors[0] : ""
        totalSensor: root.controller.totalSensors.length > 1 ? root.controller.totalSensors[1] : ""

        contentMargin: chart.chart.thickness
        updateRateLimit: chart.updateRateLimit
    }
}
