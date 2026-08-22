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
  const objectiveModes = {
    tutorial: [
      { value: "战局与行动", name: "面板标题", fontSize: 18, binding: "static" },
      { value: "关卡  T0 · 操作校准", name: "关卡", fontSize: 15, binding: "tutorial_chapter" },
      { value: "目标  完成选择、取消、标注与一次确认移动", name: "关卡目标", fontSize: 14, binding: "tutorial_goal" },
      { value: "步骤  1 / 3", name: "步骤", fontSize: 15, binding: "tutorial_step" },
      { value: "当前  先选择，再取消", name: "当前操作", fontSize: 15, binding: "tutorial_current" },
      { value: "提示  左键选择红兵，右键取消", name: "提示／状态", fontSize: 14, binding: "tutorial_hint" }
    ],
    match: [
      { value: "战局与行动", name: "面板标题", fontSize: 18, binding: "static" },
      { value: "行动方：赤　已选：象", name: "选择状态", fontSize: 14, binding: "selection_status" },
      { value: "我方已发现旗帜：1 / 3", name: "旗帜数", fontSize: 14, binding: "own_flags" },
      { value: "我方阵亡：无", name: "我方阵亡", fontSize: 14, binding: "own_casualties" },
      { value: "敌方阵亡：兵 × 1", name: "敌方阵亡", fontSize: 14, binding: "enemy_casualties" },
      { value: "位置：（6，4）", name: "位置", fontSize: 14, binding: "board_position" }
    ]
  };
  const resizeHandles = ["nw", "n", "ne", "e", "se", "s", "sw", "w"];
  const draftStorageKey = "veilfront.match_hud_layout.v5.draft";
  const text = (id, name, value, rect, fontSize, align = "left", binding = "static") => ({ id, name, value, rect, fontSize, align, binding });
  const objects = [
    { id: "board", parent: null, name: "棋盘可视区域", kind: "BOARD", binding: "board_rect", rect: { x: 340, y: 32, w: 600, h: 544 }, z: 0, visible: true },
    { id: "faction-left", parent: null, name: "赤方军势", kind: "PANEL", binding: "faction_left", asset: "art/ui/terracotta_hud_v2/faction_status_plate_v1.png", rect: { x: 48, y: 10, w: 306, h: 120 }, z: 4, visible: true, texts: [text("name", "阵营名称", "赤方军势", { x: .32, y: .29, w: .44, h: .21 }, 14), text("stats", "阵营数据", "墙 完好 · 旗 0 · 损 0", { x: .327, y: .5, w: .51, h: .17 }, 10)] },
    { id: "faction-right", parent: null, name: "玄方军势", kind: "PANEL", binding: "faction_right", asset: "art/ui/terracotta_hud_v2/faction_status_plate_v1.png", mirror: true, rect: { x: 928, y: 10, w: 303, h: 119 }, z: 4, visible: true, texts: [text("name", "阵营名称", "玄方军势", { x: .22, y: .295, w: .446, h: .21 }, 14, "right"), text("stats", "阵营数据", "墙 破损 · 旗 0 · 损 1", { x: .165, y: .505, w: .512, h: .168 }, 10, "right")] },
    { id: "minimap", parent: null, name: "战场态势", kind: "PANEL", binding: "minimap", asset: "art/ui/terracotta_hud_v2/minimap_frame_v1.png", rect: { x: 64, y: 130, w: 241, h: 264 }, z: 3, visible: true, texts: [text("title", "小地图标题", "战场态势", { x: .18, y: .04, w: .64, h: .1 }, 12, "center")] },
    { id: "unit-info", parent: null, name: "棋子信息卡", kind: "PANEL", binding: "unit_info", asset: "art/ui/terracotta_hud_v2/unit_info_card_v1.png", rect: { x: 129, y: 408, w: 184, h: 246 }, z: 4, visible: true, texts: [text("piece-name", "棋子名称", "象", { x: .14, y: .055, w: .72, h: .09 }, 14, "center", "unit_name")] },
    { id: "objective", parent: null, name: "战局与行动", kind: "PANEL", binding: "objective_events", asset: "art/ui/terracotta_hud_v2/objective_event_panel_v1.png", rect: { x: 1280, y: 144, w: 360, h: 504 }, z: 3, visible: true, texts: [text("heading", "面板标题", "战局与行动", { x: .16, y: .13, w: .68, h: .085 }, 18, "center"), text("row-1", "关卡", "关卡  T0 · 操作校准", { x: .245, y: .245, w: .67, h: .09 }, 15, "left", "tutorial_chapter"), text("row-2", "关卡目标", "目标  完成选择、取消、标注与一次确认移动", { x: .245, y: .345, w: .67, h: .12 }, 14, "left", "tutorial_goal"), text("row-3", "步骤", "步骤  1 / 3", { x: .245, y: .49, w: .67, h: .08 }, 15, "left", "tutorial_step"), text("row-4", "当前操作", "当前  先选择，再取消", { x: .245, y: .59, w: .67, h: .09 }, 15, "left", "tutorial_current"), text("row-5", "提示／状态", "提示  左键选择红兵，右键取消", { x: .245, y: .695, w: .67, h: .12 }, 14, "left", "tutorial_hint")] },
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
  const state = { profile: "1680x720", selectedId: "objective", objectiveMode: "tutorial", zoom: 1, history: [], future: [], drag: null, textId: null };
  const $ = id => document.getElementById(id);
  const selected = () => objects.find(item => item.id === state.selectedId);
  const profile = () => profiles[state.profile];
  const snap = value => Math.round(value / Number($("snap-select").value)) * Number($("snap-select").value);
  const cloneRect = rect => ({ x: rect.x, y: rect.y, w: rect.w, h: rect.h });

  function computeSubjectRect() {
    const protectedObjects = objects.filter(item => item.visible && !item.virtual && item.id !== "objective");
    if (!protectedObjects.length) return { x: 0, y: 0, w: 0, h: 0 };
    const left = Math.min(...protectedObjects.map(item => item.rect.x));
    const top = Math.min(...protectedObjects.map(item => item.rect.y));
    const right = Math.max(...protectedObjects.map(item => item.rect.x + item.rect.w));
    const bottom = Math.max(...protectedObjects.map(item => item.rect.y + item.rect.h));
    return { x: left, y: top, w: right - left, h: bottom - top };
  }

  function rectsOverlap(a, b, gap = 0) {
    return a.x < b.x + b.w + gap && a.x + a.w + gap > b.x && a.y < b.y + b.h + gap && a.y + a.h + gap > b.y;
  }

  function objectiveIsUnsafe() {
    const objective = objects.find(item => item.id === "objective");
    return objective.visible && rectsOverlap(objective.rect, computeSubjectRect(), 16);
  }

  function clampRect(rect, minimum = { w: 48, h: 32 }) {
    const p = profile();
    rect.w = Math.max(minimum.w, Math.min(rect.w, p.width));
    rect.h = Math.max(minimum.h, Math.min(rect.h, p.height));
    rect.x = Math.max(0, Math.min(rect.x, p.width - rect.w));
    rect.y = Math.max(0, Math.min(rect.y, p.height - rect.h));
    return rect;
  }

  function updateSubjectOverlay() {
    const rect = computeSubjectRect();
    const overlay = $("subject-safe-area");
    overlay.style.left = `${rect.x}px`;
    overlay.style.top = `${rect.y}px`;
    overlay.style.width = `${rect.w}px`;
    overlay.style.height = `${rect.h}px`;
  }

  function updateSafetyReadout(item) {
    const readout = $("safety-readout");
    if (item.id !== "objective") {
      readout.dataset.status = "neutral";
      readout.querySelector("strong").textContent = "主体安全检查";
      readout.querySelector("span").textContent = "选择“战局与行动”板后显示检测结果。";
      return;
    }
    const unsafe = objectiveIsUnsafe();
    readout.dataset.status = unsafe ? "unsafe" : "safe";
    readout.querySelector("strong").textContent = unsafe ? "正在遮挡游戏主体" : "未遮挡游戏主体";
    readout.querySelector("span").textContent = unsafe
      ? "请继续向右移动、缩小面板，或切换到 21:9 右置预设。"
      : "面板与游戏主体边界保持至少 16 px 间距。";
  }

  function applyObjectiveMode(mode) {
    state.objectiveMode = objectiveModes[mode] ? mode : "tutorial";
    $("objective-mode-select").value = state.objectiveMode;
    const objective = objects.find(item => item.id === "objective");
    const values = objectiveModes[state.objectiveMode];
    objective.texts.forEach((layer, index) => {
      const source = values[index];
      layer.name = source.name;
      layer.value = source.value;
      layer.fontSize = source.fontSize;
      layer.binding = source.binding;
    });
  }

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
      const unsafe = item.id === "objective" && objectiveIsUnsafe();
      const classes = ["hud-node", item.id === "board" ? "board-node" : "", item.smoke ? `smoke-node ${item.smoke}` : "", item.id === state.selectedId ? "selected" : "", unsafe ? "is-unsafe" : "", item.visible ? "" : "hidden"].join(" ");
      const handles = item.id === state.selectedId && item.visible
        ? resizeHandles.map(handle => `<button class="resize-handle" data-handle="${handle}" type="button" aria-label="${handle} 方向缩放"></button>`).join("")
        : "";
      return `<div class="${classes}" data-id="${item.id}" data-label="${item.name}" style="left:${item.rect.x}px;top:${item.rect.y}px;width:${item.rect.w}px;height:${item.rect.h}px;z-index:${item.z}">${nodeContent(item)}${handles}</div>`;
    }).join("");
    updateSubjectOverlay();
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
    updateSafetyReadout(item);
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
    const minimum = item.id === "objective" ? { w: 280, h: 360 } : { w: 24, h: 24 };
    item.rect = clampRect({ x: Number($("rect-x").value), y: Number($("rect-y").value), w: Number($("rect-w").value), h: Number($("rect-h").value) }, minimum);
    renderAll();
  }

  function changeProfile(nextKey) {
    if (!profiles[nextKey] || nextKey === state.profile) return;
    const previous = profile();
    const next = profiles[nextKey];
    state.profile = nextKey;
    for (const item of objects) {
      item.rect.x *= next.width / previous.width;
      item.rect.w *= next.width / previous.width;
      item.rect.y *= next.height / previous.height;
      item.rect.h *= next.height / previous.height;
      clampRect(item.rect, item.id === "objective" ? { w: 280, h: 360 } : { w: 24, h: 24 });
    }
    $("profile-select").value = nextKey;
  }

  function applyObjectivePreset(forceWide = false) {
    pushHistory();
    if (forceWide && state.profile !== "1680x720") {
      state.profile = "1680x720";
      $("profile-select").value = state.profile;
      for (const item of objects) clampRect(item.rect, item.id === "objective" ? { w: 280, h: 360 } : { w: 24, h: 24 });
    }
    const p = profile();
    const subject = computeSubjectRect();
    const gap = 24;
    const desiredWidth = Math.min(380, p.width - 40);
    let x = Math.max(subject.x + subject.w + gap, p.width - desiredWidth - 24);
    let width = p.width - x - 24;
    if (width < 280) {
      width = Math.min(320, p.width - 48);
      x = p.width - width - 24;
    }
    const objective = objects.find(item => item.id === "objective");
    objective.rect = clampRect({ x, y: Math.max(40, (p.height - 504) / 2), w: width, h: Math.min(504, p.height - 80) }, { w: 280, h: 360 });
    state.selectedId = "objective";
    state.textId = null;
    applyObjectiveMode("tutorial");
    renderAll();
    updateStageScale(true);
  }

  function updatePreviewState() {
    const key = $("piece-select").value;
    const piece = pieceData[key];
    const side = $("side-select").value === "red" ? "赤" : "玄";
    const unit = objects.find(item => item.id === "unit-info");
    unit.texts[0].value = piece.name;
    const objective = objects.find(item => item.id === "objective");
    if (state.objectiveMode === "match") objective.texts.find(layer => layer.id === "row-1").value = `行动方：${side}　已选：${piece.name === "未选择" ? "无" : piece.name}`;
    const detail = objects.find(item => item.id === "detail");
    detail.texts.find(layer => layer.id === "summary").value = piece.description;
    detail.texts.find(layer => layer.id === "skill").value = piece.skill;
    detail.visible = key !== "none" && $("drawer-input").checked;
    renderAll();
  }

  function exportData() {
    return {
      schema: "veilfront.match_hud_layout.v5",
      scene: "res://scenes/dev/ui/match_hud_v2_interaction_lab.tscn",
      profile: state.profile,
      preview: { objective_mode: state.objectiveMode },
      guides: { gameplay_subject_rect: computeSubjectRect(), objective_overlaps_subject: objectiveIsUnsafe() },
      objects: clone(objects)
    };
  }

  function importData(data) {
    if (!data || !Array.isArray(data.objects)) throw new Error("布局 JSON 缺少 objects。");
    if (data.schema && !["veilfront.match_hud_layout.v4", "veilfront.match_hud_layout.v5"].includes(data.schema)) throw new Error(`不支持的布局 schema：${data.schema}`);
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
      if (Array.isArray(incoming.texts) && target.texts) {
        target.texts = incoming.texts.map((layer, index) => target.id === "objective" ? { ...layer, id: index === 0 ? "heading" : `row-${index}` } : layer);
      }
    }
    state.objectiveMode = data.preview?.objective_mode === "match" || data.schema === "veilfront.match_hud_layout.v4" ? "match" : "tutorial";
    $("objective-mode-select").value = state.objectiveMode;
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
    event.preventDefault();
    if (state.selectedId !== node.dataset.id) selectItem(node.dataset.id);
    const item = selected();
    pushHistory();
    const handle = event.target.closest("[data-handle]");
    state.drag = {
      type: handle ? "resize" : "move",
      direction: handle?.dataset.handle || "",
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      startRect: cloneRect(item.rect),
      ratio: item.rect.w / item.rect.h
    };
    $("stage-elements").setPointerCapture(event.pointerId);
  });
  $("stage-elements").addEventListener("pointermove", event => {
    if (!state.drag || event.pointerId !== state.drag.pointerId) return;
    const item = selected();
    const useSnap = !event.shiftKey;
    const dx = (event.clientX - state.drag.startX) / state.zoom;
    const dy = (event.clientY - state.drag.startY) / state.zoom;
    const start = state.drag.startRect;
    if (state.drag.type === "move") {
      const x = start.x + dx;
      const y = start.y + dy;
      item.rect.x = useSnap ? snap(x) : Math.round(x);
      item.rect.y = useSnap ? snap(y) : Math.round(y);
      clampRect(item.rect, item.id === "objective" ? { w: 280, h: 360 } : { w: 24, h: 24 });
    } else {
      const direction = state.drag.direction;
      let rect = cloneRect(start);
      if (direction.includes("e")) rect.w = start.w + dx;
      if (direction.includes("s")) rect.h = start.h + dy;
      if (direction.includes("w")) { rect.x = start.x + dx; rect.w = start.w - dx; }
      if (direction.includes("n")) { rect.y = start.y + dy; rect.h = start.h - dy; }
      const minimum = item.id === "objective" ? { w: 280, h: 360 } : { w: 24, h: 24 };
      rect.w = Math.max(minimum.w, rect.w);
      rect.h = Math.max(minimum.h, rect.h);
      if (item.lockAspect) {
        const horizontalOnly = ["e", "w"].includes(direction);
        const verticalOnly = ["n", "s"].includes(direction);
        if (horizontalOnly) {
          rect.h = rect.w / state.drag.ratio;
          rect.y = start.y + (start.h - rect.h) / 2;
        } else if (verticalOnly) {
          rect.w = rect.h * state.drag.ratio;
          rect.x = start.x + (start.w - rect.w) / 2;
        } else if (Math.abs(dx) >= Math.abs(dy * state.drag.ratio)) {
          rect.h = rect.w / state.drag.ratio;
          if (direction.includes("n")) rect.y = start.y + start.h - rect.h;
        } else {
          rect.w = rect.h * state.drag.ratio;
          if (direction.includes("w")) rect.x = start.x + start.w - rect.w;
        }
      }
      if (useSnap) rect = { x: snap(rect.x), y: snap(rect.y), w: snap(rect.w), h: snap(rect.h) };
      item.rect = clampRect(rect, minimum);
    }
    renderStage(); renderInspector();
  });
  const finishDrag = event => {
    if (!state.drag) return;
    if ($("stage-elements").hasPointerCapture(state.drag.pointerId)) $("stage-elements").releasePointerCapture(state.drag.pointerId);
    state.drag = null;
    renderAll();
  };
  $("stage-elements").addEventListener("pointerup", finishDrag);
  $("stage-elements").addEventListener("pointercancel", finishDrag);

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
    pushHistory();
    changeProfile($("profile-select").value);
    renderAll();
    updateStageScale(true);
  });
  $("fit-button").addEventListener("click", () => updateStageScale(true));
  $("toggle-grid").addEventListener("click", () => { $("canvas-grid").classList.toggle("hidden"); $("toggle-grid").classList.toggle("is-active"); });
  $("toggle-safe").addEventListener("click", () => {
    $("safe-area").classList.toggle("hidden");
    $("subject-safe-area").classList.toggle("hidden");
    $("toggle-safe").classList.toggle("is-active");
  });
  $("wide-objective-preset").addEventListener("click", () => applyObjectivePreset(true));
  $("current-objective-preset").addEventListener("click", () => applyObjectivePreset(false));
  $("objective-mode-select").addEventListener("change", () => {
    pushHistory();
    applyObjectiveMode($("objective-mode-select").value);
    updatePreviewState();
  });
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
  $("download-json").addEventListener("click", () => { const url = URL.createObjectURL(new Blob([JSON.stringify(exportData(), null, 2)], { type: "application/json" })); const link = document.createElement("a"); link.href = url; link.download = `match_hud_v5_${state.profile}.json`; link.click(); URL.revokeObjectURL(url); });
  $("import-json").addEventListener("click", () => $("file-input").click());
  $("file-input").addEventListener("change", async () => { const file = $("file-input").files[0]; if (!file) return; try { pushHistory(); importData(JSON.parse(await file.text())); } catch (error) { $("status-message").textContent = `导入失败：${error.message}`; } });
  $("save-draft").addEventListener("click", () => {
    try {
      localStorage.setItem(draftStorageKey, JSON.stringify(exportData()));
      $("status-message").textContent = "草稿已保存到当前浏览器。";
    } catch (error) { $("status-message").textContent = `保存失败：${error.message}`; }
  });
  $("load-draft").addEventListener("click", () => {
    try {
      const raw = localStorage.getItem(draftStorageKey);
      if (!raw) { $("status-message").textContent = "当前浏览器还没有 V5 草稿。"; return; }
      pushHistory();
      importData(JSON.parse(raw));
      updateStageScale(true);
      $("status-message").textContent = "已载入浏览器草稿。";
    } catch (error) { $("status-message").textContent = `载入失败：${error.message}`; }
  });
  $("reset-layout").addEventListener("click", () => {
    pushHistory();
    objects.splice(0, objects.length, ...clone(defaultObjects));
    state.profile = "1680x720";
    state.selectedId = "objective";
    state.textId = null;
    $("profile-select").value = state.profile;
    applyObjectiveMode("tutorial");
    renderAll();
    updateStageScale(true);
  });
  window.addEventListener("resize", () => updateStageScale(true));
  window.addEventListener("keydown", event => {
    if (event.key === "Escape") state.drag = null;
    if (event.ctrlKey && event.key.toLowerCase() === "z") {
      event.preventDefault();
      (event.shiftKey ? $("redo-button") : $("undo-button")).click();
      return;
    }
    const editing = event.target.closest("input, textarea, select, [contenteditable='true']");
    if (editing || !["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) return;
    event.preventDefault();
    pushHistory();
    const item = selected();
    const amount = event.shiftKey ? Number($("snap-select").value) : 1;
    const dx = event.key === "ArrowLeft" ? -amount : event.key === "ArrowRight" ? amount : 0;
    const dy = event.key === "ArrowUp" ? -amount : event.key === "ArrowDown" ? amount : 0;
    if (event.altKey) {
      item.rect.w += dx;
      item.rect.h += dy;
    } else {
      item.rect.x += dx;
      item.rect.y += dy;
    }
    clampRect(item.rect, item.id === "objective" ? { w: 280, h: 360 } : { w: 24, h: 24 });
    renderAll();
  });

  applyObjectiveMode("tutorial");
  renderAll();
  requestAnimationFrame(() => updateStageScale(true));
})();
