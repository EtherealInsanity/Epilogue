/**
 * 🌌 EPILOGUE (독자의 에필로그) — HERO 3D HARDCOVER BOOK EXPERIENCE
 * Interactive WebGL 3D book rendered with Three.js (r128)
 *
 * Features:
 * - High-fidelity 3D hardcover book mesh with realistic page block & ribbon bookmark
 * - Procedural canvas textures with star-stream metallic foil & book leaf details
 * - Continuous breathing & floating celestial animation
 * - Gentle mouse & touch parallax tilt interaction with smooth easing
 * - IntersectionObserver lifecycle to pause rAF loop when out of viewport
 * - prefers-reduced-motion media query support to halt motion
 * - Graceful fallback if WebGL is unavailable or fails
 */

(function (root, factory) {
  if (typeof define === 'function' && define.amd) {
    define(['three'], factory);
  } else if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('three'));
  } else {
    root.Hero3DBook = factory(root.THREE);
    // Also expose shorthand helper on window
    root.initHero3DBook = function (canvasSelector, options) {
      return root.Hero3DBook.init(canvasSelector, options);
    };
  }
})(typeof self !== 'undefined' ? self : this, function (THREE) {
  'use strict';

  /**
   * Detects WebGL rendering capability safely
   */
  function isWebGLSupported() {
    try {
      const canvas = document.createElement('canvas');
      return !!(
        window.WebGLRenderingContext &&
        (canvas.getContext('webgl') || canvas.getContext('experimental-webgl'))
      );
    } catch (e) {
      return false;
    }
  }

  /**
   * Generates procedural front cover texture with metallic star-stream foil
   */
  function createCoverTexture(isFront = true) {
    const canvas = document.createElement('canvas');
    canvas.width = 1024;
    canvas.height = 1440;
    const ctx = canvas.getContext('2d');

    // Rich obsidian navy leatherette background
    const bgGradient = ctx.createLinearGradient(0, 0, 1024, 1440);
    bgGradient.addColorStop(0, '#070c18');
    bgGradient.addColorStop(0.5, '#0b1329');
    bgGradient.addColorStop(1, '#050914');
    ctx.fillStyle = bgGradient;
    ctx.fillRect(0, 0, 1024, 1440);

    // Subtle leather grain texture
    ctx.fillStyle = 'rgba(255, 255, 255, 0.015)';
    for (let i = 0; i < 18000; i++) {
      const gx = Math.random() * 1024;
      const gy = Math.random() * 1440;
      ctx.fillRect(gx, gy, 1.5, 1.5);
    }

    // Outer double metallic gold/cyan foil border
    ctx.strokeStyle = 'rgba(6, 182, 212, 0.75)';
    ctx.lineWidth = 4;
    ctx.strokeRect(52, 52, 920, 1336);

    ctx.strokeStyle = 'rgba(245, 158, 11, 0.65)';
    ctx.lineWidth = 1.5;
    ctx.strokeRect(66, 66, 892, 1308);

    // Corner decorative geometric accents
    const corners = [
      [52, 52, 1, 1],
      [972, 52, -1, 1],
      [52, 1388, 1, -1],
      [972, 1388, -1, -1]
    ];
    corners.forEach(([cx, cy, sx, sy]) => {
      ctx.beginPath();
      ctx.moveTo(cx, cy + sy * 40);
      ctx.lineTo(cx, cy);
      ctx.lineTo(cx + sx * 40, cy);
      ctx.strokeStyle = 'rgba(245, 158, 11, 0.9)';
      ctx.lineWidth = 3;
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(cx + sx * 20, cy + sy * 20, 4, 0, Math.PI * 2);
      ctx.fillStyle = '#f59e0b';
      ctx.fill();
    });

    if (isFront) {
      // Celestial constellation lines on front cover
      ctx.save();
      ctx.strokeStyle = 'rgba(6, 182, 212, 0.28)';
      ctx.lineWidth = 1.5;
      const stars = [
        [512, 280], [380, 360], [644, 360], [320, 500],
        [704, 500], [512, 560], [430, 440], [594, 440]
      ];
      ctx.beginPath();
      stars.forEach(([sx, sy], idx) => {
        if (idx === 0) ctx.moveTo(sx, sy);
        else ctx.lineTo(sx, sy);
      });
      ctx.closePath();
      ctx.stroke();

      // Constellation stars
      stars.forEach(([sx, sy]) => {
        ctx.beginPath();
        ctx.arc(sx, sy, 3.5, 0, Math.PI * 2);
        ctx.fillStyle = '#67e8f9';
        ctx.shadowColor = '#06b6d4';
        ctx.shadowBlur = 12;
        ctx.fill();
      });
      ctx.restore();

      // Main Title: EPILOGUE
      ctx.save();
      ctx.textAlign = 'center';
      ctx.font = 'bold 84px "Times New Roman", Times, Georgia, serif';
      ctx.fillStyle = '#f8fafc';
      ctx.shadowColor = 'rgba(6, 182, 212, 0.85)';
      ctx.shadowBlur = 18;
      ctx.fillText('EPILOGUE', 512, 740);

      // Foil shine line across title
      const titleGrad = ctx.createLinearGradient(200, 740, 824, 740);
      titleGrad.addColorStop(0, '#67e8f9');
      titleGrad.addColorStop(0.5, '#fef08a');
      titleGrad.addColorStop(1, '#67e8f9');
      ctx.fillStyle = titleGrad;
      ctx.fillText('EPILOGUE', 512, 740);

      // Korean Subtitle: 독자의 에필로그
      ctx.font = '500 34px -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Malgun Gothic", sans-serif';
      ctx.fillStyle = '#94a3b8';
      ctx.shadowBlur = 0;
      ctx.letterSpacing = '6px';
      ctx.fillText('독 자 의   에 필 로 그', 512, 810);

      // Decorative divider
      ctx.strokeStyle = 'rgba(245, 158, 11, 0.7)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(340, 860);
      ctx.lineTo(684, 860);
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(512, 860, 5, 0, Math.PI * 2);
      ctx.fillStyle = '#f59e0b';
      ctx.fill();

      // Author & Platform seal
      ctx.font = '600 24px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
      ctx.fillStyle = '#cbd5e1';
      ctx.fillText('DISTRACTION-FREE BOOK READER', 512, 1220);

      ctx.font = '400 20px "Courier New", monospace';
      ctx.fillStyle = '#64748b';
      ctx.fillText('ETHEREAL INSANITY • v2.0', 512, 1260);
      ctx.restore();
    } else {
      // Back Cover: ORV Quote & Barcode / Insignia
      ctx.save();
      ctx.textAlign = 'center';

      ctx.font = 'italic 30px "Times New Roman", Times, Georgia, serif';
      ctx.fillStyle = '#38bdf8';
      ctx.fillText('[The Fourth Wall whispers]', 512, 420);

      ctx.font = 'italic 28px Georgia, serif';
      ctx.fillStyle = '#e2e8f0';
      const quoteLines = [
        '"There are three ways to survive in a ruined world.',
        'Now, I have forgotten a few, but one thing is certain:',
        'you who are reading this will survive."'
      ];
      quoteLines.forEach((line, i) => {
        ctx.fillText(line, 512, 490 + i * 46);
      });

      // Embellished star crest
      ctx.beginPath();
      ctx.arc(512, 740, 48, 0, Math.PI * 2);
      ctx.strokeStyle = 'rgba(6, 182, 212, 0.5)';
      ctx.lineWidth = 2;
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(512, 740, 8, 0, Math.PI * 2);
      ctx.fillStyle = '#f59e0b';
      ctx.fill();

      // Barcode at bottom
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(412, 1150, 200, 70);
      ctx.fillStyle = '#000000';
      for (let bx = 422; bx < 602; bx += 5 + Math.floor(Math.sin(bx) * 3)) {
        ctx.fillRect(bx, 1155, Math.random() > 0.3 ? 2 : 4, 50);
      }
      ctx.font = '14px monospace';
      ctx.fillText('979-11-90123-45-6', 512, 1215);

      ctx.restore();
    }

    const texture = new THREE.CanvasTexture(canvas);
    texture.generateMipmaps = true;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    return texture;
  }

  /**
   * Generates procedural spine texture with horizontal ribs and vertical lettering
   */
  function createSpineTexture() {
    const canvas = document.createElement('canvas');
    canvas.width = 256;
    canvas.height = 1440;
    const ctx = canvas.getContext('2d');

    // Deep leather gradient
    const grad = ctx.createLinearGradient(0, 0, 256, 0);
    grad.addColorStop(0, '#04070f');
    grad.addColorStop(0.2, '#0c162e');
    grad.addColorStop(0.5, '#122245');
    grad.addColorStop(0.8, '#0c162e');
    grad.addColorStop(1, '#04070f');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, 256, 1440);

    // Decorative raised ribs at spine top and bottom
    const ribPositions = [120, 160, 1280, 1320];
    ribPositions.forEach((ry) => {
      ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
      ctx.fillRect(0, ry - 3, 256, 8);
      ctx.fillStyle = 'rgba(245, 158, 11, 0.7)';
      ctx.fillRect(0, ry, 256, 3);
      ctx.fillStyle = 'rgba(6, 182, 212, 0.7)';
      ctx.fillRect(0, ry + 3, 256, 1);
    });

    // Vertical title on spine
    ctx.save();
    ctx.translate(128, 720);
    ctx.rotate(Math.PI / 2);
    ctx.textAlign = 'center';
    ctx.font = 'bold 54px "Times New Roman", Times, Georgia, serif';
    ctx.fillStyle = '#f8fafc';
    ctx.shadowColor = 'rgba(6, 182, 212, 0.8)';
    ctx.shadowBlur = 12;
    ctx.fillText('EPILOGUE', 0, 18);

    ctx.font = '24px sans-serif';
    ctx.fillStyle = '#94a3b8';
    ctx.shadowBlur = 0;
    ctx.fillText('독자의 에필로그', -260, 10);
    ctx.restore();

    // Star icon at spine head
    ctx.beginPath();
    ctx.arc(128, 80, 10, 0, Math.PI * 2);
    ctx.fillStyle = '#f59e0b';
    ctx.fill();

    const texture = new THREE.CanvasTexture(canvas);
    texture.generateMipmaps = true;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    return texture;
  }

  /**
   * Generates realistic paper page edge texture with fine micro-leafing lines
   */
  function createPagesTexture() {
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 512;
    const ctx = canvas.getContext('2d');

    // Warm cream / book paper tint
    ctx.fillStyle = '#fbf8ee';
    ctx.fillRect(0, 0, 512, 512);

    // Subtle edge shading near binding
    const vignette = ctx.createLinearGradient(0, 0, 512, 0);
    vignette.addColorStop(0, 'rgba(0,0,0,0.08)');
    vignette.addColorStop(0.15, 'rgba(0,0,0,0.02)');
    vignette.addColorStop(0.85, 'rgba(0,0,0,0.02)');
    vignette.addColorStop(1, 'rgba(0,0,0,0.12)');
    ctx.fillStyle = vignette;
    ctx.fillRect(0, 0, 512, 512);

    // Hundreds of subtle horizontal page edge lines
    ctx.fillStyle = 'rgba(168, 140, 104, 0.35)';
    for (let y = 1; y < 512; y += 2) {
      if (Math.random() > 0.25) {
        ctx.fillRect(0, y, 512, 1);
      }
    }

    const texture = new THREE.CanvasTexture(canvas);
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    return texture;
  }

  /**
   * Constructs the 3D book mesh hierarchy
   */
  function createBookMesh() {
    const bookGroup = new THREE.Group();

    // Book physical proportions
    const bookW = 2.4;
    const bookH = 3.3;
    const bookD = 0.54;
    const coverThick = 0.045;
    const overhang = 0.06;

    // Materials
    const frontCoverTexture = createCoverTexture(true);
    const backCoverTexture = createCoverTexture(false);
    const spineTexture = createSpineTexture();
    const pagesTexture = createPagesTexture();

    const leatherMaterialOptions = {
      color: 0xffffff,
      roughness: 0.38,
      metalness: 0.22,
    };

    const frontCoverMat = new THREE.MeshStandardMaterial({
      ...leatherMaterialOptions,
      map: frontCoverTexture,
    });

    const backCoverMat = new THREE.MeshStandardMaterial({
      ...leatherMaterialOptions,
      map: backCoverTexture,
    });

    const spineMat = new THREE.MeshStandardMaterial({
      ...leatherMaterialOptions,
      map: spineTexture,
    });

    const edgeLeatherMat = new THREE.MeshStandardMaterial({
      color: 0x091122,
      roughness: 0.5,
      metalness: 0.1,
    });

    const pagesMat = new THREE.MeshStandardMaterial({
      color: 0xfcf9f0,
      roughness: 0.88,
      metalness: 0.04,
      map: pagesTexture,
    });

    // 1. Front Cover Board
    // Box materials: [right, left, top, bottom, front, back]
    const frontMaterials = [
      edgeLeatherMat,
      edgeLeatherMat,
      edgeLeatherMat,
      edgeLeatherMat,
      frontCoverMat,
      edgeLeatherMat,
    ];
    const frontCoverGeo = new THREE.BoxGeometry(bookW, bookH, coverThick);
    const frontCover = new THREE.Mesh(frontCoverGeo, frontMaterials);
    frontCover.position.set(0, 0, (bookD + coverThick) / 2);
    bookGroup.add(frontCover);

    // 2. Back Cover Board
    const backMaterials = [
      edgeLeatherMat,
      edgeLeatherMat,
      edgeLeatherMat,
      edgeLeatherMat,
      edgeLeatherMat,
      backCoverMat,
    ];
    const backCoverGeo = new THREE.BoxGeometry(bookW, bookH, coverThick);
    const backCover = new THREE.Mesh(backCoverGeo, backMaterials);
    backCover.position.set(0, 0, -(bookD + coverThick) / 2);
    bookGroup.add(backCover);

    // 3. Curved Spine (Left Side)
    const spineGeo = new THREE.BoxGeometry(coverThick * 1.5, bookH, bookD + coverThick * 1.8);
    const spineMaterials = [
      edgeLeatherMat,
      spineMat,
      edgeLeatherMat,
      edgeLeatherMat,
      edgeLeatherMat,
      edgeLeatherMat,
    ];
    const spine = new THREE.Mesh(spineGeo, spineMaterials);
    spine.position.set(-bookW / 2 + coverThick / 2, 0, 0);
    bookGroup.add(spine);

    // 4. Paper Page Block (recessed slightly from top, bottom, right)
    const pageW = bookW - overhang * 1.8;
    const pageH = bookH - overhang * 2.2;
    const pageD = bookD - 0.02;

    const pageMaterials = [
      pagesMat,       // right open edge
      edgeLeatherMat, // left binding edge
      pagesMat,       // top edge
      pagesMat,       // bottom edge
      pagesMat,       // front face
      pagesMat,       // back face
    ];
    const pagesGeo = new THREE.BoxGeometry(pageW, pageH, pageD);
    const pages = new THREE.Mesh(pagesGeo, pageMaterials);
    // Align flush against spine on left, recessed on top/bottom/right
    pages.position.set((bookW - pageW) / 2 - overhang * 0.4, 0, 0);
    bookGroup.add(pages);

    // 5. Satin Bookmark Ribbon (draping down from bottom page block)
    const ribbonCurve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(0.2, -pageH / 2 + 0.1, 0.04),
      new THREE.Vector3(0.24, -pageH / 2 - 0.2, 0.12),
      new THREE.Vector3(0.32, -pageH / 2 - 0.48, 0.16),
      new THREE.Vector3(0.42, -pageH / 2 - 0.72, 0.08),
    ]);
    const ribbonGeo = new THREE.TubeGeometry(ribbonCurve, 20, 0.035, 8, false);
    const ribbonMat = new THREE.MeshStandardMaterial({
      color: 0x06b6d4, // Cyan silk ribbon
      roughness: 0.35,
      metalness: 0.3,
    });
    const ribbon = new THREE.Mesh(ribbonGeo, ribbonMat);
    bookGroup.add(ribbon);

    return {
      bookGroup,
      textures: [frontCoverTexture, backCoverTexture, spineTexture, pagesTexture],
      materials: [frontCoverMat, backCoverMat, spineMat, edgeLeatherMat, pagesMat, ribbonMat],
      geometries: [frontCoverGeo, backCoverGeo, spineGeo, pagesGeo, ribbonGeo],
    };
  }

  /**
   * Main Initializer Class / Controller
   */
  class Hero3DBookExperience {
    constructor(canvas, options = {}) {
      this.canvas = typeof canvas === 'string' ? document.querySelector(canvas) : canvas;
      this.options = Object.assign(
        {
          fallbackSelector: '.hero-fallback-img, .hero-artwork-img',
          ambientColor: 0xdbeafe,
          keyLightColor: 0x38bdf8,
          warmLightColor: 0xf59e0b,
          baseRotationX: 0.24,
          baseRotationY: -0.62,
          baseRotationZ: 0.05,
        },
        options
      );

      this.animId = null;
      this.isRunning = false;
      this.isReducedMotion = false;
      this.clock = new THREE.Clock();

      // Mouse / touch parallax state
      this.targetTiltX = 0;
      this.targetTiltY = 0;
      this.currentTiltX = 0;
      this.currentTiltY = 0;

      // Event handlers bound
      this._onPointerMove = this._handlePointerMove.bind(this);
      this._onPointerLeave = this._handlePointerLeave.bind(this);
      this._onResize = this._handleResize.bind(this);
      this._onVisibilityChange = this._handleVisibilityChange.bind(this);
      this._onMotionPreferenceChange = this._handleMotionPreferenceChange.bind(this);

      this.init();
    }

    init() {
      if (!this.canvas) {
        console.warn('[Hero3D] Canvas element not found.');
        return;
      }

      if (!isWebGLSupported()) {
        console.warn('[Hero3D] WebGL unsupported. Retaining fallback visual.');
        this._showFallback();
        return;
      }

      try {
        // Setup Scene & Camera
        this.scene = new THREE.Scene();

        const rect = this.canvas.getBoundingClientRect();
        const width = rect.width || this.canvas.clientWidth || 480;
        const height = rect.height || this.canvas.clientHeight || 340;

        this.camera = new THREE.PerspectiveCamera(36, width / height, 0.1, 50);
        this.camera.position.set(0, 0, 6.8);

        // Renderer
        this.renderer = new THREE.WebGLRenderer({
          canvas: this.canvas,
          alpha: true,
          antialias: true,
          powerPreference: 'high-performance',
        });
        this.renderer.setSize(width, height, false);
        this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
        if (THREE.ACESFilmicToneMapping) {
          this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
          this.renderer.toneMappingExposure = 1.15;
        }

        // Lighting
        const ambientLight = new THREE.AmbientLight(this.options.ambientColor, 0.85);
        this.scene.add(ambientLight);

        const keyLight = new THREE.DirectionalLight(this.options.keyLightColor, 1.4);
        keyLight.position.set(4, 5, 5);
        this.scene.add(keyLight);

        const warmLight = new THREE.PointLight(this.options.warmLightColor, 1.3, 16);
        warmLight.position.set(-4, -3, 3);
        this.scene.add(warmLight);

        const rimLight = new THREE.DirectionalLight(0x818cf8, 0.8);
        rimLight.position.set(-2, 3, -4);
        this.scene.add(rimLight);

        // Book mesh construction
        const bookData = createBookMesh();
        this.bookGroup = bookData.bookGroup;
        this.textures = bookData.textures;
        this.materials = bookData.materials;
        this.geometries = bookData.geometries;

        this.bookGroup.rotation.x = this.options.baseRotationX;
        this.bookGroup.rotation.y = this.options.baseRotationY;
        this.bookGroup.rotation.z = this.options.baseRotationZ;
        this.scene.add(this.bookGroup);

        // Motion preference check
        this.motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
        this.isReducedMotion = this.motionQuery.matches;
        if (this.motionQuery.addEventListener) {
          this.motionQuery.addEventListener('change', this._onMotionPreferenceChange);
        } else if (this.motionQuery.addListener) {
          this.motionQuery.addListener(this._onMotionPreferenceChange);
        }

        // Parallax Interaction Listeners
        const targetEl = this.canvas.parentElement || this.canvas;
        targetEl.addEventListener('pointermove', this._onPointerMove, { passive: true });
        targetEl.addEventListener('pointerleave', this._onPointerLeave, { passive: true });
        window.addEventListener('resize', this._onResize, { passive: true });
        document.addEventListener('visibilitychange', this._onVisibilityChange);

        // IntersectionObserver lifecycle
        this.observer = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (entry.isIntersecting) {
                this.start();
              } else {
                this.stop();
              }
            });
          },
          { threshold: 0.05 }
        );
        this.observer.observe(this.canvas);

        // Make canvas visible and hide fallback image
        this.canvas.style.display = 'block';
        const fallback = document.querySelector(this.options.fallbackSelector);
        if (fallback) {
          fallback.style.display = 'none';
        }

        // Initial render
        this.start();
      } catch (err) {
        console.warn('[Hero3D] Initialization failed:', err);
        this._showFallback();
      }
    }

    _showFallback() {
      if (this.canvas) this.canvas.style.display = 'none';
      const fallback = document.querySelector(this.options.fallbackSelector);
      if (fallback) fallback.style.display = 'block';
    }

    _handleMotionPreferenceChange(e) {
      this.isReducedMotion = !!e.matches;
      if (this.isReducedMotion) {
        this.targetTiltX = 0;
        this.targetTiltY = 0;
        this.currentTiltX = 0;
        this.currentTiltY = 0;
        if (this.bookGroup) {
          this.bookGroup.position.y = 0;
          this.bookGroup.rotation.x = this.options.baseRotationX;
          this.bookGroup.rotation.y = this.options.baseRotationY;
          this.bookGroup.rotation.z = this.options.baseRotationZ;
        }
        if (this.renderer && this.scene && this.camera) {
          this.renderer.render(this.scene, this.camera);
        }
      }
    }

    _handlePointerMove(e) {
      if (this.isReducedMotion) return;
      const rect = (this.canvas.parentElement || this.canvas).getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;

      const normX = ((clientX - rect.left) / rect.width) * 2 - 1;
      const normY = ((clientY - rect.top) / rect.height) * 2 - 1;

      // Soft parallax tilt bounds
      this.targetTiltY = Math.max(-1, Math.min(1, normX)) * 0.38;
      this.targetTiltX = -Math.max(-1, Math.min(1, normY)) * 0.28;
    }

    _handlePointerLeave() {
      this.targetTiltX = 0;
      this.targetTiltY = 0;
    }

    _handleResize() {
      if (!this.canvas || !this.renderer || !this.camera) return;
      const rect = this.canvas.getBoundingClientRect();
      const width = rect.width || this.canvas.clientWidth || 480;
      const height = rect.height || this.canvas.clientHeight || 340;

      this.camera.aspect = width / height;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(width, height, false);
      this.renderer.render(this.scene, this.camera);
    }

    _handleVisibilityChange() {
      if (document.hidden) {
        this.stop();
      } else {
        this.start();
      }
    }

    start() {
      if (this.isRunning) return;
      this.isRunning = true;
      this.clock.start();
      const tick = () => {
        if (!this.isRunning) return;
        this._update();
        this.renderer.render(this.scene, this.camera);
        this.animId = requestAnimationFrame(tick);
      };
      this.animId = requestAnimationFrame(tick);
    }

    stop() {
      if (!this.isRunning) return;
      this.isRunning = false;
      if (this.animId) {
        cancelAnimationFrame(this.animId);
        this.animId = null;
      }
    }

    _update() {
      if (!this.bookGroup) return;

      if (!this.isReducedMotion) {
        const t = this.clock.getElapsedTime();

        // Subtle continuous floating and breathing oscillations
        const floatY = Math.sin(t * 1.5) * 0.085;
        const breathX = Math.sin(t * 1.1) * 0.02;
        const breathY = Math.cos(t * 0.85) * 0.035;
        const breathZ = Math.sin(t * 0.7) * 0.015;

        // Smooth spring/lerp for parallax interaction
        this.currentTiltX += (this.targetTiltX - this.currentTiltX) * 0.06;
        this.currentTiltY += (this.targetTiltY - this.currentTiltY) * 0.06;

        this.bookGroup.position.y = floatY;
        this.bookGroup.rotation.x = this.options.baseRotationX + breathX + this.currentTiltX;
        this.bookGroup.rotation.y = this.options.baseRotationY + breathY + this.currentTiltY;
        this.bookGroup.rotation.z = this.options.baseRotationZ + breathZ;
      } else {
        this.bookGroup.position.y = 0;
        this.bookGroup.rotation.x = this.options.baseRotationX;
        this.bookGroup.rotation.y = this.options.baseRotationY;
        this.bookGroup.rotation.z = this.options.baseRotationZ;
      }
    }

    destroy() {
      this.stop();

      if (this.observer) {
        this.observer.disconnect();
        this.observer = null;
      }

      const targetEl = this.canvas ? this.canvas.parentElement || this.canvas : null;
      if (targetEl) {
        targetEl.removeEventListener('pointermove', this._onPointerMove);
        targetEl.removeEventListener('pointerleave', this._onPointerLeave);
      }
      window.removeEventListener('resize', this._onResize);
      document.removeEventListener('visibilitychange', this._onVisibilityChange);

      if (this.motionQuery) {
        if (this.motionQuery.removeEventListener) {
          this.motionQuery.removeEventListener('change', this._onMotionPreferenceChange);
        } else if (this.motionQuery.removeListener) {
          this.motionQuery.removeListener(this._onMotionPreferenceChange);
        }
      }

      if (this.geometries) {
        this.geometries.forEach((g) => g.dispose());
      }
      if (this.materials) {
        this.materials.forEach((m) => m.dispose());
      }
      if (this.textures) {
        this.textures.forEach((t) => t.dispose());
      }
      if (this.renderer) {
        this.renderer.dispose();
      }
    }
  }

  return {
    init: function (canvasSelector = '#hero-3d-canvas', options = {}) {
      return new Hero3DBookExperience(canvasSelector, options);
    },
    Hero3DBookExperience: Hero3DBookExperience,
    isWebGLSupported: isWebGLSupported,
  };
});
