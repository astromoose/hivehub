// HIVEHUB — SVG hexmap renderer (pointy-top, axial coordinates).
(function () {
  "use strict";

  const container = document.getElementById("hexmap-container");
  if (!container) return;
  const zoneId = container.dataset.zoneId;
  const svg = document.getElementById("hexmap");
  const tooltip = document.getElementById("turf-tooltip");
  const legendEl = document.getElementById("legend");
  const detailEl = document.getElementById("turf-detail");
  const NS = "http://www.w3.org/2000/svg";
  const SIZE = 52; // hex radius
  const NO_MANS = "#2c2438";

  let state = { turfs: [], gangs: [], selectedId: null };

  function hexCenter(q, r) {
    return {
      x: SIZE * Math.sqrt(3) * (q + r / 2),
      y: SIZE * 1.5 * r,
    };
  }

  function hexPoints(cx, cy) {
    const pts = [];
    for (let i = 0; i < 6; i++) {
      const angle = (Math.PI / 180) * (60 * i - 30);
      pts.push(`${(cx + SIZE * Math.cos(angle)).toFixed(2)},${(cy + SIZE * Math.sin(angle)).toFixed(2)}`);
    }
    return pts.join(" ");
  }

  function gangById(id) {
    return state.gangs.find((g) => g.id === id) || null;
  }

  function el(tag, attrs, text) {
    const node = document.createElementNS(NS, tag);
    for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function truncate(s, n) {
    return s.length > n ? s.slice(0, n - 1) + "…" : s;
  }

  function render() {
    svg.innerHTML = "";
    if (!state.turfs.length) return;

    const centers = state.turfs.map((t) => ({ t, c: hexCenter(t.q, t.r) }));
    const pad = SIZE * 1.3;
    const xs = centers.map((o) => o.c.x);
    const ys = centers.map((o) => o.c.y);
    const minX = Math.min(...xs) - pad, maxX = Math.max(...xs) + pad;
    const minY = Math.min(...ys) - pad, maxY = Math.max(...ys) + pad;
    svg.setAttribute("viewBox", `${minX} ${minY} ${maxX - minX} ${maxY - minY}`);

    // Cap on-screen hex size so tall, narrow maps don't render huge:
    // limit the SVG's width to ~104px per hex-column of viewBox width.
    const MAX_PX_PER_HEX = 104;
    svg.style.maxWidth = `${((maxX - minX) / (SIZE * Math.sqrt(3))) * MAX_PX_PER_HEX}px`;

    for (const { t, c } of centers) {
      const gang = gangById(t.gang_id);
      const poly = el("polygon", {
        points: hexPoints(c.x, c.y),
        class: "hex" + (t.id === state.selectedId ? " selected" : ""),
        fill: gang ? gang.color : NO_MANS,
        "fill-opacity": "1",
      });
      poly.addEventListener("click", () => selectTurf(t.id));
      poly.addEventListener("mousemove", (e) => showTooltip(e, t));
      poly.addEventListener("mouseleave", hideTooltip);
      svg.appendChild(poly);

      if (t.home_gang_id && t.home_gang_id === t.gang_id) {
        svg.appendChild(el("text", {
          x: c.x, y: c.y - SIZE * 0.35,
          "text-anchor": "middle", class: "hex-home",
        }, "⌂"));
      }

      const words = t.name.split(" ");
      const line1 = words.slice(0, Math.ceil(words.length / 2)).join(" ");
      const line2 = words.slice(Math.ceil(words.length / 2)).join(" ");
      svg.appendChild(el("text", {
        x: c.x, y: c.y + 2, "text-anchor": "middle", class: "hex-label",
      }, truncate(line1, 14)));
      if (line2) {
        svg.appendChild(el("text", {
          x: c.x, y: c.y + 13, "text-anchor": "middle", class: "hex-label",
        }, truncate(line2, 14)));
      }
    }

    renderLegend();
    renderDetail();
  }

  function showTooltip(e, t) {
    const gang = gangById(t.gang_id);
    const rect = container.getBoundingClientRect();
    tooltip.innerHTML = "";
    const name = document.createElement("div");
    name.className = "tt-name";
    name.textContent = t.name;
    const owner = document.createElement("div");
    owner.className = "tt-owner";
    owner.textContent = gang
      ? `Held by ${gang.name}${t.home_gang_id === gang.id ? " (home turf)" : ""}`
      : "No-man's-land";
    const desc = document.createElement("div");
    desc.className = "tt-desc";
    desc.textContent = t.description || "";
    tooltip.append(name, owner, desc);
    tooltip.hidden = false;
    const x = Math.min(e.clientX - rect.left + 14, rect.width - 250);
    tooltip.style.left = `${Math.max(0, x)}px`;
    tooltip.style.top = `${e.clientY - rect.top + 14}px`;
  }

  function hideTooltip() {
    tooltip.hidden = true;
  }

  function renderLegend() {
    legendEl.innerHTML = "";
    const entries = state.gangs.map((g) => {
      const held = state.turfs.filter((t) => t.gang_id === g.id).length;
      return { color: g.color, label: g.name, sub: `${g.gang_type} · ${held} turf${held === 1 ? "" : "s"}` };
    });
    const nml = state.turfs.filter((t) => !t.gang_id).length;
    entries.push({ color: NO_MANS, label: "No-man's-land", sub: `${nml} turf${nml === 1 ? "" : "s"}` });

    for (const entry of entries) {
      const li = document.createElement("li");
      const sw = document.createElement("span");
      sw.className = "swatch";
      sw.style.background = entry.color;
      const name = document.createElement("span");
      name.className = "gang-name";
      name.textContent = entry.label;
      const sub = document.createElement("span");
      sub.className = "muted small";
      sub.textContent = entry.sub;
      li.append(sw, name, sub);
      legendEl.appendChild(li);
    }
  }

  function selectTurf(id) {
    state.selectedId = state.selectedId === id ? null : id;
    render();
  }

  function renderDetail() {
    detailEl.innerHTML = "";
    const t = state.turfs.find((x) => x.id === state.selectedId);
    if (!t) {
      const p = document.createElement("p");
      p.className = "muted small";
      p.textContent = "Select a turf hex to inspect and reassign it.";
      detailEl.appendChild(p);
      return;
    }

    const h = document.createElement("h3");
    h.textContent = t.name;
    const desc = document.createElement("p");
    desc.className = "muted small";
    desc.textContent = t.description || "";
    detailEl.append(h, desc);

    const label = document.createElement("p");
    label.className = "small";
    label.textContent = "Assign to:";
    detailEl.appendChild(label);

    const list = document.createElement("ul");
    list.className = "assign-list";

    const options = [{ id: null, name: "No-man's-land", color: NO_MANS }].concat(state.gangs);
    for (const opt of options) {
      const li = document.createElement("li");
      const btn = document.createElement("button");
      btn.className = "assign-btn" + (t.gang_id === opt.id ? " current" : "");
      const sw = document.createElement("span");
      sw.className = "swatch";
      sw.style.background = opt.color;
      btn.append(sw, document.createTextNode(opt.name));
      btn.addEventListener("click", () => assign(t.id, opt.id));
      li.appendChild(btn);
      list.appendChild(li);
    }
    detailEl.appendChild(list);
  }

  async function assign(turfId, gangId) {
    const res = await fetch(`/turfs/${turfId}/assign`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ gang_id: gangId }),
    });
    if (res.ok) {
      const turf = state.turfs.find((x) => x.id === turfId);
      turf.gang_id = gangId;
      render();
    }
  }

  async function load() {
    const res = await fetch(`/zones/${zoneId}/data`);
    const data = await res.json();
    state.turfs = data.turfs;
    state.gangs = data.gangs;
    render();
  }

  load();
})();
