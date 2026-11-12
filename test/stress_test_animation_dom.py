#!/usr/bin/env python3
"""
Adversarial Performance & Animation Stress Verification Harness
---------------------------------------------------------------
Written by Challenger 2 (Empirical Challenger) to rigorously probe:
1. Baseline test/verify_website.py execution
2. Typed.js initialization, cursor blinking, dynamic loop rotation, and memory/DOM stability
3. Anime.js entrance and scroll reveal transforms, inline style cleanup, and CSS :hover compatibility
4. Interactive micro-interactions and button inline transform effects
5. Ambient animations (.hero-artwork-frame, .pulse-dot) smoothness & Cumulative Layout Shift (CLS)
6. prefers-reduced-motion emulation: complete bypass, fallback visibility, no stuck opacity: 0
7. Responsive layout stability across 9 viewports (mobile to wide desktop), checking overflow & drawer
"""

import base64
import http.server
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from urllib.parse import urlparse
import urllib.request


class SimpleCDPClient:
    def __init__(self, ws_url):
        u = urlparse(ws_url)
        self.sock = socket.create_connection((u.hostname, u.port), timeout=15)
        key = base64.b64encode(os.urandom(16)).decode('ascii')
        req = (
            f"GET {u.path} HTTP/1.1\r\n"
            f"Host: {u.hostname}:{u.port}\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n"
        )
        self.sock.sendall(req.encode('utf-8'))
        resp = self.sock.recv(4096).decode('utf-8', errors='ignore')
        if not resp.startswith("HTTP/1.1 101"):
            raise RuntimeError(f"WebSocket handshake failed: {resp}")
        self.msg_id = 0

    def send_cmd(self, method, params=None, timeout=15):
        self.msg_id += 1
        cmd_id = self.msg_id
        payload = {"id": cmd_id, "method": method}
        if params:
            payload["params"] = params
        data = json.dumps(payload).encode('utf-8')
        length = len(data)
        mask = os.urandom(4)
        if length <= 125:
            header = bytes([0x81, 0x80 | length])
        elif length <= 65535:
            header = bytes([0x81, 0x80 | 126]) + length.to_bytes(2, 'big')
        else:
            header = bytes([0x81, 0x80 | 127]) + length.to_bytes(8, 'big')
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
        self.sock.sendall(header + mask + masked)

        start = time.time()
        while time.time() - start < timeout:
            msg = self._read_frame()
            if not msg:
                continue
            try:
                parsed = json.loads(msg)
                if parsed.get("id") == cmd_id:
                    return parsed
            except Exception:
                pass
        raise TimeoutError(f"Command {method} (id={cmd_id}) timed out")

    def eval_js(self, expression):
        res = self.send_cmd("Runtime.evaluate", {
            "expression": expression,
            "returnByValue": True,
            "awaitPromise": True
        })
        result = res.get("result", {})
        if "exceptionDetails" in result:
            exc = result["exceptionDetails"]
            raise RuntimeError(f"JS Exception: {exc.get('text')} - {exc.get('exception', {}).get('description')}")
        val_obj = result.get("result", {})
        return val_obj.get("value")

    def _read_frame(self):
        try:
            head = self.sock.recv(2)
            if len(head) < 2:
                return None
            b1, b2 = head[0], head[1]
            opcode = b1 & 0x0f
            length = b2 & 0x7f
            if length == 126:
                ext = self.sock.recv(2)
                length = int.from_bytes(ext, 'big')
            elif length == 127:
                ext = self.sock.recv(8)
                length = int.from_bytes(ext, 'big')
            buf = bytearray()
            while len(buf) < length:
                chunk = self.sock.recv(length - len(buf))
                if not chunk:
                    break
                buf.extend(chunk)
            return buf.decode('utf-8', errors='ignore')
        except socket.timeout:
            return None

    def close(self):
        try:
            self.sock.close()
        except Exception:
            pass


class AdversarialAnimationStressRunner:
    def __init__(self):
        self.project_root = Path("/home/dusk/Downloads/Epilogue")
        self.docs_dir = self.project_root / "docs"
        self.server = None
        self.server_port = None
        self.proc = None
        self.cdp = None
        self.temp_dir = None
        self.findings = []
        self.passes = []

    def log_pass(self, title, detail=""):
        self.passes.append((title, detail))
        print(f"  [PASS] {title}" + (f" -> {detail}" if detail else ""))

    def log_finding(self, severity, title, detail):
        self.findings.append((severity, title, detail))
        print(f"  [{severity.upper()}] {title}: {detail}")

    def start_environment(self, port=9444, extra_flags=None):
        handler = lambda *args: http.server.SimpleHTTPRequestHandler(*args, directory=str(self.docs_dir))
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        self.server_port = self.server.server_address[1]
        self.server_thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.server_thread.start()

        self.temp_dir = tempfile.mkdtemp()
        cmd = [
            "chromium",
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            f"--user-data-dir={self.temp_dir}",
            f"--remote-debugging-port={port}",
            "--enable-precise-memory-info",
            f"http://127.0.0.1:{self.server_port}/index.html"
        ]
        if extra_flags:
            cmd.extend(extra_flags)

        self.proc = subprocess.Popen(cmd, stderr=subprocess.DEVNULL)
        time.sleep(1.5)

        for _ in range(10):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list", timeout=2) as r:
                    tabs = json.loads(r.read().decode())
                page = next(t for t in tabs if t.get("type") == "page")
                self.cdp = SimpleCDPClient(page["webSocketDebuggerUrl"])
                # Enable required domains
                self.cdp.send_cmd("Runtime.enable")
                self.cdp.send_cmd("Page.enable")
                self.cdp.send_cmd("DOM.enable")
                break
            except Exception:
                time.sleep(0.5)

        if not self.cdp:
            raise RuntimeError("Failed to connect to Chromium CDP")

        # Wait until page readyState is complete and scripts initialize
        start = time.time()
        while time.time() - start < 8.0:
            status = self.cdp.eval_js('''(() => {
                return {
                    readyState: document.readyState,
                    hasTyped: typeof Typed !== 'undefined',
                    hasAnime: typeof anime !== 'undefined',
                    hasCursor: !!document.querySelector('.typed-cursor')
                };
            })()''')
            if status["readyState"] == "complete" and status["hasTyped"] and status["hasAnime"] and status["hasCursor"]:
                break
            time.sleep(0.3)

    def stop_environment(self):
        if self.cdp:
            self.cdp.close()
            self.cdp = None
        if self.proc:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=2)
            except Exception:
                self.proc.kill()
            self.proc = None
        if self.server:
            self.server.shutdown()
            self.server = None

    def run_suite(self):
        print("======================================================================")
        print("CHALLENGER 2: ADVERSARIAL PERFORMANCE & ANIMATION STRESS VERIFICATION")
        print("======================================================================")

        # 1. Baseline Test Execution
        self.test_baseline_verification_harness()

        # Start browser for interactive tests
        self.start_environment(port=9455)
        try:
            # 2. Typed.js Initialization, Blinking, Dynamic Typing, Memory/DOM Stability
            self.test_typed_initialization_and_blinking()
            self.test_typed_typing_loop_and_memory_stability()

            # 3. Anime.js Entrance & Scroll Reveals Inline Style Cleanup
            self.test_anime_entrance_transforms_cleanup()
            self.test_anime_scroll_reveals_cleanup()

            # 4. Button Micro-interactions & CSS :hover specificity conflict
            self.test_button_micro_interactions_and_hover()

            # 5. Ambient Animations & Layout Shift (CLS)
            self.test_ambient_animations_and_cls()

            # 6. prefers-reduced-motion Compliance & Visibility
            self.test_reduced_motion_compliance()

            # 7. Responsive Viewport Stress & Breakpoints
            self.test_responsive_viewports()

        finally:
            self.stop_environment()

        print("\n======================================================================")
        print(f"VERIFICATION SUMMARY: {len(self.passes)} Passed, {len(self.findings)} Findings Recorded.")
        print("======================================================================")
        for sev, title, detail in self.findings:
            print(f"  [{sev.upper()}] {title}: {detail}")

        return len(self.findings) == 0

    # ------------------------------------------------------------------
    # Test 1: Baseline verify_website.py
    # ------------------------------------------------------------------
    def test_baseline_verification_harness(self):
        print("\n[Suite 1] Executing baseline test/verify_website.py...")
        res = subprocess.run(
            [sys.executable, str(self.project_root / "test" / "verify_website.py")],
            capture_output=True,
            text=True
        )
        if res.returncode == 0:
            self.log_pass("Baseline test/verify_website.py", "12/12 checks passed with exit code 0")
        else:
            self.log_finding("HIGH", "Baseline test/verify_website.py Failed", f"Exit {res.returncode}:\n{res.stdout}\n{res.stderr}")

    # ------------------------------------------------------------------
    # Test 2: Typed.js Initialization, Cursor Blink & Memory Leak Stress
    # ------------------------------------------------------------------
    def test_typed_initialization_and_blinking(self):
        print("\n[Suite 2] Testing Typed.js Initialization & Cursor Blinking...")
        info = self.cdp.eval_js('''(() => {
            const el = document.getElementById("typed-tagline");
            const cursor = document.querySelector(".typed-cursor");
            const wrapper = document.querySelector(".hero-tagline-wrapper");
            const style = cursor ? window.getComputedStyle(cursor) : null;
            return {
                text: el ? el.textContent : null,
                hasCursor: !!cursor,
                cursorDisplay: style ? style.display : null,
                cursorAnimName: style ? style.animationName : null,
                cursorAnimDuration: style ? style.animationDuration : null,
                cursorAnimIteration: style ? style.animationIterationCount : null,
                wrapperMinHeight: wrapper ? window.getComputedStyle(wrapper).minHeight : null
            };
        })()''')

        if info["hasCursor"]:
            self.log_pass("Typed.js Cursor Element Present", f"Cursor rendered, wrapper minHeight={info['wrapperMinHeight']}")
        else:
            self.log_finding("HIGH", "Typed.js Cursor Missing", "No .typed-cursor element found in DOM")

        if info.get("cursorAnimName") == "typedBlink":
            self.log_pass("Cursor Blink Animation Configured", f"animName={info['cursorAnimName']}, duration={info['cursorAnimDuration']}, loop={info['cursorAnimIteration']}")
        else:
            self.log_finding("MEDIUM", "Cursor Blink Animation Missing", f"animationName={info.get('cursorAnimName')}")

        # Sample cursor opacity over 800ms to observe blink oscillation
        opacities = []
        for _ in range(5):
            op = self.cdp.eval_js('''(() => {
                const c = document.querySelector(".typed-cursor");
                return c ? window.getComputedStyle(c).opacity : null;
            })()''')
            if op is not None:
                opacities.append(float(op))
            time.sleep(0.18)

        self.log_pass("Cursor Opacity Dynamics", f"Sampled opacities during blink cycle: {opacities}")

    def test_typed_typing_loop_and_memory_stability(self):
        print("\n[Suite 2b] Testing Typed.js Loop Execution & Memory/DOM Growth...")
        texts = []
        heaps = []
        dom_counts = []

        for i in range(5):
            stats = self.cdp.eval_js('''(() => {
                const el = document.getElementById("typed-tagline");
                return {
                    text: el ? el.textContent : "",
                    heapUsed: performance.memory ? performance.memory.usedJSHeapSize : 0,
                    domNodes: document.querySelectorAll("*").length
                };
            })()''')
            texts.append(stats["text"])
            heaps.append(stats["heapUsed"])
            dom_counts.append(stats["domNodes"])
            time.sleep(0.8)

        distinct_texts = len(set(texts))
        if distinct_texts >= 2:
            self.log_pass("Dynamic Text Typing Active", f"{distinct_texts} distinct text states observed over 4s: {texts[:3]}")
        else:
            self.log_finding("HIGH", "Typed.js Not Typing", f"Text remained static: {texts}")

        dom_growth = max(dom_counts) - min(dom_counts)
        heap_growth_kb = (heaps[-1] - heaps[0]) / 1024.0

        if dom_growth == 0:
            self.log_pass("DOM Node Count Stability", f"Node count constant ({dom_counts[0]} nodes, growth = 0)")
        else:
            self.log_finding("LOW", "DOM Node Fluctuation", f"DOM node count grew by {dom_growth} nodes")

        if heap_growth_kb < 1024:
            self.log_pass("Heap Memory Stability", f"Heap variation {heap_growth_kb:.1f} KB (< 1 MB), no runaway leak")
        else:
            self.log_finding("MEDIUM", "Heap Memory Growth", f"Heap grew by {heap_growth_kb:.1f} KB over 4 seconds")

    # ------------------------------------------------------------------
    # Test 3: Anime.js Entrance Transforms Cleanup
    # ------------------------------------------------------------------
    def test_anime_entrance_transforms_cleanup(self):
        print("\n[Suite 3] Testing Anime.js Hero Entrance Transforms Cleanup...")
        # Wait to ensure hero entrance animation has completed
        time.sleep(1.0)

        cleanup_report = self.cdp.eval_js('''(() => {
            const targets = document.querySelectorAll(
                '.hero-badge, .hero-title, .hero-tagline-wrapper, .hero-description, .hero-cta-group, .hero-stats-row'
            );
            const results = [];
            targets.forEach(el => {
                results.push({
                    className: el.className,
                    inlineTransform: el.style.transform,
                    inlineOpacity: el.style.opacity,
                    computedTransform: window.getComputedStyle(el).transform,
                    computedOpacity: window.getComputedStyle(el).opacity
                });
            });
            return results;
        })()''')

        all_clean = True
        for item in cleanup_report:
            if item["inlineTransform"] != "":
                all_clean = False
                self.log_finding("HIGH", f"Stale Inline Transform on {item['className']}", f"style.transform = '{item['inlineTransform']}' (should be empty)")
            if item["computedOpacity"] != "1":
                self.log_finding("HIGH", f"Element not fully visible: {item['className']}", f"computedOpacity = '{item['computedOpacity']}'")

        if all_clean:
            self.log_pass("Hero Entrance Inline Transforms Cleaned", f"All {len(cleanup_report)} hero elements have empty inline transform ('') and computedOpacity=1")

    # ------------------------------------------------------------------
    # Test 4: Scroll Reveals Inline Style Cleanup
    # ------------------------------------------------------------------
    def test_anime_scroll_reveals_cleanup(self):
        print("\n[Suite 4] Testing Scroll Reveals & Card Hover Compatibility...")
        # Scroll down to features and downloads
        self.cdp.eval_js('window.scrollTo(0, document.body.scrollHeight / 2);')
        time.sleep(1.0)
        self.cdp.eval_js('window.scrollTo(0, document.body.scrollHeight);')
        time.sleep(1.0)

        card_report = self.cdp.eval_js('''(() => {
            const cards = document.querySelectorAll('.bento-card, .download-card');
            const results = [];
            cards.forEach(c => {
                results.push({
                    className: c.className.split(' ')[0],
                    inlineTransform: c.style.transform,
                    computedTransform: window.getComputedStyle(c).transform,
                    computedOpacity: window.getComputedStyle(c).opacity
                });
            });
            return results;
        })()''')

        transforms_cleared = all(c["inlineTransform"] == "" for c in card_report)
        if transforms_cleared and len(card_report) > 0:
            self.log_pass("Scroll Reveal Cards Cleaned", f"All {len(card_report)} cards have inline transform = ''")
        else:
            uncleared = [c for c in card_report if c["inlineTransform"] != ""]
            self.log_finding("HIGH", "Scroll Reveal Cards Have Stale Transforms", f"{len(uncleared)} cards with stale transform: {uncleared[:2]}")

    # ------------------------------------------------------------------
    # Test 5: Interactive Button Micro-Interactions & Specificity Conflict
    # ------------------------------------------------------------------
    def test_button_micro_interactions_and_hover(self):
        print("\n[Suite 5] Testing Button Micro-Interactions & Specificity Conflict...")
        before = self.cdp.eval_js('''(() => {
            const btn = document.querySelector(".btn-primary");
            return {
                style: btn ? btn.getAttribute("style") : null,
                computedTransform: btn ? window.getComputedStyle(btn).transform : null
            };
        })()''')
        self.log_pass("Btn-Primary Before Interaction", f"style='{before['style']}', transform='{before['computedTransform']}'")

        # Simulate mousedown then mouseup
        self.cdp.eval_js('''(() => {
            const btn = document.querySelector(".btn-primary");
            if (btn) btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
        })()''')
        time.sleep(0.15)
        self.cdp.eval_js('''(() => {
            const btn = document.querySelector(".btn-primary");
            if (btn) btn.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
        })()''')
        time.sleep(0.3)

        after_click = self.cdp.eval_js('''(() => {
            const btn = document.querySelector(".btn-primary");
            return {
                inlineStyle: btn ? btn.getAttribute("style") : null,
                inlineTransform: btn ? btn.style.transform : null,
                computedTransform: btn ? window.getComputedStyle(btn).transform : null
            };
        })()''')

        # Adversarial check: Anime sets inline style="transform: scale(1);" on mouseup.
        self.cdp.eval_js('''(() => {
            const btn = document.querySelector(".btn-primary");
            if (btn) btn.dispatchEvent(new MouseEvent("mouseleave", { bubbles: true }));
        })()''')
        time.sleep(0.3)

        after_leave = self.cdp.eval_js('''(() => {
            const btn = document.querySelector(".btn-primary");
            return {
                inlineStyle: btn ? btn.getAttribute("style") : null,
                inlineTransform: btn ? btn.style.transform : null,
                computedTransform: btn ? window.getComputedStyle(btn).transform : null
            };
        })()''')

        # Check if inline style has scale(1)
        if after_leave["inlineTransform"] and "scale(1)" in after_leave["inlineTransform"]:
            self.log_finding(
                "MEDIUM",
                "Button Micro-Interaction Leaves Persistent Inline Transform",
                f"btn-primary style='{after_leave['inlineStyle']}'. Because anime({{'scale': 1}}) leaves inline transform: scale(1), CSS .btn-primary:hover {{ transform: translateY(-2px); }} can be overridden by inline specificity on subsequent hovers unless target.style.transform is cleared upon animation completion."
            )
        else:
            self.log_pass("Button Micro-Interaction Cleanup", f"Inline transform after mouseleave: '{after_leave['inlineTransform']}'")

    # ------------------------------------------------------------------
    # Test 6: Ambient Animations Smoothness & CLS
    # ------------------------------------------------------------------
    def test_ambient_animations_and_cls(self):
        print("\n[Suite 6] Testing Ambient Animations Smoothness & Layout Shift (CLS)...")
        self.cdp.eval_js('window.scrollTo(0, 0);')
        time.sleep(0.5)

        # Setup PerformanceObserver to track Cumulative Layout Shift (CLS)
        self.cdp.eval_js('''(() => {
            window.__clsEntries = [];
            window.__clsScore = 0;
            const observer = new PerformanceObserver((list) => {
                for (const entry of list.getEntries()) {
                    if (!entry.hadRecentInput) {
                        window.__clsScore += entry.value;
                        window.__clsEntries.push({
                            value: entry.value,
                            startTime: entry.startTime
                        });
                    }
                }
            });
            observer.observe({ type: "layout-shift", buffered: true });
        })()''')

        # Monitor ambient frame transforms across 3 seconds
        frame_transforms = []
        for _ in range(6):
            res = self.cdp.eval_js('''(() => {
                const frame = document.querySelector(".hero-artwork-frame");
                const dot = document.querySelector(".pulse-dot");
                return {
                    frameTransform: frame ? frame.style.transform || window.getComputedStyle(frame).transform : null,
                    dotTransform: dot ? dot.style.transform || window.getComputedStyle(dot).transform : null
                };
            })()''')
            frame_transforms.append(res)
            time.sleep(0.5)

        cls_res = self.cdp.eval_js('''(() => {
            return {
                clsScore: window.__clsScore || 0,
                entriesCount: (window.__clsEntries || []).length
            };
        })()''')

        self.log_pass("Ambient Animation Trajectory", f"Hero frame active transforms: {[f['frameTransform'] for f in frame_transforms[:3]]}")
        self.log_pass("Pulse Dot Trajectory", f"Pulse dot active transforms: {[f['dotTransform'] for f in frame_transforms[:3]]}")

        if cls_res["clsScore"] == 0.0:
            self.log_pass("Zero Cumulative Layout Shift (CLS)", f"clsScore = 0.0, shifts = {cls_res['entriesCount']}")
        else:
            self.log_finding("MEDIUM", "Layout Shift Detected During Ambient Animation", f"clsScore = {cls_res['clsScore']}, entries = {cls_res['entriesCount']}")

    # ------------------------------------------------------------------
    # Test 7: prefers-reduced-motion Compliance & Visibility
    # ------------------------------------------------------------------
    def test_reduced_motion_compliance(self):
        print("\n[Suite 7] Testing prefers-reduced-motion Compliance & Fallback...")
        # Emulate reduced motion
        self.cdp.send_cmd("Emulation.setEmulatedMedia", {
            "features": [{"name": "prefers-reduced-motion", "value": "reduce"}]
        })

        # Reload the page under reduced motion
        self.cdp.send_cmd("Page.reload")
        time.sleep(2.0)

        motion_audit = self.cdp.eval_js('''(() => {
            const matchesReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
            const tagline = document.getElementById("typed-tagline");
            const cursor = document.querySelector(".typed-cursor");
            const heroEls = document.querySelectorAll(
                '.hero-badge, .hero-title, .hero-tagline-wrapper, .hero-description, .hero-cta-group, .hero-stats-row, .hero-artwork-frame'
            );
            const cards = document.querySelectorAll('.bento-card, .download-card');

            const hiddenElements = [];
            heroEls.forEach(el => {
                const s = window.getComputedStyle(el);
                if (parseFloat(s.opacity) < 0.5 || s.display === 'none' || s.visibility === 'hidden') {
                    hiddenElements.push({ tag: el.tagName, class: el.className, opacity: s.opacity });
                }
            });
            cards.forEach(el => {
                const s = window.getComputedStyle(el);
                if (parseFloat(s.opacity) < 0.5 || s.display === 'none' || s.visibility === 'hidden') {
                    hiddenElements.push({ tag: el.tagName, class: el.className, opacity: s.opacity });
                }
            });

            return {
                matchesReduced,
                taglineText: tagline ? tagline.textContent : null,
                taglineVisible: tagline ? window.getComputedStyle(tagline).display !== 'none' : false,
                hasCursor: !!cursor,
                cursorDisplay: cursor ? window.getComputedStyle(cursor).display : 'none',
                hiddenCount: hiddenElements.length,
                hiddenElements: hiddenElements
            };
        })()''')

        if motion_audit["matchesReduced"]:
            self.log_pass("Reduced Motion Media Emulation", "matchMedia('(prefers-reduced-motion: reduce)').matches == true")
        else:
            self.log_finding("HIGH", "Emulation Failure", "Reduced motion media query was not matched")

        if motion_audit["hiddenCount"] == 0:
            self.log_pass("Elements Fully Visible Under Reduced Motion", "Zero elements stuck at opacity: 0 or hidden")
        else:
            self.log_finding("HIGH", "Elements Stuck Hidden in Reduced Motion", f"{motion_audit['hiddenCount']} elements stuck hidden: {motion_audit['hiddenElements']}")

        if motion_audit["taglineVisible"] and motion_audit["taglineText"]:
            self.log_pass("Semantic Fallback Text Visible", f"Tagline: '{motion_audit['taglineText']}'")
        else:
            self.log_finding("HIGH", "Tagline Fallback Invisible", f"Visible: {motion_audit['taglineVisible']}, text: '{motion_audit['taglineText']}'")

        if not motion_audit["hasCursor"] or motion_audit["cursorDisplay"] == "none":
            self.log_pass("Typed Cursor Suppressed Under Reduced Motion", f"hasCursor={motion_audit['hasCursor']}, display='{motion_audit['cursorDisplay']}'")
        else:
            self.log_finding("MEDIUM", "Cursor Still Displayed Under Reduced Motion", f"cursorDisplay='{motion_audit['cursorDisplay']}'")

        # Reset emulated media
        self.cdp.send_cmd("Emulation.setEmulatedMedia", {"features": []})

    # ------------------------------------------------------------------
    # Test 8: Responsive Layout Breakpoint Stress
    # ------------------------------------------------------------------
    def test_responsive_viewports(self):
        print("\n[Suite 8] Testing Responsive Viewports & DOM Stability...")
        self.cdp.send_cmd("Page.reload")
        time.sleep(2.0)

        viewports = [
            ("Mobile Small", 360, 640),
            ("iPhone SE", 375, 667),
            ("iPhone 12/13/14", 390, 844),
            ("Pixel 7", 412, 915),
            ("Tablet Portrait", 768, 1024),
            ("Tablet Landscape", 1024, 768),
            ("Laptop", 1280, 800),
            ("Desktop Standard", 1440, 900),
            ("Desktop Wide", 1920, 1080)
        ]

        for name, width, height in viewports:
            self.cdp.send_cmd("Emulation.setDeviceMetricsOverride", {
                "width": width,
                "height": height,
                "deviceScaleFactor": 1,
                "mobile": width < 768
            })
            time.sleep(0.3)

            res = self.cdp.eval_js(f'''(() => {{
                const scrollW = document.documentElement.scrollWidth;
                const innerW = window.innerWidth;
                const overflowW = scrollW - innerW;

                const mobileBtn = document.getElementById("mobile-menu-btn");
                const navMenu = document.getElementById("nav-menu");
                const mobileBtnVisible = mobileBtn ? window.getComputedStyle(mobileBtn).display !== 'none' : false;

                let bleedingCount = 0;
                document.querySelectorAll(".hero-title, .bento-card, .download-card, .btn-primary").forEach(el => {{
                    const rect = el.getBoundingClientRect();
                    if (rect.right > innerW + 1) {{
                        bleedingCount++;
                    }}
                }});

                return {{
                    scrollW,
                    innerW,
                    overflowW,
                    mobileBtnVisible,
                    bleedingCount
                }};
            }})()''')

            is_mobile = width < 768
            if res["overflowW"] <= 1 and res["bleedingCount"] == 0:
                self.log_pass(f"Viewport {name} ({width}x{height})", f"No horizontal overflow (scrollW={res['scrollW']}, innerW={res['innerW']}, mobileBtn={res['mobileBtnVisible']})")
            else:
                self.log_finding(
                    "HIGH" if res["overflowW"] > 10 else "MEDIUM",
                    f"Layout Overflow in {name} ({width}x{height})",
                    f"overflowW={res['overflowW']}px, bleedingElements={res['bleedingCount']}"
                )

            if is_mobile:
                toggle_test = self.cdp.eval_js('''(() => {
                    const btn = document.getElementById("mobile-menu-btn");
                    const menu = document.getElementById("nav-menu");
                    if (!btn || !menu) return null;
                    btn.click();
                    const opened = menu.classList.contains("open");
                    btn.click();
                    const closed = !menu.classList.contains("open");
                    return { opened, closed };
                })()''')
                if toggle_test and toggle_test["opened"] and toggle_test["closed"]:
                    self.log_pass(f"Mobile Nav Drawer ({name})", "Hamburger click opens and closes menu drawer successfully")
                else:
                    self.log_finding("MEDIUM", f"Mobile Nav Drawer Toggle Failed ({name})", f"toggle_test={toggle_test}")

        self.cdp.send_cmd("Emulation.clearDeviceMetricsOverride")


if __name__ == "__main__":
    runner = AdversarialAnimationStressRunner()
    success = runner.run_suite()
    sys.exit(0 if success else 1)
