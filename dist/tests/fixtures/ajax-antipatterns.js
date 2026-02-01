/**
 * Test Fixture: AJAX polling antipatterns
 *
 * Intentional misuse of setInterval + AJAX to trigger detection.
 */

// 🚨 ANTIPATTERN: setInterval with fetch (no backoff/rate limit)
setInterval(() => {
  fetch('/wp-json/toolkit/v1/status')
    .then((res) => res.json())
    .then((data) => console.log(data));
}, 1000);

// 🚨 ANTIPATTERN: setInterval with jQuery.ajax
setInterval(function () {
  jQuery.ajax({
    url: window.ajaxurl,
    data: { action: 'ping_server' },
  });
}, 2000);

// SAFE: Debounced handler (should NOT trigger polling rule)
const refresh = () => {
  window.clearTimeout(window.nptDebounce);
  window.nptDebounce = window.setTimeout(() => {
    fetch('/wp-json/toolkit/v1/safe-refresh');
  }, 500);
};

document.addEventListener('keyup', refresh);
