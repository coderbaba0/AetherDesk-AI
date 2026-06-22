const HOST_NAME = "com.aetherdesk.ai";
const CURRENT_KEY = "aetherdesk_current_tab";
const TREND_STATE_KEY = "aetherdesk_trendradar_state";
const TREND_ALARM = "aetherdesk_trendradar_poll";
const TREND_TIMEOUT_MS = 15 * 60 * 1000;

function sendNative(payload) {
  return new Promise((resolve) => {
    chrome.runtime.sendNativeMessage(HOST_NAME, payload, (response) => {
      if (chrome.runtime.lastError) {
        resolve({
          ok: false,
          error: chrome.runtime.lastError.message
        });
        return;
      }

      resolve(response || { ok: false, error: "Empty native host response" });
    });
  });
}

function getDomain(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return "";
  }
}

async function getActiveTab() {
  const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
  return tabs && tabs.length ? tabs[0] : null;
}

async function getCurrentRecord() {
  const data = await chrome.storage.local.get(CURRENT_KEY);
  return data[CURRENT_KEY] || null;
}

async function setCurrentRecord(tab) {
  if (!tab || !tab.url || !/^https?:\/\//i.test(tab.url)) {
    await chrome.storage.local.remove(CURRENT_KEY);
    return;
  }

  await chrome.storage.local.set({
    [CURRENT_KEY]: {
      tabId: tab.id,
      title: tab.title || "",
      url: tab.url,
      domain: getDomain(tab.url),
      startedAt: new Date().toISOString()
    }
  });
}

async function flushCurrentRecord(reason) {
  const record = await getCurrentRecord();
  if (!record || !record.startedAt) {
    return;
  }

  const started = new Date(record.startedAt).getTime();
  const ended = Date.now();
  const durationSeconds = Math.max(0, Math.round((ended - started) / 1000));

  if (durationSeconds < 5) {
    return;
  }

  await sendNative({
    command: "logActivity",
    reason,
    title: record.title,
    url: record.url,
    domain: record.domain,
    startedAt: record.startedAt,
    endedAt: new Date(ended).toISOString(),
    durationSeconds
  });
}

async function rotateActiveTab(reason) {
  await flushCurrentRecord(reason);
  const tab = await getActiveTab();
  await setCurrentRecord(tab);
}

async function getTrendState() {
  const data = await chrome.storage.local.get(TREND_STATE_KEY);
  return data[TREND_STATE_KEY] || { status: "idle" };
}

async function setTrendState(state) {
  await chrome.storage.local.set({ [TREND_STATE_KEY]: state });
}

async function pollTrendRadar() {
  const state = await getTrendState();
  if (!state || state.status !== "running") {
    chrome.alarms.clear(TREND_ALARM);
    return;
  }

  const started = new Date(state.startedAt || 0).getTime();
  if (started && Date.now() - started > TREND_TIMEOUT_MS) {
    await setTrendState({
      ...state,
      status: "failed",
      completedAt: new Date().toISOString(),
      error: "TrendRadar did not finish within 15 minutes"
    });
    chrome.alarms.clear(TREND_ALARM);
    chrome.notifications.create({
      type: "basic",
      iconUrl: "icon-128.png",
      title: "AetherDesk TrendRadar",
      message: "TrendRadar did not finish within 15 minutes."
    });
    return;
  }

  const latest = await sendNative({ command: "getLatestReport" });
  if (!latest.ok || !latest.path || !latest.lastWriteTime) {
    return;
  }

  const reportTime = new Date(latest.lastWriteTime).getTime();
  const name = (latest.name || "").toLowerCase();

  if (name.includes("trendradar") && reportTime >= started) {
    const completed = {
      ...state,
      status: "completed",
      completedAt: new Date().toISOString(),
      reportPath: latest.path,
      reportName: latest.name
    };
    await setTrendState(completed);
    chrome.alarms.clear(TREND_ALARM);
    chrome.notifications.create({
      type: "basic",
      iconUrl: "icon-128.png",
      title: "AetherDesk TrendRadar",
      message: `Report ready: ${latest.name}`
    });
    await sendNative({ command: "openLatestReport" });
  }
}

chrome.tabs.onActivated.addListener(() => {
  rotateActiveTab("tabActivated");
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === "complete" && tab.active) {
    rotateActiveTab("tabUpdated");
  }
});

chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) {
    flushCurrentRecord("windowBlur");
  } else {
    rotateActiveTab("windowFocus");
  }
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    if (message.action === "ping") {
      sendResponse(await sendNative({ command: "ping" }));
      return;
    }

    if (message.action === "getStats") {
      sendResponse(await sendNative({ command: "getStats" }));
      return;
    }

    if (message.action === "getTrendRadarStatus") {
      sendResponse({ ok: true, ...(await getTrendState()) });
      return;
    }

    if (message.action === "openLatestReport") {
      sendResponse(await sendNative({ command: "openLatestReport" }));
      return;
    }

    if (message.action === "openReportsFolder") {
      sendResponse(await sendNative({ command: "openReportsFolder" }));
      return;
    }

    if (message.action === "saveCurrentPage") {
      const tab = await getActiveTab();
      sendResponse(await sendNative({
        command: "savePage",
        title: tab ? tab.title : "",
        url: tab ? tab.url : "",
        domain: tab ? getDomain(tab.url || "") : "",
        note: message.note || "",
        topic: message.topic || ""
      }));
      return;
    }

    if (message.action === "runTrendRadar") {
      const tab = await getActiveTab();
      const topic = (message.topic || (tab ? tab.title : "") || "").trim();
      sendResponse(await sendNative({
        command: "runTrendRadar",
        topic,
        sourceTitle: tab ? tab.title : "",
        sourceUrl: tab ? tab.url : ""
      }).then(async (response) => {
        if (response.ok) {
          await setTrendState({
            status: "running",
            topic,
            startedAt: response.startedAt || new Date().toISOString(),
            reportPath: "",
            reportName: ""
          });
          chrome.alarms.create(TREND_ALARM, { periodInMinutes: 0.5 });
        }
        return response;
      }));
      return;
    }

    if (message.action === "savePageSource") {
      const tab = await getActiveTab();
      sendResponse(await sendNative({
        command: "saveSource",
        title: tab ? tab.title : "",
        url: tab ? tab.url : "",
        domain: tab ? getDomain(tab.url || "") : "",
        html: message.html || "",
        text: message.text || "",
        selectedText: message.selectedText || ""
      }));
      return;
    }

    if (message.action === "saveScreenshot") {
      const tab = await getActiveTab();
      sendResponse(await sendNative({
        command: "saveScreenshot",
        title: tab ? tab.title : "",
        url: tab ? tab.url : "",
        domain: tab ? getDomain(tab.url || "") : "",
        selector: message.selector || "",
        dataUrl: message.dataUrl || ""
      }));
      return;
    }

    sendResponse({ ok: false, error: "Unknown extension action" });
  })();

  return true;
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === TREND_ALARM) {
    pollTrendRadar();
  }
});
