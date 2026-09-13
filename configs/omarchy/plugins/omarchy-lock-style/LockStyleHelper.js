// LockStyleHelper.js - Utilities, presets, quotes, and configuration management for Omarchy Lock Style

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

var POPULAR_FONTS = [
  "JetBrainsMono Nerd Font",
  "JetBrainsMono Nerd Font Propo",
  "Inter",
  "Roboto",
  "Outfit",
  "Poppins",
  "Fira Code",
  "Montserrat",
  "Hack",
  "Cantarell",
  "Adwaita Sans",
  "Adwaita Mono",
  "DejaVu Sans",
  "Ubuntu"
];

function defaultConfig() {
  return {
    version: 1,
    pinBox: {
      mode: "dots", // "dots" | "asterisks" | "dashes" | "stealth"
      radius: 18,
      width: 380,
      height: 66,
      opacity: 0.88,
      placeholder: "Enter Password",
      borderThickness: 3,
      fontSize: 22,
      showFingerprintHint: true
    },
    clock: {
      enabled: true,
      format: "24h", // "24h" | "12h"
      showAmPm: true,
      layout: "horizontal", // "horizontal" | "vertical"
      position: "above_pin", // "above_pin" | "below_pin"
      fontFamily: "JetBrainsMono Nerd Font",
      fontSize: 72,
      fontWeight: "bold", // "thin" | "light" | "normal" | "medium" | "bold" | "extrabold"
      letterSpacing: 2,
      color: "" // empty means theme foreground
    },
    date: {
      enabled: true,
      position: "below_clock", // "above_clock" | "below_clock"
      format: "dddd, MMMM d", // "dddd, MMMM d" | "ddd, d MMM yyyy" | "yyyy-MM-dd" | "d MMMM yyyy"
      fontSize: 16,
      capitalize: true
    },
    user: {
      enabled: true,
      avatarEnabled: true,
      avatarSize: 84,
      avatarCustomPath: "",
      greetingEnabled: true,
      greetingTemplate: "Welcome back, {user}",
      quoteEnabled: true,
      quoteMode: "random", // "random" | "fixed"
      quoteFixedIndex: 0,
      position: "above_pin" // "above_pin" | "below_pin"
    },
    media: {
      enabled: true,
      showAlbumArt: true,
      showProgress: true,
      compact: false,
      position: "bottom"
    },
    visuals: {
      animations: true,
      backgroundBlur: 1.0,
      contrast: -0.08,
      pulseColon: true,
      breathingFocus: true,
      glassEffect: true
    },
    menu: {
      enablePowerMenu: true,
      showIcons: true,
      showBarIcon: true,
      barIcon: "󰌾"
    },
    layout: {
      position: "center",
      margin: 40
    },
    wallpaper: {
      mode: "system", // "system" | "custom"
      customPath: "",
      history: [],
      blur: 1.0,
      dim: 0.22
    }
  };
}

var PRESETS = {
  "modern_elegance": {
    name: "Modern Elegance",
    description: "Vertical 12h clock with date on top, sleek circular avatar, and motivational quote",
    config: {
      pinBox: { mode: "dots", radius: 24, width: 380, height: 66, opacity: 0.85, placeholder: "Enter Password", borderThickness: 3, fontSize: 22, showFingerprintHint: true },
      clock: { enabled: true, format: "12h", showAmPm: true, layout: "vertical", position: "above_pin", fontFamily: "JetBrainsMono Nerd Font", fontSize: 88, fontWeight: "bold", letterSpacing: 3, color: "" },
      date: { enabled: true, position: "above_clock", format: "dddd, MMMM d", fontSize: 16, capitalize: true },
      user: { enabled: true, avatarEnabled: true, avatarSize: 80, avatarCustomPath: "", greetingEnabled: true, greetingTemplate: "Welcome back, {user}", quoteEnabled: true, quoteMode: "random", quoteFixedIndex: 0, position: "above_pin" },
      media: { enabled: true, showAlbumArt: true, showProgress: true, compact: false, position: "bottom" },
      visuals: { animations: true, backgroundBlur: 1.0, contrast: -0.08, pulseColon: true, breathingFocus: true, glassEffect: true }
    }
  },
  "cyberpunk_neon": {
    name: "Cyberpunk Terminal",
    description: "Monospace 24h clock, asterisks PIN box with sharp corners and hacker dev quotes",
    config: {
      pinBox: { mode: "asterisks", radius: 4, width: 400, height: 62, opacity: 0.92, placeholder: "USER_PIN >", borderThickness: 2, fontSize: 24, showFingerprintHint: true },
      clock: { enabled: true, format: "24h", showAmPm: false, layout: "horizontal", position: "above_pin", fontFamily: "JetBrainsMono Nerd Font", fontSize: 80, fontWeight: "extrabold", letterSpacing: 4, color: "" },
      date: { enabled: true, position: "below_clock", format: "yyyy-MM-dd", fontSize: 15, capitalize: true },
      user: { enabled: true, avatarEnabled: true, avatarSize: 76, avatarCustomPath: "", greetingEnabled: true, greetingTemplate: "SYS://AUTH: {user}", quoteEnabled: true, quoteMode: "random", quoteFixedIndex: 23, position: "above_pin" },
      media: { enabled: true, showAlbumArt: true, showProgress: true, compact: true, position: "bottom" },
      visuals: { animations: true, backgroundBlur: 0.8, contrast: -0.04, pulseColon: true, breathingFocus: true, glassEffect: true }
    }
  },
  "minimalist_clean": {
    name: "Minimalist Focus",
    description: "Ultra-clean horizontal 24h clock above pill PIN box, no distracting text",
    config: {
      pinBox: { mode: "dots", radius: 33, width: 360, height: 60, opacity: 0.8, placeholder: "Unlock", borderThickness: 2, fontSize: 20, showFingerprintHint: true },
      clock: { enabled: true, format: "24h", showAmPm: false, layout: "horizontal", position: "above_pin", fontFamily: "Inter", fontSize: 68, fontWeight: "medium", letterSpacing: 2, color: "" },
      date: { enabled: true, position: "below_clock", format: "ddd, d MMM", fontSize: 14, capitalize: true },
      user: { enabled: false, avatarEnabled: false, avatarSize: 70, avatarCustomPath: "", greetingEnabled: false, greetingTemplate: "", quoteEnabled: false, quoteMode: "random", quoteFixedIndex: 0, position: "above_pin" },
      media: { enabled: true, showAlbumArt: false, showProgress: true, compact: true, position: "bottom" },
      visuals: { animations: true, backgroundBlur: 1.0, contrast: -0.08, pulseColon: false, breathingFocus: true, glassEffect: true }
    }
  },
  "retro_hacker": {
    name: "Retro Terminal",
    description: "Dashes PIN box, vertical stacked time, and coding quotes",
    config: {
      pinBox: { mode: "dashes", radius: 8, width: 380, height: 64, opacity: 0.9, placeholder: "Password:", borderThickness: 3, fontSize: 22, showFingerprintHint: true },
      clock: { enabled: true, format: "24h", showAmPm: false, layout: "vertical", position: "above_pin", fontFamily: "JetBrainsMono Nerd Font", fontSize: 92, fontWeight: "bold", letterSpacing: 2, color: "" },
      date: { enabled: true, position: "above_clock", format: "dddd, d MMMM yyyy", fontSize: 15, capitalize: true },
      user: { enabled: true, avatarEnabled: true, avatarSize: 84, avatarCustomPath: "", greetingEnabled: true, greetingTemplate: "Operator: {user}", quoteEnabled: true, quoteMode: "random", quoteFixedIndex: 5, position: "above_pin" },
      media: { enabled: true, showAlbumArt: true, showProgress: true, compact: false, position: "bottom" },
      visuals: { animations: true, backgroundBlur: 0.9, contrast: -0.06, pulseColon: true, breathingFocus: true, glassEffect: true }
    }
  },
  "stock_omarchy": {
    name: "Stock Omarchy Default",
    description: "Default Omarchy factory lock view layout with clean centered PIN box",
    config: {
      pinBox: { mode: "dots", radius: 18, width: 381, height: 67, opacity: 0.88, placeholder: "Enter Password", borderThickness: 3, fontSize: 22, showFingerprintHint: true },
      clock: { enabled: false, format: "24h", showAmPm: true, layout: "horizontal", position: "above_pin", fontFamily: "JetBrainsMono Nerd Font", fontSize: 72, fontWeight: "bold", letterSpacing: 2, color: "" },
      date: { enabled: false, position: "below_clock", format: "dddd, MMMM d", fontSize: 16, capitalize: true },
      user: { enabled: false, avatarEnabled: false, avatarSize: 80, avatarCustomPath: "", greetingEnabled: false, greetingTemplate: "", quoteEnabled: false, quoteMode: "random", quoteFixedIndex: 0, position: "above_pin", customText: "" },
      media: { enabled: false, showAlbumArt: false, showProgress: false, compact: false, position: "bottom" },
      visuals: { animations: false, backgroundBlur: 1.0, contrast: -0.08, pulseColon: false, breathingFocus: false, glassEffect: false },
      layout: { position: "center", margin: 40 },
      wallpaper: { mode: "system", customPath: "", blur: 1.0, dim: 0.20 }
    }
  }
};

function deepMerge(target, source) {
  if (!source || typeof source !== "object") return target;
  var output = {};
  for (var key in target) {
    if (Object.prototype.hasOwnProperty.call(target, key)) {
      output[key] = target[key];
    }
  }
  for (var srcKey in source) {
    if (Object.prototype.hasOwnProperty.call(source, srcKey)) {
      if (typeof source[srcKey] === "object" && source[srcKey] !== null && !Array.isArray(source[srcKey])) {
        output[srcKey] = deepMerge(output[srcKey] || {}, source[srcKey]);
      } else {
        output[srcKey] = source[srcKey];
      }
    }
  }
  return output;
}

function getQuote(mode, fixedIndex) {
  if (mode === "fixed" && fixedIndex >= 0 && fixedIndex < DEV_QUOTES.length) {
    return DEV_QUOTES[fixedIndex];
  }
  // Random or fallback
  var idx = Math.floor(Math.random() * DEV_QUOTES.length);
  return DEV_QUOTES[idx];
}

function formatGreeting(template, username) {
  var user = username || "User";
  if (!template) return "Welcome back, " + user;
  return template.replace(/\{user\}/g, user);
}

function formatTimePreview(date, format, layout, showAmPm) {
  var d = date || new Date();
  var hours = d.getHours();
  var minutes = d.getMinutes();
  var ampm = "";

  if (format === "12h") {
    ampm = hours >= 12 ? "PM" : "AM";
    hours = hours % 12;
    hours = hours ? hours : 12; // 0 becomes 12
  }

  var hStr = (hours < 10 ? "0" : "") + hours;
  var mStr = (minutes < 10 ? "0" : "") + minutes;

  if (layout === "vertical") {
    return {
      hours: hStr,
      minutes: mStr,
      ampm: showAmPm && format === "12h" ? ampm : "",
      full: hStr + "\n" + mStr
    };
  }

  var res = hStr + ":" + mStr;
  if (showAmPm && format === "12h") {
    res += " " + ampm;
  }
  return {
    hours: hStr,
    minutes: mStr,
    ampm: showAmPm && format === "12h" ? ampm : "",
    full: res
  };
}

function formatDatePreview(date, formatPattern) {
  var d = date || new Date();
  var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  var daysShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  var monthsShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  var dayName = days[d.getDay()];
  var dayNameShort = daysShort[d.getDay()];
  var monthName = months[d.getMonth()];
  var monthNameShort = monthsShort[d.getMonth()];
  var dayNum = d.getDate();
  var yearNum = d.getFullYear();

  if (formatPattern === "ddd, d MMM yyyy") {
    return dayNameShort + ", " + dayNum + " " + monthNameShort + " " + yearNum;
  } else if (formatPattern === "ddd, d MMM") {
    return dayNameShort + ", " + dayNum + " " + monthNameShort;
  } else if (formatPattern === "yyyy-MM-dd") {
    var mStr = (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1);
    var dStr = (dayNum < 10 ? "0" : "") + dayNum;
    return yearNum + "-" + mStr + "-" + dStr;
  } else if (formatPattern === "d MMMM yyyy") {
    return dayNum + " " + monthName + " " + yearNum;
  }

  // Default "dddd, MMMM d"
  return dayName + ", " + monthName + " " + dayNum;
}

function maskPasswordText(text, mode) {
  var len = text ? text.length : 0;
  if (len === 0) return "";
  if (mode === "asterisks") return "*".repeat(len);
  if (mode === "dashes") return "—".repeat(len);
  if (mode === "stealth") return "";
  // default "dots"
  return "●".repeat(len);
}
