/*
    SPDX-FileCopyrightText: 2019 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2019 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2019 Arjen Hiemstra <ahiemstra@heimr.nl>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtCore
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.faces as Faces
import org.kde.ksysguard.formatter as Formatter
import org.kde.quickcharts as Charts

Charts.LineChart {
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
    
    property var controller

    readonly property alias sensorsModel: sensorsModel
    readonly property int historyAmount: controller.faceConfiguration.historyAmount

    direction: Charts.XYChart.ZeroAtEnd

    fillOpacity: controller.faceConfiguration.lineChartFillOpacity / 100
    stacked: controller.faceConfiguration.lineChartStacked
    interpolate: controller.faceConfiguration.lineChartSmooth

    //TODO: Have a central heading here too?
    //TODO: Have a plasmoid config value for line thickness?

    readonly property bool stackedAuto: chart.controller.faceConfiguration.rangeAutoY && chart.controller.faceConfiguration.lineChartStacked

    readonly property real rangeFromY: chart.controller.faceConfiguration.rangeFromY *
                                       chart.controller.faceConfiguration.rangeFromYMultiplier

    readonly property real rangeToY: chart.controller.faceConfiguration.rangeToY *
                                     chart.controller.faceConfiguration.rangeToYMultiplier

    yRange {
        from: stackedAuto ? Math.min(sensorsModel.minimum, 0) : chart.rangeFromY
        to: stackedAuto ? sensorsModel.stackedMaximum : chart.rangeToY
        automatic: (chart.controller.faceConfiguration.rangeAutoY && !chart.controller.faceConfiguration.lineChartStacked)
            || stackedAuto && yRange.from == yRange.to
    }

    Sensors.SensorDataModel {
        id: sensorsModel
        sensors: chart.controller.highPrioritySensorIds
        updateRateLimit: chart.controller.updateRateLimit
        sensorLabels: chart.controller.sensorLabels

        property int unit: (sensorsModel.ready && sensorsModel.headerData(0, Qt.Horizontal, Sensors.SensorDataModel.Unit)) ?? Formatter.Units.UnitInvalid
        property double stackedMaximum: yRange.stackedAuto ? calcStackedMaximum() : 0

        function calcStackedMaximum() {
            let max = 0
            for (let i = 0; i < sensorsModel.sensors.length; ++i) {
                max += sensorsModel.headerData(i, Qt.Horizontal, Sensors.SensorDataModel.Maximum)
            }
            return max
        }
    }

    Connections {
        target: sensorsModel
        enabled: chart.stackedAuto
        function onColumnsInserted() {
            sensorsModel.stackedMaximum = sensorsModel.calcStackedMaximum()
        }
        function onColumnsRemoved() {
            sensorsModel.stackedMaximum = sensorsModel.calcStackedMaximum()
        }
        function onSensorMetaDataChanged() {
            sensorsModel.stackedMaximum = sensorsModel.calcStackedMaximum()
        }
    }

    Instantiator {
        model: sensorsModel.sensors
        delegate: Charts.HistoryProxySource {
            id: history

            source: Charts.ModelSource {
                model: sensorsModel
                column: index
                roleName: "Value"
            }

            interval: {
                if (chart.controller.updateRateLimit > 0) {
                    return chart.controller.updateRateLimit
                }

                if (sensorsModel.ready) {
                    return sensorsModel.headerData(index, Qt.Horizontal, Sensors.SensorDataModel.UpdateInterval) ?? 0
                }

                return 0
            }
            maximumHistory: interval > 0 ? (chart.historyAmount * 1000) / interval : 0
            fillMode: Charts.HistoryProxySource.FillFromEnd

            property var connection: Connections {
                target: chart.controller
                function onUpdateRateLimitChanged() {
                    history.clear()
                }
            }
        }
        onObjectAdded: (index, object) => {
            chart.insertValueSource(index, object)
        }
        onObjectRemoved: (index, object) => {
            chart.removeValueSource(object)
        }
    }

    Charts.SingleValueSource {
        id: wallpaperSingleColor
        value: chart.wallpaperAccent
    }
    Charts.ColorGradientSource {
        id: wallpaperGradient
        baseColor: chart.wallpaperAccent
        itemCount: sensorsModel.sensors.length
    }
    colorSource: sensorsModel.sensors.length === 1 ? wallpaperSingleColor : wallpaperGradient
    nameSource: Charts.ModelSource {
        roleName: "Name";
        model: sensorsModel
        indexColumns: true
    }
    shortNameSource: Charts.ModelSource {
        roleName: "ShortName";
        model: sensorsModel
        indexColumns: true
    }
}
