// Injected into the page under test so the caption banner and (Task 4) the
// synthetic cursor/highlight are real DOM — Playwright video captures the
// rendering engine, not the OS, so anything visible must live in the DOM.
window.__demo = window.__demo || {};

window.__demo.ensureCaption = function () {
  let el = document.getElementById("demo-caption");
  if (!el) {
    el = document.createElement("div");
    el.id = "demo-caption";
    el.style.cssText = [
      "position:fixed", "left:0", "right:0", "bottom:0", "z-index:2147483647",
      "padding:16px 24px", "font:600 20px/1.4 system-ui,sans-serif",
      "color:#fff", "background:rgba(17,24,39,.92)", "text-align:center",
      // Display-only overlay: never intercept clicks on the page beneath it
      // (the banner sits at the bottom, over submit buttons). The cursor and
      // ripple are already pointer-events:none for the same reason.
      "pointer-events:none"
    ].join(";");
    document.body.appendChild(el);
  }
  return el;
};

window.__demo.caption = function (text) {
  window.__demo.ensureCaption().textContent = text;
};

window.__demo.ensureCursor = function () {
  let c = document.getElementById("demo-cursor");
  if (!c) {
    c = document.createElement("div");
    c.id = "demo-cursor";
    c.style.cssText = [
      "position:fixed", "width:22px", "height:22px", "z-index:2147483647",
      "margin:-11px 0 0 -11px", "border-radius:50%",
      "background:rgba(37,99,235,.45)", "border:2px solid #2563eb",
      "transition:left .4s ease,top .4s ease", "pointer-events:none",
      "left:-100px", "top:-100px"
    ].join(";");
    document.body.appendChild(c);
  }
  return c;
};

// Move the cursor over an element's center and add a highlight outline.
window.__demo.point = function (selector) {
  const el = document.querySelector(selector);
  if (!el) return false;
  el.scrollIntoView({ block: "center", behavior: "instant" });
  const r = el.getBoundingClientRect();
  const c = window.__demo.ensureCursor();
  c.style.left = (r.left + r.width / 2) + "px";
  c.style.top = (r.top + r.height / 2) + "px";
  el.style.outline = "3px solid #2563eb";
  el.style.outlineOffset = "2px";
  el.dataset.demoHighlighted = "1";
  return true;
};

window.__demo.unpoint = function () {
  document.querySelectorAll("[data-demo-highlighted]").forEach((el) => {
    el.style.outline = ""; el.style.outlineOffset = ""; delete el.dataset.demoHighlighted;
  });
};

// A ripple at the cursor position to signal a click.
window.__demo.ripple = function () {
  const c = window.__demo.ensureCursor();
  const ring = document.createElement("div");
  ring.style.cssText = [
    "position:fixed", "z-index:2147483646", "width:22px", "height:22px",
    "margin:-11px 0 0 -11px", "border-radius:50%", "border:2px solid #2563eb",
    "left:" + c.style.left, "top:" + c.style.top,
    "animation:demo-ripple .5s ease-out forwards", "pointer-events:none"
  ].join(";");
  if (!document.getElementById("demo-ripple-kf")) {
    const s = document.createElement("style");
    s.id = "demo-ripple-kf";
    s.textContent = "@keyframes demo-ripple{to{transform:scale(2.6);opacity:0}}";
    document.head.appendChild(s);
  }
  document.body.appendChild(ring);
  setTimeout(() => ring.remove(), 600);
};
