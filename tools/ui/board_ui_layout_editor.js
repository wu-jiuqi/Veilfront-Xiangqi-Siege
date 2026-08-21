(() => {
  "use strict";

  const BOARD_ID = "board-visible-region";
  const STORAGE_KEY = "veilfront.board-ui-layout-editor.v2";
  const MIN_UI_SIZE = { w: 40, h: 32 };
  const MIN_BOARD_SIZE = { w: 160, h: 120 };
  const MIN_TEXT_SIZE = { w: 16, h: 12 };

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

  const textLayer = (id, name, text, rect, fontSize, horizontal = "left", binding = "static") => ({
    id,
    name,
    text,
    binding,
    visible: true,
    fontSize,
    horizontal,
    vertical: "center",
    normalizedRect: rect
  });

  const DEFAULT_TEXT_LAYERS = {
    "turn-status": [textLayer("status", "回合状态", "第十八回合 · 赤方行动", { x: 0.12, y: 0.22, w: 0.76, h: 0.56 }, 16, "center", "turn_status")],
    "faction-left": [
      textLayer("portrait", "阵营字", "赤", { x: 0.02, y: 0.08, w: 0.24, h: 0.78 }, 30, "center", "faction_glyph"),
      textLayer("name", "阵营名称", "赤方军势", { x: 0.28, y: 0.20, w: 0.44, h: 0.28 }, 14, "left", "faction_name"),
      textLayer("turn", "行动状态", "等待行动", { x: 0.28, y: 0.44, w: 0.46, h: 0.17 }, 11, "left", "turn_state"),
      textLayer("stats", "阵营数据", "墙 完好 · 旗 0 · 损 0", { x: 0.28, y: 0.60, w: 0.50, h: 0.16 }, 10, "left", "faction_stats"),
      textLayer("return", "返回按钮", "返回", { x: 0.77, y: 0.31, w: 0.20, h: 0.44 }, 11, "center")
    ],
    "faction-right": [
      textLayer("portrait", "阵营字", "玄", { x: 0.74, y: 0.08, w: 0.24, h: 0.78 }, 30, "center", "faction_glyph"),
      textLayer("name", "阵营名称", "玄方军势", { x: 0.28, y: 0.20, w: 0.44, h: 0.28 }, 14, "right", "faction_name"),
      textLayer("turn", "行动状态", "等待行动", { x: 0.26, y: 0.44, w: 0.46, h: 0.17 }, 11, "right", "turn_state"),
      textLayer("stats", "阵营数据", "墙 完好 · 旗 0 · 损 0", { x: 0.22, y: 0.60, w: 0.50, h: 0.16 }, 10, "right", "faction_stats"),
      textLayer("mirror", "镜像按钮", "镜像", { x: 0.03, y: 0.31, w: 0.22, h: 0.44 }, 10, "center")
    ],
    "unit-info": [
      textLayer("name", "单位名称", "未选择单位", { x: 0.14, y: 0.055, w: 0.72, h: 0.09 }, 14, "center", "unit_name"),
      textLayer("glyph", "棋子字", "—", { x: 0.15, y: 0.18, w: 0.70, h: 0.40 }, 44, "center", "unit_glyph"),
      textLayer("side", "阵营状态", "阵营：—", { x: 0.20, y: 0.685, w: 0.60, h: 0.06 }, 11, "left", "unit_side"),
      textLayer("position", "单位坐标", "坐标：—", { x: 0.20, y: 0.77, w: 0.60, h: 0.06 }, 11, "left", "unit_position"),
      textLayer("state", "单位状态", "状态：—", { x: 0.20, y: 0.855, w: 0.60, h: 0.065 }, 11, "left", "unit_state")
    ],
    "objective-events": [
      textLayer("heading", "面板标题", "战局与行动", { x: 0.15, y: 0.155, w: 0.70, h: 0.065 }, 14, "center"),
      textLayer("selection", "选择状态", "行动方：— · 已选：无", { x: 0.14, y: 0.21, w: 0.72, h: 0.065 }, 11, "center", "selection_status"),
      textLayer("move", "移动按钮", "移动", { x: 0.14, y: 0.285, w: 0.36, h: 0.1825 }, 12, "center"),
      textLayer("bombard", "炮击按钮", "炮击", { x: 0.50, y: 0.285, w: 0.36, h: 0.1825 }, 12, "center"),
      textLayer("resurrect", "复活按钮", "复活", { x: 0.14, y: 0.4675, w: 0.36, h: 0.1825 }, 12, "center"),
      textLayer("pass", "跳过按钮", "跳过", { x: 0.50, y: 0.4675, w: 0.36, h: 0.1825 }, 12, "center"),
      textLayer("message", "提示信息", "提示：选择棋子后选择目标交点。", { x: 0.15, y: 0.675, w: 0.70, h: 0.125 }, 10, "left", "message")
    ],
    "action-bar": [textLayer("actions", "行动指令", "移动　攻击　技能　结束回合", { x: 0.08, y: 0.20, w: 0.84, h: 0.60 }, 14, "center")],
    "minimap": [textLayer("title", "小地图标题", "战场态势", { x: 0.18, y: 0.04, w: 0.64, h: 0.10 }, 12, "center")]
  };

  const DEFAULT_BOARD_RECT = { x: 340, y: 48, w: 600, h: 536 };
  const DEFAULT_CATALOG = [
    {
      id: "faction-left",
      name: "左方阵营状态",
      function: "显示左方阵营信息、资源和状态。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/faction_status_plate_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 48, y: 48, w: 255, h: 100 }
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
      baseRect: { x: 976, y: 48, w: 255, h: 100 }
    },
    {
      id: "unit-info",
      name: "单位信息卡",
      function: "显示当前选中棋子的身份、属性与状态。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/unit_info_card_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 64, y: 448, w: 178, h: 238 }
    },
    {
      id: "objective-events",
      name: "目标与事件",
      function: "显示当前目标、战场事件和提示信息。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/objective_event_panel_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 952, y: 80, w: 296, h: 512 }
    },
    {
      id: "minimap",
      name: "小地图",
      function: "显示完整棋盘概览、视野和战场标记。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/minimap_frame_v1.png",
      visible: true,
      lockAspect: true,
      baseRect: { x: 64, y: 152, w: 234, h: 256 }
    },
    {
      id: "custom-ui-1787265872199-1",
      name: "回合进度条",
      function: "用燃香展示当前回合进度。",
      kind: "image",
      asset: "res://assets/art/ui/terracotta_hud_v2/turn_progress_incense/turn_progress_incense_preview_v1.png",
      visible: true,
      lockAspect: false,
      baseRect: { x: 256, y: 600, w: 952, h: 72 }
    }
  ];

  const DEFAULT_PROFILE_LAYOUTS = {
    "1280x720": {
      board: { x: 340, y: 48, w: 600, h: 536 },
      uiRects: {
        "faction-left": { x: 48, y: 48, w: 255, h: 100 },
        "faction-right": { x: 976, y: 48, w: 255, h: 100 },
        "unit-info": { x: 64, y: 448, w: 178, h: 238 },
        "objective-events": { x: 952, y: 80, w: 296, h: 512 },
        "minimap": { x: 64, y: 152, w: 234, h: 256 },
        "custom-ui-1787265872199-1": { x: 256, y: 600, w: 952, h: 72 }
      }
    },
    "1680x720": {
      board: { x: 341, y: 104, w: 998, h: 450 },
      uiRects: {
        "faction-left": { x: 24, y: 70, w: 335, h: 100 },
        "faction-right": { x: 1322, y: 70, w: 335, h: 100 },
        "unit-info": { x: 24, y: 458, w: 234, h: 238 },
        "objective-events": { x: 1412, y: 183, w: 244, h: 268 },
        "minimap": { x: 1436, y: 516, w: 221, h: 184 },
        "custom-ui-1787265872199-1": { x: 420, y: 600, w: 1155, h: 72 }
      }
    },
    "1280x800": {
      board: { x: 260, y: 116, w: 760, h: 500 },
      uiRects: {
        "faction-left": { x: 18, y: 78, w: 255, h: 111 },
        "faction-right": { x: 1007, y: 78, w: 255, h: 111 },
        "unit-info": { x: 18, y: 509, w: 178, h: 264 },
        "objective-events": { x: 1076, y: 203, w: 186, h: 298 },
        "minimap": { x: 1094, y: 573, w: 168, h: 204 },
        "custom-ui-1787265872199-1": { x: 320, y: 667, w: 880, h: 80 }
      }
    },
    "1280x960": {
      board: { x: 260, y: 139, w: 760, h: 600 },
      uiRects: {
        "faction-left": { x: 18, y: 93, w: 255, h: 133 },
        "faction-right": { x: 1007, y: 93, w: 255, h: 133 },
        "unit-info": { x: 18, y: 611, w: 178, h: 317 },
        "objective-events": { x: 1076, y: 244, w: 186, h: 357 },
        "minimap": { x: 1094, y: 688, w: 168, h: 245 },
        "custom-ui-1787265872199-1": { x: 320, y: 800, w: 880, h: 96 }
      }
    }
  };

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
      const definition = { ...item, textLayers: clone(DEFAULT_TEXT_LAYERS[item.id] || []) };
      delete definition.baseRect;
      return definition;
    });
    const layouts = {};
    for (const [profileId, profile] of Object.entries(PROFILE_DEFS)) {
      const preset = DEFAULT_PROFILE_LAYOUTS[profileId];
      layouts[profileId] = preset
        ? clone(preset)
        : { board: scaleRectFromBase(DEFAULT_BOARD_RECT, profile), uiRects: {} };
      if (!preset) {
        for (const item of DEFAULT_CATALOG) layouts[profileId].uiRects[item.id] = scaleRectFromBase(item.baseRect, profile);
      }
    }
    return { currentProfile: "1280x720", catalog, layouts };
  }

  let state = makeDefaultState();
  let selectedId = BOARD_ID;
  let selectedTextId = null;
  let stageScale = 1;
  let interaction = null;
  let textInteraction = null;
  let drawState = null;
  let drawMode = false;
  let customSequence = 1;
  let textSequence = 1;
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
    textUnavailable: document.getElementById("text-unavailable"),
    textEditor: document.getElementById("text-editor"),
    textEditorFields: document.getElementById("text-editor-fields"),
    textLayerSelect: document.getElementById("text-layer-select"),
    textLayerName: document.getElementById("text-layer-name"),
    textContent: document.getElementById("text-content"),
    textFontSize: document.getElementById("text-font-size"),
    textAlign: document.getElementById("text-align"),
    textVerticalAlign: document.getElementById("text-vertical-align"),
    textVisible: document.getElementById("text-visible"),
    textBindingHint: document.getElementById("text-binding-hint"),
    addTextButton: document.getElementById("add-text-layer"),
    deleteTextButton: document.getElementById("delete-text-layer"),
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
    },
    textRectInputs: {
      x: document.getElementById("text-rect-x"),
      y: document.getElementById("text-rect-y"),
      w: document.getElementById("text-rect-w"),
      h: document.getElementById("text-rect-h")
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

  function textLayerById(uiId, textId) {
    const definition = definitionById(uiId);
    if (!definition || !Array.isArray(definition.textLayers)) return null;
    return definition.textLayers.find(layer => layer.id === textId) || null;
  }

  function currentTextLayer() {
    return selectedId === BOARD_ID || !selectedTextId ? null : textLayerById(selectedId, selectedTextId);
  }

  function textRectPixels(layer, uiRect) {
    const rect = layer.normalizedRect || { x: 0, y: 0, w: 1, h: 1 };
    return { x: rect.x * uiRect.w, y: rect.y * uiRect.h, w: rect.w * uiRect.w, h: rect.h * uiRect.h };
  }

  function normalizedTextRect(rect, uiRect) {
    return {
      x: rect.x / Math.max(1, uiRect.w),
      y: rect.y / Math.max(1, uiRect.h),
      w: rect.w / Math.max(1, uiRect.w),
      h: rect.h / Math.max(1, uiRect.h)
    };
  }

  function constrainTextRect(rect, uiRect) {
    const next = {
      x: safeNumber(rect.x),
      y: safeNumber(rect.y),
      w: clamp(safeNumber(rect.w, MIN_TEXT_SIZE.w), MIN_TEXT_SIZE.w, uiRect.w),
      h: clamp(safeNumber(rect.h, MIN_TEXT_SIZE.h), MIN_TEXT_SIZE.h, uiRect.h)
    };
    next.x = clamp(next.x, 0, uiRect.w - next.w);
    next.y = clamp(next.y, 0, uiRect.h - next.h);
    return next;
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

  function makeTextNode(definition, layer) {
    const node = document.createElement("div");
    node.className = "text-layer-box";
    node.dataset.uiId = definition.id;
    node.dataset.textId = layer.id;
    node.title = `${layer.name} · 拖动或八向缩放`;
    const content = document.createElement("span");
    content.className = "text-layer-content";
    content.textContent = layer.text || "文字";
    node.appendChild(content);
    node.insertAdjacentHTML("beforeend", HANDLE_HTML);
    node.addEventListener("pointerdown", event => startTextInteraction(event, definition.id, layer.id));
    node.addEventListener("pointermove", moveTextInteraction);
    node.addEventListener("pointerup", endTextInteraction);
    node.addEventListener("pointercancel", endTextInteraction);
    return node;
  }

  function makeTextHost(definition) {
    const host = document.createElement("div");
    host.className = "text-layer-host";
    for (const layer of definition.textLayers || []) host.appendChild(makeTextNode(definition, layer));
    return host;
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

    node.appendChild(makeTextHost(definition));

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

    dom.textUnavailable.hidden = !isBoard;
    dom.textEditor.hidden = isBoard;
    dom.addTextButton.disabled = isBoard;
    if (isBoard) return;

    const layers = Array.isArray(definition.textLayers) ? definition.textLayers : [];
    if (selectedTextId && !layers.some(layer => layer.id === selectedTextId)) selectedTextId = null;
    const placeholder = document.createElement("option");
    placeholder.value = "";
    placeholder.textContent = layers.length ? "选择一个文字框…" : "当前 UI 暂无文字框";
    const options = layers.map(layer => {
      const option = document.createElement("option");
      option.value = layer.id;
      option.textContent = layer.name;
      return option;
    });
    dom.textLayerSelect.replaceChildren(placeholder, ...options);
    dom.textLayerSelect.value = selectedTextId || "";

    const layer = currentTextLayer();
    const hasLayer = Boolean(layer);
    dom.deleteTextButton.disabled = !hasLayer;
    dom.textEditorFields.classList.toggle("is-disabled", !hasLayer);
    for (const input of [dom.textLayerName, dom.textContent, dom.textFontSize, dom.textAlign, dom.textVerticalAlign, dom.textVisible, ...Object.values(dom.textRectInputs)]) {
      input.disabled = !hasLayer;
    }
    if (!layer) {
      dom.textLayerName.value = "";
      dom.textContent.value = "";
      for (const input of Object.values(dom.textRectInputs)) input.value = "";
      dom.textFontSize.value = "";
      dom.textBindingHint.textContent = layers.length ? "选择一个文字框后，可编辑内容、位置和尺寸。" : "点击“添加文字框”创建第一段文字。";
      return;
    }

    const textRect = textRectPixels(layer, rect);
    dom.textLayerName.value = layer.name;
    dom.textContent.value = layer.text;
    dom.textRectInputs.x.value = Math.round(textRect.x);
    dom.textRectInputs.y.value = Math.round(textRect.y);
    dom.textRectInputs.w.value = Math.round(textRect.w);
    dom.textRectInputs.h.value = Math.round(textRect.h);
    dom.textFontSize.value = layer.fontSize;
    dom.textAlign.value = layer.horizontal;
    dom.textVerticalAlign.value = layer.vertical;
    dom.textVisible.checked = layer.visible !== false;
    dom.textBindingHint.textContent = layer.binding === "static"
      ? "STATIC · 文字内容会作为静态文案导出。"
      : `DATA · ${layer.binding} · 当前内容用于编辑器预览，游戏运行时可由数据覆盖。`;
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
      node.classList.toggle("text-editing", selectedId === definition.id && Boolean(selectedTextId));
      node.classList.toggle("hidden", definition.visible === false);
      const tag = node.querySelector(".ui-tag");
      if (tag) tag.textContent = definition.name;

      const textNodes = new Map(Array.from(node.querySelectorAll(".text-layer-box")).map(textNode => [textNode.dataset.textId, textNode]));
      for (const layer of definition.textLayers || []) {
        const textNode = textNodes.get(layer.id);
        if (!textNode) continue;
        const textRect = constrainTextRect(textRectPixels(layer, rect), rect);
        layer.normalizedRect = normalizedTextRect(textRect, rect);
        Object.assign(textNode.style, {
          left: `${textRect.x}px`,
          top: `${textRect.y}px`,
          width: `${textRect.w}px`,
          height: `${textRect.h}px`,
          fontSize: `${clamp(safeNumber(layer.fontSize, 12), 6, 96)}px`
        });
        textNode.querySelector(".text-layer-content").textContent = layer.text || "文字";
        textNode.classList.toggle("selected", selectedId === definition.id && selectedTextId === layer.id);
        textNode.classList.toggle("is-hidden", layer.visible === false);
        for (const value of ["left", "center", "right"]) textNode.classList.toggle(`align-${value}`, layer.horizontal === value);
        for (const value of ["top", "center", "bottom"]) textNode.classList.toggle(`valign-${value}`, layer.vertical === value);
      }
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
    selectedTextId = null;
    render();
    if (announce) {
      const definition = definitionById(id);
      dom.status.textContent = id === BOARD_ID
        ? "已选择棋盘默认可视区域。拖动青色区域或手柄调整它。"
        : `已选择“${definition.name}”。可调整 UI 尺寸，也可以在文字图层中编辑文案和文字框。`;
    }
  }

  function selectTextLayer(uiId, textId, announce = true) {
    if (!textLayerById(uiId, textId)) return;
    selectedId = uiId;
    selectedTextId = textId;
    render();
    if (announce) {
      const layer = currentTextLayer();
      dom.status.textContent = `已选择文字框“${layer.name}”。拖动文字框或手柄调整位置和大小。`;
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

  function pointerInUi(event, uiId) {
    const uiNode = document.getElementById(`layout-${uiId}`);
    const uiRect = rectById(uiId);
    const bounds = uiNode.getBoundingClientRect();
    return {
      x: clamp((event.clientX - bounds.left) * uiRect.w / Math.max(1, bounds.width), 0, uiRect.w),
      y: clamp((event.clientY - bounds.top) * uiRect.h / Math.max(1, bounds.height), 0, uiRect.h)
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

  function startTextInteraction(event, uiId, textId) {
    if (drawMode || event.button !== 0) return;
    event.preventDefault();
    event.stopPropagation();
    selectedId = uiId;
    selectedTextId = textId;
    renderCanvas();
    renderObjectList();
    renderInspector();
    const node = event.currentTarget;
    const point = pointerInUi(event, uiId);
    const uiRect = rectById(uiId);
    const layer = textLayerById(uiId, textId);
    const origin = textRectPixels(layer, uiRect);
    textInteraction = {
      pointerId: event.pointerId,
      uiId,
      textId,
      handle: event.target.dataset.handle || "move",
      start: point,
      origin,
      node
    };
    node.setPointerCapture(event.pointerId);
  }

  function moveTextInteraction(event) {
    if (!textInteraction || textInteraction.pointerId !== event.pointerId) return;
    const point = pointerInUi(event, textInteraction.uiId);
    const dx = point.x - textInteraction.start.x;
    const dy = point.y - textInteraction.start.y;
    const uiRect = rectById(textInteraction.uiId);
    let next;
    if (textInteraction.handle === "move") {
      next = {
        ...textInteraction.origin,
        x: snapValue(textInteraction.origin.x + dx),
        y: snapValue(textInteraction.origin.y + dy)
      };
    } else {
      next = resizedRect(textInteraction.origin, textInteraction.handle, dx, dy, { lockAspect: false }, 1.0);
    }
    const constrained = constrainTextRect(next, uiRect);
    textLayerById(textInteraction.uiId, textInteraction.textId).normalizedRect = normalizedTextRect(constrained, uiRect);
    renderCanvas();
    renderInspector();
  }

  function endTextInteraction(event) {
    if (!textInteraction || textInteraction.pointerId !== event.pointerId) return;
    const layer = textLayerById(textInteraction.uiId, textInteraction.textId);
    const rect = textRectPixels(layer, rectById(textInteraction.uiId));
    dom.status.textContent = `${layer.name} 已更新：X ${Math.round(rect.x)} · Y ${Math.round(rect.y)} · ${Math.round(rect.w)}×${Math.round(rect.h)}。`;
    textInteraction = null;
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
      lockAspect: false,
      textLayers: []
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

  function addTextLayer() {
    if (selectedId === BOARD_ID) return;
    const definition = definitionById(selectedId);
    if (!Array.isArray(definition.textLayers)) definition.textLayers = [];
    const id = `text-${Date.now()}-${textSequence}`;
    const layer = textLayer(
      id,
      `新文字 ${textSequence}`,
      "新文字",
      { x: 0.15, y: 0.35, w: 0.70, h: 0.30 },
      14,
      "center"
    );
    textSequence += 1;
    definition.textLayers.push(layer);
    selectedTextId = id;
    syncElementNodes();
    render();
    dom.status.textContent = `已在“${definition.name}”中添加文字框，请编辑内容或在画布上调整。`;
    dom.textContent.focus();
  }

  function deleteTextLayer() {
    const definition = definitionById(selectedId);
    if (!definition || !selectedTextId || !Array.isArray(definition.textLayers)) return;
    const index = definition.textLayers.findIndex(layer => layer.id === selectedTextId);
    if (index < 0) return;
    const [removed] = definition.textLayers.splice(index, 1);
    selectedTextId = null;
    syncElementNodes();
    render();
    dom.status.textContent = `已删除文字框“${removed.name}”。`;
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
    selectedTextId = null;
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

  function exportedTextLayer(layer) {
    const rect = layer.normalizedRect || { x: 0, y: 0, w: 1, h: 1 };
    return {
      id: layer.id,
      name: layer.name,
      text: layer.text,
      binding: layer.binding || "static",
      visible: layer.visible !== false,
      font_size: Math.round(clamp(safeNumber(layer.fontSize, 12), 6, 96)),
      horizontal_alignment: layer.horizontal || "left",
      vertical_alignment: layer.vertical || "center",
      normalized_rect: { x: rect.x, y: rect.y, width: rect.w, height: rect.h }
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
      ui_catalog: state.catalog.map(({ id, name, function: purpose, kind, asset, mirrorX, visible, lockAspect, textLayers }) => ({
        id, name, function: purpose, kind, asset: asset || null, mirror_x: Boolean(mirrorX), visible: visible !== false, lock_aspect: Boolean(lockAspect),
        text_layers: (textLayers || []).map(exportedTextLayer)
      })),
      profiles
    };
  }

  function parseTextLayers(item, uiId) {
    if (!Array.isArray(item.text_layers)) return clone(DEFAULT_TEXT_LAYERS[uiId] || []);
    const layerIds = new Set();
    return item.text_layers.map((entry, index) => {
      let id = String(entry.id || `text-${index + 1}`);
      if (layerIds.has(id)) id = `${id}-${index + 1}`;
      layerIds.add(id);
      const source = entry.normalized_rect || {};
      const width = clamp(safeNumber(source.width, 0.5), 0.01, 1.0);
      const height = clamp(safeNumber(source.height, 0.2), 0.01, 1.0);
      return {
        id,
        name: String(entry.name || `文字 ${index + 1}`).slice(0, 32),
        text: String(entry.text || "").slice(0, 240),
        binding: String(entry.binding || "static").slice(0, 48),
        visible: entry.visible !== false,
        fontSize: Math.round(clamp(safeNumber(entry.font_size, 12), 6, 96)),
        horizontal: ["left", "center", "right"].includes(entry.horizontal_alignment) ? entry.horizontal_alignment : "left",
        vertical: ["top", "center", "bottom"].includes(entry.vertical_alignment) ? entry.vertical_alignment : "center",
        normalizedRect: {
          x: clamp(safeNumber(source.x), 0, 1.0 - width),
          y: clamp(safeNumber(source.y), 0, 1.0 - height),
          w: width,
          h: height
        }
      };
    });
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
        lockAspect: Boolean(item.lock_aspect),
        textLayers: parseTextLayers(item, id)
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
    selectedTextId = null;
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

  dom.textLayerSelect.addEventListener("change", () => {
    if (!dom.textLayerSelect.value) {
      selectedTextId = null;
      render();
      return;
    }
    selectTextLayer(selectedId, dom.textLayerSelect.value);
  });

  dom.addTextButton.addEventListener("click", addTextLayer);
  dom.deleteTextButton.addEventListener("click", deleteTextLayer);

  dom.textLayerName.addEventListener("input", () => {
    const layer = currentTextLayer();
    if (!layer) return;
    layer.name = dom.textLayerName.value || "未命名文字";
    const option = Array.from(dom.textLayerSelect.options).find(item => item.value === layer.id);
    if (option) option.textContent = layer.name;
  });

  dom.textContent.addEventListener("input", () => {
    const layer = currentTextLayer();
    if (!layer) return;
    layer.text = dom.textContent.value;
    renderCanvas();
  });

  for (const [key, input] of Object.entries(dom.textRectInputs)) {
    input.addEventListener("change", () => {
      const layer = currentTextLayer();
      if (!layer) return;
      const uiRect = rectById(selectedId);
      const rect = { ...textRectPixels(layer, uiRect), [key]: safeNumber(input.value) };
      layer.normalizedRect = normalizedTextRect(constrainTextRect(rect, uiRect), uiRect);
      render();
    });
  }

  dom.textFontSize.addEventListener("change", () => {
    const layer = currentTextLayer();
    if (!layer) return;
    layer.fontSize = Math.round(clamp(safeNumber(dom.textFontSize.value, 12), 6, 96));
    render();
  });

  dom.textAlign.addEventListener("change", () => {
    const layer = currentTextLayer();
    if (!layer) return;
    layer.horizontal = dom.textAlign.value;
    renderCanvas();
  });

  dom.textVerticalAlign.addEventListener("change", () => {
    const layer = currentTextLayer();
    if (!layer) return;
    layer.vertical = dom.textVerticalAlign.value;
    renderCanvas();
  });

  dom.textVisible.addEventListener("change", () => {
    const layer = currentTextLayer();
    if (!layer) return;
    layer.visible = dom.textVisible.checked;
    renderCanvas();
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
    selectedTextId = null;
    lastDeleted = null;
    customSequence = 1;
    textSequence = 1;
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
    const layer = currentTextLayer();
    if (layer) {
      const uiRect = rectById(selectedId);
      const textRect = textRectPixels(layer, uiRect);
      textRect.x += dx * amount;
      textRect.y += dy * amount;
      layer.normalizedRect = normalizedTextRect(constrainTextRect(textRect, uiRect), uiRect);
      render();
      return;
    }
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
