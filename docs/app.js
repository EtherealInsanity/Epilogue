/**
 * 🌌 EPILOGUE (독자의 에필로그) — OFFICIAL WEB PLATFORM SCRIPT
 * Handles Starfield Canvas, Showcase Architecture Tabs, Dynamic Latest Releases,
 * and Responsive Mobile Navigation.
 */

document.addEventListener('DOMContentLoaded', () => {
  initStarfield();
  initThemeToggle();
  initShowcaseTabs();
  initDynamicReleases();
  initMobileNav();
});

/* ==========================================================================
   1. Cosmic Starfield Background Canvas
   ========================================================================== */
function initStarfield() {
  const canvas = document.getElementById('starfield-canvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  let width, height;
  let stars = [];
  const isMobile = window.innerWidth < 768;
  const starCount = isMobile ? 35 : 70;

  function resize() {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
    createStars();
  }

  function createStars() {
    stars = [];
    for (let i = 0; i < starCount; i++) {
      stars.push({
        x: Math.random() * width,
        y: Math.random() * height,
        radius: Math.random() * 1.3 + 0.3,
        alpha: Math.random() * 0.75 + 0.25,
        twinkleSpeed: (Math.random() * 0.015 + 0.005) * (Math.random() > 0.5 ? 1 : -1),
        vx: (Math.random() - 0.5) * 0.1,
        vy: (Math.random() - 0.5) * 0.1,
      });
    }
  }

  function draw() {
    ctx.clearRect(0, 0, width, height);

    // Subtle Constellation Lines
    for (let i = 0; i < stars.length; i++) {
      for (let j = i + 1; j < stars.length; j++) {
        const dx = stars[i].x - stars[j].x;
        const dy = stars[i].y - stars[j].y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < 90) {
          const lineAlpha = (1 - dist / 90) * 0.1 * Math.min(stars[i].alpha, stars[j].alpha);
          ctx.strokeStyle = `rgba(6, 182, 212, ${lineAlpha})`;
          ctx.lineWidth = 0.5;
          ctx.beginPath();
          ctx.moveTo(stars[i].x, stars[i].y);
          ctx.lineTo(stars[j].x, stars[j].y);
          ctx.stroke();
        }
      }
    }

    // Stars
    for (const star of stars) {
      star.alpha += star.twinkleSpeed;
      if (star.alpha > 0.95 || star.alpha < 0.2) {
        star.twinkleSpeed = -star.twinkleSpeed;
      }

      star.x += star.vx;
      star.y += star.vy;

      if (star.x < 0) star.x = width;
      if (star.x > width) star.x = 0;
      if (star.y < 0) star.y = height;
      if (star.y > height) star.y = 0;

      ctx.fillStyle = `rgba(240, 249, 255, ${star.alpha})`;
      ctx.beginPath();
      ctx.arc(star.x, star.y, star.radius, 0, Math.PI * 2);
      ctx.fill();
    }

    requestAnimationFrame(draw);
  }

  window.addEventListener('resize', resize);
  resize();
  draw();
}

/* ==========================================================================
   2. Theme Toggle (Cosmic Dark vs Paper Light)
   ========================================================================== */
function initThemeToggle() {
  const toggleBtn = document.getElementById('theme-toggle-btn');
  if (!toggleBtn) return;

  const currentTheme = localStorage.getItem('epilogue-theme') || 'dark';
  applyTheme(currentTheme);

  toggleBtn.addEventListener('click', () => {
    const isDark = document.documentElement.getAttribute('data-theme') !== 'light';
    const nextTheme = isDark ? 'light' : 'dark';
    applyTheme(nextTheme);
    localStorage.setItem('epilogue-theme', nextTheme);
  });

  function applyTheme(theme) {
    if (theme === 'light') {
      document.documentElement.setAttribute('data-theme', 'light');
      toggleBtn.innerHTML = `
        <svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
        </svg>`;
      toggleBtn.setAttribute('title', 'Switch to Dark Mode');
    } else {
      document.documentElement.removeAttribute('data-theme');
      toggleBtn.innerHTML = `
        <svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="5"></circle>
          <line x1="12" y1="1" x2="12" y2="3"></line>
          <line x1="12" y1="21" x2="12" y2="23"></line>
          <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
          <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
          <line x1="1" y1="12" x2="3" y2="12"></line>
          <line x1="21" y1="12" x2="23" y2="12"></line>
          <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
          <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
        </svg>`;
      toggleBtn.setAttribute('title', 'Switch to Light Mode');
    }
  }
}

/* ==========================================================================
   3. Showcase Architecture Tabs
   ========================================================================== */
function initShowcaseTabs() {
  const tabs = document.querySelectorAll('.showcase-tab');
  const panes = document.querySelectorAll('.showcase-pane');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetTab = tab.getAttribute('data-tab');
      tabs.forEach(t => t.classList.remove('active'));
      panes.forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const targetPane = document.getElementById(`pane-${targetTab}`);
      if (targetPane) {
        targetPane.classList.add('active');
      }
    });
  });
}

/* ==========================================================================
   4. Dynamic GitHub Releases & Latest Downloads
   ========================================================================== */
async function initDynamicReleases() {
  const REPO = 'EtherealInsanity/Epilogue';
  const API_URL = `https://api.github.com/repos/${REPO}/releases/latest`;

  const heroDownloadBtn = document.getElementById('hero-download-btn');
  const heroDownloadLabel = document.getElementById('hero-download-label');
  const latestBadge = document.getElementById('latest-version-badge');

  const arm64Link = document.getElementById('dl-arm64');
  const universalLink = document.getElementById('dl-universal');
  const armeabiLink = document.getElementById('dl-armeabi');
  const x86_64Link = document.getElementById('dl-x86_64');
  const windowsLink = document.getElementById('dl-windows');
  const linuxLink = document.getElementById('dl-linux');

  const sizeArm64 = document.getElementById('size-arm64');
  const sizeUniversal = document.getElementById('size-universal');
  const sizeArmeabi = document.getElementById('size-armeabi');
  const sizeX86_64 = document.getElementById('size-x86_64');
  const sizeWindows = document.getElementById('size-windows');
  const sizeLinux = document.getElementById('size-linux');

  const ua = (navigator.userAgent || navigator.vendor || window.opera || '').toLowerCase();
  const isAndroid = /android/i.test(ua);
  const isWindows = /windows/i.test(ua);
  const isLinux = /linux/i.test(ua) && !isAndroid;

  try {
    const res = await fetch(API_URL);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const release = await res.json();

    const tag = release.tag_name || 'v2.0.3';
    const cleanVersion = tag.replace(/^v/, '');

    if (latestBadge) {
      latestBadge.innerText = `VERSION ${cleanVersion} • EPILOGUE STUDIO & STAR STREAM SUITE`;
    }

    if (heroDownloadLabel) {
      if (isAndroid) {
        heroDownloadLabel.innerText = `Download APK (${cleanVersion} • ARM64)`;
      } else if (isWindows) {
        heroDownloadLabel.innerText = `Download for Windows (${cleanVersion})`;
      } else if (isLinux) {
        heroDownloadLabel.innerText = `Download for Linux (${cleanVersion})`;
      } else {
        heroDownloadLabel.innerText = `Download Epilogue (${cleanVersion})`;
      }
    }

    // Match release assets
    if (Array.isArray(release.assets)) {
      release.assets.forEach(asset => {
        const name = asset.name.toLowerCase();
        const url = asset.browser_download_url;
        const sizeMb = (asset.size / (1024 * 1024)).toFixed(1);

        if (name.includes('arm64-v8a.apk')) {
          if (arm64Link) arm64Link.href = url;
          if (sizeArm64) sizeArm64.innerText = `~${sizeMb} MB • Split APK`;
          if (heroDownloadBtn && isAndroid) heroDownloadBtn.href = url;
        } else if (name.includes('universal.apk')) {
          if (universalLink) universalLink.href = url;
          if (sizeUniversal) sizeUniversal.innerText = `~${sizeMb} MB • Standalone`;
          if (heroDownloadBtn && !isAndroid && !isWindows && !isLinux) heroDownloadBtn.href = url;
        } else if (name.includes('armeabi-v7a.apk')) {
          if (armeabiLink) armeabiLink.href = url;
          if (sizeArmeabi) sizeArmeabi.innerText = `~${sizeMb} MB • Split APK`;
        } else if (name.includes('x86_64.apk')) {
          if (x86_64Link) x86_64Link.href = url;
          if (sizeX86_64) sizeX86_64.innerText = `~${sizeMb} MB • Split APK`;
        } else if (name.includes('windows') && name.endsWith('.zip')) {
          if (windowsLink) windowsLink.href = url;
          if (sizeWindows) sizeWindows.innerText = `~${sizeMb} MB • Portable Zip`;
          if (heroDownloadBtn && isWindows) heroDownloadBtn.href = url;
        } else if (name.includes('linux') && (name.endsWith('.tar.gz') || name.endsWith('.zip'))) {
          if (linuxLink) linuxLink.href = url;
          if (sizeLinux) sizeLinux.innerText = `~${sizeMb} MB • Portable Archive`;
          if (heroDownloadBtn && isLinux) heroDownloadBtn.href = url;
        }
      });
    }
  } catch (err) {
    // Graceful offline fallback: links point to canonical latest release download endpoints
    if (heroDownloadBtn) {
      heroDownloadBtn.href = `https://github.com/${REPO}/releases/latest`;
    }
  }
}

/* ==========================================================================
   5. Mobile Navigation Menu Drawer
   ========================================================================== */
function initMobileNav() {
  const mobileBtn = document.getElementById('mobile-menu-btn');
  const navMenu = document.getElementById('nav-menu');

  if (!mobileBtn || !navMenu) return;

  function toggleMenu() {
    const isOpen = navMenu.classList.toggle('open');
    mobileBtn.classList.toggle('open', isOpen);
    mobileBtn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    document.body.style.overflow = isOpen ? 'hidden' : '';
  }

  function closeMenu() {
    navMenu.classList.remove('open');
    mobileBtn.classList.remove('open');
    mobileBtn.setAttribute('aria-expanded', 'false');
    document.body.style.overflow = '';
  }

  mobileBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    toggleMenu();
  });

  const navLinks = navMenu.querySelectorAll('.nav-link');
  navLinks.forEach(link => {
    link.addEventListener('click', () => {
      closeMenu();
    });
  });

  document.addEventListener('click', (e) => {
    if (navMenu.classList.contains('open') && !navMenu.contains(e.target) && !mobileBtn.contains(e.target)) {
      closeMenu();
    }
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && navMenu.classList.contains('open')) {
      closeMenu();
    }
  });
}
