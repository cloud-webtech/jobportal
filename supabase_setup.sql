-- ================================================================
-- MyCareerJob.in — COMPLETE SUPABASE DATABASE SETUP
-- ================================================================
-- HOW TO RUN:
-- 1. Go to https://supabase.com → Your Project
-- 2. Click "SQL Editor" in left sidebar
-- 3. Click "New Query"
-- 4. Copy ALL this text and paste it
-- 5. Click "Run" (green button)
-- ================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- TABLE 1: admin_profiles
-- Stores admin user details (linked to Supabase Auth)
-- ================================================================
CREATE TABLE IF NOT EXISTS admin_profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  full_name   TEXT DEFAULT 'Admin',
  role        TEXT DEFAULT 'admin',
  is_active   BOOLEAN DEFAULT true,
  last_login  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 2: jobs
-- Main jobs table - all job listings stored here
-- ================================================================
CREATE TABLE IF NOT EXISTS jobs (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug             TEXT UNIQUE NOT NULL,
  title            TEXT NOT NULL,
  description      TEXT,
  full_description TEXT,
  organization     TEXT,
  category         TEXT DEFAULT 'Govt',
  location         TEXT DEFAULT 'Maharashtra',
  salary           TEXT,
  vacancies        TEXT,
  qualification    TEXT,
  experience       TEXT,
  age_limit        TEXT,
  apply_link       TEXT,
  last_date        TEXT,
  exam_date        TEXT,
  tags             TEXT[] DEFAULT '{}',
  status           TEXT DEFAULT 'published',
  priority         TEXT DEFAULT 'normal',
  is_featured      BOOLEAN DEFAULT false,
  views            INTEGER DEFAULT 0,
  source           TEXT,
  created_by       UUID REFERENCES admin_profiles(id),
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 3: subscribers
-- Email subscribers for job alerts
-- ================================================================
CREATE TABLE IF NOT EXISTS subscribers (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         TEXT UNIQUE NOT NULL,
  name          TEXT,
  category_pref TEXT DEFAULT 'all',
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- TABLE 4: site_settings
-- Key-value store for site configuration
-- ================================================================
CREATE TABLE IF NOT EXISTS site_settings (
  key         TEXT PRIMARY KEY,
  value       TEXT,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default settings
INSERT INTO site_settings (key, value) VALUES
  ('site_name',    'MyCareerJob.in'),
  ('site_tagline', 'Maharashtra No.1 Job Portal'),
  ('site_url',     'https://mycareerjob.in'),
  ('ga_id',        ''),
  ('adsense_id',   '')
ON CONFLICT (key) DO NOTHING;

-- ================================================================
-- INDEXES for fast queries
-- ================================================================
CREATE INDEX IF NOT EXISTS idx_jobs_status     ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_category   ON jobs(category);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_is_featured ON jobs(is_featured);
CREATE INDEX IF NOT EXISTS idx_jobs_slug       ON jobs(slug);

-- ================================================================
-- AUTO-UPDATE updated_at trigger
-- ================================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS jobs_updated_at ON jobs;
CREATE TRIGGER jobs_updated_at
  BEFORE UPDATE ON jobs
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ================================================================
-- INCREMENT VIEWS function (called from frontend)
-- ================================================================
CREATE OR REPLACE FUNCTION increment_views(job_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE jobs SET views = views + 1 WHERE id = job_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- DASHBOARD STATS function (called from admin)
-- ================================================================
CREATE OR REPLACE FUNCTION get_stats()
RETURNS JSON AS $$
DECLARE result JSON;
BEGIN
  SELECT json_build_object(
    'total',      (SELECT COUNT(*) FROM jobs),
    'published',  (SELECT COUNT(*) FROM jobs WHERE status = 'published'),
    'featured',   (SELECT COUNT(*) FROM jobs WHERE status = 'featured' OR is_featured = true),
    'draft',      (SELECT COUNT(*) FROM jobs WHERE status = 'draft'),
    'expired',    (SELECT COUNT(*) FROM jobs WHERE status = 'expired'),
    'views',      (SELECT COALESCE(SUM(views), 0) FROM jobs),
    'subscribers',(SELECT COUNT(*) FROM subscribers WHERE is_active = true),
    'this_week',  (SELECT COUNT(*) FROM jobs WHERE created_at > NOW() - INTERVAL '7 days'),
    'by_category',(
      SELECT json_object_agg(category, cnt)
      FROM (
        SELECT category, COUNT(*) as cnt 
        FROM jobs 
        WHERE status IN ('published','featured')
        GROUP BY category
      ) t
    )
  ) INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- ROW LEVEL SECURITY (RLS)
-- ================================================================
ALTER TABLE jobs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscribers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_settings  ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "public_read_jobs"        ON jobs;
DROP POLICY IF EXISTS "admin_all_jobs"          ON jobs;
DROP POLICY IF EXISTS "public_read_settings"    ON site_settings;
DROP POLICY IF EXISTS "admin_all_settings"      ON site_settings;
DROP POLICY IF EXISTS "anyone_subscribe"        ON subscribers;
DROP POLICY IF EXISTS "admin_read_subscribers"  ON subscribers;
DROP POLICY IF EXISTS "admin_read_own_profile"  ON admin_profiles;
DROP POLICY IF EXISTS "admin_update_own_profile" ON admin_profiles;

-- JOBS: Public can read published/featured jobs
CREATE POLICY "public_read_jobs" ON jobs
  FOR SELECT TO anon, authenticated
  USING (status IN ('published', 'featured'));

-- JOBS: Admins can do everything
CREATE POLICY "admin_all_jobs" ON jobs
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE id = auth.uid() AND is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE id = auth.uid() AND is_active = true
    )
  );

-- SETTINGS: Public can read
CREATE POLICY "public_read_settings" ON site_settings
  FOR SELECT TO anon, authenticated
  USING (true);

-- SETTINGS: Admins can update
CREATE POLICY "admin_all_settings" ON site_settings
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE id = auth.uid() AND is_active = true
    )
  );

-- SUBSCRIBERS: Anyone can subscribe
CREATE POLICY "anyone_subscribe" ON subscribers
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

-- SUBSCRIBERS: Admins can read/manage
CREATE POLICY "admin_read_subscribers" ON subscribers
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE id = auth.uid() AND is_active = true
    )
  );

-- ADMIN PROFILES: Admin can read/update own
CREATE POLICY "admin_read_own_profile" ON admin_profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY "admin_update_own_profile" ON admin_profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid());

-- ================================================================
-- ENABLE REALTIME for jobs table
-- ================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE jobs;

-- ================================================================
-- SAMPLE DATA — 10 real Maharashtra jobs
-- ================================================================
INSERT INTO jobs (slug, title, description, full_description, organization, category, location, salary, vacancies, qualification, experience, age_limit, apply_link, last_date, tags, status, priority, is_featured, source) VALUES

('mpsc-state-service-pre-2025',
 'MPSC State Service Pre Examination 2025',
 'Maharashtra Public Service Commission invites applications for State Service Preliminary Examination 2025. Total 400+ vacancies for Group A & B state service posts.',
 '<h3>Post Details</h3><p>MPSC is conducting State Service Pre Exam 2025 for Group A & B posts across Maharashtra.</p><h3>Total Vacancies</h3><ul><li>Group A: 250 posts</li><li>Group B: 180 posts</li></ul><h3>Eligibility</h3><ul><li><strong>Education:</strong> Bachelor Degree from recognized university</li><li><strong>Age:</strong> 19 to 38 years</li><li><strong>Nationality:</strong> Indian</li></ul><h3>Important Dates</h3><ul><li>Application Start: 1 January 2025</li><li>Last Date: 31 January 2025</li><li>Prelim Exam: March 2025</li></ul><h3>Selection Process</h3><ol><li>Preliminary Examination (Objective)</li><li>Mains Examination (Descriptive)</li><li>Interview / Personality Test</li></ol><h3>How to Apply</h3><p>Visit <strong>mpsc.gov.in</strong> → Apply Online → Fill form → Pay fees → Submit</p>',
 'MPSC', 'Govt', 'Maharashtra', NULL, '430+', 'Bachelor Degree', 'No experience required', '19-38 years',
 'https://mpsc.gov.in', '31 Jan 2025', ARRAY['mpsc','state service','government','maharashtra','ias'], 'published', 'urgent', true, 'MPSC Official'),

('sbi-po-recruitment-2025',
 'SBI PO Recruitment 2025 — 2000 Vacancies',
 'State Bank of India invites applications for Probationary Officer posts. Graduate eligible. Written exam followed by interview. CTC: ₹41,960/month.',
 '<h3>About the Vacancy</h3><p>SBI is recruiting Probationary Officers (PO) through a competitive selection process for 2000 posts across India.</p><h3>Pay Scale</h3><p>₹41,960 - ₹1,05,000 per month + DA, HRA and other perks</p><h3>Eligibility</h3><ul><li><strong>Education:</strong> Graduation in any discipline</li><li><strong>Age:</strong> 21 to 30 years</li><li><strong>Relaxation:</strong> OBC 3 years, SC/ST 5 years</li></ul><h3>Selection Process</h3><ol><li>Phase I: Preliminary Exam (100 marks)</li><li>Phase II: Mains Exam (225 marks)</li><li>Group Exercise + Interview (50 marks)</li></ol><h3>Application Fee</h3><ul><li>General/OBC: ₹750</li><li>SC/ST/PwD: Nil</li></ul><h3>How to Apply</h3><p>Apply at <strong>sbi.co.in/careers</strong> → Fill form online → Pay fee → Take printout</p>',
 'State Bank of India', 'Bank', 'All India', '₹41,960 - ₹1,05,000/month', '2000', 'Graduation', 'Fresher', '21-30 years',
 'https://sbi.co.in/careers', '20 Jan 2025', ARRAY['sbi','bank','po','probationary officer','bank job'], 'published', 'urgent', true, 'SBI Official'),

('rrb-ntpc-2025-railway',
 'RRB NTPC 2025 — 11,558 Railway Vacancies',
 'Railway Recruitment Board announces NTPC CEN 05/2025 for 11,558 posts. Graduate and 12th pass candidates eligible for various Non-Technical Popular Category posts.',
 '<h3>Post Details</h3><p>RRB NTPC recruitment for various posts at Graduate and Undergraduate level across Indian Railways.</p><h3>Graduate Level Posts (7,951 posts)</h3><ul><li>Senior Commercial cum Ticket Clerk: 2,409</li><li>Station Master: 994</li><li>Goods Guard: 3,144</li><li>Junior Account Assistant: 1,404</li></ul><h3>12th Pass Level Posts (3,607 posts)</h3><ul><li>Junior Clerk cum Typist: 2,119</li><li>Accounts Clerk cum Typist: 361</li><li>Junior Time Keeper: 10</li></ul><h3>Pay Scale</h3><p>Pay Level 2 to 6 — ₹19,900 to ₹35,400 per month</p><h3>Eligibility</h3><ul><li>12th Pass or Graduation based on post</li><li>Age: 18 to 33 years</li></ul>',
 'Railway Recruitment Board', 'Railway', 'All India', '₹19,900 - ₹35,400/month', '11,558', '12th Pass / Graduation', 'Fresher', '18-33 years',
 'https://rrbcdg.gov.in', '10 Feb 2025', ARRAY['railway','rrb','ntpc','loco pilot','goods guard'], 'published', 'urgent', true, 'RRB Official'),

('maharashtra-police-constable-2025',
 'Maharashtra Police Constable Bharti 2025 — 15,000+ Posts',
 'Massive recruitment drive for Police Constable in Maharashtra. 15,000+ vacancies. 12th pass eligible. Physical fitness test is mandatory. State Government job with pension.',
 '<h3>Vacancy Details</h3><p>Maharashtra State Government is conducting massive Police Constable recruitment across all districts.</p><h3>Total Posts: 15,000+</h3><ul><li>Armed Police Constable: 8,500</li><li>Unarmed Police Constable: 6,500+</li></ul><h3>Eligibility</h3><ul><li><strong>Education:</strong> 12th Pass from recognized board</li><li><strong>Age:</strong> 18 to 28 years</li><li><strong>Physical:</strong> Height and Chest requirements as per rules</li></ul><h3>Physical Tests</h3><ul><li>1600m Running: 7 minutes (Male), 5 min 40 sec (Female)</li><li>High Jump, Long Jump, Shotput</li></ul><h3>Selection</h3><ol><li>Written Exam: 100 marks</li><li>Physical Fitness Test</li><li>Medical Examination</li><li>Document Verification</li></ol>',
 'Maharashtra Police Department', 'Police', 'Maharashtra', '₹25,500 - ₹81,100/month', '15,000+', '12th Pass', 'Fresher', '18-28 years',
 'https://mahapolice.gov.in', '28 Feb 2025', ARRAY['police','maharashtra','constable','bharti','12th pass'], 'published', 'urgent', true, 'Maharashtra Police'),

('tcs-software-engineer-pune-2025',
 'TCS Software Engineer — Pune (2-5 Years Exp)',
 'Tata Consultancy Services hiring Software Engineers for Pune. Java, Python, Cloud skills required. 2-5 years experience. Good package with benefits.',
 '<h3>About TCS</h3><p>Tata Consultancy Services is expanding its Pune development center and hiring experienced Software Engineers.</p><h3>Job Role</h3><p>Senior Software Engineer / Technology Analyst</p><h3>Required Skills</h3><ul><li>Java 8+ / Python 3.x</li><li>Spring Boot, Hibernate, REST APIs</li><li>Cloud: AWS / Azure / GCP</li><li>Microservices architecture</li><li>Git, Agile/Scrum</li></ul><h3>Good to Have</h3><ul><li>React.js or Angular</li><li>Docker, Kubernetes</li><li>CI/CD pipelines</li></ul><h3>Package</h3><p>₹8 LPA - ₹18 LPA based on experience</p><h3>Benefits</h3><ul><li>Medical insurance for family</li><li>Learning & development platform</li><li>Provident Fund</li><li>Performance bonus</li></ul>',
 'Tata Consultancy Services', 'IT', 'Pune', '₹8 - ₹18 LPA', 'Multiple', 'B.E / B.Tech CS/IT', '2-5 years', '22-35 years',
 'https://careers.tcs.com', '15 Feb 2025', ARRAY['tcs','software engineer','java','python','pune','it'], 'published', 'high', false, 'TCS Careers'),

('infosys-java-developer-pune-nashik',
 'Infosys Java Full Stack Developer — Pune / Nashik',
 'Infosys BPM hiring Java Full Stack Developers for Pune and Nashik offices. 1-3 years experience. React frontend preferred.',
 '<h3>Position</h3><p>Senior Associate — Technology (Java Full Stack)</p><h3>Location</h3><p>Pune or Nashik, Maharashtra (Work from Office)</p><h3>Required Skills</h3><ul><li>Java 8+, Spring Boot, Hibernate</li><li>React.js / Angular (frontend)</li><li>MySQL / PostgreSQL</li><li>REST API development</li><li>Git version control</li></ul><h3>Compensation</h3><ul><li>CTC: ₹5 - ₹10 LPA</li><li>Health insurance</li><li>Transport allowance</li><li>Annual performance bonus</li></ul><h3>Shift</h3><p>General shift 9 AM - 6 PM, Monday to Friday</p>',
 'Infosys BPM', 'IT', 'Pune, Nashik', '₹5 - ₹10 LPA', 'Multiple', 'B.E / B.Tech', '1-3 years', '22-30 years',
 'https://infosys.com/careers', '25 Jan 2025', ARRAY['infosys','java','full stack','react','pune','nashik'], 'published', 'normal', false, 'Infosys Careers'),

('crpf-head-constable-ministerial-2025',
 'CRPF Head Constable Ministerial 2025 — 457 Posts',
 'Central Reserve Police Force recruiting Head Constable Ministerial posts. Central Govt job with pension. 12th pass with typing skills required.',
 '<h3>Vacancy Details</h3><p>CRPF under Ministry of Home Affairs is recruiting Head Constable (Ministerial) for 457 posts.</p><h3>Eligibility</h3><ul><li><strong>Education:</strong> 12th Pass</li><li><strong>Typing:</strong> 35 WPM English or 30 WPM Hindi</li><li><strong>Age:</strong> 18 to 25 years</li><li><strong>Relaxation:</strong> OBC 3 yrs, SC/ST 5 yrs</li></ul><h3>Pay Scale</h3><p>Pay Level 4 — ₹25,500 - ₹81,100 + Central Govt Benefits</p><h3>Benefits</h3><ul><li>Government pension</li><li>Central Government Health Scheme (CGHS)</li><li>House Rent Allowance</li><li>Dearness Allowance</li></ul><h3>Selection Process</h3><ol><li>Written Examination (CBT)</li><li>Skill Test (Typing)</li><li>Physical Standard Test</li><li>Medical Examination</li></ol>',
 'CRPF (Ministry of Home Affairs)', 'Defence', 'All India', '₹25,500 - ₹81,100/month', '457', '12th Pass', 'Fresher', '18-25 years',
 'https://crpf.gov.in', '5 Mar 2025', ARRAY['crpf','defence','constable','central government','typing'], 'published', 'high', false, 'CRPF Official'),

('wipro-fresher-nlth-2025',
 'Wipro NLTH Fresher Hiring 2025 — Pune & Mumbai',
 'Wipro National Level Talent Hunt for 2024/2025 graduates. 3.5 LPA starting package. 6-month training at Wipro Academy. Locations: Pune and Mumbai.',
 '<h3>About the Program</h3><p>Wipro NLTH (National Level Talent Hunt) is Wipros flagship campus hiring program for fresh graduates.</p><h3>Eligibility</h3><ul><li><strong>Degree:</strong> B.E / B.Tech / M.E / M.Tech / MCA</li><li><strong>Branches:</strong> CS, IT, ECE, EE, Mechanical, Civil</li><li><strong>Batch:</strong> 2024 or 2025 passouts</li><li><strong>Aggregate:</strong> 60% throughout (10th, 12th, Graduation)</li><li><strong>Backlogs:</strong> No active backlogs allowed</li></ul><h3>Package</h3><ul><li>Turbo Program: ₹6.5 LPA</li><li>Elite Program: ₹3.5 LPA</li><li>Pro C5 Program: ₹7.5 LPA</li></ul><h3>Selection Process</h3><ol><li>Online Aptitude Test</li><li>Coding Assessment</li><li>Technical Interview</li><li>HR Interview</li></ol>',
 'Wipro Technologies', 'IT', 'Pune, Mumbai', '₹3.5 - ₹7.5 LPA', 'Multiple', 'B.E / B.Tech / MCA', 'Fresher (2024/2025)', '21-26 years',
 'https://careers.wipro.com', '28 Jan 2025', ARRAY['wipro','fresher','nlth','software','pune','mumbai','campus'], 'published', 'normal', false, 'Wipro Careers'),

('pmc-pune-municipal-recruitment-2025',
 'Pune Municipal Corporation Recruitment 2025 — 312 Posts',
 'PMC announces 312 vacancies across Engineering, Health, Education departments. Degree and Diploma holders eligible. Maharashtra state government job.',
 '<h3>Department-wise Vacancies</h3><ul><li>Civil Engineering: 125 posts</li><li>Health Department: 89 posts</li><li>Education Department: 54 posts</li><li>Finance/Accounts: 44 posts</li></ul><h3>Eligibility</h3><ul><li>Engineering posts: B.E / B.Tech or Diploma</li><li>Health posts: MBBS / BDS / GNM / ANM</li><li>Education posts: B.Ed with subject specialization</li><li>Accounts: B.Com with CA/CMA</li></ul><h3>Pay Scale</h3><p>As per 7th Pay Commission — ₹28,000 to ₹92,000 per month</p><h3>Age Limit</h3><p>18 to 38 years with relaxation for reserved categories</p><h3>How to Apply</h3><p>Apply online at <strong>pune.gov.in</strong> or <strong>mahaonline.gov.in</strong></p>',
 'Pune Municipal Corporation', 'Govt', 'Pune', '₹28,000 - ₹92,000/month', '312', 'Degree / Diploma', 'Fresher preferred', '18-38 years',
 'https://pune.gov.in', '15 Mar 2025', ARRAY['pmc','pune','municipal','corporation','engineer','health'], 'published', 'normal', false, 'PMC Official'),

('ibps-rrb-clerk-po-2025',
 'IBPS RRB PO & Clerk 2025 — 9,800+ Posts',
 'IBPS announces Regional Rural Bank recruitment for Officer Scale I (PO) and Office Assistant (Clerk). 9,800+ posts across all states including Maharashtra.',
 '<h3>Posts Available</h3><ul><li>Officer Scale-I (PO): 4,800 posts</li><li>Office Assistant (Clerk): 5,000+ posts</li></ul><h3>Pay Scale</h3><ul><li>Officer Scale-I: ₹36,000 - ₹63,840/month</li><li>Office Assistant: ₹18,000 - ₹47,920/month</li></ul><h3>Eligibility</h3><ul><li><strong>PO:</strong> Graduation in any discipline, Age 18-30 years</li><li><strong>Clerk:</strong> Graduation, Age 18-28 years</li><li><strong>Language:</strong> Proficiency in local language required</li></ul><h3>Selection Process</h3><ol><li>Preliminary Examination (Online)</li><li>Mains Examination (Online)</li><li>Interview (for PO only)</li></ol><h3>Application Fee</h3><ul><li>General/OBC: ₹850 (PO) / ₹700 (Clerk)</li><li>SC/ST/PwD: ₹175</li></ul>',
 'IBPS (Institute of Banking)', 'Bank', 'All India', '₹18,000 - ₹63,840/month', '9,800+', 'Graduation', 'Fresher', '18-30 years',
 'https://ibps.in', '12 Feb 2025', ARRAY['ibps','rrb','bank','po','clerk','regional rural bank'], 'published', 'high', true, 'IBPS Official');

-- ================================================================
-- VERIFY — Check everything was created
-- ================================================================
SELECT 'admin_profiles' as tbl, COUNT(*) FROM admin_profiles
UNION ALL SELECT 'jobs', COUNT(*) FROM jobs
UNION ALL SELECT 'subscribers', COUNT(*) FROM subscribers
UNION ALL SELECT 'site_settings', COUNT(*) FROM site_settings;

-- ================================================================
-- DONE! Now create your admin user:
-- 1. Go to Supabase → Authentication → Users → Add User
-- 2. Enter your email and password
-- 3. Copy the User UID shown
-- 4. Run this SQL (replace values):
--
-- INSERT INTO admin_profiles (id, email, full_name, role, is_active)
-- VALUES ('PASTE-UID-HERE', 'your@email.com', 'Your Name', 'superadmin', true);
-- ================================================================
