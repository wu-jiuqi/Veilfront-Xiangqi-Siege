(() => {
  "use strict";

  const BOARD_ID = "board-visible-region";
  const STORAGE_KEY = "veilfront.board-ui-layout-editor.v2";
  const MIN_UI_SIZE = { w: 40, h: 32 };
  const MIN_BOARD_SIZE = { w: 160, h: 120 };

  const PROFILE_DEFS = {
    "1280x720": { width: 1280, height: 720, label: "16:9" },
    "1680x720": { width: 1680, height: 720, label: "21:9" },
    "1280x800": { width: 1280, height: 800, label: "16:10" },
    "1280x960": { width: 1280, height: 960, label: "4:3" }
  };

  const BOARD_META = {
    id: BOARD_ID,
    name: "棋盘默认可视区域",
    function: "玩家进入棋局时，屏幕内默认显示的棋盘区域；不是完整棋盘世界尺寸。",
    kind: "board",
    visible: true,
    lockAspect: false
  };

  const DEFAULT_BOARD_RECT = { x: 260, y: 104, w: 760, h: 450 };
  const DEFAULT_CATALOG = [
    {
      id: "turn-status",
      name: "顶部回合条",
      function: "显示当前回合、行动方和局势状态。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/turn_status_bar_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 425, y: 12, w: 430, h: 88 }
    },
    {
      id: "faction-left",
      name: "左方阵营状态",
      function: "显示左方阵营信息、资源和状态。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/faction_status_plate_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 18, y: 70, w: 255, h: 100 }
    },
    {
      id: "faction-right",
      name: "右方阵营状态",
      function: "显示右方阵营信息、资源和状态。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/faction_status_plate_v1.png",
      mirrorX: true,
      visible: true,
      lockAspect: true,
      baseRect: { x: 1007, y: 70, w: 255, h: 100 }
    },
    {
      id: "unit-info",
      name: "单位信息卡",
      function: "显示当前选中棋子的身份、属性与状态。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/unit_info_card_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 18, y: 458, w: 178, h: 238 }
    },
    {
      id: "objective-events",
      name: "目标与事件",
      function: "显示当前目标、战场事件和提示信息。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/objective_event_panel_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 1076, y: 183, w: 186, h: 268 }
    },
    {
      id: "action-bar",
      name: "底部行动栏",
      function: "承载移动、攻击、技能和回合操作。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/action_bar_frame_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 435, y: 578, w: 410, h: 132 }
    },
    {
      id: "minimap",
      name: "小地图",
      function: "显示完整棋盘概览、视野和战场标记。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/minimap_frame_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 1094, y: 516, w: 168, h: 184 }
    }
  ];

  const HANDLE_NAMES = ["nw", "n", "ne", "e", "se", "s", "sw", "w"];
  const HANDLE_HTML = `<div class="selection-handles" aria-hidden="true">${HANDLE_NAMES.map(handle => `<i class="resize-handle" data-handle="${handle}"></i>`).join("")}</div>`;

  const clone = value => JSON.parse(JSON.stringify(value));
  const clamp = (value, min, max) => Math.min(Math.max(value, min), max);
  const currentProfileDef = () => PROFILE_DEFS[state.currentProfile];
  const currentLayout = () => state.layouts[state.currentProfile];
  const webAssetPath = asset => asset ? `../../${asset.replace(/^res:\/\//, "")}` : null;
  const safeNumber = (value, fallback = 0) => Number.isFinite(Number(value)) ? Number(value) : fallback;

  function scaleRectFromBase(rect, profile) {
    return {
      x: rect.x * profile.width / 1280,
      y: rect.y * profile.height / 720,
      w: rect.w * profile.width / 1280,
      h: rect.h * profile.height / 720
    };
  }

  function makeDefaultState() {
    const catalog = clone(DEFAULT_CATALOG).map(item => {
      const definition = { ...item };
      delete definition.baseRect;
      return definition;
    });
    const layouts = {};
    for (const [profileId, profile] of Object.entries(PROFILE_DEFS)) {
      layouts[profileId] = { board: scaleRectFromBase(DEFAULT_BOARD_RECT, profile), uiRects: {} };
      for (const item of DEFAULT_CATALOG) layouts[profileId].uiRects[item.id] = scaleRectFromBase(item.baseRect, profile);
    }
    return { currentProfile: "1280x720", catalog, layouts };
  }

  let state = makeDefaultState();
  let selectedId = BOARD_ID;
  let stageScale = 1;
  let interaction = null;
  let drawState = null;
  let drawMode = false;
  let customSequence = 1;
  let lastDeleted = null;

  const dom = {
    workspace: document.getElementById("workspace"),
    stageShell: document.getElementById("stage-shell"),
    stage: document.getElementById("stage"),
    elementsLayer: document.getElementById("elements-layer"),
    boardRegion: document.getElementById("board-region"),
    drawLayer: document.getElementById("draw-layer"),
    drawPreview: document.getElementById("draw-preview"),
    safeArea: document.getElementById("safe-area"),
    gridOverlay: document.getElementById("grid-overlay"),
    objectList: document.getElementById("object-list"),
    objectCount: document.getElementById("object-count"),
    status: document.getElementById("status"),
    selectionKind: document.getElementById("selection-kind"),
    selectionTitle: document.getElementById("selection-title"),
    topSelection: document.getElementById("top-selection"),
    topProfile: document.getElementById("top-profile"),
    canvasTag: document.getElementById("canvas-tag"),
    cursor: document.getElementById("cursor"),
    zoom: document.getElementById("zoom"),
    name: document.getElementById("element-name"),
    function: document.getElementById("element-function"),
    visible: document.getElementById("element-visible"),
    lockAspect: document.getElementById("lock-aspect"),
    deleteButton: document.getElementById("delete-ui"),
    undoButton: document.getElementById("undo-delete"),
    addButton: document.getElementById("add-ui"),
    fileInput: document.getElementById("file-input"),
    rectInputs: {
      x: document.getElementById("rect-x"),
      y: document.getElementById("rect-y"),
      w: document.getElementById("rect-w"),
      h: document.getElementById("rect-h")
    },
    normalized: {
      x: document.getElementById("norm-x"),
      y: document.getElementById("norm-y"),
      w: document.getElementById("norm-w"),
      h: document.getElementById("norm-h")
    }
  };

  function definitionById(id) {
    return id === BOARD_ID ? BOARD_META : state.catalog.find(item => item.id === id) || null;
  }

  function rectById(id) {
    return id === BOARD_ID ? currentLayout().board : currentLayout().uiRects[id];
  }

  function setRectById(id, rect) {
    if (id === BOARD_ID) currentLayout().board = rect;
    else currentLayout().uiRects[id] = rect;
  }

  function normalizedRect(rect, profile = currentProfileDef()) {
    return { x: rect.x / profile.width, y: rect.y / profile.height, w: rect.w / profile.width, h: rect.h / profile.height };
  }

  function pixelRectFromNormalized(rect, profile) {
    return { x: rect.x * profile.width, y: rect.y * profile.height, w: rect.w * profile.width, h: rect.h * profile.height };
  }

  function snapValue(value) {
    const snap = Number(document.getElementById("snap").value) || 1;
    return Math.round(value / snap) * snap;
  }

  function constrainRect(rect, id) {
    const profile = currentProfileDef();
    const minimum = id === BOARD_ID ? MIN_BOARD_SIZE : MIN_UI_SIZE;
    const next = {
      x: safeNumber(rect.x), y: safeNumber(rect.y),
      w: Math.max(minimum.w, safeNumber(rect.w, minimum.w)),
      h: Math.max(minimum.h, safeNumber(rect.h, minimum.h))
    };
    next.w = Math.min(next.w, profile.width);
    next.h = Math.min(next.h, profile.height);
    next.x = clamp(next.x, 0, profile.width - next.w);
    next.y = clamp(next.y, 0, profile.height - next.h);
    return next;
  }

  function fitStage() {
    const profile = currentProfileDef();
    const availableW = Math.max(320, dom.workspace.clientWidth - 68);
    const availableH = Math.max(240, dom.workspace.clientHeight - 68);
    stageScale = Math.min(availableW / profile.width, availableH / profile.height, 1);
    dom.stage.style.transform = `scale(${stageScale})`;
    dom.stageShell.style.width = `${profile.width * stageScale}px`;
    dom.stageShell.style.height = `${profile.height * stageScale}px`;
    dom.zoom.textContent = `${Math.round(stageScale * 100)}%`;
  }

  function makeElementNode(definition, index) {
    const node = document.createElement("div");
    node.className = "ui-element";
    node.id = `layout-${definition.id}`;
    node.dataset.id = definition.id;
    node.style.zIndex = String(10 + index);

    if (definition.kind === "image" && definition.asset) {
      const image = document.createElement("img");
      image.src = webAssetPath(definition.asset);
      image.alt = definition.name;
      if (definition.mirrorX) image.style.transform = "scaleX(-1)";
      node.appendChild(image);
    } else {
      const card = document.createElement("div");
      card.className = "custom-ui-card";
      const title = document.createElement("strong");
      title.textContent = definition.name;
      const description = document.createElement("small");
      description.textContent = definition.function || "请在左侧填写功能说明";
      card.append(title, description);
      node.appendChild(card);
    }

    const tag = document.createElement("div");
    tag.className = "ui-tag";
    tag.textContent = definition.name;
    node.appendChild(tag);
    node.insertAdjacentHTML("beforeend", HANDLE_HTML);
    node.addEventListener("pointerdown", event => startObjectInteraction(event, definition.id));
    node.addEventListener("pointermove", moveObjectInteraction);
    node.addEventListener("pointerup", endObjectInteraction);
    node.addEventListener("pointercancel", endObjectInteraction);
    return node;
  }

  function syncElementNodes() {
    dom.elementsLayer.replaceChildren(...state.catalog.map(makeElementNode));
  }

  function renderObjectList() {
    const rows = [BOARD_META, ...state.catalog];
    dom.objectCount.textContent = `02 · ${rows.length}`;
    const fragment = document.createDocumentFragment();

    rows.forEach((definition, index) => {
      const row = document.createElement("div");
      row.className = `object-row${definition.id === BOARD_ID ? " board" : ""}${selectedId === definition.id ? " active" : ""}${definition.visible === false ? " is-hidden" : ""}`;
      row.dataset.id = definition.id;
      row.setAttribute("role", "button");
      row.tabIndex = 0;

      const number = document.createElement("span");
      number.className = "object-index";
      number.textContent = String(index + 1).padStart(2, "0");
      const name = document.createElement("span");
      name.className = "object-name";
      name.textContent = definition.name;
      const visibility = document.createElement("button");
      visibility.className = "visibility-button";
      visibility.type = "button";
      visibility.textContent = definition.id === BOARD_ID ? "LOCK" : definition.visible === false ? "HID" : "VIS";
      visibility.disabled = definition.id === BOARD_ID;
      visibility.title = definition.id === BOARD_ID ? "棋盘默认可视区域不能隐藏" : "切换显示";
      visibility.addEventListener("click", event => {
        event.stopPropagation();
        definition.visible = !definition.visible;
        render();
      });

      const activate = () => selectObject(definition.id);
      row.addEventListener("click", activate);
      row.addEventListener("keydown", event => {
        if (event.key === "Enter" || event.key === " ") { event.preventDefault(); activate(); }
      });
      row.append(number, name, visibility);
      fragment.appendChild(row);
    });

    dom.objectList.replaceChildren(fragment);
  }

  function renderInspector() {
    const definition = definitionById(selectedId) || BOARD_META;
    const rect = rectById(selectedId) || currentLayout().board;
    const profile = currentProfileDef();
    const normalized = normalizedRect(rect, profile);
    const isBoard = selectedId === BOARD_ID;

    dom.selectionKind.textContent = isBoard ? "BOARD" : definition.kind === "custom" ? "CUSTOM UI" : "HUD ASSET";
    dom.selectionKind.classList.toggle("board", isBoard);
    dom.selectionTitle.textContent = definition.name;
    dom.topSelection.textContent = definition.name;
    dom.name.value = definition.name;
    dom.function.value = definition.function || "";
    dom.name.disabled = isBoard;
    dom.function.disabled = isBoard;
    dom.visible.checked = definition.visible !== false;
    dom.visible.disabled = isBoard;
    dom.lockAspect.checked = Boolean(definition.lockAspect);
    dom.lockAspect.disabled = isBoard;
    dom.deleteButton.disabled = isBoard;
    dom.undoButton.disabled = !lastDeleted;

    for (const key of ["x", "y", "w", "h"]) dom.rectInputs[key].value = Math.round(rect[key]);
    dom.normalized.x.textContent = `X ${normalized.x.toFixed(3)}`;
    dom.normalized.y.textContent = `Y ${normalized.y.toFixed(3)}`;
    dom.normalized.w.textContent = `W ${normalized.w.toFixed(3)}`;
    dom.normalized.h.textContent = `H ${normalized.h.toFixed(3)}`;
  }

  function renderCanvas() {
    const profile = currentProfileDef();
    const board = constrainRect(currentLayout().board, BOARD_ID);
    currentLayout().board = board;
    Object.assign(dom.boardRegion.style, { left: `${board.x}px`, top: `${board.y}px`, width: `${board.w}px`, height: `${board.h}px` });
    dom.boardRegion.classList.toggle("selected", selectedId === BOARD_ID);

    state.catalog.forEach(definition => {
      const node = document.getElementById(`layout-${definition.id}`);
      if (!node) return;
      const rect = constrainRect(currentLayout().uiRects[definition.id], definition.id);
      currentLayout().uiRects[definition.id] = rect;
      Object.assign(node.style, { left: `${rect.x}px`, top: `${rect.y}px`, width: `${rect.w}px`, height: `${rect.h}px` });
      node.classList.toggle("selected", selectedId === definition.id);
      node.classList.toggle("hidden", definition.visible === false);
      const tag = node.querySelector(".ui-tag");
      if (tag) tag.textContent = definition.name;
    });

    dom.topProfile.textContent = `${profile.width}×${profile.height} · ${profile.label}`;
    dom.canvasTag.textContent = `DESIGN CANVAS · ${profile.width}×${profile.height} · ${profile.label}`;
  }

  function render() {
    renderCanvas();
    renderObjectList();
    renderInspector();
  }

  function selectObject(id, announce = true) {
    if (!definitionById(id)) return;
    selectedId = id;
    render();
    if (announce) {
      const definition = definitionById(id);
      dom.status.textContent = id === BOARD_ID
        ? "已选择棋盘默认可视区域。拖动青色区域或手柄调整它。"
        : `已选择“${definition.name}”。可拖动、缩放、改名、填写功能或删除。`;
    }
  }

  function pointerInCanvas(event) {
    const profile = currentProfileDef();
    const rect = dom.stage.getBoundingClientRect();
    return {
      x: clamp((event.clientX - rect.left) * profile.width / rect.width, 0, profile.width),
      y: clamp((event.clientY - rect.top) * profile.height / rect.height, 0, profile.height)
    };
  }

  function startObjectInteraction(event, id) {
    if (drawMode || event.button !== 0) return;
    event.preventDefault();
    event.stopPropagation();
    selectObject(id, false);
    const node = event.currentTarget;
    const point = pointerInCanvas(event);
    const origin = { ...rectById(id) };
    interaction = {
      pointerId: event.pointerId,
      id,
      handle: event.target.dataset.handle || "move",
      start: point,
      origin,
      aspect: origin.w / origin.h,
      node
    };
    node.setPointerCapture(event.pointerId);
  }

  function resizedRect(origin, handle, dx, dy, definition, aspect) {
    let next = { ...origin };
    if (handle.includes("e")) next.w = snapValue(origin.w + dx);
    if (handle.includes("s")) next.h = snapValue(origin.h + dy);
    if (handle.includes("w")) { const right = origin.x + origin.w; next.x = snapValue(origin.x + dx); next.w = right - next.x; }
    if (handle.includes("n")) { const bottom = origin.y + origin.h; next.y = snapValue(origin.y + dy); next.h = bottom - next.y; }

    if (definition.lockAspect) {
      const usesHorizontal = handle.includes("e") || handle.includes("w");
      const usesVertical = handle.includes("n") || handle.includes("s");
      const horizontalDelta = Math.abs(next.w - origin.w);
      const verticalDelta = Math.abs(next.h - origin.h);
      if (usesHorizontal && (!usesVertical || horizontalDelta >= verticalDelta)) {
        const oldBottom = next.y + next.h;
        next.h = next.w / aspect;
        if (handle.includes("n")) next.y = oldBottom - next.h;
      } else {
        const oldRight = next.x + next.w;
        next.w = next.h * aspect;
        if (handle.includes("w")) next.x = oldRight - next.w;
      }
    }
    return next;
  }

  function moveObjectInteraction(event) {
    if (!interaction || interaction.pointerId !== event.pointerId) return;
    const point = pointerInCanvas(event);
    const dx = point.x - interaction.start.x;
    const dy = point.y - interaction.start.y;
    let next;

    if (interaction.handle === "move") {
      next = { ...interaction.origin, x: snapValue(interaction.origin.x + dx), y: snapValue(interaction.origin.y + dy) };
    } else {
      next = resizedRect(interaction.origin, interaction.handle, dx, dy, definitionById(interaction.id), interaction.aspect);
    }

    setRectById(interaction.id, constrainRect(next, interaction.id));
    renderCanvas();
    renderInspector();
  }

  function endObjectInteraction(event) {
    if (!interaction || interaction.pointerId !== event.pointerId) return;
    const definition = definitionById(interaction.id);
    const rect = rectById(interaction.id);
    dom.status.textContent = `${definition.name} 已更新：X ${Math.round(rect.x)} · Y ${Math.round(rect.y)} · ${Math.round(rect.w)}×${Math.round(rect.h)}。`;
    interaction = null;
    renderObjectList();
  }

  function beginDrawMode() {
    drawMode = !drawMode;
    drawState = null;
    dom.drawPreview.style.display = "none";
    dom.drawLayer.classList.toggle("active", drawMode);
    dom.addButton.textContent = drawMode ? "取消框选" : "框选添加新 UI";
    dom.status.textContent = drawMode
      ? "添加模式：在画布上拖动框选新 UI 区域，按 Esc 可以取消。"
      : "已取消添加新 UI。";
  }

  function addCustomUi(rect) {
    const profile = currentProfileDef();
    const normalized = normalizedRect(rect, profile);
    const id = `custom-ui-${Date.now()}-${customSequence}`;
    const definition = {
      id,
      name: `新 UI ${customSequence}`,
      function: "",
      kind: "custom",
      asset: null,
      visible: true,
      lockAspect: false
    };
    customSequence += 1;
    state.catalog.push(definition);
    for (const [profileId, profileDef] of Object.entries(PROFILE_DEFS)) {
      state.layouts[profileId].uiRects[id] = pixelRectFromNormalized(normalized, profileDef);
    }
    drawMode = false;
    drawState = null;
    dom.drawLayer.classList.remove("active");
    dom.drawPreview.style.display = "none";
    dom.addButton.textContent = "框选添加新 UI";
    syncElementNodes();
    selectObject(id, false);
    dom.status.textContent = `已添加“${definition.name}”。请在左侧填写 UI 名称和功能说明。`;
    dom.function.focus();
  }

  function startDraw(event) {
    if (!drawMode || event.button !== 0) return;
    event.preventDefault();
    const point = pointerInCanvas(event);
    drawState = { pointerId: event.pointerId, start: point, rect: { x: point.x, y: point.y, w: 0, h: 0 } };
    dom.drawLayer.setPointerCapture(event.pointerId);
    dom.drawPreview.style.display = "block";
  }

  function moveDraw(event) {
    if (!drawState || drawState.pointerId !== event.pointerId) return;
    const point = pointerInCanvas(event);
    const x = snapValue(Math.min(drawState.start.x, point.x));
    const y = snapValue(Math.min(drawState.start.y, point.y));
    const w = snapValue(Math.abs(point.x - drawState.start.x));
    const h = snapValue(Math.abs(point.y - drawState.start.y));
    drawState.rect = { x, y, w, h };
    Object.assign(dom.drawPreview.style, { left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px` });
  }

  function endDraw(event) {
    if (!drawState || drawState.pointerId !== event.pointerId) return;
    const rect = drawState.rect;
    if (rect.w < MIN_UI_SIZE.w || rect.h < MIN_UI_SIZE.h) {
      dom.status.textContent = `框选区域至少需要 ${MIN_UI_SIZE.w}×${MIN_UI_SIZE.h} 像素，请重新拖动。`;
      drawState = null;
      dom.drawPreview.style.display = "none";
      return;
    }
    addCustomUi(constrainRect(rect, "new-ui"));
  }

  function deleteSelected() {
    if (selectedId === BOARD_ID) return;
    const index = state.catalog.findIndex(item => item.id === selectedId);
    if (index < 0) return;
    const definition = state.catalog[index];
    const rects = {};
    for (const profileId of Object.keys(PROFILE_DEFS)) rects[profileId] = clone(state.layouts[profileId].uiRects[selectedId]);
    lastDeleted = { definition: clone(definition), index, rects };
    state.catalog.splice(index, 1);
    for (const profileId of Object.keys(PROFILE_DEFS)) delete state.layouts[profileId].uiRects[selectedId];
    selectedId = BOARD_ID;
    syncElementNodes();
    render();
    dom.status.textContent = `已删除“${definition.name}”。需要恢复时点击“撤销删除”。`;
  }

  function undoDelete() {
    if (!lastDeleted) return;
    const restored = lastDeleted;
    state.catalog.splice(Math.min(restored.index, state.catalog.length), 0, restored.definition);
    for (const profileId of Object.keys(PROFILE_DEFS)) state.layouts[profileId].uiRects[restored.definition.id] = restored.rects[profileId];
    lastDeleted = null;
    syncElementNodes();
    selectObject(restored.definition.id, false);
    dom.status.textContent = `已恢复“${restored.definition.name}”。`;
  }

  function centerSelected() {
    const profile = currentProfileDef();
    const rect = { ...rectById(selectedId) };
    rect.x = snapValue((profile.width - rect.w) / 2);
    rect.y = snapValue((profile.height - rect.h) / 2);
    setRectById(selectedId, constrainRect(rect, selectedId));
    render();
    dom.status.textContent = `${definitionById(selectedId).name} 已在当前画布中居中。`;
  }

  function exportedRect(rect, profile) {
    const normalized = normalizedRect(rect, profile);
    return {
      pixel_rect: { x: Math.round(rect.x), y: Math.round(rect.y), width: Math.round(rect.w), height: Math.round(rect.h) },
      normalized_rect: { x: normalized.x, y: normalized.y, width: normalized.w, height: normalized.h }
    };
  }

  function exportPayload() {
    const profiles = {};
    for (const [profileId, profile] of Object.entries(PROFILE_DEFS)) {
      const layout = state.layouts[profileId];
      profiles[profileId] = {
        canvas: { width: profile.width, height: profile.height, aspect: profile.label },
        default_visible_board_screen_rect: exportedRect(layout.board, profile),
        ui_layout: state.catalog.map((definition, zIndex) => ({
          id: definition.id,
          z_index: zIndex,
          visible: definition.visible !== false,
          ...exportedRect(layout.uiRects[definition.id], profile)
        }))
      };
    }
    return {
      schema_version: "veilfront-board-ui-layout-v2",
      coordinate_space: "design_canvas",
      board_rect_meaning: "default_visible_board_screen_rect",
      board_rect_explicitly_not: "full_board_world_size",
      full_board_world_reference: { width: 1152, height: 3072 },
      active_profile: state.currentProfile,
      ui_catalog: state.catalog.map(({ id, name, function: purpose, kind, asset, mirrorX, visible, lockAspect }) => ({
        id, name, function: purpose, kind, asset: asset || null, mirror_x: Boolean(mirrorX), visible: visible !== false, lock_aspect: Boolean(lockAspect)
      })),
      profiles
    };
  }

  function parseRect(entry, profile, label) {
    if (entry?.pixel_rect) {
      const value = entry.pixel_rect;
      return constrainRectForProfile({ x: value.x, y: value.y, w: value.width, h: value.height }, profile, label === BOARD_ID ? MIN_BOARD_SIZE : MIN_UI_SIZE);
    }
    if (entry?.normalized_rect) {
      const value = entry.normalized_rect;
      return constrainRectForProfile({ x: value.x * profile.width, y: value.y * profile.height, w: value.width * profile.width, h: value.height * profile.height }, profile, label === BOARD_ID ? MIN_BOARD_SIZE : MIN_UI_SIZE);
    }
    throw new Error(`${label} 缺少 pixel_rect 或 normalized_rect`);
  }

  function constrainRectForProfile(rect, profile, minimum) {
    const next = {
      x: safeNumber(rect.x), y: safeNumber(rect.y),
      w: clamp(safeNumber(rect.w, minimum.w), minimum.w, profile.width),
      h: clamp(safeNumber(rect.h, minimum.h), minimum.h, profile.height)
    };
    next.x = clamp(next.x, 0, profile.width - next.w);
    next.y = clamp(next.y, 0, profile.height - next.h);
    return next;
  }

  function importPayload(payload) {
    if (payload?.schema_version !== "veilfront-board-ui-layout-v2") throw new Error("只支持 veilfront-board-ui-layout-v2");
    if (!Array.isArray(payload.ui_catalog) || !payload.profiles) throw new Error("JSON 缺少 ui_catalog 或 profiles");
    const ids = new Set();
    const catalog = payload.ui_catalog.map((item, index) => {
      const id = String(item.id || `imported-ui-${index + 1}`);
      if (id === BOARD_ID || ids.has(id)) throw new Error(`UI id 重复或保留：${id}`);
      ids.add(id);
      return {
        id,
        name: String(item.name || `未命名 UI ${index + 1}`).slice(0, 40),
        function: String(item.function || "").slice(0, 240),
        kind: item.kind === "image" && typeof item.asset === "string" ? "image" : "custom",
        asset: typeof item.asset === "string" ? item.asset : null,
        mirrorX: Boolean(item.mirror_x),
        visible: item.visible !== false,
        lockAspect: Boolean(item.lock_aspect)
      };
    });

    const layouts = {};
    for (const [profileId, profile] of Object.entries(PROFILE_DEFS)) {
      const imported = payload.profiles[profileId];
      if (!imported) throw new Error(`缺少分辨率布局：${profileId}`);
      const entries = new Map((imported.ui_layout || []).map(entry => [String(entry.id), entry]));
      layouts[profileId] = {
        board: parseRect(imported.default_visible_board_screen_rect, profile, BOARD_ID),
        uiRects: {}
      };
      for (const definition of catalog) {
        const entry = entries.get(definition.id);
        if (!entry) throw new Error(`${profileId} 缺少 UI：${definition.id}`);
        layouts[profileId].uiRects[definition.id] = parseRect(entry, profile, definition.id);
        definition.visible = entry.visible !== false;
      }
    }

    state = {
      currentProfile: PROFILE_DEFS[payload.active_profile] ? payload.active_profile : "1280x720",
      catalog,
      layouts
    };
    selectedId = BOARD_ID;
    lastDeleted = null;
    document.getElementById("profile").value = state.currentProfile;
    applyProfile();
    syncElementNodes();
    render();
  }

  async function copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      const textarea = document.createElement("textarea");
      textarea.value = text;
      textarea.style.position = "fixed";
      textarea.style.left = "-9999px";
      document.body.appendChild(textarea);
      textarea.select();
      const copied = document.execCommand("copy");
      textarea.remove();
      return copied;
    }
  }

  function downloadJson() {
    const blob = new Blob([JSON.stringify(exportPayload(), null, 2)], { type: "application/json" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = "veilfront-board-ui-layout.json";
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 0);
    dom.status.textContent = "已下载 veilfront-board-ui-layout.json。";
  }

  function applyProfile() {
    const profile = currentProfileDef();
    document.documentElement.style.setProperty("--design-w", profile.width);
    document.documentElement.style.setProperty("--design-h", profile.height);
    fitStage();
  }

  dom.boardRegion.addEventListener("pointerdown", event => startObjectInteraction(event, BOARD_ID));
  dom.boardRegion.addEventListener("pointermove", moveObjectInteraction);
  dom.boardRegion.addEventListener("pointerup", endObjectInteraction);
  dom.boardRegion.addEventListener("pointercancel", endObjectInteraction);

  dom.drawLayer.addEventListener("pointerdown", startDraw);
  dom.drawLayer.addEventListener("pointermove", moveDraw);
  dom.drawLayer.addEventListener("pointerup", endDraw);
  dom.drawLayer.addEventListener("pointercancel", endDraw);

  dom.stage.addEventListener("pointermove", event => {
    const point = pointerInCanvas(event);
    dom.cursor.textContent = `X ${Math.round(point.x)} · Y ${Math.round(point.y)}`;
  });

  for (const [key, input] of Object.entries(dom.rectInputs)) {
    input.addEventListener("change", () => {
      const rect = { ...rectById(selectedId), [key]: safeNumber(input.value) };
      setRectById(selectedId, constrainRect(rect, selectedId));
      render();
    });
  }

  dom.name.addEventListener("input", () => {
    if (selectedId === BOARD_ID) return;
    const definition = definitionById(selectedId);
    definition.name = dom.name.value || "未命名 UI";
    dom.selectionTitle.textContent = definition.name;
    dom.topSelection.textContent = definition.name;
    const node = document.getElementById(`layout-${selectedId}`);
    node?.querySelector(".ui-tag")?.replaceChildren(definition.name);
    const title = node?.querySelector(".custom-ui-card strong");
    if (title) title.textContent = definition.name;
    renderObjectList();
  });

  dom.function.addEventListener("input", () => {
    if (selectedId === BOARD_ID) return;
    const definition = definitionById(selectedId);
    definition.function = dom.function.value;
    const description = document.getElementById(`layout-${selectedId}`)?.querySelector(".custom-ui-card small");
    if (description) description.textContent = definition.function || "请在左侧填写功能说明";
  });

  dom.visible.addEventListener("change", () => {
    if (selectedId === BOARD_ID) return;
    definitionById(selectedId).visible = dom.visible.checked;
    render();
  });

  dom.lockAspect.addEventListener("change", () => {
    if (selectedId === BOARD_ID) return;
    definitionById(selectedId).lockAspect = dom.lockAspect.checked;
  });

  document.getElementById("profile").addEventListener("change", event => {
    state.currentProfile = event.target.value;
    applyProfile();
    render();
    dom.status.textContent = `已切换到 ${currentProfileDef().width}×${currentProfileDef().height}；该分辨率拥有独立布局。`;
  });

  document.getElementById("view-mode").addEventListener("change", event => {
    dom.stage.classList.toggle("wireframe", event.target.value === "wireframe");
    dom.stage.classList.toggle("board-focus", event.target.value === "board-focus");
  });

  document.getElementById("show-safe").addEventListener("change", event => { dom.safeArea.hidden = !event.target.checked; });
  document.getElementById("show-grid").addEventListener("change", event => { dom.gridOverlay.hidden = !event.target.checked; });
  dom.addButton.addEventListener("click", beginDrawMode);
  dom.deleteButton.addEventListener("click", deleteSelected);
  dom.undoButton.addEventListener("click", undoDelete);
  document.getElementById("center-object").addEventListener("click", centerSelected);

  document.getElementById("copy-json").addEventListener("click", async () => {
    const copied = await copyText(JSON.stringify(exportPayload(), null, 2));
    dom.status.textContent = copied ? "完整布局 JSON 已复制，可直接粘贴给 Codex 接入 Godot。" : "复制失败，请使用“下载 JSON”。";
  });

  document.getElementById("download-json").addEventListener("click", downloadJson);
  document.getElementById("import-json").addEventListener("click", () => dom.fileInput.click());
  dom.fileInput.addEventListener("change", async event => {
    const file = event.target.files[0];
    if (!file) return;
    try {
      importPayload(JSON.parse(await file.text()));
      dom.status.textContent = `已导入 ${file.name}。`;
    } catch (error) {
      dom.status.textContent = `导入失败：${error.message}`;
    }
    event.target.value = "";
  });

  document.getElementById("save-draft").addEventListener("click", () => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(exportPayload()));
    dom.status.textContent = "当前所有分辨率布局已保存到浏览器本地草稿。";
  });

  document.getElementById("load-draft").addEventListener("click", () => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) { dom.status.textContent = "当前浏览器还没有保存过布局草稿。"; return; }
    try { importPayload(JSON.parse(saved)); dom.status.textContent = "已载入浏览器本地布局草稿。"; }
    catch (error) { dom.status.textContent = `草稿损坏：${error.message}`; }
  });

  document.getElementById("reset-layout").addEventListener("click", () => {
    state = makeDefaultState();
    selectedId = BOARD_ID;
    lastDeleted = null;
    customSequence = 1;
    document.getElementById("profile").value = state.currentProfile;
    applyProfile();
    syncElementNodes();
    render();
    dom.status.textContent = "已恢复全部分辨率的默认布局，并移除自定义 UI。";
  });

  window.addEventListener("keydown", event => {
    if (event.key === "Escape" && drawMode) { beginDrawMode(); return; }
    if (["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName)) return;
    const directions = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
    if (!directions[event.key]) return;
    event.preventDefault();
    const [dx, dy] = directions[event.key];
    const amount = event.shiftKey ? 10 : 1;
    const rect = { ...rectById(selectedId) };
    rect.x += dx * amount;
    rect.y += dy * amount;
    setRectById(selectedId, constrainRect(rect, selectedId));
    render();
  });

  new ResizeObserver(fitStage).observe(dom.workspace);
  applyProfile();
  syncElementNodes();
  render();
})();
