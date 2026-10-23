#!/usr/bin/env python3
"""
generate_pdf.py - Generates an ATS-friendly, high-fidelity vector PDF resume
using PostScript and Ghostscript (ps2pdf). Zero third-party dependencies required.
Calibrated for an elegant 1-page layout with multi-page overflow capability.
"""

import os
import subprocess
import sys

def escape_ps(text: str) -> str:
    """Escape parentheses and backslashes for PostScript string literals."""
    return text.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')

class ResumePSWriter:
    def __init__(self, output_ps_path: str):
        self.path = output_ps_path
        self.f = open(output_ps_path, "w", encoding="utf-8")
        self.page_width = 595.28  # A4 width
        self.page_height = 841.89 # A4 height
        self.margin_x = 32.0      # side margins
        self.content_width = self.page_width - (2 * self.margin_x)
        self.margin_top = 28.0
        self.margin_bottom = 24.0
        self.current_y = self.page_height - self.margin_top
        self.page_num = 1
        self._write_header()

    def _write_header(self):
        self.f.write("%!PS-Adobe-3.0\n")
        self.f.write("%%BoundingBox: 0 0 595 842\n")
        self.f.write("%%Pages: (atend)\n")
        self.f.write("%%EndComments\n\n")
        self.f.write(f"%%Page: {self.page_num} {self.page_num}\n")

    def check_page_break(self, needed_space: float):
        if self.current_y - needed_space < self.margin_bottom:
            self.f.write("showpage\n\n")
            self.page_num += 1
            self.f.write(f"%%Page: {self.page_num} {self.page_num}\n")
            self.current_y = self.page_height - self.margin_top

    def draw_line(self, x1, y1, x2, y2, width=0.5, gray=0.7):
        self.f.write(f"gsave {gray} setgray {width} setlinewidth ")
        self.f.write(f"{x1:.2f} {y1:.2f} moveto {x2:.2f} {y2:.2f} lineto stroke grestore\n")

    def draw_rect(self, x, y, w, h, stroke_gray=0.7, fill_gray=None, dashed=False):
        self.f.write("gsave\n")
        if dashed:
            self.f.write("[2 2] 0 setdash\n")
        if fill_gray is not None:
            self.f.write(f"{fill_gray} setgray {x:.2f} {y:.2f} {w:.2f} {h:.2f} rectfill\n")
        if stroke_gray is not None:
            self.f.write(f"{stroke_gray} setgray 0.5 setlinewidth {x:.2f} {y:.2f} {w:.2f} {h:.2f} rectstroke\n")
        self.f.write("grestore\n")

    def write_text(self, text, x, y, font="Helvetica", size=8.5, gray=0.0):
        esc = escape_ps(text)
        self.f.write(f"/{font} findfont {size} scalefont setfont\n")
        self.f.write(f"{gray} setgray\n")
        self.f.write(f"{x:.2f} {y:.2f} moveto ({esc}) show\n")

    def write_text_flow(self, segments, x, y):
        """Render multiple text segments continuously with automatic horizontal advancement."""
        self.f.write(f"{x:.2f} {y:.2f} moveto\n")
        for text, font, size, gray in segments:
            esc = escape_ps(text)
            self.f.write(f"/{font} findfont {size} scalefont setfont {gray} setgray ({esc}) show\n")

    def write_text_right(self, text, right_x, y, font="Helvetica", size=8.5, gray=0.0):
        esc = escape_ps(text)
        self.f.write(f"/{font} findfont {size} scalefont setfont\n")
        self.f.write(f"{gray} setgray\n")
        self.f.write(f"({esc}) stringwidth pop {right_x:.2f} exch sub {y:.2f} moveto ({esc}) show\n")

    def wrap_text(self, text: str, max_chars: int = 114):
        words = text.split()
        lines = []
        curr = []
        curr_len = 0
        for w in words:
            if curr_len + len(w) + 1 > max_chars:
                lines.append(" ".join(curr))
                curr = [w]
                curr_len = len(w)
            else:
                curr.append(w)
                curr_len += len(w) + 1
        if curr:
            lines.append(" ".join(curr))
        return lines

    def add_section_header(self, title: str):
        self.check_page_break(20)
        self.current_y -= 5
        self.write_text(title.upper(), self.margin_x, self.current_y, font="Helvetica-Bold", size=9.5, gray=0.1)
        self.current_y -= 3
        self.draw_line(self.margin_x, self.current_y, self.margin_x + self.content_width, self.current_y, width=0.6, gray=0.4)
        self.current_y -= 7

    def close(self):
        self.f.write("showpage\n")
        self.f.write("%%Trailer\n")
        self.f.write(f"%%Pages: {self.page_num}\n")
        self.f.write("%%EOF\n")
        self.f.close()


def generate_resume_pdf():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    ps_path = os.path.join(script_dir, "resume.ps")
    pdf_path = os.path.join(script_dir, "resume.pdf")

    rw = ResumePSWriter(ps_path)

    # 1. HEADER
    photo_w = 64
    photo_h = 72
    top_y = rw.current_y

    # Photo Slot (Right side of header)
    photo_x = rw.margin_x + rw.content_width - photo_w
    photo_y = top_y - photo_h + 8
    rw.draw_rect(photo_x, photo_y, photo_w, photo_h, stroke_gray=0.5, fill_gray=0.97, dashed=True)
    rw.write_text("PHOTO", photo_x + 15, photo_y + 40, font="Helvetica-Bold", size=8, gray=0.4)
    rw.write_text("35mm x 45mm", photo_x + 6, photo_y + 29, font="Helvetica", size=6.5, gray=0.5)
    rw.write_text("(Optional)", photo_x + 15, photo_y + 19, font="Helvetica-Oblique", size=6.5, gray=0.5)

    # Candidate Name & Subtitle
    rw.write_text("{{YOUR FULL NAME}}", rw.margin_x, top_y - 2, font="Helvetica-Bold", size=17, gray=0.05)
    rw.write_text("Computer Science Undergraduate  |  Aspiring Software Engineer", rw.margin_x, top_y - 15, font="Helvetica-Bold", size=9.0, gray=0.2)

    # Contact Info
    c_y = top_y - 27
    contact_1 = "Location: {{CITY, STATE/COUNTRY}}   *   Phone: {{PHONE NUMBER}}   *   Email: {{EMAIL ADDRESS}}"
    rw.write_text(contact_1, rw.margin_x, c_y, font="Helvetica", size=7.8, gray=0.25)
    c_y -= 10
    contact_2 = "GitHub: github.com/{{YOUR_GITHUB_HANDLE}}   *   LinkedIn: linkedin.com/in/{{YOUR_LINKEDIN}}   *   Portfolio: {{PORTFOLIO}}"
    rw.write_text(contact_2, rw.margin_x, c_y, font="Helvetica", size=7.8, gray=0.25)

    # Legal Details Box
    c_y -= 13
    legal_w = rw.content_width - photo_w - 10
    rw.draw_rect(rw.margin_x, c_y - 10, legal_w, 16, stroke_gray=0.85, fill_gray=0.95)
    legal_text = "LEGAL / ID: [Legal Name: {{LEGAL NAME}}]   [Nationality: {{NATIONALITY/WORK AUTH}}]   [DOB: {{DD/MM/YYYY}}]"
    rw.write_text(legal_text, rw.margin_x + 5, c_y - 5.5, font="Helvetica-Bold", size=7.2, gray=0.2)

    rw.current_y = min(c_y - 17, photo_y - 6)

    # 2. PROFESSIONAL SUMMARY
    rw.add_section_header("Professional Summary")
    summary = (
        "Motivated Computer Science student with practical experience building high-performance cross-platform software "
        "and responsive web applications. Proficient in C++, Java, and Python, with hands-on expertise building dynamic frontends "
        "in React and scalable client architectures in Flutter/Dart. Strong foundation in data structures, algorithms, "
        "OOP, and automated testing, with a proven track record of shipping open-source software and maintaining clean codebases."
    )
    for line in rw.wrap_text(summary, max_chars=118):
        rw.write_text(line, rw.margin_x, rw.current_y, font="Helvetica", size=8.0, gray=0.15)
        rw.current_y -= 9.5

    # 3. EDUCATION
    rw.add_section_header("Education")
    rw.write_text_right("{{City, Country}}  *  Expected {{Month, Year}}", rw.margin_x + rw.content_width, rw.current_y, font="Helvetica", size=8.0, gray=0.3)
    rw.write_text("{{YOUR UNIVERSITY / COLLEGE NAME}}", rw.margin_x, rw.current_y, font="Helvetica-Bold", size=8.8, gray=0.05)
    rw.current_y -= 9.8
    rw.write_text("Bachelor of Science in Computer Science   |   GPA: {{X.XX / 4.00}}", rw.margin_x, rw.current_y, font="Helvetica-Oblique", size=8.0, gray=0.2)
    rw.current_y -= 9.5
    coursework = "Relevant Coursework: Data Structures & Algorithms, OOP (Java/C++), Operating Systems, DBMS, Web Development, Software Engineering."
    rw.write_text("  *  " + coursework, rw.margin_x, rw.current_y, font="Helvetica", size=7.8, gray=0.2)
    rw.current_y -= 10.5

    # 4. TECHNICAL SKILLS
    rw.add_section_header("Technical Skills")
    skills = [
        ("Languages:", "C++, Java, Python, Dart, JavaScript (ES6+), TypeScript, C, SQL, HTML5, CSS3"),
        ("Web & Frameworks:", "React.js, Flutter, Node.js, Express, Tailwind CSS, RESTful APIs"),
        ("Developer Tools:", "Git, GitHub, Linux / Unix CLI, Android Studio, VS Code, CMake, Postman, CI/CD (GitHub Actions)"),
        ("Core Competencies:", "OOP, Data Structures, Algorithms, GLSL Shaders, Unit & Integration Testing, State Management"),
    ]
    for label, val in skills:
        rw.write_text(label, rw.margin_x + 4, rw.current_y, font="Helvetica-Bold", size=8.0, gray=0.1)
        rw.write_text(val, rw.margin_x + 105, rw.current_y, font="Helvetica", size=8.0, gray=0.2)
        rw.current_y -= 9.5

    # 5. FEATURED PROJECTS
    rw.add_section_header("Featured Projects")

    # Project 1: Epilogue
    rw.write_text_right("github.com/EtherealInsanity/Epilogue", rw.margin_x + rw.content_width, rw.current_y, font="Helvetica", size=7.8, gray=0.3)
    rw.write_text_flow([
        ("Epilogue -- Cross-Platform Reading Companion & Studio ", "Helvetica-Bold", 8.8, 0.05),
        ("[Flutter, Dart, GLSL Shaders, Linux/Android/Windows]", "Helvetica-Bold", 7.5, 0.35)
    ], rw.margin_x, rw.current_y)
    rw.current_y -= 9.5

    epilogue_bullets = [
        "Architected an open-source, distraction-free reading companion & EPUB engine supporting 500+ chapter epics on Android, Linux, and Windows.",
        "Engineered a paper-pure typography engine integrated with custom GLSL shaders for GPU-accelerated effects and progression telemetry.",
        "Maintained high software reliability with 31/31 passing unit tests, automated GitHub Actions CI/CD workflows, and 0 static analyzer issues.",
        "Implemented modular chapter parsing and local caching to deliver sub-second chapter navigation and seamless offline persistence."
    ]
    for b in epilogue_bullets:
        for i, l in enumerate(rw.wrap_text(b, max_chars=116)):
            prefix = "  *  " if i == 0 else "     "
            rw.write_text(prefix + l, rw.margin_x, rw.current_y, font="Helvetica", size=7.8, gray=0.2)
            rw.current_y -= 9.0
    rw.current_y -= 2.0

    # Project 2: React Web App
    rw.write_text_right("{{Month Year}}", rw.margin_x + rw.content_width, rw.current_y, font="Helvetica", size=7.8, gray=0.3)
    rw.write_text_flow([
        ("Full-Stack Web Application ", "Helvetica-Bold", 8.8, 0.05),
        ("[React, Node.js, Express, REST APIs, Tailwind CSS]", "Helvetica-Bold", 7.5, 0.35)
    ], rw.margin_x, rw.current_y)
    rw.current_y -= 9.5

    react_bullets = [
        "Developed a responsive web application utilizing React functional components, hooks, and client-side routing for single-page navigation.",
        "Constructed modular REST API endpoints in Node.js/Express with schema validation, structured error handling, and database queries.",
        "Optimized frontend bundle size and component rendering cycles to achieve rapid First Contentful Paint and fluid mobile responsiveness."
    ]
    for b in react_bullets:
        for i, l in enumerate(rw.wrap_text(b, max_chars=116)):
            prefix = "  *  " if i == 0 else "     "
            rw.write_text(prefix + l, rw.margin_x, rw.current_y, font="Helvetica", size=7.8, gray=0.2)
            rw.current_y -= 9.0
    rw.current_y -= 2.0

    # Project 3: C++/Java Systems
    rw.write_text_right("{{Month Year}}", rw.margin_x + rw.content_width, rw.current_y, font="Helvetica", size=7.8, gray=0.3)
    rw.write_text_flow([
        ("Systems Programming & Algorithms Utility ", "Helvetica-Bold", 8.8, 0.05),
        ("[C++, Java, OOP, Data Structures]", "Helvetica-Bold", 7.5, 0.35)
    ], rw.margin_x, rw.current_y)
    rw.current_y -= 9.5

    systems_bullets = [
        "Engineered an optimized command-line utility implementing custom graph and tree traversal algorithms with optimal time and space bounds.",
        "Applied strict OOP design patterns (Factory, Observer) to structure modular class hierarchies; validated zero memory leaks with Valgrind.",
        "Authored automated test suites in Java/JUnit covering edge cases, verifying sorting, traversal, and boundary constraints."
    ]
    for b in systems_bullets:
        for i, l in enumerate(rw.wrap_text(b, max_chars=116)):
            prefix = "  *  " if i == 0 else "     "
            rw.write_text(prefix + l, rw.margin_x, rw.current_y, font="Helvetica", size=7.8, gray=0.2)
            rw.current_y -= 9.0
    rw.current_y -= 2.0

    # Project 4: Python Pipeline
    rw.write_text_right("{{Month Year}}", rw.margin_x + rw.content_width, rw.current_y, font="Helvetica", size=7.8, gray=0.3)
    rw.write_text_flow([
        ("Automated Data Pipeline & Web Scraper ", "Helvetica-Bold", 8.8, 0.05),
        ("[Python, BeautifulSoup, Pandas, Automation]", "Helvetica-Bold", 7.5, 0.35)
    ], rw.margin_x, rw.current_y)
    rw.current_y -= 9.5

    py_bullets = [
        "Built an automated Python scraping engine to ingest, clean, and structure unstructured web content into normalized JSON/CSV stores.",
        "Implemented resilient network logic with exponential backoff and rate-limiting, reducing manual data collection time by over 80%."
    ]
    for b in py_bullets:
        for i, l in enumerate(rw.wrap_text(b, max_chars=116)):
            prefix = "  *  " if i == 0 else "     "
            rw.write_text(prefix + l, rw.margin_x, rw.current_y, font="Helvetica", size=7.8, gray=0.2)
            rw.current_y -= 9.0
    rw.current_y -= 2.0

    # 6. EXPERIENCE & LEADERSHIP
    rw.add_section_header("Experience & Leadership")
    rw.write_text_right("{{University Name}}  *  {{Month Year}} - Present", rw.margin_x + rw.content_width, rw.current_y, font="Helvetica", size=8.0, gray=0.3)
    rw.write_text("Undergraduate Teaching Assistant / Peer Tutor -- Computer Science", rw.margin_x, rw.current_y, font="Helvetica-Bold", size=8.8, gray=0.05)
    rw.current_y -= 9.5

    exp_bullets = [
        "Mentored 40+ undergraduate students in foundational C++, Java, and algorithmic problem solving during weekly lab sessions.",
        "Assisted students in isolating runtime bugs, understanding memory models, and adopting disciplined testing practices.",
        "Evaluated programming assignments, offering detailed constructive feedback on algorithmic efficiency and clean code standards."
    ]
    for b in exp_bullets:
        for i, l in enumerate(rw.wrap_text(b, max_chars=116)):
            prefix = "  *  " if i == 0 else "     "
            rw.write_text(prefix + l, rw.margin_x, rw.current_y, font="Helvetica", size=7.8, gray=0.2)
            rw.current_y -= 9.0
    rw.current_y -= 2.0

    rw.write_text_right("{{Club Name}}  *  {{Month Year}} - Present", rw.margin_x + rw.content_width, rw.current_y, font="Helvetica", size=8.0, gray=0.3)
    rw.write_text("Developer Club Member & Open Source Contributor", rw.margin_x, rw.current_y, font="Helvetica-Bold", size=8.8, gray=0.05)
    rw.current_y -= 9.5
    club_bullets = [
        "Collaborated with student developers in weekly agile sprints to build collaborative tools and hackathon prototypes.",
        "Contributed bug fixes and documentation improvements to community repositories on GitHub."
    ]
    for b in club_bullets:
        for i, l in enumerate(rw.wrap_text(b, max_chars=116)):
            prefix = "  *  " if i == 0 else "     "
            rw.write_text(prefix + l, rw.margin_x, rw.current_y, font="Helvetica", size=7.8, gray=0.2)
            rw.current_y -= 9.0
    rw.current_y -= 2.0

    # 7. CERTIFICATIONS & HONORS
    rw.add_section_header("Certifications & Honors")
    certs = [
        "Dean's Honor List / Academic Merit Scholarship: Recognized for academic excellence in Computer Science ({{Semester / Year}}).",
        "Hackathon Participant / Finalist: Built a functional full-stack prototype within 36 hours at {{Hackathon Name}} ({{Year}}).",
        "Technical Certification: {{e.g. HackerRank Problem Solving (Intermediate) / Meta Frontend Certificate}} ({{Year}})."
    ]
    for c in certs:
        for i, l in enumerate(rw.wrap_text(c, max_chars=116)):
            prefix = "  *  " if i == 0 else "     "
            rw.write_text(prefix + l, rw.margin_x, rw.current_y, font="Helvetica", size=7.8, gray=0.2)
            rw.current_y -= 9.0

    rw.close()

    # Compile with ps2pdf
    cmd = ["ps2pdf", "-dPDFSETTINGS=/prepress", "-dEmbedAllFonts=true", "-sPAPERSIZE=a4", ps_path, pdf_path]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Error compiling PDF: {res.stderr}", file=sys.stderr)
        sys.exit(1)

    print(f"Successfully generated: {pdf_path}")
    if os.path.exists(ps_path):
        os.remove(ps_path)

if __name__ == "__main__":
    generate_resume_pdf()
