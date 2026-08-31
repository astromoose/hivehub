// HIVEHUB — static print-friendly hexmap renderer (light theme, no interactivity).
(function () {
  "use strict";

  const data = JSON.parse(document.getElementById("zone-data").textContent);
  const svg = document.getElementById("hexmap");
  const legendEl = document.getElementById("legend");
  const NS = "http://www.w3.org/2000/svg";
  const SIZE = 52;

  function el(tag, attrs, text) {
    const node = document.createElementNS(NS, tag);
    for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function hexCenter(q, r) {
    return { x: SIZE * Math.sqrt(3) * (q + r / 2), y: SIZE * 1.5 * r };
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
    return data.gangs.find((g) => g.id === id) || null;
  }

  function contrastColor(hex) {
    const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
    return 0.299 * r + 0.587 * g + 0.114 * b > 140 ? "#241d2e" : "#f5efe2";
  }

  function truncate(s, n) {
    return s.length > n ? s.slice(0, n - 1) + "…" : s;
  }

  // Grey hatch pattern for no-man's-land — reads cleanly on paper.
  const defs = el("defs", {});
  const pat = el("pattern", {
    id: "nml-hatch-print", patternUnits: "userSpaceOnUse",
    width: 14, height: 14, patternTransform: "rotate(-45)",
  });
  pat.appendChild(el("rect", { width: 14, height: 14, fill: "#ffffff" }));
  pat.appendChild(el("rect", { width: 7, height: 14, fill: "#dedede" }));
  defs.appendChild(pat);
  svg.appendChild(defs);

  const centers = data.turfs.map((t) => ({ t, c: hexCenter(t.q, t.r) }));
  const pad = SIZE * 1.3;
  const xs = centers.map((o) => o.c.x);
  const ys = centers.map((o) => o.c.y);
  const minX = Math.min(...xs) - pad, maxX = Math.max(...xs) + pad;
  const minY = Math.min(...ys) - pad, maxY = Math.max(...ys) + pad;
  svg.setAttribute("viewBox", `${minX} ${minY} ${maxX - minX} ${maxY - minY}`);

  for (const { t, c } of centers) {
    const gang = gangById(t.gang_id);
    svg.appendChild(el("polygon", {
      points: hexPoints(c.x, c.y),
      class: "hex",
      fill: gang ? gang.color : "url(#nml-hatch-print)",
    }));

    const labelFill = gang ? contrastColor(gang.color) : "#2a2233";

    if (gang && gang.icon_path) {
      const size = 30;
      svg.appendChild(el("path", {
        d: gang.icon_path,
        fill: labelFill,
        "fill-opacity": "0.9",
        transform: `translate(${c.x - size / 2} ${c.y - SIZE * 0.45 - size / 2}) scale(${size / 512})`,
      }));
    }

    if (t.home_gang_id && t.home_gang_id === t.gang_id) {
      svg.appendChild(el("text", {
        x: c.x, y: c.y + SIZE * 0.72,
        "text-anchor": "middle", class: "hex-home", fill: labelFill,
      }, "⌂"));
    }

    const words = t.name.split(" ");
    const line1 = words.slice(0, Math.ceil(words.length / 2)).join(" ");
    const line2 = words.slice(Math.ceil(words.length / 2)).join(" ");
    svg.appendChild(el("text", {
      x: c.x, y: c.y + 2, "text-anchor": "middle", class: "hex-label", fill: labelFill,
    }, truncate(line1, 14)));
    if (line2) {
      svg.appendChild(el("text", {
        x: c.x, y: c.y + 13, "text-anchor": "middle", class: "hex-label", fill: labelFill,
      }, truncate(line2, 14)));
    }
    if (t.territory_type) {
      svg.appendChild(el("text", {
        x: c.x, y: c.y + (line2 ? 24 : 13), "text-anchor": "middle", class: "hex-type", fill: labelFill,
      }, truncate(t.territory_type, 18)));
    }
  }

  // Legend
  const entries = data.gangs.map((g) => {
    const held = data.turfs.filter((t) => t.gang_id === g.id).length;
    return { color: g.color, gang: g, label: g.name, sub: `${g.gang_type} · ${held} turf${held === 1 ? "" : "s"}` };
  });
  const nml = data.turfs.filter((t) => !t.gang_id).length;
  entries.push({ hatch: true, label: "No-man's-land", sub: `${nml} turf${nml === 1 ? "" : "s"}` });

  for (const entry of entries) {
    const li = document.createElement("li");
    const sw = document.createElement("span");
    sw.className = "swatch" + (entry.hatch ? " swatch-nml" : "");
    if (entry.color) sw.style.background = entry.color;
    li.appendChild(sw);
    if (entry.gang && entry.gang.icon_path) {
      const s = el("svg", { width: 16, height: 16, viewBox: "0 0 512 512" });
      s.appendChild(el("path", { d: entry.gang.icon_path, fill: entry.gang.color }));
      li.appendChild(s);
    }
    const name = document.createElement("strong");
    name.textContent = entry.label;
    const sub = document.createElement("span");
    sub.className = "sub";
    sub.textContent = entry.sub;
    li.append(name, sub);
    legendEl.appendChild(li);
  }
})();
