// Night Watch is the chosen launch direction. Explicit cream preserves the archive.
(() => {
  const name = new URLSearchParams(location.search).get('treatment');
  if (name !== 'cream') {
    document.documentElement.dataset.treatment = ['survey', 'night', 'woodcut'].includes(name) ? name : 'night';
  }
})();
