/**
 * 🌌 EPILOGUE (독자의 에필로그) — OFFICIAL WEB PLATFORM SCRIPT
 * Handles Starfield Canvas, Theme Toggle, Dynamic Releases,
 * Responsive Mobile Navigation, Typed.js Tagline, and Anime.js Motion.
 */

document.addEventListener('DOMContentLoaded', () => {
  initStarfield();
  initThemeToggle();
  initDynamicReleases();
  initMobileNav();
  initTypedTagline();
  initAnimeAnimations();
  initHero3D();
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
  applyTheme(currentTheme, false);

  toggleBtn.addEventListener('click', () => {
    const isDark = document.documentElement.getAttribute('data-theme') !== 'light';
    const nextTheme = isDark ? 'light' : 'dark';
    applyTheme(nextTheme, true);
    localStorage.setItem('epilogue-theme', nextTheme);
  });

  function applyTheme(theme, animate) {
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

    if (animate && typeof anime !== 'undefined' && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      const svg = toggleBtn.querySelector('svg');
      if (svg) {
        anime({
          targets: svg,
          rotate: '+=180deg',
          duration: 400,
          easing: 'easeOutBack'
        });
      }
    }
  }
}

/* ==========================================================================
   3. Dynamic GitHub Releases & Latest Downloads
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

    const tag = release.tag_name || 'v2.0.4';
    const cleanVersion = tag.replace(/^v/, '');

    if (latestBadge) {
      latestBadge.innerText = `VERSION ${cleanVersion} • FREE & OPEN SOURCE`;
    }

    if (heroDownloadLabel) {
      if (isAndroid) {
        heroDownloadLabel.innerText = `Download APK (${cleanVersion} • Android)`;
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
          if (sizeArm64) sizeArm64.innerText = `~${sizeMb} MB • Recommended`;
          if (heroDownloadBtn && isAndroid) heroDownloadBtn.href = url;
        } else if (name.includes('universal.apk')) {
          if (universalLink) universalLink.href = url;
          if (sizeUniversal) sizeUniversal.innerText = `~${sizeMb} MB • Standalone`;
          if (heroDownloadBtn && !isAndroid && !isWindows && !isLinux) heroDownloadBtn.href = url;
        } else if (name.includes('armeabi-v7a.apk')) {
          if (armeabiLink) armeabiLink.href = url;
          if (sizeArmeabi) sizeArmeabi.innerText = `~${sizeMb} MB • Compatible`;
        } else if (name.includes('x86_64.apk')) {
          if (x86_64Link) x86_64Link.href = url;
          if (sizeX86_64) sizeX86_64.innerText = `~${sizeMb} MB • Compatible`;
        } else if (name.includes('windows') && name.endsWith('.exe')) {
          if (windowsLink) windowsLink.href = url;
          if (sizeWindows) sizeWindows.innerText = `~${sizeMb} MB • Setup Installer`;
          if (heroDownloadBtn && isWindows) heroDownloadBtn.href = url;
        } else if (name.includes('windows') && name.endsWith('.zip')) {
          const windowsPortableLink = document.getElementById('dl-windows-portable');
          if (windowsPortableLink) windowsPortableLink.href = url;
          if (windowsLink && !windowsLink.href.includes('.exe')) {
            windowsLink.href = url;
            if (sizeWindows) sizeWindows.innerText = `~${sizeMb} MB • Portable Zip`;
            if (heroDownloadBtn && isWindows) heroDownloadBtn.href = url;
          }
        } else if (name.includes('linux') && name.endsWith('.tar.gz')) {
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
   4. Mobile Navigation Menu Drawer
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

/* ==========================================================================
   5. Typed.js Dynamic Tagline Integration
   ========================================================================== */
function initTypedTagline() {
  const target = document.getElementById('typed-tagline');
  if (!target) return;

  if (typeof Typed === 'undefined') {
    // Graceful degradation: static HTML fallback remains visible
    return;
  }

  // Check reduced motion preference
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    return;
  }

  try {
    // Clear initial fallback text right before starting typed instance
    target.textContent = '';

    new Typed('#typed-tagline', {
      strings: [
        'Your personal sanctuary for reading.',
        'Rediscover the joy of quiet focus.',
        'Pure reading pleasure, beautifully offline.',
        'Every story at your fingertips, zero distractions.'
      ],
      typeSpeed: 45,
      backSpeed: 25,
      backDelay: 2200,
      startDelay: 400,
      loop: true,
      loopCount: Infinity,
      showCursor: true,
      cursorChar: '|',
      autoInsertCss: false, // We control styling via styles.css
      smartBackspace: true
    });
  } catch (err) {
    console.warn('Typed.js initialization failed:', err);
  }
}

/* ==========================================================================
   6. Anime.js Visual & Interactive Animations
   ========================================================================== */
function initAnimeAnimations() {
  if (typeof anime === 'undefined') {
    return;
  }

  // Respect user preference for reduced motion
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    return;
  }

  try {
    // --- 6.1 Hero Entrance Stagger Timeline ---
    const heroElements = document.querySelectorAll(
      '.hero-badge, .hero-title, .hero-tagline-wrapper, .hero-description, .hero-cta-group, .hero-stats-row'
    );

    if (heroElements.length > 0) {
      anime({
        targets: heroElements,
        translateY: [24, 0],
        opacity: [0, 1],
        delay: anime.stagger(90, { start: 100 }),
        duration: 800,
        easing: 'easeOutCubic',
        complete: (anim) => {
          // Safeguard: Remove inline transform so CSS :hover rules apply cleanly
          anim.animatables.forEach(a => {
            a.target.style.transform = '';
          });
        }
      });
    }

    // --- 6.2 Hero Artwork Entrance & Ambient Bobbing ---
    const artworkFrame = document.querySelector('.hero-artwork-frame');
    if (artworkFrame) {
      anime({
        targets: artworkFrame,
        scale: [0.94, 1],
        opacity: [0, 1],
        translateY: [25, 0],
        duration: 900,
        easing: 'easeOutCubic',
        complete: () => {
          // Continuous Ambient Floating Animation
          anime({
            targets: artworkFrame,
            translateY: [-6, 6],
            duration: 4000,
            direction: 'alternate',
            loop: true,
            easing: 'easeInOutSine'
          });
        }
      });
    }

    // --- 6.3 Pulse Dot Ambient Breathing ---
    const pulseDot = document.querySelector('.pulse-dot');
    if (pulseDot) {
      anime({
        targets: pulseDot,
        scale: [1, 1.4],
        opacity: [0.6, 1],
        duration: 1500,
        direction: 'alternate',
        loop: true,
        easing: 'easeInOutQuad'
      });
    }

    // --- 6.4 Scroll-Triggered Card Reveals via IntersectionObserver ---
    initScrollReveals();

    // --- 6.5 Interactive Micro-Interactions ---
    initInteractiveMicroInteractions();

  } catch (err) {
    console.warn('Anime.js initialization error:', err);
  }
}

/**
 * Coordinated scroll reveals for cards and features using IntersectionObserver
 */
function initScrollReveals() {
  if (!('IntersectionObserver' in window)) return;

  const sections = document.querySelectorAll('.section, .download-section');
  if (sections.length === 0) return;

  const observer = new IntersectionObserver((entries, obs) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const cards = entry.target.querySelectorAll('.bento-card, .download-card');
        if (cards.length > 0) {
          anime({
            targets: cards,
            translateY: [32, 0],
            opacity: [0, 1],
            delay: anime.stagger(80),
            duration: 650,
            easing: 'easeOutCubic',
            complete: (anim) => {
              // Strip inline transform to restore CSS hover behavior
              anim.animatables.forEach(a => {
                a.target.style.transform = '';
              });
            }
          });
        }
        obs.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });

  sections.forEach(sec => observer.observe(sec));
}

/**
 * Tactile micro-interactions on click and button press
 */
function initInteractiveMicroInteractions() {
  const buttons = document.querySelectorAll('.btn-primary, .btn-secondary, .btn-discord-hero');
  buttons.forEach(btn => {
    btn.addEventListener('mousedown', () => {
      anime({
        targets: btn,
        scale: 0.97,
        duration: 120,
        easing: 'easeInOutQuad'
      });
    });
    btn.addEventListener('mouseup', () => {
      anime({
        targets: btn,
        scale: 1,
        duration: 180,
        easing: 'easeOutQuad'
      });
    });
    btn.addEventListener('mouseleave', () => {
      anime({
        targets: btn,
        scale: 1,
        duration: 150,
        easing: 'easeOutQuad'
      });
    });
  });
}

/* ==========================================================================
   7. Hero 3D Book Experience
   ========================================================================== */
function initHero3D() {
  if (typeof initHero3DBook === 'function') {
    initHero3DBook('#hero-3d-canvas');
  }
}
