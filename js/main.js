// mobile nav
  const navToggle = document.getElementById('navToggle');
  const nav = document.getElementById('nav');
  navToggle.addEventListener('click', () => nav.classList.toggle('open'));
  nav.querySelectorAll('.nav-links a').forEach(a => a.addEventListener('click', () => nav.classList.remove('open')));

  // region toggle — drives pricing, rank card, and "what we test" visibility everywhere on the page
  function setRegion(region){
    document.body.dataset.region = region;
    document.querySelectorAll('.region-tab').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.regionTab === region);
    });
    document.querySelectorAll('.amount[data-india]').forEach(el => {
      el.textContent = region === 'india' ? el.dataset.india : el.dataset.intl;
    });
  }

  // scroll reveal
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => { if(e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { threshold: 0.12 });
  document.querySelectorAll('.reveal').forEach(el => io.observe(el));