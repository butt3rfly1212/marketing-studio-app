"""Bundle the shared web office for the Flutter workspace asset."""
import base64
import re
import shutil
from pathlib import Path


APP = Path(__file__).resolve().parents[1]
WEB = APP.parents[1] / "dashboard" / "src"
OUT = APP / "assets" / "office" / "index.html"

CSS = """
html, body { height: 100%; margin: 0; }
.vo .vo-close, .vo [aria-label="오피스 닫기"] { display: none; }
"""

BRIDGE = """
(() => {
  function append(node, value) {
    if (Array.isArray(value)) value.forEach(item => append(node, item));
    else if (value != null && value !== false) node.append(value);
  }
  function h(tag, attrs, ...children) {
    const node = document.createElement(tag);
    for (const [name, value] of Object.entries(attrs || {})) {
      if (value == null || value === false) continue;
      if (name.startsWith("on") && typeof value === "function") node.addEventListener(name.slice(2).toLowerCase(), value);
      else if (name === "style" && typeof value === "object") {
        for (const [key, prop] of Object.entries(value)) node.style.setProperty(key, prop);
      }
      else node.setAttribute(name, value === true ? "" : value);
    }
    children.forEach(item => append(node, item));
    return node;
  }
  const paths = {
    close: "M4 4l8 8M12 4l-8 8",
    external: "M9 3h4v4m0-4L7 9M6 4H3v9h9v-3",
    refresh: "M12 7a5 5 0 1 0-1 5M12 3v4H8"
  };
  function icon(name) {
    const ns = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(ns, "svg");
    svg.setAttribute("class", "icon");
    svg.setAttribute("viewBox", "0 0 16 16");
    svg.setAttribute("aria-hidden", "true");
    const path = document.createElementNS(ns, "path");
    path.setAttribute("d", paths[name] || paths.external);
    path.setAttribute("fill", "none");
    path.setAttribute("stroke", "currentColor");
    path.setAttribute("stroke-width", "1.5");
    svg.append(path);
    return svg;
  }
  window.Studio = { h, icon, get theme() { return document.documentElement.dataset.theme; } };
  let id = 0, active = false;
  const pending = new Map();
  function send(data) {
    const message = JSON.stringify({ office: true, ...data });
    if (window.OfficeBridge) window.OfficeBridge.postMessage(message);
    else window.parent.postMessage(message, "*");
  }
  function request(route, body) {
    return new Promise((resolve, reject) => {
      const idForRequest = ++id;
      const timeout = setTimeout(() => {
        pending.delete(idForRequest);
        reject(new Error("요청 시간이 오래 걸립니다. 다시 시도해 주세요."));
      }, 18000);
      pending.set(idForRequest, { resolve, reject, timeout });
      send({ id: idForRequest, route, body });
    });
  }
  window.officeFromHost = msg => {
    if (msg.type === "config") {
      document.documentElement.dataset.theme = msg.theme === "light" ? "light" : "dark";
      if (active !== msg.active) {
        active = msg.active;
        StudioOffice.toggle(active);
      }
      return;
    }
    const task = pending.get(msg.id);
    if (!task) return;
    clearTimeout(task.timeout);
    pending.delete(msg.id);
    if (msg.status >= 400) task.reject(Object.assign(new Error(msg.error), { status: msg.status }));
    else task.resolve(msg.data);
  };
  window.addEventListener("message", ev => {
    if (ev.source !== window.parent || typeof ev.data !== "string") return;
    try { window.officeFromHost(JSON.parse(ev.data)); } catch (_) {}
  });
  window.StudioOfficeApp = Object.freeze({
    skills: body => request("skills", body),
    meeting: body => request("meeting", body),
    metrics: (start, end) => request("metrics", { start, end })
  });
  window.officeReady = async () => {
    try {
      const user = await request("identity");
      window.dispatchEvent(new CustomEvent("studio-user", { detail: user }));
    } catch (_) {}
  };
  document.addEventListener("click", ev => {
    const link = ev.target.closest("a[href]");
    if (!link) return;
    ev.preventDefault();
    request("open", link.href).catch(() => {});
  });
})();
"""

def css_source():
    css = (WEB / "styles.css").read_text(encoding="utf-8")
    def embed_font(match):
        name = match[1]
        data = base64.b64encode((WEB / "fonts" / name).read_bytes()).decode("ascii")
        return 'url("data:font/woff2;base64,' + data + '")'
    return "\n".join([
        re.sub(r'url\("fonts/([^"]+)"\)', embed_font, css),
        *[(WEB / name).read_text(encoding="utf-8") for name in ("skill-runs.css", "office.css")],
        CSS,
    ])


def main():
    files = ["office-sprites.js", "office-roster.js", "office-world.js", "skill-runs.js", "office-live.js", "office.js"]
    scripts = [BRIDGE, *((WEB / name).read_text(encoding="utf-8") for name in files), "window.officeReady();"]
    page = "\n".join([
        '<!doctype html><html lang="ko" data-theme="dark"><head><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width,initial-scale=1">',
        '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src \'unsafe-inline\'; style-src \'unsafe-inline\'; font-src data:; img-src data:">',
        '<title>버추얼 오피스</title><style>', css_source(), '</style></head><body>',
        *['<script>\n' + script.replace("</script", "<\\/script") + '\n</script>' for script in scripts],
        '</body></html>',
    ])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page, encoding="utf-8", newline="\n")
    shutil.copyfile(WEB / "favicon" / "favicon-32.png", OUT.parent / "studio-mark.png")
    for license_file in sorted((WEB / "fonts").glob("LICENSE-*.txt")):
        shutil.copyfile(license_file, OUT.parent / license_file.name)


if __name__ == "__main__":
    main()
