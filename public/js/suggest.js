// HIVEHUB — 🎲 name suggestion buttons.
// Usage: <button class="suggest-btn" data-kind="campaign" data-target="input-id"
//         data-type-from="css-selector-of-select"> — fills the target input.
(function () {
  "use strict";

  document.querySelectorAll(".suggest-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const input = document.getElementById(btn.dataset.target);
      if (!input) return;
      let url = `/suggest/${btn.dataset.kind}`;
      if (btn.dataset.typeFrom) {
        const sel = document.querySelector(btn.dataset.typeFrom);
        if (sel) url += `?gang_type=${encodeURIComponent(sel.value)}`;
      }
      try {
        const res = await fetch(url);
        if (res.ok) input.value = (await res.json()).name;
      } catch { /* underhive vox interference — leave the input alone */ }
    });
  });
})();
