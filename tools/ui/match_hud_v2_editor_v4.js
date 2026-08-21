(() => {
  "use strict";

  const ASSET = "../../assets/";
  const profiles = {
    "1280x720": { width: 1280, height: 720 },
    "1680x720": { width: 1680, height: 720 },
    "1280x800": { width: 1280, height: 800 },
    "1280x960": { width: 1280, height: 960 }
  };
  const pieceData = {
    minister: { name: "象", asset: "art/pieces/terracotta_warriors/red_minister_idle.png", description: "斜行两格，象眼受阻时不可通过，并展开侦察区域。", skill: "无技能" },
    chariot: { name: "车", asset: "art/pieces/terracotta_warriors/red_chariot_idle.png", description: "沿直线移动，路径上不可越过其他棋子。", skill: "冲阵" },
    trebuchet: { name: "炮", asset: "art/pieces/terracotta_warriors/red_trebuchet_idle.png", description: "沿直线移动；隔一枚棋子可执行轰炸。", skill: "轰炸" },
    guard: { name: "士", asset: "art/pieces/terracotta_warriors/red_guard_idle.png", description: "守卫九宫并可在满足条件时复活友军。", skill: "复活" },
    cavalry: { name: "马", asset: "art/pieces/terracotta_warriors/red_cavalry_idle.png", description: "日字行进，马腿受阻时不可通过。", skill: "无技能" },
    infantry: { name: "兵", asset: "art/pieces/terracotta_warriors/red_infantry_idle.png", description: "向敌阵推进，越过河界后可横向移动。", skill: "无技能" },
    none: { name: "未选择", asset: "", description: "选择棋子后显示移动规则与操作。", skill: "无技能" }
  };
  const text = (id, name, value, rect, fontSize, align = "left", binding = "static") => ({ id, name, value, rect, fontSize, align, binding });
  const objects = [
    { id: "board", parent: null, name: "棋盘可视区域", kind: "BOARD", binding: "board_rect", rect: { x: 340, y: 32, w: 600, h: 544 }, z: 0, visible: true },
    { id: "faction-left", parent: null, name: "赤方军势", kind: "PANEL", binding: "faction_left", asset: "art/ui/terracotta_hud_v2/faction_status_plate_v1.png", rect: { x: 48, y: 10, w: 306, h: 120 }, z: 4, visible: true, texts: [text("name", "阵营名称", "赤方军势", { x: .32, y: .29, w: .44, h: .21 }, 14), text("stats", "阵营数据", "墙 完好 · 旗 0 · 损 0", { x: .327, y: .5, w: .51, h: .17 }, 10)] },
    { id: "faction-right", parent: null, name: "玄方军势", kind: "PANEL", binding: "faction_right", asset: "art/ui/terracotta_hud_v2/faction_status_plate_v1.png", mirror: true, rect: { x: 928, y: 10, w: 303, h: 119 }, z: 4, visible: true, texts: [text("name", "阵营名称", "玄方军势", { x: .22, y: .295, w: .446, h: .21 }, 14, "right"), text("stats", "阵营数据", "墙 破损 · 旗 0 · 损 1", { x: .165, y: .505, w: .512, h: .168 }, 10, "right")] },
    { id: "minimap", parent: null, name: "战场态势", kind: "PANEL", binding: "minimap", asset: "art/ui/terracotta_hud_v2/minimap_frame_v1.png", rect: { x: 64, y: 130, w: 241, h: 264 }, z: 3, visible: true, texts: [text("title", "小地图标题", "战场态势", { x: .18, y: .04, w: .64, h: .1 }, 12, "center")] },
    { id: "unit-info", parent: null, name: "棋子信息卡", kind: "PANEL", binding: "unit_info", asset: "art/ui/terracotta_hud_v2/unit_info_card_v1.png", rect: { x: 129, y: 408, w: 184, h: 246 }, z: 4, visible: true, texts: [text("piece-name", "棋子名称", "象", { x: .14, y: .055, w: .72, h: .09 }, 14, "center", "unit_name")] },
    { id: "objective", parent: null, name: "战局与行动", kind: "PANEL", binding: "objective_events", asset: "art/ui/terracotta_hud_v2/objective_event_panel_v1.png", rect: { x: 916, y: 220, w: 288, h: 432 }, z: 3, visible: true, texts: [text("heading", "面板标题", "战局与行动", { x: .194, y: .167, w: .612, h: .065 }, 14, "center"), text("selection", "选择状态", "行动方: 赤 已选: 象", { x: .295, y: .278, w: .5, h: .065 }, 11, "center", "selection_status"), text("flags", "旗帜数", "我方已发现旗帜: 1/3", { x: .295, y: .37, w: .5, h: .065 }, 12, "center"), text("our-loss", "我方阵亡", "我方阵亡: 无", { x: .295, y: .481, w: .5, h: .065 }, 12, "center"), text("enemy-loss", "敌方阵亡", "敌方阵亡: 兵*1", { x: .295, y: .583, w: .5, h: .065 }, 12, "center"), text("position", "位置", "位置: (6, 4)", { x: .295, y: .692, w: .5, h: .065 }, 12, "center")] },
    { id: "detail", parent: null, name: "棋子详情栏", kind: "PANEL", binding: "piece_info_drawer", asset: "art/ui/terracotta_hud_v2/incense_assembly/piece_info_drawer_frame_v2.png", rect: { x: 296, y: 584, w: 648, h: 56 }, z: 5, visible: true, texts: [text("caption", "介绍标题", "棋子介绍", { x: .052, y: .107, w: .18, h: .268 }, 11), text("summary", "介绍说明", "斜行两格，象眼受阻时不可通过，并展开侦察区域。", { x: .052, y: .375, w: .66, h: .518 }, 10), text("move", "按钮一", "移动", { x: .76, y: .107, w: .1, h: .786 }, 11, "center", "move_action"), text("skill", "按钮二", "无技能", { x: .87, y: .107, w: .1, h: .786 }, 11, "center", "piece_action")] },
    { id: "incense-group", parent: null, name: "燃香与香盘", kind: "GROUP", binding: "incense_turn_clock", rect: { x: 64, y: 160, w: 1152, h: 556 }, z: 1, visible: true, virtual: true },
    { id: "timer-body", parent: "incense-group", name: "左侧计时香", kind: "IMAGE", binding: "timer_incense", asset: "art/ui/terracotta_hud_v2/incense_assembly/timer_incense_vertical_v1.png", rect: { x: 72, y: 443, w: 48, h: 232 }, z: -2, visible: true },
    { id: "timer-smoke", parent: "incense-group", name: "左侧镜像烟雾", kind: "VFX", binding: "timer_smoke", rect: { x: 84, y: 397, w: 86, h: 132 }, z: 1, visible: true, smoke: "timer" },
    { id: "stand", parent: "incense-group", name: "龙虎青铜香盘", kind: "IMAGE", binding: "incense_stand", asset: "art/ui/terracotta_hud_v2/incense_assembly/dual_incense_bronze_stand_v1.png", rect: { x: 64, y: 636, w: 1152, h: 80 }, z: -1, visible: true },
    { id: "round-body", parent: "incense-group", name: "右侧回合香", kind: "IMAGE", binding: "round_incense", asset: "art/ui/terracotta_hud_v2/incense_assembly/round_incense_vertical_v1.png", rect: { x: 1168, y: 272, w: 40, h: 408 }, z: -1, visible: true },
    { id: "round-smoke", parent: "incense-group", name: "右侧回合烟雾", kind: "VFX", binding: "round_smoke", rect: { x: 1098, y: 224, w: 104, h: 176 }, z: 1, visible: true, smoke: "round" },
    { id: "round-display", parent: "incense-group", name: "回合数显示区", kind: "PANEL", binding: "round_display", asset: "art/ui/terracotta_hud_v2/incense_assembly/round_smoke_display_frame_v1.png", rect: { x: 1104, y: 160, w: 104, h: 96 }, z: 2, visible: true, texts: [text("number", "回合数字", "十八", { x: .14, y: .19, w: .72, h: .53 }, 30, "center", "round_number"), text("caption", "回合标题", "回合", { x: .24, y: .7, w: .52, h: .21 }, 12, "center")] }
  ];

  const clone = value => JSON.parse(JSON.stringify(value));
  const defaultObjects = clone(objects);
  const state = { profile: "1280x720", selectedId: "board", zoom: 1, history: [], future: [], drag: null, textId: null };
  const $ = id => document.getElementById(id);
  const selected = () => objects.find(item => item.id === state.selectedId);
  const profile = () => profiles[state.profile];
  const snap = value => Math.round(value / Number($("snap-select").value)) * Number($("snap-select").value);

  function asset(path) { return `${ASSET}${path}`; }
  function pushHistory() { state.history.push(exportData()); if (state.history.length > 40) state.history.shift(); state.future = []; updateHistoryButtons(); }
  function updateHistoryButtons() { $("undo-button").disabled = state.history.length === 0; $("redo-button").disabled = state.future.length === 0; }

  function renderTree() {
    $("scene-tree").innerHTML = objects.map((item, index) => `
      <div class="tree-row ${item.parent ? "child" : ""} ${item.id === state.selectedId ? "active" : ""} ${item.visible ? "" : "is-hidden"}" data-id="${item.id}">
        <span class="tree-icon">${item.parent ? "└" : String(index + 1).padStart(2, "0")}</span>
        <span class="tree-name">${item.name}</span>
        <button class="tree-visibility" data-visible="${item.id}" type="button" title="切换显示">${item.visible ? "ON" : "OFF"}</button>
      </div>`).join("");
  }

  function nodeContent(item) {
    if (item.id === "board") return `<img class="board-art" src="${asset("art/boards/terracotta_warriors/terracotta_battlefield_board_bg_gridless_v1.png")}" alt=""><div class="board-lines"></div><div class="river"></div><div class="board-title">缓冲区<br><br><br>大本营</div>`;
    if (item.virtual) return "";
    if (item.smoke) return `<div class="smoke-sprite"></div>`;
    let html = item.asset ? `<img class="asset ${item.mirror ? "mirror-x" : ""}" src="${asset(item.asset)}" alt="">` : "";
    if (item.id === "faction-left") html += `<span class="portrait-mask" style="left:9%;top:18%;width:19%;height:60%"><img src="${asset("art/pieces/terracotta_warriors/red_general_idle.png")}" alt="赤方将帅"></span>`;
    if (item.id === "faction-right") html += `<span class="portrait-mask" style="left:72.5%;top:18%;width:19%;height:60%"><img src="${asset("art/pieces/terracotta_warriors/black_general_idle.png")}" alt="玄方将帅"></span>`;
    if (item.id === "unit-info") {
      const piece = pieceData[$("piece-select").value];
      html += `<span class="unit-mask" style="left:13%;top:18%;width:74%;height:72%">${piece.asset ? `<img src="${asset(piece.asset)}" alt="${piece.name}">` : ""}</span>`;
    }
    html += (item.texts || []).filter(layer => item.id !== "detail" || !["move", "skill"].includes(layer.id)).map(layer => `<span class="hud-text ${layer.align}" data-text-id="${layer.id}" style="left:${layer.rect.x * 100}%;top:${layer.rect.y * 100}%;width:${layer.rect.w * 100}%;height:${layer.rect.h * 100}%;font-size:${layer.fontSize}px">${escapeHtml(layer.value)}</span>`).join("");
    if (item.id === "detail") {
      html += `<span class="detail-button" style="left:76%;top:10.7%;width:10%;height:78.6%">${escapeHtml(item.texts[2].value)}</span><span class="detail-button" style="left:87%;top:10.7%;width:10%;height:78.6%">${escapeHtml(item.texts[3].value)}</span>`;
    }
    return html;
  }

  function renderStage() {
    const root = $("stage-elements");
    root.innerHTML = objects.filter(item => !item.virtual).map(item => {
      const classes = ["hud-node", item.id === "board" ? "board-node" : "", item.smoke ? `smoke-node ${item.smoke}` : "", item.id === state.selectedId ? "selected" : "", item.visible ? "" : "hidden"].join(" ");
      return `<div class="${classes}" data-id="${item.id}" data-label="${item.name}" style="left:${item.rect.x}px;top:${item.rect.y}px;width:${item.rect.w}px;height:${item.rect.h}px;z-index:${item.z}">${nodeContent(item)}</div>`;
    }).join("");
    updateStageScale();
  }

  function renderInspector() {
    const item = selected();
    $("selection-kind").textContent = item.kind;
    $("selection-name").textContent = item.name;
    $("selection-binding").textContent = item.binding;
    $("rect-x").value = Math.round(item.rect.x);
    $("rect-y").value = Math.round(item.rect.y);
    $("rect-w").value = Math.round(item.rect.w);
    $("rect-h").value = Math.round(item.rect.h);
    $("visible-input").checked = item.visible;
    $("aspect-input").checked = Boolean(item.lockAspect);
    $("z-input").value = item.z;
    $("z-output").value = item.z;
    const p = profile();
    $("normalized-readout").textContent = `X ${(item.rect.x / p.width).toFixed(3)} · Y ${(item.rect.y / p.height).toFixed(3)} · W ${(item.rect.w / p.width).toFixed(3)} · H ${(item.rect.h / p.height).toFixed(3)}`;
    $("status-message").textContent = `已选择：${item.name} · ${item.binding}`;
    renderTextInspector(item);
  }

  function renderTextInspector(item) {
    const layers = item.texts || [];
    $("no-text").hidden = layers.length > 0;
    $("text-controls").hidden = layers.length === 0;
    if (!layers.length) return;
    if (!layers.some(layer => layer.id === state.textId)) state.textId = layers[0].id;
    $("text-layer-select").innerHTML = layers.map(layer => `<option value="${layer.id}" ${layer.id === state.textId ? "selected" : ""}>${layer.name}</option>`).join("");
    const layer = layers.find(entry => entry.id === state.textId);
    $("text-content").value = layer.value;
    $("font-size-input").value = layer.fontSize;
    $("font-range").value = layer.fontSize;
    $("font-output").value = layer.fontSize;
    $("align-select").value = layer.align;
    $("text-x").value = Math.round(layer.rect.x * item.rect.w);
    $("text-y").value = Math.round(layer.rect.y * item.rect.h);
    $("text-w").value = Math.round(layer.rect.w * item.rect.w);
    $("text-h").value = Math.round(layer.rect.h * item.rect.h);
    $("text-binding").textContent = `绑定：${layer.binding}`;
  }

  function renderAll() { renderTree(); renderStage(); renderInspector(); updateHistoryButtons(); }
  function selectItem(id) { state.selectedId = id; state.textId = null; renderAll(); }

  function updateStageScale(forceFit = false) {
    const p = profile();
    const shell = $("stage-shell");
    document.documentElement.style.setProperty("--design-w", p.width);
    document.documentElement.style.setProperty("--design-h", p.height);
    const fit = Math.min((shell.clientWidth - 32) / p.width, (shell.clientHeight - 32) / p.height);
    if (forceFit || !Number.isFinite(state.zoom)) state.zoom = Math.min(1, fit);
    $("stage").style.transform = `scale(${state.zoom})`;
    $("zoom-readout").textContent = `${Math.round(state.zoom * 100)}%`;
    $("canvas-size").textContent = `${p.width} × ${p.height}`;
  }

  function mutateRect() {
    const item = selected();
    item.rect = { x: Number($("rect-x").value), y: Number($("rect-y").value), w: Math.max(8, Number($("rect-w").value)), h: Math.max(8, Number($("rect-h").value)) };
    renderAll();
  }

  function updatePreviewState() {
    const key = $("piece-select").value;
    const piece = pieceData[key];
    const side = $("side-select").value === "red" ? "赤" : "玄";
    const unit = objects.find(item => item.id === "unit-info");
    unit.texts[0].value = piece.name;
    const objective = objects.find(item => item.id === "objective");
    objective.texts.find(layer => layer.id === "selection").value = `行动方: ${side} 已选: ${piece.name === "未选择" ? "无" : piece.name}`;
    const detail = objects.find(item => item.id === "detail");
    detail.texts.find(layer => layer.id === "summary").value = piece.description;
    detail.texts.find(layer => layer.id === "skill").value = piece.skill;
    detail.visible = key !== "none" && $("drawer-input").checked;
    renderAll();
  }

  function exportData() {
    return { schema: "veilfront.match_hud_layout.v4", scene: "res://scenes/dev/ui/match_hud_v2_interaction_lab.tscn", profile: state.profile, objects: clone(objects) };
  }

  function importData(data) {
    if (!data || !Array.isArray(data.objects)) throw new Error("布局 JSON 缺少 objects。");
    if (profiles[data.profile]) {
      state.profile = data.profile;
      $("profile-select").value = data.profile;
    }
    for (const incoming of data.objects) {
      const target = objects.find(item => item.id === incoming.id);
      if (!target) continue;
      target.rect = { ...target.rect, ...incoming.rect };
      target.visible = incoming.visible !== false;
      target.z = Number.isFinite(Number(incoming.z)) ? Number(incoming.z) : target.z;
      if (Array.isArray(incoming.texts) && target.texts) target.texts = incoming.texts;
    }
    renderAll();
  }

  function escapeHtml(value) { return String(value).replace(/[&<>'"]/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[char]); }

  $("scene-tree").addEventListener("click", event => {
    const visibleButton = event.target.closest("[data-visible]");
    if (visibleButton) { event.stopPropagation(); pushHistory(); const item = objects.find(entry => entry.id === visibleButton.dataset.visible); item.visible = !item.visible; renderAll(); return; }
    const row = event.target.closest("[data-id]");
    if (row) selectItem(row.dataset.id);
  });
  $("stage-elements").addEventListener("pointerdown", event => {
    const node = event.target.closest(".hud-node");
    if (!node) return;
    selectItem(node.dataset.id);
    const item = selected();
    pushHistory();
    state.drag = { pointerId: event.pointerId, startX: event.clientX, startY: event.clientY, x: item.rect.x, y: item.rect.y };
    node.setPointerCapture(event.pointerId);
  });
  $("stage-elements").addEventListener("pointermove", event => {
    if (!state.drag || event.pointerId !== state.drag.pointerId) return;
    const item = selected();
    const useSnap = !event.shiftKey;
    const x = state.drag.x + (event.clientX - state.drag.startX) / state.zoom;
    const y = state.drag.y + (event.clientY - state.drag.startY) / state.zoom;
    item.rect.x = useSnap ? snap(x) : Math.round(x);
    item.rect.y = useSnap ? snap(y) : Math.round(y);
    renderStage(); renderInspector();
  });
  $("stage-elements").addEventListener("pointerup", () => { state.drag = null; });

  ["rect-x", "rect-y", "rect-w", "rect-h"].forEach(id => $(id).addEventListener("change", () => { pushHistory(); mutateRect(); }));
  $("visible-input").addEventListener("change", () => { pushHistory(); selected().visible = $("visible-input").checked; renderAll(); });
  $("aspect-input").addEventListener("change", () => { selected().lockAspect = $("aspect-input").checked; });
  $("z-input").addEventListener("input", () => { selected().z = Number($("z-input").value); $("z-output").value = selected().z; renderStage(); });
  $("z-input").addEventListener("change", pushHistory);

  document.querySelectorAll("[data-anchor]").forEach(button => button.addEventListener("click", () => {
    pushHistory();
    const item = selected(); const p = profile(); const key = button.dataset.anchor;
    if (key[1] === "l") item.rect.x = 0; else if (key[1] === "c") item.rect.x = (p.width - item.rect.w) / 2; else item.rect.x = p.width - item.rect.w;
    if (key[0] === "t") item.rect.y = 0; else if (key[0] === "m" || key[0] === "c") item.rect.y = (p.height - item.rect.h) / 2; else item.rect.y = p.height - item.rect.h;
    renderAll();
  }));

  document.querySelectorAll(".tabs button").forEach(button => button.addEventListener("click", () => {
    document.querySelectorAll(".tabs button").forEach(tab => tab.classList.toggle("active", tab === button));
    document.querySelectorAll(".tab-page").forEach(page => page.classList.toggle("active", page.dataset.page === button.dataset.tab));
  }));
  $("text-layer-select").addEventListener("change", () => { state.textId = $("text-layer-select").value; renderTextInspector(selected()); });
  function mutateText() {
    const item = selected(); const layer = item.texts.find(entry => entry.id === state.textId);
    layer.value = $("text-content").value; layer.fontSize = Number($("font-size-input").value); layer.align = $("align-select").value;
    layer.rect = { x: Number($("text-x").value) / item.rect.w, y: Number($("text-y").value) / item.rect.h, w: Number($("text-w").value) / item.rect.w, h: Number($("text-h").value) / item.rect.h };
    $("font-range").value = layer.fontSize; $("font-output").value = layer.fontSize; renderStage();
  }
  ["text-content", "font-size-input", "align-select", "text-x", "text-y", "text-w", "text-h"].forEach(id => $(id).addEventListener("change", () => { pushHistory(); mutateText(); }));
  $("font-range").addEventListener("input", () => { $("font-size-input").value = $("font-range").value; $("font-output").value = $("font-range").value; mutateText(); });

  $("profile-select").addEventListener("change", () => {
    const previous = profile();
    const nextKey = $("profile-select").value;
    const next = profiles[nextKey];
    pushHistory();
    for (const item of objects) {
      item.rect.x *= next.width / previous.width;
      item.rect.w *= next.width / previous.width;
      item.rect.y *= next.height / previous.height;
      item.rect.h *= next.height / previous.height;
    }
    state.profile = nextKey;
    renderAll();
    updateStageScale(true);
  });
  $("fit-button").addEventListener("click", () => updateStageScale(true));
  $("toggle-grid").addEventListener("click", () => { $("canvas-grid").classList.toggle("hidden"); $("toggle-grid").classList.toggle("is-active"); });
  $("toggle-safe").addEventListener("click", () => { $("safe-area").classList.toggle("hidden"); $("toggle-safe").classList.toggle("is-active"); });
  $("side-select").addEventListener("change", updatePreviewState);
  $("piece-select").addEventListener("change", updatePreviewState);
  $("drawer-input").addEventListener("change", updatePreviewState);
  $("motion-input").addEventListener("change", () => $("stage").classList.toggle("no-motion", !$("motion-input").checked));
  $("timer-input").addEventListener("input", () => { $("timer-output").value = `${$("timer-input").value}%`; const timer = objects.find(item => item.id === "timer-body"); const ratio = Number($("timer-input").value) / 100; timer.rect.y = 443 + 232 * (1 - ratio); timer.rect.h = 232 * ratio; renderStage(); });
  $("round-input").addEventListener("change", () => { const layer = objects.find(item => item.id === "round-display").texts[0]; layer.value = $("round-input").value; renderStage(); });

  $("undo-button").addEventListener("click", () => { if (!state.history.length) return; state.future.push(exportData()); importData(state.history.pop()); updateHistoryButtons(); });
  $("redo-button").addEventListener("click", () => { if (!state.future.length) return; state.history.push(exportData()); importData(state.future.pop()); updateHistoryButtons(); });
  $("copy-json").addEventListener("click", async () => {
    const value = JSON.stringify(exportData(), null, 2);
    try {
      if (navigator.clipboard && window.isSecureContext) await navigator.clipboard.writeText(value);
      else {
        const helper = document.createElement("textarea"); helper.value = value; helper.style.position = "fixed"; helper.style.opacity = "0";
        document.body.appendChild(helper); helper.select(); document.execCommand("copy"); helper.remove();
      }
      $("status-message").textContent = "布局 JSON 已复制。";
    } catch (error) { $("status-message").textContent = `复制失败：${error.message}`; }
  });
  $("download-json").addEventListener("click", () => { const url = URL.createObjectURL(new Blob([JSON.stringify(exportData(), null, 2)], { type: "application/json" })); const link = document.createElement("a"); link.href = url; link.download = `match_hud_v4_${state.profile}.json`; link.click(); URL.revokeObjectURL(url); });
  $("import-json").addEventListener("click", () => $("file-input").click());
  $("file-input").addEventListener("change", async () => { const file = $("file-input").files[0]; if (!file) return; try { pushHistory(); importData(JSON.parse(await file.text())); } catch (error) { $("status-message").textContent = `导入失败：${error.message}`; } });
  $("reset-layout").addEventListener("click", () => { pushHistory(); objects.splice(0, objects.length, ...clone(defaultObjects)); state.selectedId = "board"; renderAll(); });
  window.addEventListener("resize", () => updateStageScale(true));
  window.addEventListener("keydown", event => { if (event.key === "Escape") state.drag = null; if (event.ctrlKey && event.key.toLowerCase() === "z") { event.preventDefault(); (event.shiftKey ? $("redo-button") : $("undo-button")).click(); } });

  renderAll();
  requestAnimationFrame(() => updateStageScale(true));
})();
