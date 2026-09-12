// mobile nav
  const navToggle = document.getElementById('navToggle');
  const nav = document.getElementById('nav');
  navToggle.addEventListener('click', () => nav.classList.toggle('open'));
  nav.querySelectorAll('.nav-links a').forEach(a => a.addEventListener('click', () => nav.classList.remove('open')));

  // Logged-in nav state: practice-test.html and workspace.html both write
  // { regId, childName } to localStorage['fe_student'] once a student is
  // identified. Any page that includes this script swaps the "Login" button
  // for the child's name (linking straight to their workspace) plus a
  // logout option, without needing a server round trip just to know
  // whether someone's logged in.
  function syncAuthNav(){
    let student = null;
    try { student = JSON.parse(localStorage.getItem('fe_student') || 'null'); } catch (e) { student = null; }

    const loggedIn = !!(student && student.regId);
    document.querySelectorAll('.js-login-link').forEach(el => { el.hidden = loggedIn; });
    document.querySelectorAll('.js-user-link').forEach(el => { el.hidden = !loggedIn; });
    if (loggedIn) {
      document.querySelectorAll('.js-user-name').forEach(el => {
        el.textContent = student.childName || 'My workspace';
        el.setAttribute('href', 'workspace.html?regId=' + encodeURIComponent(student.regId));
      });
    }
  }
  syncAuthNav();

  document.querySelectorAll('.js-logout-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      try { localStorage.removeItem('fe_student'); } catch (e) { /* ignore */ }
      // Don't rely solely on the navigation below to reset the nav's look —
      // if we're already on index.html, going to index.html#top is just a
      // hash change, not a full reload, so the DOM wouldn't otherwise update.
      syncAuthNav();
      window.location.href = 'index.html#top';
    });
  });

  // If this page is restored from the back/forward cache (e.g. the student
  // hit the browser's back button after logging out elsewhere), re-check
  // localStorage rather than trusting whatever nav state was frozen into
  // the cached page — otherwise a logged-out visitor could briefly see
  // their old "logged in" nav flash back up.
  window.addEventListener('pageshow', (event) => {
    if (event.persisted) syncAuthNav();
  });

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