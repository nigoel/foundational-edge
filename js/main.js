// mobile nav
  const navToggle = document.getElementById('navToggle');
  const nav = document.getElementById('nav');
  navToggle.addEventListener('click', () => nav.classList.toggle('open'));
  nav.querySelectorAll('.nav-links a').forEach(a => a.addEventListener('click', () => nav.classList.remove('open')));

  // pricing region toggle
  function setRegion(region){
    document.getElementById('tab-india').classList.toggle('active', region === 'india');
    document.getElementById('tab-intl').classList.toggle('active', region === 'intl');
    document.querySelectorAll('.amount[data-india]').forEach(el => {
      el.textContent = region === 'india' ? el.dataset.india : el.dataset.intl;
    });
  }

  // scroll reveal
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => { if(e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { threshold: 0.12 });
  document.querySelectorAll('.reveal').forEach(el => io.observe(el));