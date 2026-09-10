/**
 * Script principal N’MaShop Distribution (Windows PC - Guinée)
 * Design Elite inspiré des meilleures pages SaaS ThemeForest & Pinterest.
 * Gère le showcase interactif, les onglets produit, les effets sonores Web Audio,
 * et la synchronisation intégrale du son de la démo vidéo avec la voix-off.
 */
document.addEventListener("DOMContentLoaded", () => {
  // ── 1. Injection des constantes centralisées ────────────────────
  if (typeof CONFIG !== "undefined") {
    document.querySelectorAll("[data-config]").forEach((el) => {
      const key = el.getAttribute("data-config");
      if (CONFIG[key] !== undefined) {
        el.textContent = CONFIG[key];
      }
    });

    document.querySelectorAll('a[data-action="download"]').forEach((link) => {
      link.setAttribute("href", CONFIG.DOWNLOAD_URL);
      link.setAttribute("target", "_blank");
      link.setAttribute("rel", "noopener noreferrer");
    });

    document.querySelectorAll('a[data-action="whatsapp"]').forEach((link) => {
      const planKey = link.getAttribute("data-plan");
      if (planKey && CONFIG.PRICING && CONFIG.PRICING[planKey.toUpperCase()]?.WHATSAPP_LINK) {
        link.setAttribute("href", CONFIG.PRICING[planKey.toUpperCase()].WHATSAPP_LINK);
      } else {
        link.setAttribute("href", CONFIG.WHATSAPP_URL);
      }
      link.setAttribute("target", "_blank");
      link.setAttribute("rel", "noopener noreferrer");
    });
  }

  // Année actuelle
  const yearEl = document.getElementById("current-year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  // ── 1.4 Sélection interactive dynamique des cartes tarifaires ───────
  const pricingCards = document.querySelectorAll(".pricing-plan-card");
  if (pricingCards.length > 0) {
    pricingCards.forEach((card) => {
      card.addEventListener("click", () => {
        pricingCards.forEach((c) => {
          c.classList.remove("is-popular", "is-selected");
          const btn = c.querySelector(".btn-plan-cta");
          if (btn) {
            btn.classList.remove("btn-plan-primary");
            btn.classList.add("btn-plan-outline");
          }
        });

        card.classList.add("is-selected");
        const activeBtn = card.querySelector(".btn-plan-cta");
        if (activeBtn) {
          activeBtn.classList.remove("btn-plan-outline");
          activeBtn.classList.add("btn-plan-primary");
        }
      });
    });
  }

  // ── 1.5 Gestion Complète du Thème Clair / Sombre (Segmented Switch 100% Cohérent) ──
  function applyTheme(theme) {
    const validTheme = theme === "dark" ? "dark" : "light";
    document.documentElement.setAttribute("data-theme", validTheme);
    try {
      localStorage.setItem("nmashop_theme", validTheme);
    } catch (e) {}

    // Mise à jour de tous les boutons segmentés (Header et Mobile Drawer)
    document.querySelectorAll(".theme-segment-btn").forEach((btn) => {
      const choice = btn.getAttribute("data-theme-choice");
      const isActive = choice === validTheme;
      btn.classList.toggle("is-active", isActive);
      btn.setAttribute("aria-pressed", isActive ? "true" : "false");
    });
  }

  // Initialisation à partir de la préférence stockée ou light par défaut
  let currentTheme = "light";
  try {
    currentTheme = localStorage.getItem("nmashop_theme") || "light";
  } catch (e) {
    currentTheme = "light";
  }
  applyTheme(currentTheme);

  // Écouteurs sur tous les boutons segmentés
  document.querySelectorAll(".theme-segment-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const chosen = btn.getAttribute("data-theme-choice");
      if (chosen === "dark" || chosen === "light") {
        applyTheme(chosen);
      }
    });
  });

  // ── 2. Menu Mobile Latéral (Drawer) ─────────────────────────────
  const menuToggle = document.getElementById("mobile-menu-toggle");
  const navDrawer = document.getElementById("nav-drawer");
  const navBackdrop = document.getElementById("nav-backdrop");
  const navLinks = document.querySelectorAll(".nav-drawer a");

  function openMenu() {
    navDrawer?.classList.add("is-open");
    navBackdrop?.classList.add("is-visible");
    document.body.classList.add("menu-open");
    menuToggle?.setAttribute("aria-expanded", "true");
  }

  function closeMenu() {
    navDrawer?.classList.remove("is-open");
    navBackdrop?.classList.remove("is-visible");
    document.body.classList.remove("menu-open");
    menuToggle?.setAttribute("aria-expanded", "false");
  }

  if (menuToggle) {
    menuToggle.addEventListener("click", () => {
      const isOpen = navDrawer?.classList.contains("is-open");
      if (isOpen) closeMenu(); else openMenu();
    });
  }

  navBackdrop?.addEventListener("click", closeMenu);
  navLinks.forEach((link) => link.addEventListener("click", closeMenu));

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && navDrawer?.classList.contains("is-open")) {
      closeMenu();
    }
  });

  // ── 3. Header au Défilement ─────────────────────────────────────
  const header = document.querySelector(".site-header");
  function handleScroll() {
    if (window.scrollY > 20) {
      header?.classList.add("scrolled");
    } else {
      header?.classList.remove("scrolled");
    }
  }
  window.addEventListener("scroll", handleScroll, { passive: true });
  handleScroll();

  // ── 4. Défilement Doux (Smooth Scroll) ───────────────────────────
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener("click", function (e) {
      const targetId = this.getAttribute("href");
      if (targetId && targetId !== "#") {
        const targetElement = document.querySelector(targetId);
        if (targetElement) {
          e.preventDefault();
          const headerHeight = header ? header.offsetHeight : 74;
          const targetPosition =
            targetElement.getBoundingClientRect().top +
            window.pageYOffset -
            headerHeight -
            16;

          window.scrollTo({
            top: targetPosition,
            behavior: "smooth",
          });
        }
      }
    });
  });

  // ── 5. EFFETS SONORES SYNTHÉTISÉS (Web Audio API - Sans dépendance) ──
  function playRegisterSound(type) {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();

      if (type === "tap") {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.frequency.setValueAtTime(850, ctx.currentTime);
        gain.gain.setValueAtTime(0.08, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.05);
        osc.start();
        osc.stop(ctx.currentTime + 0.05);
      } else if (type === "cash") {
        const osc1 = ctx.createOscillator();
        const osc2 = ctx.createOscillator();
        const gain = ctx.createGain();

        osc1.connect(gain);
        osc2.connect(gain);
        gain.connect(ctx.destination);

        osc1.frequency.setValueAtTime(587.33, ctx.currentTime); // D5
        osc2.frequency.setValueAtTime(880.00, ctx.currentTime + 0.08); // A5

        gain.gain.setValueAtTime(0.18, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.45);

        osc1.start();
        osc1.stop(ctx.currentTime + 0.2);
        osc2.start(ctx.currentTime + 0.08);
        osc2.stop(ctx.currentTime + 0.45);
      }
    } catch (e) {
      // Ignorer si audio restreint par le navigateur
    }
  }

  // ── 6. SHOWCASE INTERACTIF THEMEFOREST : Onglets & Simulation POS ──
  const showcaseTabButtons = document.querySelectorAll(".showcase-tab-btn");
  const showcaseViewPanels = document.querySelectorAll(".showcase-view-panel");

  showcaseTabButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      showcaseTabButtons.forEach((b) => b.classList.remove("active"));
      showcaseViewPanels.forEach((p) => p.classList.remove("active"));

      btn.classList.add("active");
      const targetView = btn.getAttribute("data-view");
      const activePanel = document.getElementById(`view-${targetView}`);
      if (activePanel) activePanel.classList.add("active");
    });
  });

  // Simulation interactive de caisse dans le showcase
  let showcaseTicketItems = [
    { name: "Sac Riz Blanc 50kg", price: 350000, qty: 1 },
    { name: "Bidon Huile 20L", price: 290000, qty: 2 },
    { name: "Carton Lait Bonnet R.", price: 165000, qty: 1 }
  ];

  const ticketLinesEl = document.getElementById("pos-ticket-lines");
  const ticketTotalEl = document.getElementById("pos-ticket-total");
  const btnShowcaseCheckout = document.getElementById("btn-showcase-checkout");

  function updateShowcaseTicketUI() {
    if (!ticketLinesEl || !ticketTotalEl) return;
    ticketLinesEl.innerHTML = "";
    let total = 0;

    showcaseTicketItems.forEach((item) => {
      total += item.price * item.qty;
      const row = document.createElement("div");
      row.className = "ticket-line";
      row.innerHTML = `
        <span>${item.qty}× ${item.name}</span>
        <strong>${(item.price * item.qty).toLocaleString("fr-FR")} GNF</strong>
      `;
      ticketLinesEl.appendChild(row);
    });

    ticketTotalEl.textContent = `${total.toLocaleString("fr-FR")} GNF`;
  }

  // Ajout au clic sur les cartes produits de la caisse
  document.querySelectorAll(".pos-card-item").forEach((card) => {
    card.addEventListener("click", () => {
      playRegisterSound("tap");
      const title = card.querySelector(".p-title")?.textContent || "Article";
      const priceText = card.querySelector(".p-price-tag")?.textContent || "0";
      const price = parseInt(priceText.replace(/\D/g, ""), 10) || 100000;

      const existing = showcaseTicketItems.find((i) => i.name === title);
      if (existing) {
        existing.qty += 1;
      } else {
        showcaseTicketItems.push({ name: title, price, qty: 1 });
      }
      updateShowcaseTicketUI();
    });
  });

  // Bouton d'encaissement du showcase
  if (btnShowcaseCheckout) {
    btnShowcaseCheckout.addEventListener("click", () => {
      playRegisterSound("cash");
      const originalText = btnShowcaseCheckout.innerHTML;
      btnShowcaseCheckout.innerHTML = `<span>✓ Encaissé ! Ticket Imprimé</span>`;
      btnShowcaseCheckout.style.background = "#10B981";

      setTimeout(() => {
        btnShowcaseCheckout.innerHTML = originalText;
        btnShowcaseCheckout.style.background = "";
      }, 2500);
    });
  }

  // Sélection mode de paiement dans le showcase
  document.querySelectorAll(".pay-methods-row .pay-tag").forEach((tag) => {
    tag.addEventListener("click", () => {
      document.querySelectorAll(".pay-methods-row .pay-tag").forEach((t) => t.classList.remove("active"));
      tag.classList.add("active");
    });
  });

  // ── 7. VRAIE DÉMO VIDÉO : Synchronisation Intégrale Son & Voix-Off ──
  const video = document.getElementById("main-demo-video");
  const audio = document.getElementById("demo-voiceover-audio");
  const playOverlay = document.getElementById("video-play-overlay");
  const btnMasterPlay = document.getElementById("btn-master-play");
  const soundStatusText = document.getElementById("sound-status-text");
  const btnToggleMute = document.getElementById("btn-toggle-mute");
  const audioWave = document.getElementById("audio-wave");
  const chapterButtons = document.querySelectorAll(".video-chapter-btn");

  let isMuted = false;

  function syncAudioWithVideo() {
    if (!video || !audio) return;
    if (Math.abs(audio.currentTime - video.currentTime) > 0.25) {
      audio.currentTime = video.currentTime;
    }
  }

  function startPlaybackWithSound() {
    if (!video || !audio) return;

    video.muted = false;
    audio.muted = isMuted;
    audio.currentTime = video.currentTime;

    const p1 = video.play();
    const p2 = audio.play();

    Promise.all([p1, p2]).then(() => {
      playOverlay?.classList.add("is-hidden");
      audioWave?.classList.add("is-active");
      if (soundStatusText) {
        soundStatusText.innerHTML = "🔊 <strong>Son & Voix-off Active :</strong> Explications pas à pas en direct";
      }
    }).catch(() => {
      playOverlay?.classList.remove("is-hidden");
    });
  }

  if (btnMasterPlay) {
    btnMasterPlay.addEventListener("click", (e) => {
      e.stopPropagation();
      startPlaybackWithSound();
    });
  }

  if (playOverlay) {
    playOverlay.addEventListener("click", startPlaybackWithSound);
  }

  if (video && audio) {
    video.addEventListener("play", () => {
      playOverlay?.classList.add("is-hidden");
      audio.currentTime = video.currentTime;
      audioWave?.classList.add("is-active");
      if (!isMuted) audio.play().catch(() => {});
    });

    video.addEventListener("pause", () => {
      audio.pause();
      audioWave?.classList.remove("is-active");
    });

    video.addEventListener("seeking", () => {
      syncAudioWithVideo();
    });

    video.addEventListener("seeked", () => {
      syncAudioWithVideo();
      if (!video.paused && !isMuted) {
        audio.play().catch(() => {});
      }
    });

    video.addEventListener("timeupdate", () => {
      syncAudioWithVideo();
    });

    video.addEventListener("ended", () => {
      audio.pause();
      audio.currentTime = 0;
      audioWave?.classList.remove("is-active");
      playOverlay?.classList.remove("is-hidden");
    });
  }

  // Bouton Coupe-son / Réactivation Son
  if (btnToggleMute && audio) {
    btnToggleMute.addEventListener("click", () => {
      isMuted = !isMuted;
      audio.muted = isMuted;
      if (video) video.muted = isMuted;

      if (isMuted) {
        btnToggleMute.innerHTML = "<span>🔇 Activer le Son</span>";
        btnToggleMute.classList.add("muted");
        audioWave?.classList.remove("is-active");
        if (soundStatusText) soundStatusText.textContent = "🔇 Son coupé";
      } else {
        btnToggleMute.innerHTML = "<span>🔊 Couper le Son</span>";
        btnToggleMute.classList.remove("muted");
        if (video && !video.paused) {
          audioWave?.classList.add("is-active");
          audio.play().catch(() => {});
        }
        if (soundStatusText) soundStatusText.innerHTML = "🔊 <strong>Son & Voix-off Active :</strong> Explications en direct";
      }
    });
  }

  // Navigation par chapitres dans la démo
  chapterButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      chapterButtons.forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");

      const seekTime = parseFloat(btn.getAttribute("data-time") || "0");
      if (video) {
        video.currentTime = seekTime;
        if (audio) audio.currentTime = seekTime;
        startPlaybackWithSound();
      }
    });
  });

  // ── 9. Accordéon Interactif FAQ ─────────────────────────────────
  const faqItems = document.querySelectorAll(".faq-item");
  faqItems.forEach((item) => {
    const questionBtn = item.querySelector(".faq-question");
    const toggleIcon = item.querySelector(".faq-toggle-icon");
    if (!questionBtn) return;

    questionBtn.addEventListener("click", () => {
      const isOpen = item.classList.contains("is-open");

      // Fermer tous les autres accordéons pour une lecture propre
      faqItems.forEach((other) => {
        if (other !== item) {
          other.classList.remove("is-open");
          const otherBtn = other.querySelector(".faq-question");
          const otherIcon = other.querySelector(".faq-toggle-icon");
          if (otherBtn) otherBtn.setAttribute("aria-expanded", "false");
          if (otherIcon) otherIcon.textContent = "+";
        }
      });

      // Basculer l'élément courant
      if (isOpen) {
        item.classList.remove("is-open");
        questionBtn.setAttribute("aria-expanded", "false");
        if (toggleIcon) toggleIcon.textContent = "+";
      } else {
        item.classList.add("is-open");
        questionBtn.setAttribute("aria-expanded", "true");
        if (toggleIcon) toggleIcon.textContent = "−";
      }
    });
  });

  // ── 10. Bouton Retour en Haut (Back to Top) ─────────────────────
  const btnBackToTop = document.getElementById("btn-back-to-top");
  function checkBackToTop() {
    if (window.scrollY > 450) {
      btnBackToTop?.classList.add("is-visible");
    } else {
      btnBackToTop?.classList.remove("is-visible");
    }
  }
  window.addEventListener("scroll", checkBackToTop, { passive: true });
  checkBackToTop();

  btnBackToTop?.addEventListener("click", () => {
    window.scrollTo({
      top: 0,
      behavior: "smooth",
    });
  });

  // ── 11. Modal Toast de Téléchargement et Guide Rapide ───────────
  const dlModalBackdrop = document.getElementById("download-modal-backdrop");
  const btnCloseModal = document.getElementById("btn-close-modal");
  const btnDismissModal = document.getElementById("btn-modal-dismiss");

  function openDownloadModal() {
    dlModalBackdrop?.classList.add("is-open");
    document.body.classList.add("modal-open");
  }

  function closeDownloadModal() {
    dlModalBackdrop?.classList.remove("is-open");
    document.body.classList.remove("modal-open");
  }

  // Intercepter les clics sur les boutons de téléchargement pour ouvrir le modal
  document.querySelectorAll('a[data-action="download"]').forEach((link) => {
    link.addEventListener("click", () => {
      // Petite latence pour laisser le navigateur déclencher le téléchargement du fichier
      setTimeout(openDownloadModal, 400);
    });
  });

  btnCloseModal?.addEventListener("click", closeDownloadModal);
  btnDismissModal?.addEventListener("click", closeDownloadModal);
  dlModalBackdrop?.addEventListener("click", (e) => {
    if (e.target === dlModalBackdrop) closeDownloadModal();
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && dlModalBackdrop?.classList.contains("is-open")) {
      closeDownloadModal();
    }
  });

  // ── 12. ScrollSpy Navigation (Mise en surbrillance automatique) ──
  const sections = document.querySelectorAll("section[id]");
  const navHeaderLinks = document.querySelectorAll(".nav-links a");

  function updateScrollSpy() {
    const scrollPosition = window.scrollY + 140;
    sections.forEach((section) => {
      const sectionTop = section.offsetTop;
      const sectionHeight = section.offsetHeight;
      const sectionId = section.getAttribute("id");

      if (
        scrollPosition >= sectionTop &&
        scrollPosition < sectionTop + sectionHeight
      ) {
        navHeaderLinks.forEach((link) => {
          link.classList.remove("active");
          if (link.getAttribute("href") === `#${sectionId}`) {
            link.classList.add("active");
          }
        });
      }
    });
  }
  window.addEventListener("scroll", updateScrollSpy, { passive: true });
  updateScrollSpy();
});
