/*
 * SPDX-FileCopyrightText: 2015 Aleix Pol Gonzalez <aleixpol@kde.org>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick 2.15
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.7 as Kirigami
import org.kde.kdeconnect 1.0

Kirigami.Page
{
    id: mousepad
    title: i18nd("kdeconnect-app", "Remote Control")
    property QtObject pluginInterface
    property QtObject device

    // Otherwise swiping on the MouseArea might trigger changing the page
    Kirigami.ColumnView.preventStealing: true

    Component.onCompleted: {
        PointerLocker.window = applicationWindow()
    }

    ColumnLayout
    {
        anchors.fill: parent

        MouseArea {
            id: area
            Layout.fillWidth: true
            Layout.fillHeight: true
            property var lastPos: Qt.point(-1, -1)
            property var pressedPos: Qt.point(-1, -1)
            property var releasedPos: Qt.point(-1, -1)

            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            Button {
                id: lockButton
                anchors.centerIn: parent
                text: i18n("Lock")
                visible: !Kirigami.Settings.tabletMode && !PointerLocker.isLocked
                onClicked: {
                    PointerLocker.isLocked = true
                    area.pressedPos = Qt.point(-1, -1);
                }
            }
            Label {
                anchors.centerIn: parent
                visible: PointerLocker.isLocked
                width: parent.width

                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter

                text: i18n("Press the left and right mouse buttons at the same time to unlock")
            }

            Connections {
                target: PointerLocker
                function onPointerMoved() {
                    if (!PointerLocker.isLocked) {
                        return;
                    }
                    mousepad.pluginInterface.moveCursor(Qt.point(delta.x, delta.y));
                }
            }

            // We don't want to see the lock button when using a touchscreen
            TapHandler {
                acceptedDevices: PointerDevice.TouchScreen
                onTapped: lockButton.visible = false
            }

            onClicked: {
                var clickType = "";
                var packet = {};
                switch (mouse.button) {
                case Qt.LeftButton:
                    if (PointerLocker.isLocked) // we directly send singleclick and singlehold to emulate all mouse actions inc. drag and drop
                        return;
                    if (pressedPos == releasedPos) {
                        clickType = "singleclick";
                    }
                    break;
                case Qt.RightButton:
                    clickType = "rightclick";
                    break;
                case Qt.MiddleButton:
                    clickType = "middleclick";
                    break;
                default:
                    console.log("This click input is not handled yet!");
                    break;
                }

                if (clickType) {
                    packet[clickType] = true;
                    mousepad.pluginInterface.sendCommand(packet);
                }
            }

            onPressAndHold: {
                if (PointerLocker.isLocked)
                    return;                     // we send singlehold and singlerelease twice instead through onPressed and onReleased
                var clickType = "";
                var packet = {};
                switch (mouse.button) {
                case Qt.LeftButton:
                    clickType = "singlehold";
                    break;
                default:
                    console.log("This click input is not handled yet!");
                    break;
                }

                if (clickType) {
                    packet[clickType] = true;
                    mousepad.pluginInterface.sendCommand(packet);
                }
            }

            onPositionChanged: {
                if (lastPos.x > -1) {
    //                 console.log("move", mouse.x, mouse.y, lastPos)
                    var delta = Qt.point(mouse.x-lastPos.x, mouse.y-lastPos.y);

                    pluginInterface.moveCursor(delta);
                }
                lastPos = Qt.point(mouse.x, mouse.y);
            }

            Keys.onPressed: {
                if (event.key == Qt.Key_X) {
                    PointerLocker.isLocked = false
                    event.accepted = true;
                }
            }
            onPressed: {
                if (PointerLocker.isLocked) {
                    if (pressedButtons === (Qt.LeftButton | Qt.RightButton)) {
                        PointerLocker.isLocked = false
                    }
                    var pressType = "";
                    var packet = {};
                    switch (mouse.buttons) {
                    case Qt.LeftButton:
                        pressType = "singlehold";
                        break;
                    default:
                        console.log("This click input is not handled yet!");
                        break;
                    }
                    if (pressType) {
                        packet[pressType] = true;
                        mousepad.pluginInterface.sendCommand(packet);
                    }
                } else {
                    pressedPos = Qt.point(mouse.x, mouse.y);
                }
            }

            onWheel: {
                var packet = {};
                packet["scroll"] = true;
                packet["dy"] = wheel.angleDelta.y;
                packet["dx"] = wheel.angleDelta.x;
                mousepad.pluginInterface.sendCommand(packet);
            }

            onReleased: {
                if (!PointerLocker.isLocked) {
                    lastPos = Qt.point(-1,-1);
                    releasedPos = Qt.point(mouse.x, mouse.y);
                }
                mousepad.pluginInterface.sendCommand({"singlerelease" : true});
            }
        }

        RemoteKeyboard {
            device: mousepad.device
            Layout.fillWidth: true
            visible: remoteState
            focus: !lockButton.visible
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                Layout.fillWidth: true
                icon.name: "input-mouse-click-left"
                onClicked: mousepad.pluginInterface.sendCommand({"singleclick": true});
            }
            Button {
                Layout.fillWidth: true
                icon.name: "input-mouse-click-middle"
                onClicked: mousepad.pluginInterface.sendCommand({"middleclick": true});
            }
            Button {
                Layout.fillWidth: true
                icon.name: "input-mouse-click-right"
                onClicked: mousepad.pluginInterface.sendCommand({"rightclick": true});
            }
        }
    }
}
