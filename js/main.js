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
    document.querySelectorAll('.amount[data-india], .amount-strike[data-india]').forEach(el => {
      el.textContent = region === 'india' ? el.dataset.india : el.dataset.intl;
    });
  }

  // grade band toggle — "What we test" switches between K-5 (Verbal/Quantitative/Logical
  // Reasoning, matching CogAT/NNAT-style screening) and 6-8 (subject domains like Algebra and
  // Geometry, matching how AMC 8/MATHCOUNTS/state curricula actually organize middle-school math).
  window.setGradeBand = function setGradeBand(band){
    document.getElementById('tab-early').classList.toggle('active', band === 'early');
    document.getElementById('tab-middle').classList.toggle('active', band === 'middle');
    document.getElementById('band-early').style.display = band === 'early' ? '' : 'none';
    document.getElementById('band-middle').style.display = band === 'middle' ? '' : 'none';
  };

  // scroll reveal
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => { if(e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { threshold: 0.12 });
  document.querySelectorAll('.reveal').forEach(el => io.observe(el));

  // rank card sample: randomize which of the two dummy certificates shows first
  const rankScroll = document.getElementById('rankcardScroll');
  if(rankScroll && Math.random() < 0.5){
    const cards = [...rankScroll.children];
    cards.reverse().forEach(c => rankScroll.appendChild(c));
  }