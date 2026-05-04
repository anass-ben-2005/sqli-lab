/**
 * Library Management System - Client-side Enhancements
 * Features: Mobile nav, table search, table sort, collapsible panels, alerts
 */

document.addEventListener('DOMContentLoaded', function() {
  initMobileNav();
  initTableSearch();
  initTableSort();
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
   Table Search
   ============================================ */
function initTableSearch() {
  const searchInputs = document.querySelectorAll('[data-table-search]');

  searchInputs.forEach(function(input) {
    const tableId = input.getAttribute('data-table-search');
    const table = document.getElementById(tableId);
    if (!table) return;

    const rows = table.querySelectorAll('tbody tr');

    input.addEventListener('input', function() {
      const query = this.value.toLowerCase().trim();

      rows.forEach(function(row) {
        const text = row.textContent.toLowerCase();
        row.style.display = text.includes(query) ? '' : 'none';
      });
    });
  });
}

/* ============================================
   Table Sort
   ============================================ */
function initTableSort() {
  const headers = document.querySelectorAll('[data-sort]');

  headers.forEach(function(header) {
    header.addEventListener('click', function() {
      const table = header.closest('table');
      if (!table) return;

      const tbody = table.querySelector('tbody');
      const rows = Array.from(tbody.querySelectorAll('tr'));
      const colIndex = parseInt(header.getAttribute('data-sort'), 10);
      const sortType = header.getAttribute('data-sort-type') || 'string';

      // Toggle direction
      const currentDir = header.getAttribute('data-sort-dir') || 'asc';
      const newDir = currentDir === 'asc' ? 'desc' : 'asc';

      // Reset other headers
      table.querySelectorAll('[data-sort]').forEach(function(h) {
        h.removeAttribute('data-sort-dir');
        h.classList.remove('sorted');
      });

      header.setAttribute('data-sort-dir', newDir);
      header.classList.add('sorted');

      // Sort rows
      rows.sort(function(a, b) {
        let aVal = a.children[colIndex]?.textContent.trim() || '';
        let bVal = b.children[colIndex]?.textContent.trim() || '';

        if (sortType === 'number') {
          aVal = parseFloat(aVal) || 0;
          bVal = parseFloat(bVal) || 0;
        }

        if (aVal < bVal) return newDir === 'asc' ? -1 : 1;
        if (aVal > bVal) return newDir === 'asc' ? 1 : -1;
        return 0;
      });

      // Re-append in new order
      rows.forEach(function(row) {
        tbody.appendChild(row);
      });
    });
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
