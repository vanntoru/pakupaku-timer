const foods = [
  {
    id: "yogurt",
    label: "ヨーグルト",
    color: "#b9a4ed",
    startAngle: 240,
    endAngle: 0,
    input: document.querySelector("#yogurtInput"),
    remaining: document.querySelector("#yogurtRemaining"),
  },
  {
    id: "egg",
    label: "卵焼き",
    color: "#ffc928",
    startAngle: 120,
    endAngle: 240,
    input: document.querySelector("#eggInput"),
    remaining: document.querySelector("#eggRemaining"),
  },
  {
    id: "rice",
    label: "ごはん",
    color: "#f6f0db",
    startAngle: 0,
    endAngle: 120,
    input: document.querySelector("#riceInput"),
    remaining: document.querySelector("#riceRemaining"),
  },
];

const eatingOrder = ["rice", "egg", "yogurt"].map((id) => foods.find((food) => food.id === id));

const state = {
  running: false,
  testMode: false,
  sound: true,
  elapsed: 0,
  lastTick: 0,
  mouthOpen: true,
  mouthTimer: 0,
  audioContext: null,
};

const stage = document.querySelector(".stage");
const segmentsRoot = document.querySelector("#segments");
const totalMinutes = document.querySelector("#totalMinutes");
const startPauseButton = document.querySelector("#startPauseButton");
const resetButton = document.querySelector("#resetButton");
const testButton = document.querySelector("#testButton");
const settingsButton = document.querySelector("#settingsButton");
const settingsPanel = document.querySelector("#settingsPanel");
const soundButton = document.querySelector("#soundButton");
const completeMessage = document.querySelector("#completeMessage");
const pakupaku = document.querySelector("#pakupaku");

function polarToCartesian(cx, cy, radius, angleInDegrees) {
  const angleInRadians = ((angleInDegrees - 90) * Math.PI) / 180;
  return {
    x: cx + radius * Math.cos(angleInRadians),
    y: cy + radius * Math.sin(angleInRadians),
  };
}

function clockwiseDelta(start, end) {
  return (end - start + 360) % 360 || 360;
}

function sectorPath(startAngle, endAngle, outerRadius = 270, innerRadius = 104) {
  const delta = clockwiseDelta(startAngle, endAngle);
  const largeArc = delta > 180 ? 1 : 0;
  const outerStart = polarToCartesian(320, 320, outerRadius, startAngle);
  const outerEnd = polarToCartesian(320, 320, outerRadius, endAngle);
  const innerEnd = polarToCartesian(320, 320, innerRadius, endAngle);
  const innerStart = polarToCartesian(320, 320, innerRadius, startAngle);

  return [
    `M ${outerStart.x.toFixed(2)} ${outerStart.y.toFixed(2)}`,
    `A ${outerRadius} ${outerRadius} 0 ${largeArc} 1 ${outerEnd.x.toFixed(2)} ${outerEnd.y.toFixed(2)}`,
    `L ${innerEnd.x.toFixed(2)} ${innerEnd.y.toFixed(2)}`,
    `A ${innerRadius} ${innerRadius} 0 ${largeArc} 0 ${innerStart.x.toFixed(2)} ${innerStart.y.toFixed(2)}`,
    "Z",
  ].join(" ");
}

function arcPath(startAngle, endAngle, radius = 238) {
  const delta = clockwiseDelta(startAngle, endAngle);
  const largeArc = delta > 180 ? 1 : 0;
  const start = polarToCartesian(320, 320, radius, startAngle);
  const end = polarToCartesian(320, 320, radius, endAngle);
  return `M ${start.x.toFixed(2)} ${start.y.toFixed(2)} A ${radius} ${radius} 0 ${largeArc} 1 ${end.x.toFixed(2)} ${end.y.toFixed(2)}`;
}

function renderSegments() {
  segmentsRoot.innerHTML = "";
  foods.forEach((food) => {
    const segment = document.createElementNS("http://www.w3.org/2000/svg", "path");
    segment.setAttribute("id", `segment-${food.id}`);
    segment.setAttribute("class", "segment");
    segment.setAttribute("fill", food.color);
    segment.setAttribute("d", sectorPath(food.startAngle, food.endAngle));
    segmentsRoot.appendChild(segment);

    const eaten = document.createElementNS("http://www.w3.org/2000/svg", "path");
    eaten.setAttribute("id", `eaten-${food.id}`);
    eaten.setAttribute("class", "eaten");
    eaten.setAttribute("d", "");
    segmentsRoot.appendChild(eaten);

    const outline = document.createElementNS("http://www.w3.org/2000/svg", "path");
    outline.setAttribute("class", "segment-outline");
    outline.setAttribute("d", arcPath(food.startAngle + 8, food.endAngle - 8));
    segmentsRoot.appendChild(outline);
  });
}

function getDurations() {
  if (state.testMode) {
    return foods.map(() => 5);
  }

  return foods.map((food) => {
    const value = Number.parseInt(food.input.value, 10);
    return Number.isFinite(value) ? Math.min(60, Math.max(1, value)) * 60 : 60;
  });
}

function populateDurationSelects() {
  foods.forEach((food) => {
    const defaultMinutes = Number.parseInt(food.input.dataset.defaultMinutes, 10);
    const selectedMinutes = Number.isFinite(defaultMinutes) ? Math.min(60, Math.max(1, defaultMinutes)) : 1;

    for (let minutes = 1; minutes <= 60; minutes += 1) {
      const option = document.createElement("option");
      option.value = String(minutes);
      option.textContent = String(minutes);
      food.input.appendChild(option);
    }

    food.input.value = String(selectedMinutes);
  });
}

function setTestMode(isTestMode) {
  state.testMode = isTestMode;
  testButton.setAttribute("aria-pressed", String(isTestMode));
}

function getDurationByFood() {
  const durations = getDurations();
  return new Map(foods.map((food, index) => [food.id, durations[index]]));
}

function getTotalSeconds() {
  return getDurations().reduce((sum, seconds) => sum + seconds, 0);
}

function formatMinutes(seconds) {
  return `${Math.max(0, Math.ceil(seconds / 60))}分`;
}

function getFoodProgress(elapsed) {
  const durationByFood = getDurationByFood();
  let cursor = 0;
  for (let index = 0; index < eatingOrder.length; index += 1) {
    const food = eatingOrder[index];
    const duration = durationByFood.get(food.id);
    const start = cursor;
    const end = cursor + duration;
    if (elapsed < end) {
      return {
        activeIndex: index,
        activeFood: food,
        activeElapsed: Math.max(0, elapsed - start),
        durationByFood,
      };
    }
    cursor = end;
  }
  return {
    activeIndex: eatingOrder.length,
    activeFood: null,
    activeElapsed: 0,
    durationByFood,
  };
}

function setCompletion(isComplete) {
  completeMessage.hidden = !isComplete;
  pakupaku.classList.toggle("chomping", state.running && !isComplete);
  pakupaku.classList.toggle("happy", isComplete);
  if (isComplete) {
    pakupaku.classList.remove("closed");
  }
}

function updateVisuals() {
  const durations = getDurations();
  const total = durations.reduce((sum, seconds) => sum + seconds, 0);
  const elapsed = Math.min(state.elapsed, total);
  const progress = getFoodProgress(elapsed);

  totalMinutes.textContent = formatMinutes(total - elapsed);
  stage.classList.remove("active-yogurt", "active-egg", "active-rice");

  foods.forEach((food, index) => {
    const orderIndex = eatingOrder.findIndex((orderedFood) => orderedFood.id === food.id);
    const start = eatingOrder
      .slice(0, orderIndex)
      .reduce((sum, orderedFood) => sum + durations[foods.indexOf(orderedFood)], 0);
    const foodElapsed = Math.min(Math.max(elapsed - start, 0), durations[index]);
    const remaining = durations[index] - foodElapsed;
    const ratio = durations[index] === 0 ? 1 : foodElapsed / durations[index];
    const segment = document.querySelector(`#segment-${food.id}`);
    const eaten = document.querySelector(`#eaten-${food.id}`);
    const sweep = clockwiseDelta(food.startAngle, food.endAngle);
    const eatenAngle = food.startAngle + sweep * ratio;

    food.remaining.textContent = formatMinutes(remaining);
    segment.style.opacity = ratio >= 1 ? "0.18" : "1";
    eaten.setAttribute("d", ratio <= 0 ? "" : sectorPath(food.startAngle, eatenAngle));
  });

  if (progress.activeFood) {
    stage.classList.add(`active-${progress.activeFood.id}`);
  }

  setCompletion(elapsed >= total);
  startPauseButton.textContent = state.running ? "とめる" : elapsed >= total ? "もう一回" : "スタート";
}

function playPakuSound() {
  if (!state.sound) return;
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  if (!AudioContext) return;
  state.audioContext ||= new AudioContext();
  const context = state.audioContext;
  if (context.state === "suspended") {
    context.resume();
  }
  const oscillator = context.createOscillator();
  const gain = context.createGain();
  const now = context.currentTime;

  oscillator.type = "sine";
  oscillator.frequency.setValueAtTime(480, now);
  oscillator.frequency.exponentialRampToValueAtTime(720, now + 0.08);
  oscillator.frequency.exponentialRampToValueAtTime(420, now + 0.16);
  gain.gain.setValueAtTime(0.0001, now);
  gain.gain.exponentialRampToValueAtTime(0.16, now + 0.018);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.18);
  oscillator.connect(gain);
  gain.connect(context.destination);
  oscillator.start(now);
  oscillator.stop(now + 0.2);
}

function unlockAudio() {
  if (!state.sound) return;
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  if (!AudioContext) return;
  state.audioContext ||= new AudioContext();
  if (state.audioContext.state === "suspended") {
    state.audioContext.resume();
  }
}

function tick(timestamp) {
  if (!state.running) return;
  if (!state.lastTick) state.lastTick = timestamp;
  const delta = (timestamp - state.lastTick) / 1000;
  state.lastTick = timestamp;

  const previousProgress = getFoodProgress(state.elapsed).activeIndex;
  state.elapsed = Math.min(state.elapsed + delta, getTotalSeconds());
  const nextProgress = getFoodProgress(state.elapsed).activeIndex;

  state.mouthTimer += delta;
  if (state.mouthTimer > 0.28) {
    state.mouthTimer = 0;
    state.mouthOpen = !state.mouthOpen;
    pakupaku.classList.toggle("closed", !state.mouthOpen);
  }

  if (nextProgress !== previousProgress) {
    playPakuSound();
  }

  if (state.elapsed >= getTotalSeconds()) {
    state.running = false;
    state.lastTick = 0;
    playPakuSound();
  }

  updateVisuals();
  if (state.running) requestAnimationFrame(tick);
}

function startTimer() {
  unlockAudio();
  if (state.elapsed >= getTotalSeconds()) {
    state.elapsed = 0;
  }
  state.running = true;
  state.lastTick = 0;
  state.mouthOpen = true;
  pakupaku.classList.remove("closed", "happy");
  pakupaku.classList.add("chomping");
  requestAnimationFrame(tick);
  updateVisuals();
}

function pauseTimer() {
  state.running = false;
  state.lastTick = 0;
  pakupaku.classList.remove("chomping");
  updateVisuals();
}

startPauseButton.addEventListener("click", () => {
  if (state.running) {
    pauseTimer();
  } else {
    startTimer();
  }
});

resetButton.addEventListener("click", () => {
  resetTimer();
});

testButton.addEventListener("click", () => {
  unlockAudio();
  setTestMode(true);
  resetTimer();
});

function resetTimer() {
  state.running = false;
  state.elapsed = 0;
  state.lastTick = 0;
  state.mouthTimer = 0;
  state.mouthOpen = true;
  pakupaku.classList.remove("closed", "chomping", "happy");
  updateVisuals();
}

function openSettingsPanel() {
  settingsPanel.hidden = false;
  settingsButton.setAttribute("aria-expanded", "true");
}

function closeSettingsPanel() {
  settingsPanel.hidden = true;
  settingsButton.setAttribute("aria-expanded", "false");
}

function toggleSettingsPanel() {
  if (settingsPanel.hidden) {
    openSettingsPanel();
  } else {
    closeSettingsPanel();
  }
}

settingsButton.addEventListener("click", () => {
  toggleSettingsPanel();
});

document.addEventListener("pointerdown", (event) => {
  if (settingsPanel.hidden) return;
  if (!(event.target instanceof Node)) return;
  if (settingsPanel.contains(event.target) || settingsButton.contains(event.target)) return;

  closeSettingsPanel();
});

soundButton.addEventListener("click", () => {
  state.sound = !state.sound;
  soundButton.setAttribute("aria-pressed", String(state.sound));
  unlockAudio();
});

foods.forEach((food) => {
  food.input.addEventListener("change", () => {
    setTestMode(false);
    state.elapsed = Math.min(state.elapsed, getTotalSeconds());
    updateVisuals();
  });
});

populateDurationSelects();
renderSegments();
updateVisuals();

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker
      .register("./service-worker.js")
      .then((registration) => {
        registration.update();
        registration.addEventListener("updatefound", () => {
          const worker = registration.installing;
          if (!worker) return;
          worker.addEventListener("statechange", () => {
            if (worker.state === "installed" && navigator.serviceWorker.controller) {
              worker.postMessage({ type: "SKIP_WAITING" });
            }
          });
        });
      })
      .catch(() => {
        // Offline support is optional when opened as a local file.
      });
  });

  let refreshing = false;
  navigator.serviceWorker.addEventListener("controllerchange", () => {
    if (refreshing) return;
    refreshing = true;
    window.location.reload();
  });
}
