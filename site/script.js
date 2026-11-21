const views = {
  mosaico: { title: 'Cada carpeta tiene su lugar.', description: 'El mosaico convierte los tamaños en bloques: cuanto más ocupa una carpeta, más espacio verás.', image: 'assets/mosaico.png', alt: 'Vista de mosaico con carpetas de ejemplo.' },
  radial: { title: 'Dale una vuelta al espacio.', description: 'El gráfico radial organiza las carpetas en anillos para que sigas cada nivel de un vistazo.', image: 'assets/radial.png', alt: 'Vista radial con carpetas de ejemplo.' }
};
document.querySelectorAll('[data-view]').forEach((button) => button.addEventListener('click', () => {
  const view = views[button.dataset.view];
  document.querySelectorAll('[data-view]').forEach((item) => { const active = item === button; item.classList.toggle('is-active', active); item.setAttribute('aria-pressed', String(active)); });
  document.getElementById('view-title').textContent = view.title;
  document.getElementById('view-description').textContent = view.description;
  const image = document.getElementById('view-image'); image.src = view.image; image.alt = view.alt;
}));
