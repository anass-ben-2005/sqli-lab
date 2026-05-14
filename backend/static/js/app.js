/**
 * Library Management System - Client-side Enhancements
 * Features: Mobile nav, table search, table sort, collapsible panels, alerts
 */

document.addEventListener('DOMContentLoaded', function() {
  initMobileNav();
  initCollapsiblePanels();
  initAlertDismiss();
});

/* ============================================
   Mobile Navigation
   ============================================ */
function initMobileNav() {
  const toggle = document.getElementById('mobile-menu-toggle');
  const mobileNav = document.getElementById('mobile-nav');

  if (!toggle || !mobileNav) return;

  toggle.addEventListener('click', function() {
    mobileNav.classList.toggle('open');
    const isOpen = mobileNav.classList.contains('open');
    toggle.setAttribute('aria-expanded', isOpen);
  });

  // Close on outside click
  document.addEventListener('click', function(e) {
    if (!toggle.contains(e.target) && !mobileNav.contains(e.target)) {
      mobileNav.classList.remove('open');
      toggle.setAttribute('aria-expanded', 'false');
    }
  });
}


/* ============================================
   Collapsible Panels
   ============================================ */
function initCollapsiblePanels() {
  const toggles = document.querySelectorAll('[data-collapsible-toggle]');

  toggles.forEach(function(toggle) {
    toggle.addEventListener('click', function() {
      const targetId = toggle.getAttribute('data-collapsible-toggle');
      const target = document.getElementById(targetId);
      if (!target) return;

      const isCollapsed = target.classList.toggle('collapsed');

      // Update toggle icon if present
      const icon = toggle.querySelector('.toggle-icon');
      if (icon) {
        icon.style.transform = isCollapsed ? 'rotate(-90deg)' : 'rotate(0deg)';
      }

      toggle.setAttribute('aria-expanded', !isCollapsed);
    });
  });
}

/* ============================================
   Alert Dismiss
   ============================================ */
function initAlertDismiss() {
  const alerts = document.querySelectorAll('.alert');

  alerts.forEach(function(alert) {
    // Auto-dismiss after 5 seconds
    setTimeout(function() {
      alert.style.opacity = '0';
      alert.style.transform = 'translateY(-8px)';
      alert.style.transition = 'opacity 0.3s ease, transform 0.3s ease';

      setTimeout(function() {
        alert.remove();
      }, 300);
    }, 5000);
  });
}
