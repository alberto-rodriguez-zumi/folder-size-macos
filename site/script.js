const views = {
  mosaico: { title: 'Every folder in its place.', description: 'The treemap turns sizes into blocks: the more space a folder uses, the larger it appears.', image: 'assets/mosaico.png', alt: 'Treemap view with sample folders.' },
  radial: { title: 'See your space from another angle.', description: 'The radial chart arranges folders in rings so you can follow each level at a glance.', image: 'assets/radial.png', alt: 'Radial view with sample folders.' }
};
document.querySelectorAll('[data-view]').forEach((button) => button.addEventListener('click', () => {
  const view = views[button.dataset.view];
  document.querySelectorAll('[data-view]').forEach((item) => { const active = item === button; item.classList.toggle('is-active', active); item.setAttribute('aria-pressed', String(active)); });
  document.getElementById('view-title').textContent = view.title;
  document.getElementById('view-description').textContent = view.description;
  const image = document.getElementById('view-image'); image.src = view.image; image.alt = view.alt;
}));
