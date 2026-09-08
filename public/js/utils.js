/**
 * ==============================================================================
 * Bánk's Repository - Globális Kliensoldali Segédfüggvények (utils.js)
 * ==============================================================================
 * Központi biztonsági és formázási függvények modulok és nézetek számára.
 * ==============================================================================
 */

window.BankUtils = (function () {
  'use strict';

  /**
   * HTML entitások biztonságos maszkolása (XSS megelőzés)
   * @param {string} str - A maszkolandó nyers bemenet
   * @returns {string} - Biztonságosan kiírható HTML szöveg
   */
  function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  /**
   * Időbélyeg felhasználóbarát formázása (HH:MM vagy YYYY-MM-DD HH:MM)
   * @param {string|Date} dateInput
   * @returns {string}
   */
  function formatTime(dateInput) {
    if (!dateInput) return '';
    var d = new Date(dateInput);
    if (isNaN(d.getTime())) return String(dateInput);
    var hours = String(d.getHours()).padStart(2, '0');
    var minutes = String(d.getMinutes()).padStart(2, '0');
    return hours + ':' + minutes;
  }

  /**
   * Debounce függvény gyors egymásutáni események (pl. gépelés) késleltetésére
   * @param {Function} fn - A futtatandó függvény
   * @param {number} delay - Várakozási idő milliszekundumban
   * @returns {Function}
   */
  function debounce(fn, delay) {
    var timer = null;
    return function () {
      var context = this;
      var args = arguments;
      clearTimeout(timer);
      timer = setTimeout(function () {
        fn.apply(context, args);
      }, delay || 200);
    };
  }

  /**
   * Biztonságos JSON parszolás kivételmentesen
   * @param {string} jsonString
   * @param {*} fallback
   * @returns {*}
   */
  function safeJsonParse(jsonString, fallback) {
    try {
      return JSON.parse(jsonString);
    } catch (e) {
      return fallback !== undefined ? fallback : null;
    }
  }

  // Globális export
  return {
    escapeHtml: escapeHtml,
    formatTime: formatTime,
    debounce: debounce,
    safeJsonParse: safeJsonParse
  };
})();

// Visszafelé kompatibilis globális alias a meglévő ERB sablonokhoz
window.escapeHtml = window.escapeHtml || window.BankUtils.escapeHtml;
window.formatTime = window.formatTime || window.BankUtils.formatTime;

