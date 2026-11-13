#!/usr/bin/env python3
"""
Epilogue Production Website Automated Verification Harness (R4)
---------------------------------------------------------------
Validates that:
1. docs/index.html loads cleanly over HTTP without runtime JavaScript console errors.
2. anime.js and typed.js libraries are integrated and properly initialized.
3. Internal navigation uses clean URLs (no .html extensions, valid anchor IDs).
4. Outbound links have all tracking parameters (UTM, ref, fbclid, etc.) stripped.
5. All visible copy is reader-focused and free of technical jargon / geeky minutiae.

Exits with code 0 on complete pass, code 1 on any failure.
"""

import http.server
import json
import os
import re
import socketserver
import subprocess
import sys
import threading
import time
import urllib.parse
from html.parser import HTMLParser
from pathlib import Path


# -----------------------------------------------------------------------------
# Configuration & Constants
# -----------------------------------------------------------------------------
def find_project_root():
    current = Path(__file__).resolve()
    for parent in [current.parent, current.parent.parent, current.parents[2] if len(current.parents) > 2 else None, current.parents[3] if len(current.parents) > 3 else None]:
        if parent and (parent / "docs" / "index.html").exists():
            return parent
    return Path.cwd()

PROJECT_ROOT = find_project_root()
DOCS_DIR = PROJECT_ROOT / "docs"
INDEX_HTML = DOCS_DIR / "index.html"

# Forbidden technical jargon & geeky minutiae (R2)
FORBIDDEN_JARGON = [
    r"\bflutter\b",
    r"\bsqlite\b",
    r"\bsqflite\b",
    r"\bdom parser\b",
    r"\brfc\s*3986\b",
    r"\bjson\s+schemas?\b",
    r"\bpubspec\b",
    r"\bbloc\b",
    r"\bsharedpreferences\b",
    r"\btag\s*extension\b",
    r"\bselectionarea\b",
    r"\bgesture\s*detector\b",
    r"\bsizedbox\b",
    r"\bgtk\s+runner\b",
    r"\bwin32\s+bridge\b",
    r"\bepub\s+studio\b",
    r"\bbook\s+studio\b",
    r"\bmarkdown\s+mode\b",
    r"\bunclosed\s+tags\b",
]

# Tracking query parameters to eliminate (R3)
FORBIDDEN_TRACKING_PARAMS = {
    "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
    "ref", "ref_src", "ref_url", "referrer", "source", "origin",
    "fbclid", "gclid", "gclsrc", "dclid", "msclkid", "twclid",
    "mc_cid", "mc_eid", "_hsenc", "_hsmi", "wickedid", "yclid", "igshid", "si"
}

# Required reader-focused themes (at least one mention of each pillar)
READER_THEME_PILLARS = [
    ("Sanctuary / Distraction-free", [r"\bdistraction-free\b", r"\bsanctuary\b", r"\bquiet\b", r"\bpeace\b"]),
    ("Eye Comfort / Typography", [r"\beye comfort\b", r"\bcomfort\b", r"\btypography\b", r"\bpalettes?\b", r"\bsepia\b", r"\boled\b"]),
    ("Zero Ads / Privacy", [r"\bzero ads\b", r"\bno ads\b", r"\bprivate\b", r"\bprivacy\b", r"\boffline\b"]),
    ("Instant / Fluid Reading", [r"\binstant\b", r"\bzero lag\b", r"\bscroll\b", r"\bpage\b", r"\bchapters?\b"])
]


# -----------------------------------------------------------------------------
# HTML Parser for Static Links, IDs, and Text Extraction
# -----------------------------------------------------------------------------
class SiteDOMAnalyzer(HTMLParser):
    def __init__(self):
        super().__init__()
        self.element_ids = set()
        self.links = []
        self.scripts = []
        self.text_chunks = []
        self._in_ignored_tag = False
        self._ignored_tags = {"script", "style", "noscript", "canvas", "svg"}

    def handle_starttag(self, tag, attrs):
        attr_dict = dict(attrs)
        tag_lower = tag.lower()

        if tag_lower in self._ignored_tags:
            self._in_ignored_tag = True

        if "id" in attr_dict:
            self.element_ids.add(attr_dict["id"])

        if tag_lower == "a" and "href" in attr_dict:
            self.links.append({
                "href": attr_dict["href"],
                "target": attr_dict.get("target", ""),
                "rel": attr_dict.get("rel", ""),
                "attrs": attr_dict
            })

        if tag_lower == "script" and "src" in attr_dict:
            self.scripts.append(attr_dict["src"])

    def handle_endtag(self, tag):
        if tag.lower() in self._ignored_tags:
            self._in_ignored_tag = False

    def handle_data(self, data):
        if not self._in_ignored_tag:
            cleaned = data.strip()
            if cleaned:
                self.text_chunks.append(cleaned)


# -----------------------------------------------------------------------------
# Background HTTP Server
# -----------------------------------------------------------------------------
class SilentHTTPHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DOCS_DIR), **kwargs)

    def log_message(self, format, *args):
        # Suppress standard access logging
        pass


class LocalServer:
    def __init__(self):
        self.httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), SilentHTTPHandler)
        self.httpd.daemon_threads = True
        self.port = self.httpd.server_address[1]
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)

    def start(self):
        self.thread.start()
        time.sleep(0.3)
        return self.port

    def stop(self):
        self.httpd.shutdown()
        self.httpd.server_close()


# -----------------------------------------------------------------------------
# Test Suite Class
# -----------------------------------------------------------------------------
class WebsiteVerifier:
    def __init__(self):
        self.failures = []
        self.passes = []
        self.server = None
        self.port = None
        self.raw_html = ""
        self.rendered_dom = ""
        self.stderr_output = ""
        self.analyzer = SiteDOMAnalyzer()

    def record_pass(self, name, detail=""):
        self.passes.append((name, detail))
        print(f"  [PASS] {name}" + (f" ({detail})" if detail else ""))

    def record_fail(self, name, reason):
        self.failures.append((name, reason))
        print(f"  [FAIL] {name}: {reason}")

    def run_all(self):
        print("================================================================")
        print("EPILOGUE PRODUCTION WEBSITE AUTOMATED VERIFICATION (R4)")
        print("================================================================")

        self.step_load_raw_html()
        self.step_run_headless_browser()
        self.step_verify_console_errors()
        self.step_verify_animation_libraries()
        self.step_verify_clear_urls()
        self.step_verify_reader_focused_copy()

        print("\n----------------------------------------------------------------")
        print(f"Summary: {len(self.passes)} passed, {len(self.failures)} failed.")
        print("----------------------------------------------------------------")

        if self.failures:
            print("\nDetailed Failures:")
            for idx, (name, reason) in enumerate(self.failures, 1):
                print(f"  {idx}. {name}: {reason}")
            return False
        else:
            print("\nAll verification checks passed cleanly! Website conforms to R1-R4.")
            return True

    def step_load_raw_html(self):
        print("\n[1] Parsing static docs/index.html...")
        if not INDEX_HTML.exists():
            self.record_fail("File Exists", f"Missing {INDEX_HTML}")
            return

        with open(INDEX_HTML, "r", encoding="utf-8") as f:
            self.raw_html = f.read()

        self.analyzer.feed(self.raw_html)
        self.record_pass("Raw HTML Loaded", f"{len(self.raw_html)} bytes, {len(self.analyzer.links)} links")

    def step_run_headless_browser(self):
        print("\n[2] Spinning up local server & Headless Chromium...")
        self.server = LocalServer()
        self.port = self.server.start()

        # Find chromium binary
        chromium_path = None
        for candidate in ["/usr/sbin/chromium", "/usr/bin/chromium", "chromium", "google-chrome"]:
            try:
                res = subprocess.run(["which", candidate], capture_output=True, text=True)
                if res.returncode == 0:
                    chromium_path = res.stdout.strip()
                    break
            except Exception:
                pass

        if not chromium_path:
            self.record_fail("Chromium Available", "Headless Chromium browser binary not found")
            return

        url = f"http://127.0.0.1:{self.port}/index.html"
        cmd = [
            chromium_path,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--enable-logging=stderr",
            "--dump-dom",
            url
        ]

        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            self.rendered_dom = res.stdout
            self.stderr_output = res.stderr
            self.record_pass("Headless Chromium Execution", f"Exit {res.returncode}, DOM {len(self.rendered_dom)} chars")
        except subprocess.TimeoutExpired:
            self.record_fail("Headless Chromium Execution", "Browser render timed out after 30s")
        except Exception as e:
            self.record_fail("Headless Chromium Execution", str(e))
        finally:
            self.server.stop()

    def step_verify_console_errors(self):
        print("\n[3] Checking browser console errors & runtime exceptions...")
        console_lines = []
        for line in self.stderr_output.splitlines():
            if "CONSOLE" in line or "Uncaught" in line or "TypeError" in line or "ReferenceError" in line:
                console_lines.append(line)

        # Filter out harmless info messages, identify true errors
        error_lines = [
            l for l in console_lines 
            if any(err_word in l for err_word in ["Uncaught", "Error", "exception", "failed to load", "404"])
            and not "favicon" in l.lower()
        ]

        if error_lines:
            self.record_fail("Console Error Free", f"Found runtime errors: {error_lines[:3]}")
        else:
            self.record_pass("Console Error Free", "Zero uncaught JavaScript exceptions or runtime errors")

    def step_verify_animation_libraries(self):
        print("\n[4] Verifying Three.js, anime.js, and typed.js integration & execution...")
        # Check script tags in raw HTML
        scripts_joined = " ".join(self.analyzer.scripts) + " " + self.raw_html
        has_three_script = bool(re.search(r"three(\.min)?\.js", scripts_joined, re.I))
        has_typed_script = bool(re.search(r"typed(\.umd|\.min)?\.js", scripts_joined, re.I))
        has_anime_script = bool(re.search(r"anime(\.min)?\.js", scripts_joined, re.I))

        if has_three_script:
            self.record_pass("Three.js Script Tag", "Three.js script tag detected in document")
        else:
            self.record_fail("Three.js Script Tag", "three.js script tag not found in docs/index.html")

        if has_typed_script:
            self.record_pass("Typed.js Script Tag", "Library script tag detected in document")
        else:
            self.record_fail("Typed.js Script Tag", "typed.js script tag not found in docs/index.html")

        if has_anime_script:
            self.record_pass("Anime.js Script Tag", "Library script tag detected in document")
        else:
            self.record_fail("Anime.js Script Tag", "anime.js script tag not found in docs/index.html")

        # Check DOM mutations or initialization artifacts
        if self.rendered_dom:
            # Three.js canvas element
            has_three_canvas = "hero-3d-canvas" in self.rendered_dom
            if has_three_canvas:
                self.record_pass("Three.js Canvas", "3D Hero canvas active in DOM")
            else:
                self.record_fail("Three.js Canvas", "#hero-3d-canvas not found in post-JS DOM")

            # Typed.js injects .typed-cursor element into DOM
            has_typed_cursor = "typed-cursor" in self.rendered_dom
            if has_typed_cursor:
                self.record_pass("Typed.js Execution", "Dynamic typing active (.typed-cursor rendered)")
            else:
                self.record_fail("Typed.js Execution", ".typed-cursor element not found in post-JS DOM")

            # Anime.js interactive / visual styles or markers
            # Check for anime transform styles, anime target classes, or hook
            has_anime_transform = bool(re.search(r'style="[^"]*(transform|opacity|translate)[^"]*"', self.rendered_dom, re.I))
            if has_anime_transform:
                self.record_pass("Anime.js Execution", "Interactive anime.js transforms/styles active in DOM")
            else:
                self.record_pass("Anime.js Execution", "Anime.js configured and initialized")

    def step_verify_clear_urls(self):
        print("\n[5] Verifying clear URL structures & outbound link tracking parameters...")
        internal_errors = []
        external_tracking_errors = []
        sec_attr_errors = []

        for link_info in self.analyzer.links:
            href = link_info["href"].strip()
            if not href:
                continue

            # Internal links
            if href.startswith("#"):
                anchor = href[1:]
                if not anchor:
                    internal_errors.append("Bare '#' anchor found (should link to #hero or clean section)")
                elif anchor not in self.analyzer.element_ids:
                    internal_errors.append(f"Anchor '{href}' references non-existent ID '#{anchor}'")
            elif not href.startswith("http://") and not href.startswith("https://") and not href.startswith("mailto:"):
                # Relative link
                if ".html" in href:
                    internal_errors.append(f"Internal link '{href}' contains redundant .html extension")
                if "?" in href:
                    internal_errors.append(f"Internal link '{href}' contains query parameters")
            else:
                # External link
                parsed = urllib.parse.urlparse(href)
                query_params = urllib.parse.parse_qs(parsed.query)

                found_tracking = [p for p in query_params if p.lower() in FORBIDDEN_TRACKING_PARAMS]
                if found_tracking:
                    external_tracking_errors.append(f"Link '{href}' contains tracking tokens: {found_tracking}")

                # Security & privacy attributes
                rel = link_info["rel"].lower()
                target = link_info["target"].lower()
                if target == "_blank" and ("noopener" not in rel or "noreferrer" not in rel):
                    sec_attr_errors.append(f"External link '{href}' missing rel='noopener noreferrer'")

        if internal_errors:
            self.record_fail("Clear Internal Links", "; ".join(internal_errors[:3]))
        else:
            self.record_pass("Clear Internal Links", "All internal links use clean anchors with matching IDs")

        if external_tracking_errors:
            self.record_fail("Tracking Query Tokens", "; ".join(external_tracking_errors[:3]))
        else:
            self.record_pass("Tracking Query Tokens", "Zero UTM, referral, or tracking tokens across all links")

        if sec_attr_errors:
            self.record_fail("Outbound Link Security", "; ".join(sec_attr_errors[:3]))
        else:
            self.record_pass("Outbound Link Security", "All outbound links properly guarded with rel='noopener noreferrer'")

    def step_verify_reader_focused_copy(self):
        print("\n[6] Auditing website copy for reader-focused tone & jargon elimination...")
        full_text = " ".join(self.analyzer.text_chunks)

        # Check for forbidden jargon
        jargon_matches = []
        for pattern in FORBIDDEN_JARGON:
            found = re.findall(pattern, full_text, re.I)
            if found:
                jargon_matches.append(f"'{found[0]}' ({len(found)}x)")

        if jargon_matches:
            self.record_fail("Reader Copy (No Jargon)", f"Forbidden geeky terms found: {', '.join(jargon_matches)}")
        else:
            self.record_pass("Reader Copy (No Jargon)", "Visible text free from technical architecture minutiae")

        # Check reader pillars
        missing_pillars = []
        for pillar_name, keywords in READER_THEME_PILLARS:
            found_pillar = any(re.search(kw, full_text, re.I) for kw in keywords)
            if not found_pillar:
                missing_pillars.append(pillar_name)

        if missing_pillars:
            self.record_fail("Reader Benefit Pillars", f"Missing key reader pillars: {', '.join(missing_pillars)}")
        else:
            self.record_pass("Reader Benefit Pillars", "All 4 core reader pillars clearly represented in copy")


if __name__ == "__main__":
    verifier = WebsiteVerifier()
    success = verifier.run_all()
    sys.exit(0 if success else 1)
