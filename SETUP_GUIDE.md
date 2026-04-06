# 🚀 MyCareerJob.in — Complete Setup & Deployment Guide

## Architecture
```
GitHub Pages (Static Files)
        ↕  (Supabase JS Client — Real-time WebSocket)
Supabase (PostgreSQL + Auth + Realtime + Row Level Security)
        ↕
Hostinger DNS → mycareerjob.in domain
```

---

## 📁 Project File Structure
```
mycareerjob.in/
├── index.html          ← Homepage (reads from Supabase, realtime)
├── jobs.html           ← All jobs listing (filter, search, sort)
├── job.html            ← Single job detail (?slug=job-slug)
├── marathi.html        ← मराठी language page
├── contact.html        ← Contact page
├── privacy.html        ← Privacy policy
├── 404.html            ← Custom 404 page
│
├── css/
│   └── style.css       ← All frontend styles
│
├── js/
│   └── supabase.js     ← ⚠️ UPDATE WITH YOUR KEYS — Supabase client
│
├── admin/
│   ├── login.html      ← Admin login (Supabase Auth)
│   ├── index.html      ← Dashboard (realtime stats)
│   ├── jobs.html       ← Job management (CRUD)
│   ├── add-job.html    ← Add/Edit job form
│   ├── subscribers.html← Email subscribers
│   ├── settings.html   ← Site settings
│   ├── css/admin.css   ← Admin panel styles
│   └── js/core.js      ← Shared admin JS
│
├── supabase_setup.sql  ← Run this in Supabase SQL Editor
├── .github/workflows/
│   └── deploy.yml      ← Auto-deploy to GitHub Pages
└── SETUP_GUIDE.md      ← This file
```

---

## STEP 1 — SUPABASE SETUP (15 minutes)

### 1.1 Create Project
1. Go to **https://supabase.com** → Sign Up
2. Click **New Project**
3. Settings:
   - Name: `mycareerjob-in`
   - Password: (save this!)
   - Region: **ap-south-1 (Asia Pacific - Mumbai)** ← Best for India
4. Wait 2-3 minutes for project to initialize

### 1.2 Get API Keys
1. Go to **Settings → API**
2. Copy these two values:
   ```
   Project URL:   https://XXXXXXXX.supabase.co
   anon / public: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

### 1.3 Run Database SQL
1. Go to **SQL Editor** → New Query
2. Open `supabase_setup.sql` from this project
3. **Copy ALL content** → Paste → Click **Run**
4. You should see a table showing jobs count = 10 ✅

### 1.4 Create Admin User
1. Go to **Authentication → Users** → **Add User**
2. Enter your email & password
3. Toggle **"Auto Confirm User"** → ON
4. Click **Create** — Copy the UUID shown (looks like: `abc123-def456-...`)
5. Go to **SQL Editor** → New Query → Run:
```sql
INSERT INTO admin_profiles (id, email, full_name, role, is_active)
VALUES (
  'PASTE-YOUR-UUID-HERE',
  'your-email@gmail.com',
  'Your Name',
  'superadmin',
  true
);
```

### 1.5 Enable Realtime
1. Go to **Database → Replication**
2. Click **0 tables** button
3. Toggle ON the `jobs` table
4. Click **Save**

---

## STEP 2 — UPDATE SUPABASE KEYS IN PROJECT

Open `js/supabase.js` and replace:
```javascript
// Line 8 — replace with your actual Project URL
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';

// Line 9 — replace with your anon/public key
const SUPABASE_KEY = 'YOUR_ANON_PUBLIC_KEY';
```

**Also update the path in admin pages** — in all admin HTML files, the script tag loads:
```html
<script src="../js/supabase.js"></script>
```
This path is correct — no changes needed in admin pages.

---

## STEP 3 — GITHUB SETUP (10 minutes)

### 3.1 Create Repository
1. Go to **https://github.com** → New Repository
2. Name: `mycareerjob.in` (or `mycareerjob`)
3. Visibility: **Public** (required for free GitHub Pages)
4. Don't add README (we have files)
5. Create Repository

### 3.2 Push Code
Open terminal in your project folder:
```bash
git init
git add .
git commit -m "🚀 MyCareerJob.in - Initial Deploy"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/mycareerjob.in.git
git push -u origin main
```

### 3.3 Enable GitHub Pages
1. GitHub repo → **Settings → Pages**
2. Source: **Deploy from branch**
3. Branch: **main** → Folder: **/ (root)**
4. Save → Wait 3-5 minutes
5. Site live at: `https://YOUR_USERNAME.github.io/mycareerjob.in`

---

## STEP 4 — HOSTINGER DOMAIN SETUP (10 minutes)

### 4.1 Get to DNS Settings
1. Login to **hpanel.hostinger.com**
2. Domains → Click your domain → **Manage**
3. Click **DNS / Nameservers** → **DNS Records**

### 4.2 Add These DNS Records
Delete any existing A records pointing to Hostinger, then add:

| Type  | Name | Value                | TTL  |
|-------|------|----------------------|------|
| A     | @    | 185.199.108.153      | 3600 |
| A     | @    | 185.199.109.153      | 3600 |
| A     | @    | 185.199.110.153      | 3600 |
| A     | @    | 185.199.111.153      | 3600 |
| CNAME | www  | YOUR_USERNAME.github.io | 3600 |

### 4.3 Add Custom Domain in GitHub
1. GitHub repo → **Settings → Pages**
2. Custom domain: `mycareerjob.in`
3. Save → DNS check will start
4. After 24-48 hrs DNS propagates → Check **Enforce HTTPS**

### 4.4 Create CNAME File in Repo
Create a file named `CNAME` (no extension) in root with just:
```
mycareerjob.in
```
```bash
echo "mycareerjob.in" > CNAME
git add CNAME
git commit -m "Add CNAME for custom domain"
git push
```

---

## STEP 5 — SUPABASE CORS CONFIG

1. Go to Supabase → **Settings → API**
2. Scroll to **"CORS allowed origins"**
3. Add:
   ```
   https://mycareerjob.in
   https://www.mycareerjob.in
   https://YOUR_USERNAME.github.io
   http://localhost:3000
   http://127.0.0.1:5500
   ```
4. Save

---

## STEP 6 — VERIFY EVERYTHING WORKS

### Test Checklist:
- [ ] `https://mycareerjob.in` → Homepage shows 10 sample jobs
- [ ] Clicking any job → Opens `job.html?slug=...` with full details
- [ ] `https://mycareerjob.in/jobs.html` → All jobs with search/filter
- [ ] `https://mycareerjob.in/marathi.html` → Marathi page loads
- [ ] `https://mycareerjob.in/admin/login.html` → Login page loads
- [ ] Login with your email/password → Dashboard opens
- [ ] Add a new job → Appears on homepage **instantly** (realtime!)
- [ ] Delete a job → Disappears from homepage **instantly** (realtime!)
- [ ] `https://mycareerjob.in/contact.html` → Contact page (no 404)
- [ ] `https://mycareerjob.in/privacy.html` → Privacy page (no 404)
- [ ] Invalid URL → Shows 404 page

---

## HOW REALTIME WORKS

```
Admin adds job → Supabase INSERT event
                      ↓
            Supabase sends WebSocket event
                      ↓
    All open browsers receive the event automatically
                      ↓
        Homepage adds new job card at the top
        Ticker updates with new job title
        Stats counter updates
```

**No page refresh needed — it's truly live!**

---

## ADDING A NEW ADMIN USER

1. Supabase → **Authentication → Users → Add User**
2. Enter email, set password, auto-confirm ON
3. Copy the UUID
4. Run SQL:
```sql
INSERT INTO admin_profiles (id, email, full_name, role, is_active)
VALUES ('NEW-UUID', 'editor@email.com', 'Editor Name', 'admin', true);
```
Done! They can now login at `/admin/login.html`

---

## TROUBLESHOOTING

### Jobs not showing on homepage
→ Check browser console (F12) for errors
→ Verify SUPABASE_URL and SUPABASE_KEY in `js/supabase.js`
→ Check RLS policies are applied (re-run SQL setup)

### Can't login to admin
→ Verify admin_profiles row exists with is_active = true
→ Check email matches exactly what's in Supabase Auth
→ Try password reset via Supabase → Authentication → Users → Send recovery email

### Realtime not working
→ Check Database → Replication → jobs table is toggled ON
→ Check browser console for WebSocket connection errors

### 404 on custom domain
→ CNAME file exists in repo root with just `mycareerjob.in`
→ DNS records correctly added (takes 24-48 hrs to propagate)
→ GitHub Pages custom domain is set in Settings

### CORS error in browser
→ Add your domain to Supabase allowed CORS origins
→ Include both https:// and http:// versions during development

---

## COST SUMMARY (Free Tier)

| Service | Plan | Monthly Cost |
|---------|------|-------------|
| GitHub Pages | Free | ₹0 |
| Supabase | Free tier | ₹0 |
| Hostinger .in domain | Basic | ~₹65/month |
| **Total** | | **~₹65/month** |

**Supabase Free Tier Includes:**
- 500MB database storage
- 1GB file storage  
- 50,000 monthly active users
- 2GB bandwidth
- Unlimited API calls
- Realtime subscriptions

*Fully sufficient for a job portal!*

---

## QUICK COMMANDS REFERENCE

```bash
# Push code changes
git add . && git commit -m "Update" && git push

# Check GitHub Pages deployment
# Go to: GitHub repo → Actions tab → See deployment status

# Check Supabase connection
# Open browser console on your site, type:
# const {data} = await sb.from('jobs').select('count')
# console.log(data)
```

---

*Built with ❤️ for Maharashtra Job Seekers*
*Stack: HTML + CSS + Vanilla JS + Supabase + GitHub Pages*
