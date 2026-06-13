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
      "color:#fff", "background:rgba(17,24,39,.92)", "text-align:center"
    ].join(";");
    document.body.appendChild(el);
  }
  return el;
};

window.__demo.caption = function (text) {
  window.__demo.ensureCaption().textContent = text;
};
