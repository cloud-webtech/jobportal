// ================================================================
// Admin Core JS — shared across all admin pages
// ================================================================

let _adminProfile = null;

/* ── Auth Guard ─────────────────────────────────────────── */
async function requireAuth() {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) { location.href = 'login.html'; return null; }

  const { data: profile } = await sb
    .from('admin_profiles')
    .select('*')
    .eq('id', session.user.id)
    .single();

  if (!profile || !profile.is_active) {
    await sb.auth.signOut();
    location.href = 'login.html';
    return null;
  }

  _adminProfile = profile;
  const name = profile.full_name || session.user.email.split('@')[0];

  // Update UI
  document.querySelectorAll('[data-admin-name]').forEach(el => el.textContent = name);
  document.querySelectorAll('[data-admin-role]').forEach(el => el.textContent = profile.role);
  document.querySelectorAll('[data-admin-letter]').forEach(el => el.textContent = name[0].toUpperCase());

  // Update last login
  await sb.from('admin_profiles').update({ last_login: new Date().toISOString() }).eq('id', session.user.id);

  return profile;
}

async function adminLogout() {
  if (!confirm('Logout from admin panel?')) return;
  await sb.auth.signOut();
  location.href = 'login.html';
}

/* ── Shell Setup ─────────────────────────────────────────── */
function initShell() {
  // Clock
  const tick = () => {
    const el = document.getElementById('clock');
    if (el) el.textContent = new Date().toLocaleTimeString('en-IN', { hour:'2-digit', minute:'2-digit', second:'2-digit' });
  };
  tick(); setInterval(tick, 1000);

  // Greeting
  const h = new Date().getHours();
  document.querySelectorAll('[data-greeting]').forEach(el => {
    el.textContent = h < 12 ? 'morning' : h < 17 ? 'afternoon' : 'evening';
  });

  // Resize
  window.addEventListener('resize', () => {
    if (window.innerWidth > 900) document.getElementById('sidebar')?.classList.remove('mob-open');
  });
}

function toggleSidebar() {
  const sb2 = document.getElementById('sidebar');
  const main = document.getElementById('mainArea');
  if (window.innerWidth <= 900) {
    sb2?.classList.toggle('mob-open');
  } else {
    sb2?.classList.toggle('hide');
    main?.classList.toggle('full');
  }
}

/* ── Toast ─────────────────────────────────────────────── */
function aToast(msg, type = '') {
  const c = document.getElementById('toastContainer');
  if (!c) return;
  const t = document.createElement('div');
  t.className = `toast-item ${type === 'success' ? 'ok' : type === 'error' ? 'er' : type === 'info' ? 'in' : ''}`;
  t.textContent = msg;
  c.appendChild(t);
  setTimeout(() => { t.style.animation='none'; t.style.opacity='0'; t.style.transition='opacity .3s'; setTimeout(()=>t.remove(),300); }, 3200);
}

/* ── Counter anim ──────────────────────────────────────── */
function animNum(id, target) {
  const el = document.getElementById(id);
  if (!el) return;
  let n = 0;
  const step = Math.max(1, Math.ceil(target / 50));
  const t = setInterval(() => {
    n = Math.min(n + step, target);
    el.textContent = n >= 1000 ? (n/1000).toFixed(1)+'K' : n;
    if (n >= target) clearInterval(t);
  }, 25);
}

/* ── Helpers ───────────────────────────────────────────── */
function h(s=''){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
function fmtDate(d){if(!d)return'—';return new Date(d).toLocaleDateString('en-IN',{day:'numeric',month:'short',year:'numeric'});}
function relTime(d){if(!d)return'';const s=(Date.now()-new Date(d))/1000;if(s<60)return'just now';if(s<3600)return Math.floor(s/60)+'m ago';if(s<86400)return Math.floor(s/3600)+'h ago';return new Date(d).toLocaleDateString('en-IN',{day:'numeric',month:'short'});}
function slugify(t=''){return t.toLowerCase().replace(/[^a-z0-9\s-]/g,'').replace(/\s+/g,'-').replace(/-+/g,'-').trim().slice(0,80);}
function debounce(fn,ms){let t;return(...a)=>{clearTimeout(t);t=setTimeout(()=>fn(...a),ms);};}

/* ── Status pill ───────────────────────────────────────── */
function statusPill(s) {
  const map = { published:'sp-pub', draft:'sp-draft', expired:'sp-exp', featured:'sp-feat' };
  return `<span class="spl ${map[s]||'sp-draft'}">${s}</span>`;
}

/* ── Cat pill ───────────────────────────────────────────── */
const CAT_COLORS = {Govt:'#2ECC71',IT:'#3498DB',Private:'#9B59B6',Bank:'#F39C12',Railway:'#E74C3C',Defence:'#1ABC9C',Health:'#E91E63',Police:'#5D4E8A',Education:'#FF9800'};
function catPill(cat) {
  const c = CAT_COLORS[cat]||'#FF6B00';
  return `<span class="cp" style="background:${c}20;color:${c}">${cat}</span>`;
}

/* ── Sidebar active link ─────────────────────────────────── */
function setActive(id) {
  document.querySelectorAll('.sb-link').forEach(a => a.classList.remove('on'));
  document.getElementById(id)?.classList.add('on');
}
