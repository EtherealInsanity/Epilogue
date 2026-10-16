/**
 * 🌌 EPILOGUE (독자의 에필로그) — OFFICIAL INTERACTIVE SCRIPT
 * Handles Starfield Canvas, Phone Mockup Reader Engine, CRT Shader,
 * Star Stream Easter Eggs, and Platform Auto-detection.
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
  const starCount = 85;

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
        radius: Math.random() * 1.5 + 0.4,
        alpha: Math.random() * 0.8 + 0.2,
        twinkleSpeed: (Math.random() * 0.02 + 0.005) * (Math.random() > 0.5 ? 1 : -1),
        vx: (Math.random() - 0.5) * 0.15,
        vy: (Math.random() - 0.5) * 0.15,
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

        if (dist < 110) {
          const lineAlpha = (1 - dist / 110) * 0.12 * Math.min(stars[i].alpha, stars[j].alpha);
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
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
        </svg>`;
      toggleBtn.setAttribute('title', 'Switch to Cosmic Dark');
    } else {
      document.documentElement.removeAttribute('data-theme');
      toggleBtn.innerHTML = `
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
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
  const mathBadge = document.getElementById('viewport-math-badge');
  const prevPageBtn = document.getElementById('btn-page-prev');
  const nextPageBtn = document.getElementById('btn-page-next');
  const pageIndicator = document.getElementById('reader-page-indicator');

  if (!phoneScreen || !viewport) return;

  // Novel Excerpt Pages from ORV
  const pages = [
    `<h3>PROLOGUE</h3>
     <p>『There are three ways to survive in a ruined world. Now, I have forgotten a few. But one thing is certain: you who are reading this will survive.』</p>
     <p>A web novel bulletin board. A generic, unoriginal text. However, those words were written there.</p>
     <p>My name is Kim Dokja. 28 years old. An office worker at a subsidiary of a game company. My hobby was reading web novels on the subway commute.</p>
     <blockquote>[The Constellation 'Demon King of Salvation' has not yet reached his final destination.]</blockquote>`,

    `<h3>CHAPTER 1: STARTING THE PAID SERVICE</h3>
     <p>『The paid service of the 8,612th world line will now begin.』</p>
     <p>The blue notification window floated in the empty air of the train compartment. The subway carriage rattled violently along Dongdaemun station.</p>
     <p>“Huh? What’s this?”</p>
     <p>“Is this a promotional stunt for a new AR game?”</p>
     <p class="hl-cyan">People whispered in confusion. Only I knew. The world of the novel I had been reading for over ten years had just become reality.</p>`,

    `<h3>CHAPTER 1: THE DOKKAEBI APPEARS</h3>
     <p>A creature with small horns and a fluffy white fur body appeared from the void, floating in midair.</p>
     <p>“Aha, ladies and gentlemen! You’re all looking so peaceful!”</p>
     <p class="hl-gold">『Main Scenario #1 — Proof of Value has arrived.』</p>
     <p>Genre: Survival<br>Difficulty: F<br>Time Limit: 30 minutes<br>Clear Condition: Kill one or more living organisms.</p>
     <p class="hl-crimson">The doors hissed shut. The lights plunged into total darkness.</p>`
  ];

  let currentPage = 0;
  let isContinuousScroll = false;
  let isCrtMode = false;
  const themes = ['paperLight', 'sepiaWarm', 'slateGray', 'oledDark'];
  let currentThemeIdx = 0;
  const fonts = ['serif', 'sans', 'mono'];
  let currentFontIdx = 0;
  const highlights = ['hl-cyan', 'hl-gold', 'hl-crimson', 'hl-emerald', 'hl-violet'];
  let currentHlIdx = 0;

  function renderPage() {
    if (isContinuousScroll) {
      viewport.innerHTML = pages.join('<hr style="margin: 20px 0; border: none; border-top: 1px dashed rgba(120,120,120,0.3);">');
      if (pageIndicator) pageIndicator.innerText = 'Continuous Scroll';
      if (prevPageBtn) prevPageBtn.style.display = 'none';
      if (nextPageBtn) nextPageBtn.style.display = 'none';
      updateBudgetMath(3200, 48, 67);
    } else {
      viewport.innerHTML = pages[currentPage];
      if (pageIndicator) pageIndicator.innerText = `Page ${currentPage + 1} of ${pages.length}`;
      if (prevPageBtn) prevPageBtn.style.display = 'inline-block';
      if (nextPageBtn) nextPageBtn.style.display = 'inline-block';
      viewport.scrollTop = 0;
      updateBudgetMath(1680, 26, 64);
    }
  }

  function updateBudgetMath(budget, lines, chars) {
    if (!mathBadge) return;
    mathBadge.innerText = `Layout Math: Usable Lines: ${lines} × Chars: ${chars} = Budget: ${budget} (100% Filled)`;
  }

  // CRT Scanline Shader Toggle
  if (crtBtn) {
    crtBtn.addEventListener('click', () => {
      isCrtMode = !isCrtMode;
      phoneScreen.classList.toggle('crt-mode', isCrtMode);
      crtBtn.classList.toggle('active', isCrtMode);
      playSynthChime(isCrtMode ? 660 : 330, 'square');
      showStarstreamToast(isCrtMode ? 
        "[Shader Active: Retro CRT Scanline Shader 60Hz Overlay]" : 
        "[Shader Inactive: Standard Dynamic Viewport Engine]"
      );
    });
  }

  // Dual Reading Mode (Page Turn vs Continuous Scroll)
  if (modeBtn) {
    modeBtn.addEventListener('click', () => {
      isContinuousScroll = !isContinuousScroll;
      modeBtn.innerText = isContinuousScroll ? 'Mode: Scroll' : 'Mode: Page-Turn';
      modeBtn.classList.toggle('active', isContinuousScroll);
      playSynthChime(440, 'sine');
      renderPage();
    });
  }

  // Reader Themes (Paper Light, Sepia, Slate, OLED Dark)
  if (themeBtn) {
    themeBtn.addEventListener('click', () => {
      currentThemeIdx = (currentThemeIdx + 1) % themes.length;
      const selected = themes[currentThemeIdx];
      phoneScreen.setAttribute('data-reader-theme', selected);
      themeBtn.innerText = `Theme: ${selected.replace('Warm', '').replace('Dark', '').replace('Light', '')}`;
      playSynthChime(520, 'sine');
    });
  }

  // Fonts (Serif, Sans, Mono)
  if (fontBtn) {
    fontBtn.addEventListener('click', () => {
      currentFontIdx = (currentFontIdx + 1) % fonts.length;
      const font = fonts[currentFontIdx];
      viewport.classList.remove('font-sans', 'font-mono');
      if (font === 'sans') viewport.classList.add('font-sans');
      if (font === 'mono') viewport.classList.add('font-mono');
      fontBtn.innerText = `Font: ${font.toUpperCase()}`;
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
      playSynthChime(580, 'triangle');
      showStarstreamToast(`[Annotation Palette Selected: ${colorClass.replace('hl-', '').toUpperCase()}]`);
    });
  }

  // Page Buttons
  if (prevPageBtn) {
    prevPageBtn.addEventListener('click', () => {
      if (currentPage > 0) {
        currentPage--;
        playSynthChime(380, 'sine');
        renderPage();
      }
    });
  }

  if (nextPageBtn) {
    nextPageBtn.addEventListener('click', () => {
      if (currentPage < pages.length - 1) {
        currentPage++;
        playSynthChime(460, 'sine');
        renderPage();
      }
    });
  }

  // Tap left/right side of reader viewport to turn page (mirroring Epilogue tap zones)
  viewport.addEventListener('click', (e) => {
    if (isContinuousScroll) return;
    const rect = viewport.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
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
  });

  renderPage();
}

/* ==========================================================================
   4. Constellation Interactions & Star Stream Toast Easter Egg
   ========================================================================== */
function initConstellationInteractions() {
  const cards = document.querySelectorAll('.constellation-card, .scenario-card');
  const toasts = [
    "[The Constellation, 'Demon King of Salvation', has sponsored 100 coins.]",
    "[The Constellation, 'Secretive Plotter', is silent.]",
    "[The Constellation, 'Prisoner of the Golden Headband', bursts into laughter and sends 200 coins.]",
    "[The Constellation, 'Demonic Judge of Fire', is praying for your companions.]",
    "[The Constellation, 'Abyssal Black Flame Dragon', glares with pitch-black flames.]",
    "[The Fourth Wall speaks: 『You are reading the story well.』]",
    "[System: Retrocognition sequence completed. +500 Coins rewarded.]"
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
    <span style="color: var(--color-gold); font-size: 1rem;">🪙</span>
    <span>${message}</span>
  `;

  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    toast.style.transition = 'all 0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, 4200);
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
    osc.frequency.exponentialRampToValueAtTime(freq * 1.5, ctx.currentTime + 0.15);

    gain.gain.setValueAtTime(0.08, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.3);
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
   6. Mobile Menu Navigation
   ========================================================================== */
function initMobileNav() {
  const mobileBtn = document.getElementById('mobile-menu-btn');
  const navMenu = document.querySelector('.nav-menu');

  if (mobileBtn && navMenu) {
    mobileBtn.addEventListener('click', () => {
      const isVisible = navMenu.style.display === 'flex';
      navMenu.style.display = isVisible ? 'none' : 'flex';
      if (!isVisible) {
        navMenu.style.flexDirection = 'column';
        navMenu.style.position = 'absolute';
        navMenu.style.top = '72px';
        navMenu.style.left = '0';
        navMenu.style.width = '100%';
        navMenu.style.background = 'var(--bg-glass-strong)';
        navMenu.style.padding = '24px';
        navMenu.style.borderBottom = '1px solid var(--border-subtle)';
      }
    });
  }
}
