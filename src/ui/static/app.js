(function () {
  "use strict";

  var state = {
    activeTab: "setup",
    health: null,
    config: {},
    profiles: [],
    activeProfileId: null,
    history: [],
    results: [],
    lastGeneratePayload: null,
    loadingTimer: null,
    activeHelpButton: null,
    helpTooltipPinned: false,
  };

  var dom = {};

  document.addEventListener("DOMContentLoaded", init);

  function init() {
    cacheDom();
    bindEvents();
    initHelpTooltips();
    setGenerationLoading(false);
    setActiveTab("setup");
    refreshAll();
  }

  function cacheDom() {
    dom.globalStatus = byId("global-status");
    dom.tabButtons = Array.prototype.slice.call(document.querySelectorAll(".tab"));
    dom.tabPanels = Array.prototype.slice.call(document.querySelectorAll(".panel"));

    dom.refreshAllBtn = byId("refresh-all-btn");

    dom.healthCheckBtn = byId("health-check-btn");
    dom.healthPill = byId("health-pill");
    dom.healthJson = byId("health-json");

    dom.configLoadBtn = byId("config-load-btn");
    dom.configSaveBtn = byId("config-save-btn");
    dom.saveKeysBtn = byId("save-keys-btn");
    dom.configJson = byId("config-json");
    dom.openaiKeyInput = byId("openai-key-input");
    dom.geminiKeyInput = byId("gemini-key-input");
    dom.openaiStatusPill = byId("openai-status-pill");
    dom.geminiStatusPill = byId("gemini-status-pill");

    dom.promptInput = byId("prompt-input");
    dom.styleInput = byId("style-input");
    dom.countInput = byId("count-input");
    dom.formatInput = byId("format-input");
    dom.rawPromptInput = byId("raw-prompt-input");
    dom.iconWordsInput = byId("icon-words-input");
    dom.profileSelect = byId("profile-select");
    dom.modelInput = byId("model-input");
    dom.qualityInput = byId("quality-input");
    dom.backgroundInput = byId("background-input");
    dom.outputInput = byId("output-input");
    dom.fileNameInput = byId("file-name-input");
    dom.promptPreviewBtn = byId("prompt-preview-btn");
    dom.generateBtn = byId("generate-btn");
    dom.promptPreviewOutput = byId("prompt-preview-output");
    dom.generateOutput = byId("generate-output");
    dom.generateLoading = byId("generate-loading");
    dom.generateLoadingText = byId("generate-loading-text");

    dom.clearResultsBtn = byId("clear-results-btn");
    dom.resultsGrid = byId("results-grid");

    dom.historyLoadBtn = byId("history-load-btn");
    dom.historyClearBtn = byId("history-clear-btn");
    dom.historyList = byId("history-list");

    dom.profilesLoadBtn = byId("profiles-load-btn");
    dom.newProfileName = byId("new-profile-name");
    dom.newProfileJson = byId("new-profile-json");
    dom.profileCreateBtn = byId("profile-create-btn");
    dom.profilesList = byId("profiles-list");

    dom.toastContainer = byId("toast-container");
    dom.helpButtons = Array.prototype.slice.call(document.querySelectorAll(".help-text[data-help]"));
    dom.helpTooltip = null;
  }

  function bindEvents() {
    dom.tabButtons.forEach(function (button) {
      button.addEventListener("click", function () {
        setActiveTab(String(button.getAttribute("data-tab") || "setup"));
      });
    });

    dom.refreshAllBtn.addEventListener("click", refreshAll);

    dom.healthCheckBtn.addEventListener("click", checkHealth);

    dom.configLoadBtn.addEventListener("click", loadConfig);
    dom.configSaveBtn.addEventListener("click", saveConfig);
    dom.saveKeysBtn.addEventListener("click", saveApiKeys);

    dom.promptPreviewBtn.addEventListener("click", previewPrompt);
    dom.generateBtn.addEventListener("click", generateImages);

    dom.clearResultsBtn.addEventListener("click", function () {
      state.results = [];
      state.lastGeneratePayload = null;
      renderResults();
      dom.generateOutput.textContent = "No generation yet.";
      setStatus("Local results were cleared.", "info");
    });

    dom.historyLoadBtn.addEventListener("click", loadHistory);
    dom.historyClearBtn.addEventListener("click", clearHistory);

    dom.profilesLoadBtn.addEventListener("click", loadProfiles);
    dom.profileCreateBtn.addEventListener("click", createProfile);

    dom.profilesList.addEventListener("click", onProfilesListClick);
  }

  function setActiveTab(tabId) {
    state.activeTab = tabId;

    dom.tabButtons.forEach(function (button) {
      var isActive = button.getAttribute("data-tab") === tabId;
      button.classList.toggle("is-active", isActive);
    });

    dom.tabPanels.forEach(function (panel) {
      var isActive = panel.getAttribute("data-panel") === tabId;
      panel.hidden = !isActive;
      panel.classList.toggle("is-active", isActive);
    });
  }

  function setStatus(message, kind) {
    var statusKind = kind || "info";
    dom.globalStatus.textContent = message;
    dom.globalStatus.className = "status status-" + statusKind;
  }

  function setBusy(button, isBusy) {
    if (!button) {
      return;
    }
    button.disabled = !!isBusy;
  }

  function setConfigStatusPills(config) {
    var openaiConfigured = !!(config && config.openai_api_key_configured);
    var geminiConfigured = !!(config && config.google_api_key_configured);
    dom.openaiStatusPill.textContent = "OpenAI: " + (openaiConfigured ? "configured" : "not configured");
    dom.geminiStatusPill.textContent = "Gemini: " + (geminiConfigured ? "configured" : "not configured");
  }

  function setGenerationLoading(isLoading) {
    if (!dom.generateLoading || !dom.generateLoadingText) {
      return;
    }

    dom.generateLoading.hidden = !isLoading;

    if (!isLoading) {
      dom.generateLoadingText.textContent = "Generating icon...";
      if (state.loadingTimer) {
        clearInterval(state.loadingTimer);
        state.loadingTimer = null;
      }
      return;
    }

    var step = 0;
    state.loadingTimer = setInterval(function () {
      step = (step + 1) % 4;
      dom.generateLoadingText.textContent = "Generating icon" + ".".repeat(step);
    }, 320);
  }

  function initHelpTooltips() {
    if (!dom.helpButtons.length) {
      return;
    }

    var tooltip = document.createElement("div");
    tooltip.id = "help-tooltip";
    tooltip.className = "help-tooltip";
    tooltip.hidden = true;
    tooltip.setAttribute("role", "tooltip");
    document.body.appendChild(tooltip);
    dom.helpTooltip = tooltip;

    dom.helpButtons.forEach(function (button) {
      button.setAttribute("aria-expanded", "false");
      button.setAttribute("aria-describedby", "help-tooltip");

      button.addEventListener("mouseenter", function () {
        showHelpTooltip(button, false);
      });
      button.addEventListener("mouseleave", function () {
        if (!state.helpTooltipPinned) {
          hideHelpTooltip();
        }
      });
      button.addEventListener("focus", function () {
        showHelpTooltip(button, false);
      });
      button.addEventListener("blur", function () {
        if (!state.helpTooltipPinned) {
          hideHelpTooltip();
        }
      });
      button.addEventListener("click", function (event) {
        event.preventDefault();
        event.stopPropagation();
        toggleHelpTooltip(button);
      });
    });

    document.addEventListener("click", onDocumentClickForHelpTooltip);
    document.addEventListener("keydown", onDocumentKeydownForHelpTooltip);
    window.addEventListener("resize", repositionHelpTooltip);
    window.addEventListener("scroll", repositionHelpTooltip, true);
  }

  function toggleHelpTooltip(button) {
    if (state.activeHelpButton === button && state.helpTooltipPinned) {
      hideHelpTooltip();
      return;
    }
    showHelpTooltip(button, true);
  }

  function showHelpTooltip(button, pin) {
    if (!button || !dom.helpTooltip) {
      return;
    }

    var message = String(button.getAttribute("data-help") || "").trim();
    if (!message) {
      return;
    }

    if (state.activeHelpButton && state.activeHelpButton !== button) {
      state.activeHelpButton.setAttribute("aria-expanded", "false");
    }

    state.activeHelpButton = button;
    state.helpTooltipPinned = !!pin;
    button.setAttribute("aria-expanded", "true");
    dom.helpTooltip.textContent = message;
    dom.helpTooltip.hidden = false;
    repositionHelpTooltip();
  }

  function hideHelpTooltip() {
    if (state.activeHelpButton) {
      state.activeHelpButton.setAttribute("aria-expanded", "false");
    }
    state.activeHelpButton = null;
    state.helpTooltipPinned = false;
    if (dom.helpTooltip) {
      dom.helpTooltip.hidden = true;
    }
  }

  function onDocumentClickForHelpTooltip(event) {
    if (!state.helpTooltipPinned || !state.activeHelpButton) {
      return;
    }
    var target = event.target;
    if (target instanceof Element && !target.closest(".help-text")) {
      hideHelpTooltip();
    }
  }

  function onDocumentKeydownForHelpTooltip(event) {
    if (event.key === "Escape") {
      hideHelpTooltip();
    }
  }

  function repositionHelpTooltip() {
    if (!dom.helpTooltip || dom.helpTooltip.hidden || !state.activeHelpButton) {
      return;
    }

    var buttonRect = state.activeHelpButton.getBoundingClientRect();
    var tooltip = dom.helpTooltip;
    var viewportWidth = window.innerWidth;
    var viewportHeight = window.innerHeight;
    var gap = 8;
    var edgeGap = 12;

    tooltip.style.left = "0px";
    tooltip.style.top = "0px";

    var left = buttonRect.left + buttonRect.width / 2 - tooltip.offsetWidth / 2;
    left = Math.max(edgeGap, Math.min(left, viewportWidth - tooltip.offsetWidth - edgeGap));

    var top = buttonRect.bottom + gap;
    if (top + tooltip.offsetHeight > viewportHeight - edgeGap) {
      top = buttonRect.top - tooltip.offsetHeight - gap;
    }
    top = Math.max(edgeGap, top);

    tooltip.style.left = Math.round(left) + "px";
    tooltip.style.top = Math.round(top) + "px";
  }

  function showToast(message, kind) {
    if (!dom.toastContainer) {
      return;
    }
    var tone = kind === "error" ? "toast-error" : "toast-ok";
    var toast = document.createElement("div");
    toast.className = "toast " + tone;
    toast.textContent = String(message);
    dom.toastContainer.appendChild(toast);

    setTimeout(function () {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast);
      }
    }, 3600);
  }

  async function refreshAll() {
    setBusy(dom.refreshAllBtn, true);
    setStatus("Refreshing health, config, profiles, and history.", "info");

    var results = await Promise.allSettled([checkHealth(), loadConfig(), loadProfiles(), loadHistory()]);
    var hasErrors = results.some(function (result) {
      return result.status === "rejected";
    });

    setBusy(dom.refreshAllBtn, false);
    if (hasErrors) {
      setStatus("Refresh completed with one or more failures.", "warn");
    } else {
      setStatus("Refresh complete.", "ok");
    }
  }

  async function checkHealth() {
    setBusy(dom.healthCheckBtn, true);
    try {
      var payload = await apiRequest("GET", "/api/health");
      state.health = payload;
      dom.healthJson.textContent = pretty(payload);
      if (payload && payload.ok === true) {
        dom.healthPill.textContent = "OK";
        setStatus("Backend health is OK.", "ok");
      } else {
        dom.healthPill.textContent = "Unexpected";
        setStatus("Health endpoint responded but payload is unexpected.", "warn");
      }
    } catch (error) {
      dom.healthPill.textContent = "Down";
      dom.healthJson.textContent = String(error && error.message ? error.message : error);
      setStatus("Health check failed: " + getErrorMessage(error), "error");
    } finally {
      setBusy(dom.healthCheckBtn, false);
    }
  }

  async function loadConfig() {
    setBusy(dom.configLoadBtn, true);
    try {
      var payload = await apiRequest("GET", "/api/config");
      state.config = payload || {};
      dom.configJson.value = pretty(state.config);
      setConfigStatusPills(state.config);
      setStatus("Config loaded.", "ok");
    } catch (error) {
      setStatus("Failed to load config: " + getErrorMessage(error), "error");
    } finally {
      setBusy(dom.configLoadBtn, false);
    }
  }

  async function saveConfig() {
    setBusy(dom.configSaveBtn, true);
    try {
      var parsed = parseJsonField(dom.configJson.value, "Config JSON");
      var payload = await apiRequest("POST", "/api/config", parsed);
      state.config = payload || parsed;
      dom.configJson.value = pretty(state.config);
      setConfigStatusPills(state.config);
      setStatus("Config saved.", "ok");
      showToast("Config saved.", "ok");
    } catch (error) {
      setStatus("Failed to save config: " + getErrorMessage(error), "error");
      showToast("Failed to save config: " + getErrorMessage(error), "error");
    } finally {
      setBusy(dom.configSaveBtn, false);
    }
  }

  async function saveApiKeys() {
    setBusy(dom.saveKeysBtn, true);
    try {
      var openaiKey = String(dom.openaiKeyInput.value || "").trim();
      var geminiKey = String(dom.geminiKeyInput.value || "").trim();
      var payload = {};

      if (openaiKey) payload.openai_api_key = openaiKey;
      if (geminiKey) payload.google_api_key = geminiKey;

      if (!Object.keys(payload).length) {
        throw new Error("Enter at least one API key to save.");
      }

      var response = await apiRequest("POST", "/api/config", payload);
      state.config = response || state.config;
      dom.configJson.value = pretty(state.config);
      dom.openaiKeyInput.value = "";
      dom.geminiKeyInput.value = "";
      setConfigStatusPills(state.config);
      setStatus("API keys saved.", "ok");
      showToast("API keys updated.", "ok");
    } catch (error) {
      setStatus("Failed to save API keys: " + getErrorMessage(error), "error");
      showToast("Failed to save API keys: " + getErrorMessage(error), "error");
    } finally {
      setBusy(dom.saveKeysBtn, false);
    }
  }

  async function loadProfiles() {
    setBusy(dom.profilesLoadBtn, true);
    try {
      var payload = await apiRequest("GET", "/api/profiles");
      var profiles = normalizeProfiles(payload);
      state.profiles = profiles;
      state.activeProfileId = getActiveProfileId(payload, profiles);
      renderProfiles();
      renderProfileSelect();
      setStatus("Profiles loaded.", "ok");
    } catch (error) {
      setStatus("Failed to load profiles: " + getErrorMessage(error), "error");
    } finally {
      setBusy(dom.profilesLoadBtn, false);
    }
  }

  async function createProfile() {
    setBusy(dom.profileCreateBtn, true);
    try {
      var name = String(dom.newProfileName.value || "").trim();
      if (!name) {
        throw new Error("Profile name is required.");
      }

      var config = parseJsonField(dom.newProfileJson.value || "{}", "Profile JSON");
      await apiRequest("POST", "/api/profiles", {
        name: name,
        options: config,
      });

      dom.newProfileName.value = "";
      dom.newProfileJson.value = "{}";
      await loadProfiles();
      setStatus("Profile created.", "ok");
      showToast("Profile created.", "ok");
    } catch (error) {
      setStatus("Failed to create profile: " + getErrorMessage(error), "error");
      showToast("Failed to create profile: " + getErrorMessage(error), "error");
    } finally {
      setBusy(dom.profileCreateBtn, false);
    }
  }

  async function onProfilesListClick(event) {
    var button = event.target.closest("button[data-action]");
    if (!button) {
      return;
    }

    var action = String(button.getAttribute("data-action") || "");
    var id = String(button.getAttribute("data-id") || "");
    if (!id || !action) {
      return;
    }

    setBusy(button, true);

    try {
      if (action === "use") {
        await apiRequest("POST", "/api/profiles/" + encodeURIComponent(id) + "/use", {});
        state.activeProfileId = id;
        await loadProfiles();
        setStatus("Profile activated.", "ok");
      } else if (action === "delete") {
        await apiRequest("DELETE", "/api/profiles/" + encodeURIComponent(id));
        await loadProfiles();
        setStatus("Profile deleted.", "ok");
      } else if (action === "save") {
        var editors = Array.prototype.slice.call(dom.profilesList.querySelectorAll("textarea[data-profile-editor]"));
        var editor = editors.find(function (node) {
          return node.getAttribute("data-profile-editor") === id;
        });

        if (!editor) {
          throw new Error("Profile editor not found for id " + id);
        }

        var editedConfig = parseJsonField(editor.value, "Profile JSON");
        await apiRequest("PATCH", "/api/profiles/" + encodeURIComponent(id), {
          options: editedConfig,
        });
        await loadProfiles();
        setStatus("Profile updated.", "ok");
      }
    } catch (error) {
      setStatus("Profile action failed: " + getErrorMessage(error), "error");
      showToast("Profile action failed: " + getErrorMessage(error), "error");
    } finally {
      setBusy(button, false);
    }
  }

  async function previewPrompt() {
    setBusy(dom.promptPreviewBtn, true);
    try {
      var payload = buildCreatePayload(false);
      var previewPayload = {
        prompt: payload.prompt,
        style: payload.style,
        rawPrompt: payload.rawPrompt,
        useIconWords: payload.useIconWords,
      };
      var response = await apiRequest("POST", "/api/prompt-preview", previewPayload);
      var finalPrompt = response && response.finalPrompt ? response.finalPrompt : pretty(response);
      dom.promptPreviewOutput.textContent = String(finalPrompt);
      setStatus("Prompt preview generated.", "ok");
    } catch (error) {
      setStatus("Failed to preview prompt: " + getErrorMessage(error), "error");
      showToast("Failed to preview prompt: " + getErrorMessage(error), "error");
    } finally {
      setBusy(dom.promptPreviewBtn, false);
    }
  }

  async function generateImages() {
    setBusy(dom.generateBtn, true);
    setGenerationLoading(true);

    try {
      var payload = buildCreatePayload(true);
      var response = await apiRequest("POST", "/api/generate", payload);
      state.lastGeneratePayload = response;
      state.results = normalizeGeneratedItems(response);

      dom.generateOutput.textContent = pretty(response);
      renderResults();

      if (state.results.length > 0) {
        setStatus("Generation finished: " + state.results.length + " item(s).", "ok");
        showToast("Icon generation completed.", "ok");
      } else {
        setStatus("Generate request succeeded with no detectable images in payload.", "warn");
        showToast("Generation completed with no images.", "error");
      }

      setActiveTab("results");
      await loadHistory();
    } catch (error) {
      var message = getErrorMessage(error);
      dom.generateOutput.textContent = message;
      setStatus("Generation failed: " + message, "error");
      showToast("Generation failed: " + message, "error");
    } finally {
      setGenerationLoading(false);
      setBusy(dom.generateBtn, false);
    }
  }

  function buildCreatePayload(includeGenerationOptions) {
    var prompt = String(dom.promptInput.value || "").trim();
    if (!prompt) {
      throw new Error("Prompt is required.");
    }

    var style = String(dom.styleInput.value || "").trim();
    var selectedProfileId = String(dom.profileSelect.value || "").trim();
    var count = clampNumber(Number(dom.countInput.value || 1), 1, 10, 1);
    var format = String(dom.formatInput.value || "png").trim() || "png";
    var rawPrompt = !!dom.rawPromptInput.checked;
    var useIconWords = !!dom.iconWordsInput.checked;
    var model = String(dom.modelInput.value || "gpt-1.5").trim() || "gpt-1.5";
    var quality = String(dom.qualityInput.value || "").trim();
    var background = String(dom.backgroundInput.value || "auto").trim() || "auto";
    var output = String(dom.outputInput.value || "").trim();
    var fileName = String(dom.fileNameInput.value || "").trim();

    var payload = {
      prompt: prompt,
      style: style || undefined,
      rawPrompt: rawPrompt,
      useIconWords: useIconWords,
    };

    if (selectedProfileId) {
      payload.profileId = selectedProfileId;
    }

    if (includeGenerationOptions) {
      payload.options = {
        n: count,
        outputFormat: format,
        rawPrompt: rawPrompt,
        useIconWords: useIconWords,
        style: style || undefined,
        model: model,
        quality: quality || undefined,
        background: background,
        output: output || undefined,
        fileName: fileName || undefined,
      };
    }

    return payload;
  }

  async function loadHistory() {
    setBusy(dom.historyLoadBtn, true);
    try {
      var payload = await apiRequest("GET", "/api/history");
      state.history = normalizeHistory(payload);
      renderHistory();
      setStatus("History loaded.", "ok");
    } catch (error) {
      setStatus("Failed to load history: " + getErrorMessage(error), "error");
    } finally {
      setBusy(dom.historyLoadBtn, false);
    }
  }

  async function clearHistory() {
    setBusy(dom.historyClearBtn, true);
    try {
      await apiRequest("DELETE", "/api/history");
      state.history = [];
      renderHistory();
      setStatus("History cleared.", "ok");
      showToast("History cleared.", "ok");
    } catch (error) {
      setStatus("Failed to clear history: " + getErrorMessage(error), "error");
      showToast("Failed to clear history: " + getErrorMessage(error), "error");
    } finally {
      setBusy(dom.historyClearBtn, false);
    }
  }

  function renderProfileSelect() {
    var selected = dom.profileSelect.value;
    var options = ['<option value="">No profile</option>'];

    state.profiles.forEach(function (profile) {
      var id = getProfileId(profile);
      var label = getProfileName(profile) || id;
      if (!id) {
        return;
      }
      var activeMark = state.activeProfileId === id ? " (active)" : "";
      options.push('<option value="' + escapeAttr(id) + '">' + escapeHtml(label + activeMark) + "</option>");
    });

    dom.profileSelect.innerHTML = options.join("");
    if (selected && dom.profileSelect.querySelector('option[value="' + escapeAttr(selected) + '"]')) {
      dom.profileSelect.value = selected;
    } else if (state.activeProfileId) {
      dom.profileSelect.value = state.activeProfileId;
    }
  }

  function renderProfiles() {
    if (!state.profiles.length) {
      dom.profilesList.innerHTML = '<p class="muted">No profiles found.</p>';
      return;
    }

    dom.profilesList.innerHTML = state.profiles
      .map(function (profile) {
        var id = getProfileId(profile);
        var name = getProfileName(profile) || id;
        var config = getProfileConfig(profile);
        var active = state.activeProfileId === id;

        return (
          '<article class="profile-item">' +
          '<div class="row spread wrap">' +
          '<div class="profile-title">' +
          escapeHtml(name) +
          (active ? " (active)" : "") +
          "</div>" +
          '<div class="row wrap">' +
          '<button class="btn" type="button" data-action="use" data-id="' +
          escapeAttr(id) +
          '">Use</button>' +
          '<button class="btn" type="button" data-action="save" data-id="' +
          escapeAttr(id) +
          '">Save edits</button>' +
          '<button class="btn btn-danger" type="button" data-action="delete" data-id="' +
          escapeAttr(id) +
          '">Delete</button>' +
          "</div>" +
          "</div>" +
          '<textarea class="input mono" rows="6" spellcheck="false" data-profile-editor="' +
          escapeAttr(id) +
          '">' +
          escapeHtml(pretty(config)) +
          "</textarea>" +
          "</article>"
        );
      })
      .join("");
  }

  function renderHistory() {
    if (!state.history.length) {
      dom.historyList.innerHTML = '<p class="muted">No history entries found.</p>';
      return;
    }

    dom.historyList.innerHTML = state.history
      .map(function (entry, index) {
        var prompt = getAny(entry, ["prompt", "input", "rawPrompt"]) || "Prompt unavailable";
        var created = getAny(entry, ["createdAt", "timestamp", "time", "date"]);
        var model = getAny(entry, ["model"]) || "unknown";
        var provider = getAny(entry, ["provider"]) || "unknown";
        var paths = Array.isArray(entry.outputPaths) ? entry.outputPaths : [];

        var gallery = paths.length
          ? '<div class="history-gallery">' +
            paths
              .map(function (itemPath) {
                var filePath = String(itemPath);
                var encoded = encodeURIComponent(filePath);
                return (
                  '<figure class="history-thumb">' +
                  '<img loading="lazy" alt="History image" src="/api/files/' +
                  escapeAttr(encoded) +
                  '" />' +
                  '<figcaption class="history-path">' +
                  escapeHtml(filePath) +
                  "</figcaption>" +
                  "</figure>"
                );
              })
              .join("") +
            "</div>"
          : '<div class="result-meta">No saved images for this run.</div>';

        return (
          '<article class="history-item">' +
          '<div class="history-title">#' +
          (index + 1) +
          "</div>" +
          '<div class="result-meta"><strong>Model:</strong> ' +
          escapeHtml(String(model)) +
          " (" +
          escapeHtml(String(provider)) +
          ")</div>" +
          '<div class="result-meta"><strong>Time:</strong> ' +
          escapeHtml(formatMaybeDate(created)) +
          "</div>" +
          '<div class="result-meta"><strong>Prompt:</strong> ' +
          escapeHtml(String(prompt)) +
          "</div>" +
          gallery +
          "</article>"
        );
      })
      .join("");
  }

  function renderResults() {
    if (!state.results.length) {
      dom.resultsGrid.innerHTML = '<p class="muted">No generated images yet.</p>';
      return;
    }

    dom.resultsGrid.innerHTML = state.results
      .map(function (item, index) {
        var src = getRenderableSrc(item);
        var path = item.path || item.filePath || item.url || "Path unavailable";
        var prompt = item.prompt || "";
        var meta = item.meta || {};

        var imageHtml = src
          ? '<img loading="lazy" alt="Generated result ' + String(index + 1) + '" src="' + escapeAttr(src) + '" />'
          : '<div class="code-box">Thumbnail unavailable for this path.</div>';

        return (
          '<article class="result-card">' +
          imageHtml +
          '<div class="result-meta"><strong>Path:</strong> ' +
          escapeHtml(String(path)) +
          "</div>" +
          (prompt
            ? '<div class="result-meta"><strong>Prompt:</strong> ' + escapeHtml(String(prompt)) + "</div>"
            : "") +
          '<details class="result-meta"><summary>Metadata</summary><pre class="code-box">' +
          escapeHtml(pretty(meta)) +
          "</pre></details>" +
          "</article>"
        );
      })
      .join("");
  }

  async function apiRequest(method, path, body) {
    var options = {
      method: method,
      headers: {
        Accept: "application/json",
      },
    };

    if (typeof body !== "undefined") {
      options.headers["Content-Type"] = "application/json";
      options.body = JSON.stringify(body);
    }

    var response = await fetch(path, options);
    var payload = await parseResponse(response);

    if (!response.ok) {
      var message = extractApiErrorMessage(payload) || "Request failed with status " + response.status;
      throw new Error(String(message));
    }

    return payload;
  }

  async function parseResponse(response) {
    var text = await response.text();
    if (!text) {
      return {};
    }
    try {
      return JSON.parse(text);
    } catch (_err) {
      return { raw: text };
    }
  }

  function normalizeProfiles(payload) {
    if (Array.isArray(payload)) {
      return payload;
    }

    var candidates = [payload && payload.profiles, payload && payload.items, payload && payload.data];

    for (var i = 0; i < candidates.length; i += 1) {
      if (Array.isArray(candidates[i])) {
        return candidates[i];
      }
    }

    return [];
  }

  function getActiveProfileId(payload, profiles) {
    if (payload && payload.active_profile_id) {
      return String(payload.active_profile_id);
    }

    if (state.config && state.config.active_profile_id) {
      return String(state.config.active_profile_id);
    }

    for (var i = 0; i < profiles.length; i += 1) {
      var p = profiles[i];
      if (p && (p.active === true || p.isActive === true || p.inUse === true)) {
        return getProfileId(p);
      }
    }

    return "";
  }

  function getProfileId(profile) {
    var value = getAny(profile, ["id", "profileId", "name"]);
    return value == null ? "" : String(value);
  }

  function getProfileName(profile) {
    var value = getAny(profile, ["name", "title", "id"]);
    return value == null ? "" : String(value);
  }

  function getProfileConfig(profile) {
    return getAny(profile, ["config", "settings", "options"]) || profile || {};
  }

  function normalizeHistory(payload) {
    if (Array.isArray(payload)) {
      return payload;
    }

    var collection = getAny(payload, ["history", "items", "entries", "data"]);
    if (Array.isArray(collection)) {
      return collection;
    }

    return [];
  }

  function normalizeGeneratedItems(payload) {
    var result = payload && payload.result ? payload.result : payload;

    var generatedFromPaths = getAny(result, ["outputPaths"]);
    if (Array.isArray(generatedFromPaths)) {
      var fileUrls = getAny(result, ["fileUrls"]);
      return generatedFromPaths.map(function (itemPath, index) {
        var item = {
          path: String(itemPath),
          meta: result,
        };
        if (Array.isArray(fileUrls) && fileUrls[index] && fileUrls[index].url) {
          item.url = String(fileUrls[index].url);
        }
        return item;
      });
    }

    var candidates = [getAny(result, ["images", "results", "items", "files", "data"])];

    if (Array.isArray(candidates[0])) {
      return candidates[0].map(toGeneratedItem);
    }

    if (typeof result === "string") {
      return [toGeneratedItem(result)];
    }

    var singlePath = getAny(result, ["path", "filePath", "outputPath", "url"]);
    if (singlePath) {
      return [toGeneratedItem(result)];
    }

    return [];
  }

  function toGeneratedItem(value) {
    if (typeof value === "string") {
      return {
        path: value,
        meta: { raw: value },
      };
    }

    var path = getAny(value, ["path", "filePath", "file", "outputPath", "imagePath"]);
    var url = getAny(value, ["url", "src", "imageUrl", "fileUrl"]);
    var prompt = getAny(value, ["prompt", "input", "finalPrompt"]);

    return {
      path: path ? String(path) : "",
      url: url ? String(url) : "",
      prompt: prompt ? String(prompt) : "",
      meta: value,
    };
  }

  function getRenderableSrc(item) {
    if (item.url && isLikelyUrl(item.url)) {
      return item.url;
    }

    if (item.path) {
      if (String(item.path).indexOf("/api/files/") === 0) {
        return item.path;
      }
      if (isLikelyUrl(item.path) && !isLikelyFsAbsolutePath(item.path)) {
        return item.path;
      }
    }

    return "";
  }

  function isLikelyUrl(value) {
    var str = String(value || "");
    return str.indexOf("http://") === 0 || str.indexOf("https://") === 0 || str.indexOf("/") === 0;
  }

  function isLikelyFsAbsolutePath(value) {
    var str = String(value || "");
    return str.indexOf("/Users/") === 0 || str.indexOf("/home/") === 0 || /^[a-zA-Z]:\\/.test(str);
  }

  function parseJsonField(text, label) {
    try {
      return JSON.parse(text);
    } catch (_error) {
      throw new Error(label + " must be valid JSON.");
    }
  }

  function pretty(value) {
    try {
      return JSON.stringify(value, null, 2);
    } catch (_error) {
      return String(value);
    }
  }

  function getAny(obj, keys) {
    if (!obj) {
      return undefined;
    }
    for (var i = 0; i < keys.length; i += 1) {
      if (Object.prototype.hasOwnProperty.call(obj, keys[i])) {
        return obj[keys[i]];
      }
    }
    return undefined;
  }

  function formatMaybeDate(value) {
    if (!value) {
      return "Unknown";
    }

    var date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return String(value);
    }

    return date.toLocaleString();
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function escapeAttr(value) {
    return escapeHtml(value).replace(/`/g, "&#96;");
  }

  function getErrorMessage(error) {
    if (error && error.message) {
      return String(error.message);
    }
    return String(error);
  }

  function extractApiErrorMessage(payload) {
    if (!payload) {
      return "";
    }

    if (typeof payload.error === "string") {
      return payload.error;
    }

    if (payload.error && typeof payload.error === "object") {
      var nestedMessage = getAny(payload.error, ["message", "detail"]);
      if (nestedMessage) {
        return String(nestedMessage);
      }

      var nestedStatus = getAny(payload.error, ["status"]);
      if (nestedStatus) {
        return String(nestedStatus);
      }
    }

    var topMessage = getAny(payload, ["message", "detail"]);
    if (topMessage) {
      return String(topMessage);
    }

    return "";
  }

  function clampNumber(value, min, max, fallback) {
    if (Number.isNaN(value)) {
      return fallback;
    }
    return Math.max(min, Math.min(max, Math.round(value)));
  }

  function byId(id) {
    return document.getElementById(id);
  }
})();
