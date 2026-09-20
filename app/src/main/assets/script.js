const MANIFEST_URL = "https://github.com/karrar1991awad-del/eegnosis-apk/releases/download/v1.0/manifest.json";
const APP_NAME = "EEGnosis";
const SECTION_COLORS = {
  "Normal and Benign Variants": "#5faed9",
  "Artifacts": "#a694e0",
  "Newborn": "#e69bb8",
  "Focal Nonepileptiform Activity": "#4cb8ae",
  "Generalized Nonepileptiform Activity": "#7385e6",
  "ICU": "#e6c759",
  "Epileptic Encephalopathy": "#e68073",
  "Generalized Epilepsy": "#8ccd8c",
  "Focal Epilepsy": "#cdab80",
  "ALL": "#94a3b8"
};

let manifest = null;
let currentImages = [];
let currentIndex = 0;
let statusMap = {};

function playSplash() {
  const t = document.getElementById("splashTitle");
  APP_NAME.split("").forEach((ch, i) => {
    const s = document.createElement("span");
    s.textContent = ch;
    s.style.animationDelay = (0.5 + i * 0.09) + "s";
    t.appendChild(s);
  });
  setTimeout(() => {
    document.getElementById("splash").classList.add("hidden");
    setTimeout(() => {
      document.getElementById("splash").style.display = "none";
      loadManifest();
    }, 500);
  }, 2800);
}

function loadProgress() {
  try {
    const d = localStorage.getItem("eegnosis_progress");
    if (d) statusMap = JSON.parse(d).status || {};
  } catch(e) {}
}

function saveProgress() {
  try {
    localStorage.setItem("eegnosis_progress", JSON.stringify({status: statusMap}));
  } catch(e) {}
}

async function loadManifest() {
  document.getElementById("loadingScreen").style.display = "block";
  document.getElementById("sectionsScreen").classList.remove("active");
  try {
    const r = await fetch(MANIFEST_URL);
    manifest = await r.json();
    loadProgress();
    showSections();
  } catch(e) {
    document.getElementById("loadingScreen").innerHTML =
      '<div class="error-msg">فشل الاتصال<br>تحقق من الإنترنت<br><button onclick="loadManifest()">إعادة</button></div>';
  }
}

function showSections() {
  document.getElementById("loadingScreen").style.display = "none";
  document.getElementById("sectionsScreen").classList.add("active");
  document.getElementById("viewerScreen").classList.remove("active");
  const list = document.getElementById("sectionsList");
  list.innerHTML = "";
  const dl = JSON.parse(Android.getDownloadedSections());
  document.getElementById("sectionsInfo").textContent =
    manifest.total_figures + " صورة · " + manifest.sections.length + " أقسام";
  manifest.sections.forEach(sec => {
    const done = dl.includes(sec.id);
    const color = SECTION_COLORS[sec.full_name] || "#94a3b8";
    const card = document.createElement("div");
    card.className = "section-card" + (done ? " done" : "");
    card.id = "card_" + sec.id;
    const btn = done
      ? '<button class="btn done" onclick="openSection(\'' + sec.id + '\')">فتح</button>'
      : '<button class="btn" onclick="downloadSection(\'' + sec.id + '\')">تحميل</button>';
    card.innerHTML =
      '<div class="section-info">' +
      '<div class="section-title"><span class="section-dot" style="background:' + color + '"></span>' + sec.name + '</div>' +
      '<div class="section-meta">' + sec.count + ' صورة · ' + sec.size_mb + ' MB</div>' +
      '<div class="progress-bar" id="bar_' + sec.id + '"><div class="progress-fill" id="fill_' + sec.id + '"></div></div>' +
      '<div class="progress-text" id="text_' + sec.id + '"></div>' +
      '</div>' +
      '<div class="section-action" id="action_' + sec.id + '">' + btn + '</div>';
    list.appendChild(card);
  });
}

function downloadSection(id) {
  const sec = manifest.sections.find(s => s.id === id);
  if (!sec) return;
  document.getElementById("bar_" + id).classList.add("show");
  document.getElementById("text_" + id).textContent = "جاري التحميل...";
  document.getElementById("action_" + id).innerHTML = "";
  Android.downloadSection(id, sec.zip_url);
}

function updateProgress(id, pct, st) {
  const bar = document.getElementById("bar_" + id);
  const fill = document.getElementById("fill_" + id);
  const text = document.getElementById("text_" + id);
  const action = document.getElementById("action_" + id);
  if (!bar) return;
  if (st === "downloading") {
    bar.classList.add("show");
    fill.style.width = pct + "%";
    text.textContent = "جاري التحميل... " + pct + "%";
  } else if (st === "extracting") {
    fill.style.width = "100%";
    text.textContent = "جاري فك الضغط...";
  } else if (st === "done") {
    text.textContent = "✅ تم التحميل";
    action.innerHTML = '<button class="btn done" onclick="openSection(\'' + id + '\')">فتح</button>';
    document.getElementById("card_" + id).classList.add("done");
  } else if (st.indexOf("error") === 0) {
    text.textContent = "❌ فشل";
    text.style.color = "#dc2626";
    action.innerHTML = '<button class="btn" onclick="downloadSection(\'' + id + '\')">إعادة</button>';
  }
}

function openSection(id) {
  const sec = manifest.sections.find(s => s.id === id);
  if (!sec) return;
  currentImages = [];
  for (let i = sec.first; i <= sec.last; i++) {
    const n = i.toString().padStart(3, "0");
    currentImages.push({
      num: i,
      img: "file://" + Android.getFiguresDir() + "/figure_" + n + ".jpg",
      marked: "file://" + Android.getFiguresDir() + "/figure_" + n + "_marked.jpg",
      txt: "file://" + Android.getFiguresDir() + "/figure_" + n + ".txt"
    });
  }
  currentIndex = 0;
  document.getElementById("sectionsScreen").classList.remove("active");
  document.getElementById("viewerScreen").classList.add("active");
  const color = SECTION_COLORS[sec.full_name] || "#94a3b8";
  document.getElementById("chipDot").style.background = color;
  document.getElementById("chipText").textContent = sec.name;
  render(0);
  updateStats();
}

function render(dir) {
  if (currentImages.length === 0) return;
  currentIndex = Math.max(0, Math.min(currentIndex, currentImages.length - 1));
  const item = currentImages[currentIndex];
  const img = document.getElementById("figureImg");
  if (dir !== 0) {
    img.classList.add("slide");
    setTimeout(() => { img.src = item.img; img.classList.remove("slide"); }, 150);
  } else {
    img.src = item.img;
  }
  document.getElementById("prevBtn").disabled = currentIndex === 0;
  document.getElementById("nextBtn").disabled = currentIndex === currentImages.length - 1;
  const dot = document.getElementById("statusDot");
  const st = statusMap[item.num];
  dot.className = "status-dot";
  if (st) dot.classList.add("show", st);
}

function updateStats() {
  const ans = currentImages.filter(i => statusMap[i.num]).length;
  const wr = currentImages.filter(i => statusMap[i.num] === "again").length;
  document.getElementById("statDone").textContent = ans;
  document.getElementById("statWrong").textContent = wr;
  const pct = currentImages.length ? (ans / currentImages.length) * 100 : 0;
  document.getElementById("progressFill").style.width = pct + "%";
}

function nav(step) {
  const n = currentIndex + step;
  if (n >= 0 && n < currentImages.length) {
    currentIndex = n;
    render(step);
    updateStats();
  }
}

function goBack() {
  document.getElementById("viewerScreen").classList.remove("active");
  document.getElementById("sectionsScreen").classList.add("active");
  showSections();
}

function toggleMarkings() {
  const item = currentImages[currentIndex];
  const img = document.getElementById("figureImg");
  const btn = document.getElementById("btnMark");
  if (img.src === item.img) {
    img.src = item.marked;
    btn.classList.add("active");
  } else {
    img.src = item.img;
    btn.classList.remove("active");
  }
}

async function toggleCaption() {
  const sheet = document.getElementById("sheet");
  if (sheet.classList.contains("show")) {
    closeCaption();
    return;
  }
  const item = currentImages[currentIndex];
  document.getElementById("sheetTag").textContent = "FIGURE " + item.num;
  document.getElementById("sheetHeadline").textContent = "";
  document.getElementById("sheetDetails").textContent = "جاري التحميل...";
  sheet.classList.add("show");
  document.getElementById("btnCaption").classList.add("active");
  try {
    const r = await fetch(item.txt);
    if (r.ok) {
      const text = await r.text();
      document.getElementById("sheetDetails").textContent = text || "لا يوجد نص.";
    } else {
      document.getElementById("sheetDetails").textContent = "لا يوجد نص.";
    }
  } catch(e) {
    document.getElementById("sheetDetails").textContent = "تعذر التحميل.";
  }
}

function closeCaption() {
  document.getElementById("sheet").classList.remove("show");
  document.getElementById("btnCaption").classList.remove("active");
}

function markRecognized() {
  const item = currentImages[currentIndex];
  statusMap[item.num] = "rec";
  saveProgress();
  flash("#16a34a");
  updateStats();
  setTimeout(() => nav(1), 200);
}

function markAgain() {
  const item = currentImages[currentIndex];
  statusMap[item.num] = "again";
  saveProgress();
  flash("#d97706");
  updateStats();
  setTimeout(() => nav(1), 200);
}

function flash(c) {
  const f = document.getElementById("flash");
  f.style.background = c;
  f.style.opacity = "0.3";
  setTimeout(() => f.style.opacity = "0", 300);
}

function confirmReset() {
  if (confirm("هل تريد البدء من جديد؟")) {
    statusMap = {};
    saveProgress();
    currentIndex = 0;
    render(0);
    updateStats();
  }
}

let tX = 0, tY = 0, tT = 0;
document.getElementById("viewer").addEventListener("touchstart", (e) => {
  tX = e.changedTouches[0].screenX;
  tY = e.changedTouches[0].screenY;
  tT = Date.now();
}, {passive: true});

document.getElementById("viewer").addEventListener("touchend", (e) => {
  const dx = e.changedTouches[0].screenX - tX;
  const dy = e.changedTouches[0].screenY - tY;
  const dt = Date.now() - tT;
  if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5 && dt < 500) {
    nav(dx < 0 ? 1 : -1);
  }
}, {passive: true});

window.addEventListener("load", playSplash);
