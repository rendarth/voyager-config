// LockViewGenerator.js - Generates the customized LockView.qml for Omarchy Shell

.pragma library

var DEV_QUOTES = [
  "May your code compile on the first try 🚀",
  "It's not a bug, it's an undocumented feature 🐛",
  "There is no place like 127.0.0.1 🏠",
  "Remember to hydrate, stretch, and git commit ☕",
  "Talk is cheap. Show me the code 💻",
  "while (alive) { code(); drink(coffee); } ⚡",
  "Ship it! What could possibly go wrong? 🚢",
  "In code we trust, bugs we bust 🛡️",
  "Keep calm and git push --force-with-lease 🔥",
  "404: Sloth not found. Ready to build something awesome! ⚡",
  "Clean code is the best gift to your future self ✨",
  "sudo make it happen 🪄",
  "Coffee: turning caffeine into clean code ☕",
  "A commit a day keeps the merge conflicts away 🌿",
  "May the force of zero compiler warnings be with you ⚔️",
  "First, solve the problem. Then, write the code 🎯",
  "The secret to great code is deleting bad code ✂️",
  "Eat. Sleep. Code. Repeat. 🔁",
  "Debugging: Being the detective in a movie where you are also the murderer 🕵️",
  "There are 10 types of people: those who understand binary, and those who don't 🤖",
  "Simplicity is the soul of efficiency 🌌",
  "Don't comment bad code — rewrite it into poetry 📜",
  "Deleted code is debugged code 🗑️",
  "Hack the planet! Stay curious 󰈸",
  "One more commit before bed... said every dev at 3 AM 🌙",
  "Real developers test in production... just kidding 😉",
  "Ctrl + Z is the greatest invention in human history ⏪",
  "Never underestimate a developer with coffee and a deadline ☕",
  "Write clean code, because the next person maintaining it might be a psychopath 📖",
  "Everything is a file, and every day is a new commit 🐧"
];

function generateLockViewQml(cfg) {
  var c = cfg || {};
  var pin = c.pinBox || {};
  var clock = c.clock || {};
  var date = c.date || {};
  var user = c.user || {};
  var media = c.media || {};
  var visuals = c.visuals || {};

  var pinRadius = Number(pin.radius !== undefined ? pin.radius : 18) || 18;
  var pinWidth = Number(pin.width || 380) || 380;
  var pinHeight = Number(pin.height || 66) || 66;
  var pinOpacity = Number(pin.opacity !== undefined ? pin.opacity : 0.88) || 0.88;
  var pinPlaceholder = String(pin.placeholder || "Enter Password");
  var pinBorderThickness = Number(pin.borderThickness || 3) || 3;
  var pinFontSize = Number(pin.fontSize || 22) || 22;
  var pinEchoMode = String(pin.mode || "dots"); // "dots" | "asterisks" | "dashes" | "stealth"

  var clockEnabled = clock.enabled !== false;
  var clockFormat = String(clock.format || "24h");
  var clockShowAmPm = clock.showAmPm !== false;
  var clockLayout = String(clock.layout || "horizontal");
  var clockPos = String(clock.position || "above_pin");
  var clockFont = String(clock.fontFamily || "JetBrainsMono Nerd Font");
  var clockSize = Number(clock.fontSize || 72) || 72;
  var clockWeight = String(clock.fontWeight || "bold");
  var clockSpacing = Number(clock.letterSpacing !== undefined ? clock.letterSpacing : 2);

  var dateEnabled = date.enabled !== false;
  var datePos = String(date.position || "below_clock");
  var dateFormat = String(date.format || "dddd, MMMM d");
  var dateSize = Number(date.fontSize || 16) || 16;
  var dateCapitalize = date.capitalize !== false;

  var avatarEnabled = user.avatarEnabled !== false;
  var avatarSize = Number(user.avatarSize || 84) || 84;
  var avatarCustomPath = String(user.avatarCustomPath || "");
  var greetingEnabled = user.greetingEnabled !== false;
  var greetingTemplate = String(user.greetingTemplate || "Welcome back, {user}");
  var quoteEnabled = user.quoteEnabled === true;
  var customText = String(user.customText !== undefined ? user.customText : "");
  var userPos = String(user.position || "above_pin");
  var hasUserElements = avatarEnabled || greetingEnabled || quoteEnabled || (customText && customText.trim().length > 0);

  var mediaEnabled = media.enabled !== false;
  var mediaShowArt = media.showAlbumArt !== false;
  var mediaShowProg = media.showProgress !== false;
  var mediaCompact = media.compact === true;

  var animations = visuals.animations !== false;
  var contrastVal = Number(visuals.contrast !== undefined ? visuals.contrast : -0.08);
  var pulseColon = visuals.pulseColon !== false && animations;
  var breathingFocus = visuals.breathingFocus !== false && animations;

  var wp = c.wallpaper || {};
  var wpMode = String(wp.mode || "system"); // "system" | "custom"
  var wpCustomPath = String(wp.customPath || "");
  var wpBlur = Number(wp.blur !== undefined ? wp.blur : (visuals.backgroundBlur !== undefined ? visuals.backgroundBlur : 1.0));
  var wpDim = Number(wp.dim !== undefined ? wp.dim : 0.20);

  var blurVal = wpBlur;

  var layout = c.layout || {};
  var screenPos = String(layout.position || "center");
  var screenMargin = Number(layout.margin !== undefined ? layout.margin : 40) || 40;
  var isLeft = (screenPos === "top_left" || screenPos === "center_left" || screenPos === "bottom_left");
  var isRight = (screenPos === "top_right" || screenPos === "center_right" || screenPos === "bottom_right");
  var horizAlign = isLeft ? "left" : (isRight ? "right" : "center");

  var colAnchors = "";
  if (screenPos === "top_left") {
    colAnchors = "anchors.top: parent.top\n      anchors.topMargin: Style.space(" + screenMargin + ")\n      anchors.left: parent.left\n      anchors.leftMargin: Style.space(" + screenMargin + ")";
  } else if (screenPos === "center_left") {
    colAnchors = "anchors.verticalCenter: parent.verticalCenter\n      anchors.left: parent.left\n      anchors.leftMargin: Style.space(" + screenMargin + ")";
  } else if (screenPos === "bottom_left") {
    colAnchors = "anchors.bottom: parent.bottom\n      anchors.bottomMargin: Style.space(" + screenMargin + ")\n      anchors.left: parent.left\n      anchors.leftMargin: Style.space(" + screenMargin + ")";
  } else if (screenPos === "top_right") {
    colAnchors = "anchors.top: parent.top\n      anchors.topMargin: Style.space(" + screenMargin + ")\n      anchors.right: parent.right\n      anchors.rightMargin: Style.space(" + screenMargin + ")";
  } else if (screenPos === "center_right") {
    colAnchors = "anchors.verticalCenter: parent.verticalCenter\n      anchors.right: parent.right\n      anchors.rightMargin: Style.space(" + screenMargin + ")";
  } else if (screenPos === "bottom_right") {
    colAnchors = "anchors.bottom: parent.bottom\n      anchors.bottomMargin: Style.space(" + screenMargin + ")\n      anchors.right: parent.right\n      anchors.rightMargin: Style.space(" + screenMargin + ")";
  } else {
    colAnchors = "anchors.centerIn: parent";
  }

  var pinHorizAnchor = isLeft ? "anchors.left: parent.left" : (isRight ? "anchors.right: parent.right" : "anchors.horizontalCenter: parent.horizontalCenter");

  // Mask character selection - Strict security: only masked modes allowed
  var maskChar = "●"; // default dot
  var textEchoMode = "TextInput.Password";
  if (pinEchoMode === "asterisks") {
    textEchoMode = "TextInput.Password";
    maskChar = "*";
  } else if (pinEchoMode === "dashes") {
    textEchoMode = "TextInput.Password";
    maskChar = "—";
  } else if (pinEchoMode === "stealth") {
    textEchoMode = "TextInput.NoEcho";
    maskChar = "";
  } else {
    textEchoMode = "TextInput.Password";
    maskChar = "●";
  }

  // Build JSON-safe quote list
  var quotesJson = JSON.stringify(DEV_QUOTES);

  return `// Generated by Omarchy Lock Style
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string customWallpaperPath: ${JSON.stringify(wpCustomPath)}
  readonly property bool useCustomWallpaper: ${wpMode === "custom" && wpCustomPath.length > 0}
  readonly property string placeholderText: ${JSON.stringify(pinPlaceholder)}
  readonly property int fieldWidth: ${pinWidth}
  readonly property int fieldHeight: ${pinHeight}
  readonly property int outlineThickness: ${pinBorderThickness}
  readonly property int cornerRadius: ${pinRadius}
  readonly property int fieldFontSize: ${pinFontSize}
  readonly property int passwordDotFontSize: Math.round(fieldFontSize * 1.25)
  readonly property int passwordDotLetterSpacing: Math.round(fieldFontSize * 0.18)

  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 14) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1

  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  // Current system user info
  readonly property string currentUsername: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
  readonly property string userHomeDir: Quickshell.env("HOME") || ("/home/" + currentUsername)

  // Current time & date updates
  property var currentDate: new Date()
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.currentDate = new Date()
  }

  // Developer / Motivational Quote
  readonly property var quotesList: ${quotesJson}
  property string activeQuote: ""
  function refreshQuote() {
    var idx = Math.floor(Math.random() * root.quotesList.length);
    activeQuote = root.quotesList[idx] || "";
  }

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Component.onCompleted: {
    syncPasswordText()
    refreshQuote()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // Measures masked password advance width
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: ${JSON.stringify(maskChar)}.repeat(passwordInput.text.length)
  }

  // ==========================================
  // BACKGROUND & EFFECTS
  // ==========================================
  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? (root.useCustomWallpaper && root.customWallpaperPath ? ("file://" + root.customWallpaperPath) : root.fileUrl(root.backgroundPath)) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready && ${blurVal > 0.01}
      blur: ${blurVal.toFixed(2)}
      blurMax: 128
      blurMultiplier: 1.25
      contrast: ${contrastVal.toFixed(2)}
    }

    // Subtle dark vignette/overlay
    Rectangle {
      anchors.fill: parent
      color: "#000000"
      opacity: ${wpDim.toFixed(2)}
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // ==========================================
    // CENTER CONTENT STACK
    // ==========================================
    Column {
      id: centerColumn
      ${colAnchors}
      spacing: Style.space(16)
      width: Math.max(root.fieldWidth, 480)

      ${renderAboveSection(clockPos, userPos, clockEnabled, dateEnabled, hasUserElements, clockLayout, clockFormat, clockShowAmPm, clockFont, clockSize, clockWeight, clockSpacing, datePos, dateFormat, dateSize, dateCapitalize, avatarEnabled, avatarSize, avatarCustomPath, greetingEnabled, greetingTemplate, quoteEnabled, customText, animations, pulseColon, horizAlign)}

      // ========================================
      // PIN / PASSWORD INPUT FIELD
      // ========================================
      BorderSurface {
        id: inputField
        width: root.fieldWidth
        height: root.fieldHeight
        ${pinHorizAnchor}
        color: Qt.rgba(Color.lock.background.r, Color.lock.background.g, Color.lock.background.b, ${pinOpacity.toFixed(2)})
        borderSpec: root.inputBorderSpec
        radius: root.cornerRadius
        clip: true

        ${breathingFocus ? `
        // Breathing focus glow
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        scale: passwordInput.activeFocus ? 1.015 : 1.0
        ` : ""}

        TextInput {
          id: passwordInput
          anchors.fill: parent
          anchors.topMargin: inputField.borderTop
          anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
          anchors.bottomMargin: inputField.borderBottom
          anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
          verticalAlignment: TextInput.AlignVCenter
          horizontalAlignment: TextInput.AlignHCenter
          activeFocusOnPress: true
          clip: true
          enabled: root.inputEnabled && !root.authenticatingPassword
          readOnly: root.authenticatingPassword
          echoMode: ${textEchoMode}
          ${maskChar ? `passwordCharacter: ${JSON.stringify(maskChar)}` : ""}
          passwordMaskDelay: 0
          color: Color.lock.text
          selectionColor: Color.lock.selection
          selectedTextColor: Color.lock.text
          font.family: ${pinEchoMode === "dots" ? "Style.font.family" : JSON.stringify(clockFont)}
          font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
          font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
          cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
          cursorDelegate: Rectangle {
            width: 2
            color: Color.lock.text
            visible: passwordInput.cursorVisible
          }

          onTextChanged: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            if (text.length > 0) {
              root.wakeRequested()
            }
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }

          onAccepted: {
            var submitted = root.passwordText
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }

          Keys.onPressed: function(event) {
            root.wakeRequested()
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }

        Text {
          anchors.fill: passwordInput
          text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
          visible: passwordInput.text.length === 0
          color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
          font.family: Style.font.family
          font.pixelSize: root.fieldFontSize
          font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        // Fingerprint indicator
        Text {
          id: fingerprintIcon
          objectName: "fingerprintIndicator"
          anchors.right: parent.right
          anchors.rightMargin: inputField.borderRight + 18
          anchors.verticalCenter: parent.verticalCenter
          visible: root.fingerprintConfigured
          text: "󰈷"
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Math.round(root.fieldFontSize * 1.1)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }

      ${renderBelowSection(clockPos, userPos, clockEnabled, dateEnabled, hasUserElements, clockLayout, clockFormat, clockShowAmPm, clockFont, clockSize, clockWeight, clockSpacing, datePos, dateFormat, dateSize, dateCapitalize, avatarEnabled, avatarSize, avatarCustomPath, greetingEnabled, greetingTemplate, quoteEnabled, customText, animations, pulseColon, horizAlign)}

    }

    ${mediaEnabled ? renderMediaSection(mediaShowArt, mediaShowProg, mediaCompact, animations, screenPos, screenMargin) : ""}

  }
}
`;
}

function renderClockBlock(layout, format, showAmPm, font, size, weight, spacing, animations, pulseColon, horizAlign) {
  var isVertical = (layout === "vertical");
  var isLeft = (horizAlign === "left");
  var isRight = (horizAlign === "right");
  var anchorHoriz = isLeft ? "anchors.left: parent.left" : (isRight ? "anchors.right: parent.right" : "anchors.horizontalCenter: parent.horizontalCenter");
  var textAlign = isLeft ? "Text.AlignLeft" : (isRight ? "Text.AlignRight" : "Text.AlignHCenter");

  var fontWeightProp = "Font.Bold";
  if (weight === "thin") fontWeightProp = "Font.Thin";
  else if (weight === "light") fontWeightProp = "Font.Light";
  else if (weight === "medium") fontWeightProp = "Font.Medium";
  else if (weight === "extrabold") fontWeightProp = "Font.ExtraBold";
  else if (weight === "normal") fontWeightProp = "Font.Normal";

  var fontStr = JSON.stringify(String(font || "JetBrainsMono Nerd Font"));
  var formatStr = JSON.stringify(String(format || "24h"));

  return `
      // Clock Block
      Item {
        width: parent.width
        height: clockContent.implicitHeight
        implicitHeight: clockContent.implicitHeight
        ${anchorHoriz}

        ${isVertical ? `
        Column {
          id: clockContent
          width: parent.width
          ${anchorHoriz}
          spacing: -Style.space(8)

          Text {
            width: parent.width
            ${anchorHoriz}
            text: {
              var h = root.currentDate.getHours();
              if (${formatStr} === "12h") { h = h % 12; h = h ? h : 12; }
              return (h < 10 ? "0" : "") + h;
            }
            font.family: ${fontStr}
            font.pixelSize: ${size}
            font.weight: ${fontWeightProp}
            font.letterSpacing: ${spacing}
            color: Color.foreground
            horizontalAlignment: ${textAlign}
          }

          Text {
            width: parent.width
            ${anchorHoriz}
            text: {
              var m = root.currentDate.getMinutes();
              return (m < 10 ? "0" : "") + m;
            }
            font.family: ${fontStr}
            font.pixelSize: ${size}
            font.weight: ${fontWeightProp}
            font.letterSpacing: ${spacing}
            color: Color.foreground
            opacity: 0.85
            horizontalAlignment: ${textAlign}
          }

          ${(format === "12h" && showAmPm) ? `
          Text {
            width: parent.width
            ${anchorHoriz}
            text: root.currentDate.getHours() >= 12 ? "PM" : "AM"
            font.family: ${fontStr}
            font.pixelSize: Math.round(${size} * 0.26)
            font.bold: true
            color: Color.accent
            opacity: 0.9
            horizontalAlignment: ${textAlign}
          }
          ` : ""}
        }
        ` : `
        Row {
          id: clockContent
          ${anchorHoriz}
          spacing: Style.space(4)

          Text {
            text: {
              var h = root.currentDate.getHours();
              if (${formatStr} === "12h") { h = h % 12; h = h ? h : 12; }
              return (h < 10 ? "0" : "") + h;
            }
            font.family: ${fontStr}
            font.pixelSize: ${size}
            font.weight: ${fontWeightProp}
            font.letterSpacing: ${spacing}
            color: Color.foreground
            verticalAlignment: Text.AlignVCenter
          }

          Text {
            text: ":"
            font.family: ${fontStr}
            font.pixelSize: ${size}
            font.weight: ${fontWeightProp}
            color: Color.foreground
            verticalAlignment: Text.AlignVCenter
            ${pulseColon ? `
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: true
              NumberAnimation { from: 1.0; to: 0.25; duration: 900; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.25; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
            ` : ""}
          }

          Text {
            text: {
              var m = root.currentDate.getMinutes();
              return (m < 10 ? "0" : "") + m;
            }
            font.family: ${fontStr}
            font.pixelSize: ${size}
            font.weight: ${fontWeightProp}
            font.letterSpacing: ${spacing}
            color: Color.foreground
            verticalAlignment: Text.AlignVCenter
          }

          ${(format === "12h" && showAmPm) ? `
          Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(${size} * 0.16)
            text: root.currentDate.getHours() >= 12 ? "PM" : "AM"
            font.family: ${fontStr}
            font.pixelSize: Math.round(${size} * 0.28)
            font.bold: true
            color: Color.accent
            opacity: 0.9
          }
          ` : ""}
        }
        `}
      }
  `;
}

function renderDateBlock(format, size, capitalize, font, horizAlign) {
  var isLeft = (horizAlign === "left");
  var isRight = (horizAlign === "right");
  var anchorHoriz = isLeft ? "anchors.left: parent.left" : (isRight ? "anchors.right: parent.right" : "anchors.horizontalCenter: parent.horizontalCenter");
  var textAlign = isLeft ? "Text.AlignLeft" : (isRight ? "Text.AlignRight" : "Text.AlignHCenter");

  var fontStr = JSON.stringify(String(font || "JetBrainsMono Nerd Font"));
  var formatStr = JSON.stringify(String(format || "dddd, MMMM d"));

  return `
      // Date Block
      Text {
        width: parent.width
        ${anchorHoriz}
        text: {
          var d = root.currentDate;
          var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
          var daysShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
          var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
          var monthsShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
          var res = "";
          if (${formatStr} === "ddd, d MMM yyyy") {
            res = daysShort[d.getDay()] + ", " + d.getDate() + " " + monthsShort[d.getMonth()] + " " + d.getFullYear();
          } else if (${formatStr} === "yyyy-MM-dd") {
            var mS = (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1);
            var dS = (d.getDate() < 10 ? "0" : "") + d.getDate();
            res = d.getFullYear() + "-" + mS + "-" + dS;
          } else if (${formatStr} === "ddd, d MMM") {
            res = daysShort[d.getDay()] + ", " + d.getDate() + " " + monthsShort[d.getMonth()];
          } else {
            res = days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate();
          }
          return ${capitalize} ? res : res.toLowerCase();
        }
        font.family: ${fontStr}
        font.pixelSize: ${size}
        font.weight: Font.Medium
        color: Color.foreground
        opacity: 0.85
        horizontalAlignment: ${textAlign}
      }
  `;
}

function renderUserBlock(avatarEnabled, avatarSize, avatarCustomPath, greetingEnabled, greetingTemplate, quoteEnabled, customText, animations, horizAlign) {
  var isLeft = (horizAlign === "left");
  var isRight = (horizAlign === "right");
  var anchorHoriz = isLeft ? "anchors.left: parent.left" : (isRight ? "anchors.right: parent.right" : "anchors.horizontalCenter: parent.horizontalCenter");
  var textAlign = isLeft ? "Text.AlignLeft" : (isRight ? "Text.AlignRight" : "Text.AlignHCenter");

  var showText = quoteEnabled || (customText && customText.trim().length > 0);
  var avatarPathStr = JSON.stringify(String(avatarCustomPath || ""));
  var greetingStr = JSON.stringify(String(greetingTemplate || "Welcome back, {user}"));
  var quoteTextContent = quoteEnabled ? "root.activeQuote" : JSON.stringify(String(customText || ""));

  return `
      // User Profile & Quotes Block
      Column {
        ${anchorHoriz}
        spacing: Style.space(10)
        width: parent.width

        ${avatarEnabled ? `
        // Avatar Frame
        Item {
          width: ${avatarSize}
          height: ${avatarSize}
          ${anchorHoriz}

          Rectangle {
            id: avatarBorder
            anchors.fill: parent
            radius: width / 2
            color: Color.background
            border.color: Color.accent
            border.width: 2.5
            clip: true

            Image {
              id: userAvatarImg
              anchors.fill: parent
              anchors.margins: 2
              source: (${avatarPathStr}) ? ("file://" + ${avatarPathStr}) : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              visible: status === Image.Ready && source !== ""
            }

            // Fallback glyph icon
            Text {
              anchors.centerIn: parent
              visible: !userAvatarImg.visible || userAvatarImg.status !== Image.Ready
              text: "󰮯"
              font.family: Style.font.family
              font.pixelSize: Math.round(${avatarSize} * 0.55)
              color: Color.accent
            }
          }
        }
        ` : ""}

        ${greetingEnabled ? `
        // Greeting Text
        Text {
          ${anchorHoriz}
          text: (${greetingStr}).replace(/\\{user\\}/g, root.currentUsername)
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
          color: Color.foreground
          horizontalAlignment: ${textAlign}
        }
        ` : ""}

        ${showText ? `
        // Motivational / Custom Quote
        Text {
          ${anchorHoriz}
          text: ${quoteTextContent}
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.italic: true
          color: Color.foreground
          opacity: 0.75
          wrapMode: Text.WordWrap
          width: Math.min(parent.width, 460)
          horizontalAlignment: ${textAlign}
        }
        ` : ""}
      }
  `;
}

function renderAboveSection(clockPos, userPos, clockEnabled, dateEnabled, hasUserElements, clockLayout, clockFormat, clockShowAmPm, clockFont, clockSize, clockWeight, clockSpacing, datePos, dateFormat, dateSize, dateCapitalize, avatarEnabled, avatarSize, avatarCustomPath, greetingEnabled, greetingTemplate, quoteEnabled, customText, animations, pulseColon, horizAlign) {
  var isLeft = (horizAlign === "left");
  var isRight = (horizAlign === "right");
  var anchorHoriz = isLeft ? "anchors.left: parent.left" : (isRight ? "anchors.right: parent.right" : "anchors.horizontalCenter: parent.horizontalCenter");
  var code = "";

  // 1. Date or Clock above PIN
  if (clockPos === "above_pin" || (!clockEnabled && clockPos !== "below_pin")) {
    var hasClockOrDate = (clockEnabled && clockPos === "above_pin") || dateEnabled;
    if (hasClockOrDate) {
      code += `
      // Clock & Date Container (Above PIN)
      Column {
        ${anchorHoriz}
        spacing: Style.space(6)
        width: parent.width

        ${(dateEnabled && (datePos === "above_clock" || !clockEnabled)) ? renderDateBlock(dateFormat, dateSize, dateCapitalize, clockFont, horizAlign) : ""}
        ${(clockEnabled && clockPos === "above_pin") ? renderClockBlock(clockLayout, clockFormat, clockShowAmPm, clockFont, clockSize, clockWeight, clockSpacing, animations, pulseColon, horizAlign) : ""}
        ${(dateEnabled && clockEnabled && datePos === "below_clock") ? renderDateBlock(dateFormat, dateSize, dateCapitalize, clockFont, horizAlign) : ""}
      }
      `;
    }
  }

  // 2. User profile block above PIN
  if (userPos === "above_pin" && hasUserElements) {
    code += renderUserBlock(avatarEnabled, avatarSize, avatarCustomPath, greetingEnabled, greetingTemplate, quoteEnabled, customText, animations, horizAlign);
  }

  return code;
}

function renderBelowSection(clockPos, userPos, clockEnabled, dateEnabled, hasUserElements, clockLayout, clockFormat, clockShowAmPm, clockFont, clockSize, clockWeight, clockSpacing, datePos, dateFormat, dateSize, dateCapitalize, avatarEnabled, avatarSize, avatarCustomPath, greetingEnabled, greetingTemplate, quoteEnabled, customText, animations, pulseColon, horizAlign) {
  var isLeft = (horizAlign === "left");
  var isRight = (horizAlign === "right");
  var anchorHoriz = isLeft ? "anchors.left: parent.left" : (isRight ? "anchors.right: parent.right" : "anchors.horizontalCenter: parent.horizontalCenter");
  var code = "";

  // 1. User block below PIN
  if (userPos === "below_pin" && hasUserElements) {
    code += renderUserBlock(avatarEnabled, avatarSize, avatarCustomPath, greetingEnabled, greetingTemplate, quoteEnabled, customText, animations, horizAlign);
  }

  // 2. Clock or Date below PIN
  if (clockPos === "below_pin") {
    var hasClockOrDate = clockEnabled || dateEnabled;
    if (hasClockOrDate) {
      code += `
      // Clock & Date Container (Below PIN)
      Column {
        ${anchorHoriz}
        spacing: Style.space(6)
        width: parent.width

        ${(dateEnabled && (datePos === "above_clock" || !clockEnabled)) ? renderDateBlock(dateFormat, dateSize, dateCapitalize, clockFont, horizAlign) : ""}
        ${clockEnabled ? renderClockBlock(clockLayout, clockFormat, clockShowAmPm, clockFont, clockSize, clockWeight, clockSpacing, animations, pulseColon, horizAlign) : ""}
        ${(dateEnabled && clockEnabled && datePos === "below_clock") ? renderDateBlock(dateFormat, dateSize, dateCapitalize, clockFont, horizAlign) : ""}
      }
      `;
    }
  }

  return code;
}

function renderMediaSection(showArt, showProg, compact, animations, screenPos, screenMargin) {
  var mediaMargin = screenMargin || 40;
  var mediaAnchors = "";
  if (screenPos === "center") {
    mediaAnchors = `
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(${mediaMargin})
      anchors.horizontalCenter: parent.horizontalCenter
    `;
  } else if (screenPos === "top_left" || screenPos === "center_left") {
    mediaAnchors = `
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(${mediaMargin})
      anchors.left: parent.left
      anchors.leftMargin: Style.space(${mediaMargin})
    `;
  } else if (screenPos === "bottom_left") {
    mediaAnchors = `
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(${mediaMargin})
      anchors.right: parent.right
      anchors.rightMargin: Style.space(${mediaMargin})
    `;
  } else if (screenPos === "top_right" || screenPos === "center_right") {
    mediaAnchors = `
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(${mediaMargin})
      anchors.right: parent.right
      anchors.rightMargin: Style.space(${mediaMargin})
    `;
  } else if (screenPos === "bottom_right") {
    mediaAnchors = `
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(${mediaMargin})
      anchors.left: parent.left
      anchors.leftMargin: Style.space(${mediaMargin})
    `;
  } else {
    mediaAnchors = `
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(${mediaMargin})
      anchors.horizontalCenter: parent.horizontalCenter
    `;
  }

  return `
    // ==========================================
    // BOTTOM MEDIA WIDGET (MPRIS)
    // ==========================================
    Item {
      id: mediaWidget
      ${mediaAnchors}
      width: mediaCard.width
      height: mediaCard.height

      readonly property var players: Mpris.players ? Mpris.players.values : []
      readonly property var activePlayer: {
        for (var i = 0; i < players.length; i++) {
          if (players[i] && (players[i].isPlaying || (players[i].trackTitle && players[i].trackTitle.length > 0))) {
            return players[i];
          }
        }
        return null;
      }
      readonly property bool hasTrack: activePlayer !== null && !root.authenticatingPassword && !!(activePlayer.trackTitle || activePlayer.trackArtist)
      readonly property string trackLabel: {
        if (!activePlayer) return "";
        var title = activePlayer.trackTitle || "Unknown Track";
        var artist = activePlayer.trackArtist || "";
        return artist ? (title + " — " + artist) : title;
      }

      visible: hasTrack

      BorderSurface {
        id: mediaCard
        width: Math.min(mediaRow.implicitWidth + Style.space(28), Style.space(460))
        height: Style.space(36)
        radius: Style.cornerRadius
        color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.82)
        borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)
        clip: true

        Row {
          id: mediaRow
          anchors.centerIn: parent
          spacing: Style.space(8)

          Text {
            text: "󰎈"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: mediaWidget.trackLabel
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: Math.min(implicitWidth, Style.space(380))
          }
        }
      }
    }
  `;
}
