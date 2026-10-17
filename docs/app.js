/**
 * 🌌 EPILOGUE (독자의 에필로그) — OFFICIAL INTERACTIVE SCRIPT
 * Handles Starfield Canvas, Phone Mockup Reader Engine, CRT Shader,
 * Star Stream Easter Eggs, and Mobile Drawer Interactions.
 */

document.addEventListener('DOMContentLoaded', () => {
  initStarfield();
  initThemeToggle();
  initPhoneSimulator();
  initConstellationInteractions();
  initPlatformDetection();
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
  // Reduce star count slightly on small mobile devices for battery efficiency
  const isMobile = window.innerWidth < 768;
  const starCount = isMobile ? 45 : 80;

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
        radius: Math.random() * 1.4 + 0.3,
        alpha: Math.random() * 0.75 + 0.25,
        twinkleSpeed: (Math.random() * 0.02 + 0.005) * (Math.random() > 0.5 ? 1 : -1),
        vx: (Math.random() - 0.5) * 0.12,
        vy: (Math.random() - 0.5) * 0.12,
      });
    }
  }

  function draw() {
    ctx.clearRect(0, 0, width, height);

    // Draw Constellation Lines between nearby stars
    for (let i = 0; i < stars.length; i++) {
      for (let j = i + 1; j < stars.length; j++) {
        const dx = stars[i].x - stars[j].x;
        const dy = stars[i].y - stars[j].y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < 100) {
          const lineAlpha = (1 - dist / 100) * 0.12 * Math.min(stars[i].alpha, stars[j].alpha);
          ctx.strokeStyle = `rgba(6, 182, 212, ${lineAlpha})`;
          ctx.lineWidth = 0.6;
          ctx.beginPath();
          ctx.moveTo(stars[i].x, stars[i].y);
          ctx.lineTo(stars[j].x, stars[j].y);
          ctx.stroke();
        }
      }
    }

    // Draw Stars
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
      toggleBtn.setAttribute('title', 'Switch to Cosmic Dark');
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
      toggleBtn.setAttribute('title', 'Switch to Paper Light');
    }
  }
}

/* ==========================================================================
   3. Interactive Phone Simulator & Reader Engine
   ========================================================================== */
function initPhoneSimulator() {
  const phoneScreen = document.getElementById('phone-screen');
  const viewport = document.getElementById('reader-viewport');
  const crtBtn = document.getElementById('btn-sim-crt');
  const modeBtn = document.getElementById('btn-sim-mode');
  const themeBtn = document.getElementById('btn-sim-theme');
  const fontBtn = document.getElementById('btn-sim-font');
  const hlBtn = document.getElementById('btn-sim-hl');
  const prevPageBtn = document.getElementById('btn-page-prev');
  const nextPageBtn = document.getElementById('btn-page-next');
  const pageIndicator = document.getElementById('reader-page-indicator');

  if (!phoneScreen || !viewport) return;

  // Novel Excerpt Pages from ORV
  const pages = [
    `<h3>PROLOGUE</h3>
     <p>『There are three ways to survive in a ruined world. Now, I have forgotten a few. But one thing is certain: you who are reading this will survive.』</p>
     <p>A web novel bulletin board. A text that seemed ordinary enough. Yet, those exact words were written there.</p>
     <p>My name is Kim Dokja. 28 years old, an office worker at a game company affiliate. My sole hobby was reading web novels during the subway commute home.</p>
     <blockquote>[The Constellation 'Demon King of Salvation' glances at your late-night reading habits.]</blockquote>`,

    `<h3>CHAPTER 1: THE PAID SERVICE BEGINS</h3>
     <p>『The paid service of the 8,612th world line will now begin.』</p>
     <p>A bright blue notification window floated in the empty air of the train compartment. The subway carriage rattled violently past Dongdaemun station.</p>
     <p>“Wait, is this an augmented reality ad?”</p>
     <p>“Who hacked the subway screens?”</p>
     <p class="hl-cyan">People chuckled nervously. Only I knew. The 3,149-chapter novel I had followed for over ten years had just become reality.</p>`,

    `<h3>CHAPTER 1: A DOKKAEBI ARRIVES</h3>
     <p>A fluffy creature with two small horns floated into the subway car out of thin air, chuckling softly.</p>
     <p>“Aha! Everyone looks so relaxed and peaceful!”</p>
     <p class="hl-gold">『Main Scenario #1 — Proof of Value has arrived.』</p>
     <p>Genre: Survival<br>Difficulty: F<br>Time Limit: 30 minutes<br>Clear Condition: Kill one or more living organisms.</p>
     <p class="hl-crimson">The lights snapped off. The subway doors sealed shut with a deafening hiss.</p>`
  ];

  let currentPage = 0;
  let isContinuousScroll = false;
  let isCrtMode = false;
  const themes = ['paperLight', 'sepiaWarm', 'slateGray', 'oledDark'];
  const themeLabels = ['Paper Light', 'Sepia Warm', 'Slate Gray', 'OLED Pitch'];
  let currentThemeIdx = 0;
  const fonts = ['serif', 'sans', 'mono'];
  const fontLabels = ['Serif', 'Sans', 'Mono'];
  let currentFontIdx = 0;
  const highlights = ['hl-cyan', 'hl-gold', 'hl-crimson', 'hl-emerald', 'hl-violet'];
  const hlLabels = ['Cyan', 'Gold', 'Crimson', 'Emerald', 'Violet'];
  let currentHlIdx = 0;

  function renderPage() {
    if (isContinuousScroll) {
      viewport.innerHTML = pages.join('<hr style="margin: 18px 0; border: none; border-top: 1px dashed rgba(120,120,120,0.3); opacity: 0.5;">');
      if (pageIndicator) pageIndicator.innerText = 'Continuous Scroll';
      if (prevPageBtn) prevPageBtn.style.opacity = '0.3';
      if (nextPageBtn) nextPageBtn.style.opacity = '0.3';
    } else {
      viewport.innerHTML = pages[currentPage];
      if (pageIndicator) pageIndicator.innerText = `Page ${currentPage + 1} of ${pages.length}`;
      if (prevPageBtn) prevPageBtn.style.opacity = currentPage === 0 ? '0.3' : '1';
      if (nextPageBtn) nextPageBtn.style.opacity = currentPage === pages.length - 1 ? '0.3' : '1';
      viewport.scrollTop = 0;
    }
  }

  // CRT Scanline Shader Toggle
  if (crtBtn) {
    crtBtn.addEventListener('click', () => {
      isCrtMode = !isCrtMode;
      phoneScreen.classList.toggle('crt-mode', isCrtMode);
      crtBtn.classList.toggle('active', isCrtMode);
      playSynthChime(isCrtMode ? 660 : 330, 'square');
      showStarstreamToast(isCrtMode ? 
        "[Shader Active: Retro CRT Scanlines enabled]" : 
        "[Shader Inactive: Clean vector mode]"
      );
    });
  }

  // Dual Reading Mode (Page Turn vs Continuous Scroll)
  if (modeBtn) {
    modeBtn.addEventListener('click', () => {
      isContinuousScroll = !isContinuousScroll;
      modeBtn.innerText = isContinuousScroll ? 'Continuous Scroll' : 'Page-Turn';
      modeBtn.classList.toggle('active', isContinuousScroll);
      playSynthChime(440, 'sine');
      renderPage();
    });
  }

  // Reader Themes
  if (themeBtn) {
    themeBtn.addEventListener('click', () => {
      currentThemeIdx = (currentThemeIdx + 1) % themes.length;
      const selected = themes[currentThemeIdx];
      phoneScreen.setAttribute('data-reader-theme', selected);
      themeBtn.innerText = themeLabels[currentThemeIdx];
      playSynthChime(520, 'sine');
    });
  }

  // Fonts
  if (fontBtn) {
    fontBtn.addEventListener('click', () => {
      currentFontIdx = (currentFontIdx + 1) % fonts.length;
      const font = fonts[currentFontIdx];
      viewport.classList.remove('font-sans', 'font-mono');
      if (font === 'sans') viewport.classList.add('font-sans');
      if (font === 'mono') viewport.classList.add('font-mono');
      fontBtn.innerText = fontLabels[currentFontIdx];
      playSynthChime(480, 'sine');
    });
  }

  // Highlight Palette Cycle
  if (hlBtn) {
    hlBtn.addEventListener('click', () => {
      currentHlIdx = (currentHlIdx + 1) % highlights.length;
      const colorClass = highlights[currentHlIdx];
      const allHighlights = viewport.querySelectorAll('[class^="hl-"]');
      allHighlights.forEach(el => {
        highlights.forEach(h => el.classList.remove(h));
        el.classList.add(colorClass);
      });
      hlBtn.innerText = `${hlLabels[currentHlIdx]} Highlight`;
      playSynthChime(580, 'triangle');
      showStarstreamToast(`[Annotation Palette: ${hlLabels[currentHlIdx]}]`);
    });
  }

  // Page Navigation Buttons
  if (prevPageBtn) {
    prevPageBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (!isContinuousScroll && currentPage > 0) {
        currentPage--;
        playSynthChime(380, 'sine');
        renderPage();
      }
    });
  }

  if (nextPageBtn) {
    nextPageBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (!isContinuousScroll && currentPage < pages.length - 1) {
        currentPage++;
        playSynthChime(460, 'sine');
        renderPage();
      }
    });
  }

  // Left/Right Tap zones inside reader viewport (only horizontal tap, no vertical drag hijack)
  let touchStartX = 0;
  let touchStartY = 0;

  viewport.addEventListener('touchstart', (e) => {
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
  }, { passive: true });

  viewport.addEventListener('touchend', (e) => {
    if (isContinuousScroll) return;
    const touchEndX = e.changedTouches[0].clientX;
    const touchEndY = e.changedTouches[0].clientY;
    const deltaX = touchEndX - touchStartX;
    const deltaY = touchEndY - touchStartY;

    // If user was swiping vertically, don't trigger page turn
    if (Math.abs(deltaY) > 30) return;

    // If subtle tap (not swipe)
    if (Math.abs(deltaX) < 15) {
      const rect = viewport.getBoundingClientRect();
      const clickX = touchEndX - rect.left;
      if (clickX < rect.width * 0.35) {
        if (currentPage > 0) {
          currentPage--;
          playSynthChime(380, 'sine');
          renderPage();
        }
      } else if (clickX > rect.width * 0.65) {
        if (currentPage < pages.length - 1) {
          currentPage++;
          playSynthChime(460, 'sine');
          renderPage();
        }
      }
    }
  }, { passive: true });

  renderPage();
}

/* ==========================================================================
   4. Constellation Interactions & Star Stream Toast Easter Egg
   ========================================================================== */
function initConstellationInteractions() {
  const cards = document.querySelectorAll('.constellation-card, .scenario-card');
  const toasts = [
    "[The Constellation, 'Demon King of Salvation', sponsors 100 coins and tells you to go to sleep.]",
    "[The Constellation, 'Secretive Plotter', silently observes your 3 AM reading spree.]",
    "[The Constellation, 'Prisoner of the Golden Headband', bursts into laughter and sends 200 coins.]",
    "[The Constellation, 'Demonic Judge of Fire', is shedding tears over your companion loyalty.]",
    "[The Constellation, 'Abyssal Black Flame Dragon', is flexing his dark dragon flames.]",
    "[The Fourth Wall murmurs: 『One more chapter won't hurt, right?』]",
    "[System: Retrocognition complete. 18,500 Coins back-credited to your account.]"
  ];

  cards.forEach(card => {
    card.addEventListener('click', () => {
      const randomToast = toasts[Math.floor(Math.random() * toasts.length)];
      showStarstreamToast(randomToast);
      playSynthChime(554.37, 'sine'); // C#5 Star Stream Coin tone
    });
  });
}

function showStarstreamToast(message) {
  let container = document.getElementById('starstream-toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'starstream-toast-container';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  toast.className = 'starstream-toast';
  toast.innerHTML = `
    <span style="color: var(--color-gold); font-size: 0.95rem; flex-shrink: 0;">🪙</span>
    <span style="flex: 1;">${message}</span>
  `;

  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    toast.style.transition = 'all 0.25s ease';
    setTimeout(() => toast.remove(), 250);
  }, 3800);
}

/* Web Audio API Sound Chime (Zero external audio files required) */
function playSynthChime(freq = 440, type = 'sine') {
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    const ctx = new AudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = type;
    osc.frequency.setValueAtTime(freq, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(freq * 1.4, ctx.currentTime + 0.12);

    gain.gain.setValueAtTime(0.06, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.25);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.25);
  } catch (e) {
    // Audio context may be blocked by autoplay policies until user clicks
  }
}

/* ==========================================================================
   5. Platform Auto-Detection & Download Guidance
   ========================================================================== */
function initPlatformDetection() {
  const userAgent = navigator.userAgent || navigator.vendor || window.opera;
  const isAndroid = /android/i.test(userAgent);
  const heroDownloadBtn = document.getElementById('hero-download-btn');
  const heroDownloadLabel = document.getElementById('hero-download-label');

  if (heroDownloadBtn && isAndroid) {
    if (heroDownloadLabel) {
      heroDownloadLabel.innerText = 'Download APK (ARM64-v8a)';
    }
  }
}

/* ==========================================================================
   6. Mobile Navigation Menu Drawer
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

  // Close automatically when any nav link is tapped
  const navLinks = navMenu.querySelectorAll('.nav-link');
  navLinks.forEach(link => {
    link.addEventListener('click', () => {
      closeMenu();
    });
  });

  // Close when tapping outside the menu
  document.addEventListener('click', (e) => {
    if (navMenu.classList.contains('open') && !navMenu.contains(e.target) && !mobileBtn.contains(e.target)) {
      closeMenu();
    }
  });

  // Close on Escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && navMenu.classList.contains('open')) {
      closeMenu();
    }
  });
}
