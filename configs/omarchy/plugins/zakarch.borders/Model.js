.pragma library

var palettes = [
  { name: "Eventide", active: ["#5a7a7a", "#5a7a72", "#4a6a4a"], inactive: "#252b2b" },
  { name: "Aetherfire", active: ["#22C55E", "#FACC15", "#A855F7"], inactive: "#14221A" },
  { name: "Ember", active: ["#FB7185", "#F97316", "#FACC15"], inactive: "#4A2630" },
  { name: "Copper", active: ["#FED7AA", "#FB923C", "#B45309"], inactive: "#513829" },
  { name: "Solar", active: ["#FDE047", "#FB923C", "#F43F5E"], inactive: "#55412A" },
  { name: "Citrus", active: ["#FDE047", "#BEF264", "#4ADE80"], inactive: "#4A4A2A" },
  { name: "Forest", active: ["#A3E635", "#22C55E", "#14B8A6"], inactive: "#294635" },
  { name: "Matcha", active: ["#D9F99D", "#86EFAC", "#5EEAD4"], inactive: "#355047" },
  { name: "Neon", active: ["#00FF9C", "#00D9FF", "#B026FF"], inactive: "#24344C" },
  { name: "Ocean", active: ["#38BDF8", "#2563EB", "#4F46E5"], inactive: "#263B5C" },
  { name: "Glacier", active: ["#E0F2FE", "#67E8F9", "#818CF8"], inactive: "#2C4755" },
  { name: "Twilight", active: ["#818CF8", "#A78BFA", "#E879F9"], inactive: "#35345D" },
  { name: "Aurora", active: ["#8B5CF6", "#22D3EE", "#34D399"], inactive: "#334155" },
  { name: "Plasma", active: ["#F0ABFC", "#A78BFA", "#60A5FA"], inactive: "#3E315B" },
  { name: "Rose", active: ["#F9A8D4", "#E879F9", "#C084FC"], inactive: "#502D51" },
  { name: "Sakura", active: ["#FDA4AF", "#F9A8D4", "#F0ABFC"], inactive: "#542E43" },
  { name: "Mono", active: ["#FFFFFF", "#94A3B8", "#475569"], inactive: "#273244" }
]

var rounds = [0, 4, 8, 12, 16, 20, 24]
var borderSizes = [0, 1, 2, 3, 4, 5, 6]
var windowGaps = [0, 2, 4, 8, 16, 24, 32]
var cycleSpeeds = [
  { name: "Off", seconds: 0 },
  { name: "1 sec", seconds: 1 },
  { name: "2 sec", seconds: 2 },
  { name: "3 sec", seconds: 3 },
  { name: "30 sec", seconds: 30 },
  { name: "2 min", seconds: 120 },
  { name: "5 min", seconds: 300 }
]
