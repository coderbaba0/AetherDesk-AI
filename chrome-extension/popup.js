const statusEl = document.getElementById("status");
const logEl = document.getElementById("log");
const topicEl = document.getElementById("topic");
const noteEl = document.getElementById("note");
const reportCountEl = document.getElementById("reportCount");
const activityCountEl = document.getElementById("activityCount");
const pageCountEl = document.getElementById("pageCount");
const trendStatusEl = document.getElementById("trendStatus");
const selectorEl = document.getElementById("selector");

function log(message) {
  const time = new Date().toLocaleTimeString();
  logEl.textContent = `[${time}] ${message}\n` + logEl.textContent;
}

function send(action, payload = {}) {
  return new Promise((resolve) => {
    chrome.runtime.sendMessage({ action, ...payload }, (response) => {
      resolve(response || { ok: false, error: "No response" });
    });
  });
}

function setStatus(ok, text) {
  statusEl.textContent = text;
  statusEl.className = ok ? "status ok" : "status warn";
}

async function refreshStats() {
  const ping = await send("ping");
  setStatus(!!ping.ok, ping.ok ? "Connected" : "Offline");

  if (!ping.ok) {
    log(ping.error || "Native host unavailable");
    return;
  }

  const stats = await send("getStats");
  if (stats.ok) {
    reportCountEl.textContent = stats.reportCount ?? 0;
    activityCountEl.textContent = stats.browserActivityCount ?? 0;
    pageCountEl.textContent = stats.savedPageCount ?? 0;
    log(`Stats refreshed. Sources: ${stats.browserSourceCount ?? 0}, screenshots: ${stats.browserScreenshotCount ?? 0}`);
  } else {
    log(stats.error || "Could not load stats");
  }

  const trend = await send("getTrendRadarStatus");
  if (trend.ok) {
    const text = trend.status === "completed"
      ? `Completed: ${trend.reportName || "latest report"}`
      : trend.status === "running"
        ? `Running: ${trend.topic || "topic"}`
        : trend.status === "failed"
          ? `Failed: ${trend.error || "check logs"}`
          : "Idle";
    trendStatusEl.textContent = text;
  }
}

document.getElementById("savePage").addEventListener("click", async () => {
  const response = await send("saveCurrentPage", {
    topic: topicEl.value,
    note: noteEl.value
  });

  log(response.ok ? "Page saved to AetherDesk" : (response.error || "Save failed"));
  refreshStats();
});

document.getElementById("runTrendRadar").addEventListener("click", async () => {
  const response = await send("runTrendRadar", {
    topic: topicEl.value
  });

  log(response.ok ? "TrendRadar started. I will notify when a new report is ready." : (response.error || "TrendRadar failed"));
  refreshStats();
});

document.getElementById("openLatest").addEventListener("click", async () => {
  const response = await send("openLatestReport");
  log(response.ok ? "Latest report opened" : (response.error || "Open latest report failed"));
});

document.getElementById("openReports").addEventListener("click", async () => {
  const response = await send("openReportsFolder");
  log(response.ok ? "Reports folder opened" : (response.error || "Open reports folder failed"));
});

document.getElementById("saveSource").addEventListener("click", async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !tab.id) {
    log("No active tab found");
    return;
  }

  const [{ result }] = await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: () => ({
      html: document.documentElement.outerHTML,
      text: document.body ? document.body.innerText.slice(0, 200000) : "",
      selectedText: window.getSelection ? String(window.getSelection()) : ""
    })
  });

  const response = await send("savePageSource", result || {});
  log(response.ok ? "Page source saved" : (response.error || "Source save failed"));
});

function getElementCaptureInfo(selector) {
  const target = document.querySelector(selector || "body");
  if (!target) {
    return { ok: false, error: `Selector not found: ${selector}` };
  }

  target.scrollIntoView({ block: "center", inline: "center" });
  const rect = target.getBoundingClientRect();
  const visible = {
    left: Math.max(0, rect.left),
    top: Math.max(0, rect.top),
    right: Math.min(window.innerWidth, rect.right),
    bottom: Math.min(window.innerHeight, rect.bottom)
  };

  return {
    ok: true,
    selector,
    rect: {
      left: visible.left,
      top: visible.top,
      width: Math.max(1, visible.right - visible.left),
      height: Math.max(1, visible.bottom - visible.top)
    },
    viewport: {
      width: window.innerWidth,
      height: window.innerHeight,
      devicePixelRatio: window.devicePixelRatio || 1
    }
  };
}

async function cropScreenshot(dataUrl, captureInfo) {
  const image = new Image();
  image.src = dataUrl;
  await new Promise((resolve, reject) => {
    image.onload = resolve;
    image.onerror = reject;
  });

  const scaleX = image.naturalWidth / captureInfo.viewport.width;
  const scaleY = image.naturalHeight / captureInfo.viewport.height;
  const sx = Math.round(captureInfo.rect.left * scaleX);
  const sy = Math.round(captureInfo.rect.top * scaleY);
  const sw = Math.round(captureInfo.rect.width * scaleX);
  const sh = Math.round(captureInfo.rect.height * scaleY);
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, sw);
  canvas.height = Math.max(1, sh);
  const context = canvas.getContext("2d");
  context.drawImage(image, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL("image/png");
}

document.getElementById("captureNode").addEventListener("click", async () => {
  const selector = selectorEl.value.trim() || "body";
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !tab.id) {
    log("No active tab found");
    return;
  }

  const [{ result }] = await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: getElementCaptureInfo,
    args: [selector]
  });

  if (!result || !result.ok) {
    log(result?.error || "Could not inspect selector");
    return;
  }

  await new Promise((resolve) => setTimeout(resolve, 350));
  const fullShot = await chrome.tabs.captureVisibleTab(tab.windowId, { format: "png" });
  const cropped = await cropScreenshot(fullShot, result);
  const response = await send("saveScreenshot", { selector, dataUrl: cropped });
  log(response.ok ? "Selector screenshot saved" : (response.error || "Screenshot save failed"));
});

document.getElementById("refresh").addEventListener("click", refreshStats);

refreshStats();
setInterval(refreshStats, 10000);
