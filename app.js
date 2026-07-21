(function () {
  "use strict";

  var route = {
    routeId: "northstar-release-review",
    contextTags: ["northstar", "release"],
    requiredTypes: ["decision", "test"],
    allowedScopes: ["demo_public"]
  };

  var records = [
    {
      id: "NORTHSTAR-DECISION-004",
      type: "decision",
      title: "Current release decision",
      effectiveAt: "2026-07-18T13:20:00-04:00",
      status: "current",
      scope: "demo_public",
      tags: ["northstar", "release", "decision"],
      summary: "GO | publish after final smoke test remains green",
      source: "data/records.json#NORTHSTAR-DECISION-004"
    },
    {
      id: "NORTHSTAR-TEST-018",
      type: "test",
      title: "Latest release test",
      effectiveAt: "2026-07-18T14:05:00-04:00",
      status: "current",
      scope: "demo_public",
      tags: ["northstar", "release", "test"],
      summary: "PASS | 18 of 18 smoke checks passed",
      source: "data/records.json#NORTHSTAR-TEST-018"
    },
    {
      id: "NORTHSTAR-DECISION-003",
      type: "decision",
      title: "Superseded release decision",
      effectiveAt: "2026-07-16T09:00:00-04:00",
      status: "stale",
      scope: "demo_public",
      tags: ["northstar", "release", "decision"],
      summary: "HOLD | historical record",
      source: "data/records.json#NORTHSTAR-DECISION-003"
    },
    {
      id: "NORTHSTAR-INCIDENT-PRIVATE",
      type: "incident",
      title: "Restricted incident detail",
      effectiveAt: "2026-07-18T12:15:00-04:00",
      status: "current",
      scope: "restricted",
      tags: ["northstar", "release", "incident"],
      summary: "Restricted synthetic detail",
      source: "data/records.json#NORTHSTAR-INCIDENT-PRIVATE"
    },
    {
      id: "ORBIT-BUDGET-009",
      type: "budget",
      title: "Unrelated Orbit budget",
      effectiveAt: "2026-07-18T10:30:00-04:00",
      status: "current",
      scope: "demo_public",
      tags: ["orbit", "budget"],
      summary: "Unrelated synthetic project",
      source: "data/records.json#ORBIT-BUDGET-009"
    }
  ];

  var stateOrder = [
    "received",
    "dedupe_checked",
    "route_selected",
    "retrieval_completed",
    "bound",
    "reflected",
    "answered"
  ];

  var cache = new Map();
  var running = false;
  var reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var runButton = document.getElementById("run-button");
  var resetButton = document.getElementById("reset-button");
  var requestInput = document.getElementById("request-input");
  var recordsList = document.getElementById("records-list");
  var exclusionsList = document.getElementById("exclusions-list");
  var answerEmpty = document.getElementById("answer-empty");
  var answerContent = document.getElementById("answer-content");
  var answerText = document.getElementById("answer-text");
  var provenanceList = document.getElementById("provenance-list");
  var receiptId = document.getElementById("receipt-id");
  var pipelineStatus = document.getElementById("pipeline-status");
  var mountMetric = document.getElementById("mount-metric");
  var selectedMetric = document.getElementById("selected-metric");
  var recordStatus = document.getElementById("record-status");
  var answerStatus = document.getElementById("answer-status");

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function shortType(type) {
    return type.slice(0, 1).toUpperCase();
  }

  function renderRecords(selection, exclusions) {
    var selectedIds = new Set((selection || []).map(function (item) { return item.id; }));
    var reasons = new Map((exclusions || []).map(function (item) { return [item.record.id, item.reason]; }));

    recordsList.innerHTML = records.map(function (record) {
      var className = "record-row";
      var state = "Candidate";
      if (selectedIds.has(record.id)) {
        className += " selected";
        state = "Mounted";
      } else if (reasons.has(record.id)) {
        className += " excluded";
        state = reasons.get(record.id).replace(/_/g, " ");
        if (reasons.get(record.id) === "scope_denied") {
          className += " scope-denied";
        }
      }

      return [
        '<div class="' + className + '">',
        '<div class="record-icon" aria-hidden="true">' + shortType(record.type) + '</div>',
        '<div class="record-copy">',
        '<strong>' + escapeHtml(record.title) + '</strong>',
        '<span>' + escapeHtml(record.id) + ' | ' + escapeHtml(record.summary) + '</span>',
        '</div>',
        '<div class="record-state">' + escapeHtml(state) + '</div>',
        '</div>'
      ].join("");
    }).join("");
  }

  function classifyRecords(scope) {
    var eligible = [];
    var exclusions = [];

    records.forEach(function (record) {
      var reason = null;
      if (record.status !== "current") {
        reason = "status_stale";
      } else if (route.allowedScopes.indexOf(record.scope) === -1 || record.scope !== scope) {
        reason = "scope_denied";
      } else if (!route.contextTags.every(function (tag) { return record.tags.indexOf(tag) !== -1; })) {
        reason = "route_mismatch";
      }

      if (reason) {
        exclusions.push({ record: record, reason: reason });
      } else {
        eligible.push(record);
      }
    });

    var selected = route.requiredTypes.map(function (type) {
      var matches = eligible
        .filter(function (record) { return record.type === type; })
        .sort(function (a, b) { return new Date(b.effectiveAt) - new Date(a.effectiveAt); });
      return matches[0];
    }).filter(Boolean);

    eligible.forEach(function (record) {
      if (!selected.some(function (item) { return item.id === record.id; })) {
        exclusions.push({ record: record, reason: "superseded" });
      }
    });

    return { selected: selected, exclusions: exclusions };
  }

  function stableKey(value) {
    var hash = 2166136261;
    for (var i = 0; i < value.length; i += 1) {
      hash ^= value.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return ("00000000" + (hash >>> 0).toString(16)).slice(-8);
  }

  function clearPipeline() {
    document.querySelectorAll("#pipeline-list li").forEach(function (item) {
      item.classList.remove("active", "complete");
    });
  }

  function markState(state) {
    var items = Array.from(document.querySelectorAll("#pipeline-list li"));
    var targetIndex = items.findIndex(function (item) { return item.dataset.state === state; });
    items.forEach(function (item, index) {
      item.classList.toggle("complete", index < targetIndex);
      item.classList.toggle("active", index === targetIndex);
    });
    pipelineStatus.textContent = state.replace(/_/g, " ");
  }

  function wait() {
    return new Promise(function (resolve) {
      window.setTimeout(resolve, reducedMotion ? 20 : 210);
    });
  }

  async function runSequence(states) {
    clearPipeline();
    for (var i = 0; i < states.length; i += 1) {
      markState(states[i]);
      await wait();
    }
    document.querySelectorAll("#pipeline-list li").forEach(function (item) {
      item.classList.remove("active");
      item.classList.add("complete");
    });
  }

  function renderExclusions(exclusions) {
    exclusionsList.innerHTML = exclusions.map(function (item) {
      return [
        '<div class="exclusion-item">',
        '<strong>' + escapeHtml(item.record.id) + '</strong>',
        '<span>' + escapeHtml(item.reason.replace(/_/g, " ")) + '</span>',
        '</div>'
      ].join("");
    }).join("");
  }

  function renderAnswer(result, receipt) {
    answerEmpty.hidden = true;
    answerContent.hidden = false;
    answerText.textContent = "Northstar release review: GO. Publish only after the final smoke test remains green. Latest verification: 18 of 18 smoke checks passed. Environment: synthetic-staging.";
    provenanceList.innerHTML = result.selected.map(function (record) {
      return '<li><strong>' + escapeHtml(record.id) + '</strong> | ' + escapeHtml(record.source) + '</li>';
    }).join("");
    receiptId.textContent = receipt;
    answerStatus.textContent = "Bound with provenance";
  }

  async function runDemo() {
    if (running) {
      return;
    }
    running = true;
    runButton.disabled = true;

    var prompt = requestInput.value.trim();
    var key = stableKey(route.routeId + "|demo_public|" + prompt);
    var result = cache.get(key);
    var states;

    if (result) {
      states = ["received", "dedupe_checked", "bound", "reflected", "answered"];
      pipelineStatus.textContent = "reused existing mount";
      mountMetric.textContent = "Reused mount";
    } else {
      result = classifyRecords("demo_public");
      cache.set(key, result);
      states = stateOrder;
      mountMetric.textContent = "Fresh mount";
    }

    renderRecords(result.selected, result.exclusions);
    renderExclusions(result.exclusions);
    selectedMetric.textContent = result.selected.length + " / " + records.length;
    recordStatus.textContent = result.selected.length + " mounted | " + result.exclusions.length + " excluded";
    renderAnswer(result, "DEMO-" + key.toUpperCase());

    await runSequence(states);
    pipelineStatus.textContent = result === cache.get(key) && mountMetric.textContent === "Reused mount"
      ? "answered | reused existing mount"
      : "answered | fresh mount";

    runButton.disabled = false;
    running = false;
  }

  function resetDemo() {
    cache.clear();
    clearPipeline();
    renderRecords();
    exclusionsList.innerHTML = '<p class="quiet">No exclusions recorded yet.</p>';
    answerEmpty.hidden = false;
    answerContent.hidden = true;
    pipelineStatus.textContent = "Ready";
    mountMetric.textContent = "Not run";
    selectedMetric.textContent = "0 / " + records.length;
    recordStatus.textContent = "Awaiting request";
    answerStatus.textContent = "No mount";
  }

  runButton.addEventListener("click", runDemo);
  resetButton.addEventListener("click", resetDemo);
  renderRecords();
  if (window.location.search.indexOf("autorun=1") !== -1) {
    window.setTimeout(runDemo, 100);
  }
}());



