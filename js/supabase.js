// ================================================================
// js/supabase.js — UPDATED VERSION with Email Notifications
// Replace your existing js/supabase.js with this file
// ================================================================

// ⚠️  REPLACE THESE with your actual Supabase project values
const SUPABASE_URL = 'https://txhsvlsndddqklwdimgw.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4aHN2bHNuZGRkcWtsd2RpbWd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzMTI0MjksImV4cCI6MjA5MDg4ODQyOX0.1U3TmF2jQo1k76YtsuR5McJCKooCgnNQZnHRczWAPQc';

const { createClient } = supabase;
const sb = createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: { persistSession: true, autoRefreshToken: true }
});

// ── DB helper ─────────────────────────────────────────────────
const DB = {
    async getPublishedJobs(limit = 100) {
        const { data, error } = await sb.from('jobs').select('*').in('status', ['published', 'featured']).order('created_at', { ascending: false }).limit(limit);
        if (error) throw error;
        return data || [];
    },
    async getJobBySlug(slug) {
        const { data, error } = await sb.from('jobs').select('*').eq('slug', slug).in('status', ['published', 'featured']).single();
        if (error) throw error;
        return data;
    },
    async getJobsByCategory(cat, limit = 50) {
        const { data, error } = await sb.from('jobs').select('*').eq('category', cat).in('status', ['published', 'featured']).order('created_at', { ascending: false }).limit(limit);
        if (error) throw error;
        return data || [];
    },
    async searchJobs(query) {
        const { data, error } = await sb.from('jobs').select('*').in('status', ['published', 'featured']).or(`title.ilike.%${query}%,description.ilike.%${query}%,organization.ilike.%${query}%,location.ilike.%${query}%`).order('created_at', { ascending: false });
        if (error) throw error;
        return data || [];
    },
    subscribeJobs(callback) {
        return sb.channel('jobs-public').on('postgres_changes', { event: '*', schema: 'public', table: 'jobs' }, callback).subscribe();
    },
    async addSubscriber(email, name, category) {
        const { error } = await sb.from('subscribers').insert({ email, name, category_pref: category, is_active: true });
        if (error && error.code !== '23505') throw error;

        // Send welcome email
        try {
            await sendWelcomeEmail(email, name || 'Job Seeker', category);
        } catch (e) { console.warn('Welcome email failed:', e.message); }
        return true;
    },
    async incrementViews(id) { await sb.rpc('increment_views', { job_id: id }); },

    // ── ADMIN ONLY ─────────────────────────────────────────────
    async getAllJobs() {
        const { data, error } = await sb.from('jobs').select('*').order('created_at', { ascending: false });
        if (error) throw error;
        return data || [];
    },

    // ── SAVE JOB (with auto email notification) ─────────────────
    async saveJob(jobData, editId = null) {
        if (editId) {
            const { error } = await sb.from('jobs').update(jobData).eq('id', editId);
            if (error) throw error;
        } else {
            const { data, error } = await sb.from('jobs').insert(jobData).select('id').single();
            if (error) throw error;

            // Auto-send email notification if job is published
            if (jobData.status === 'published' || jobData.status === 'featured') {
                await autoNotifySubscribers(data.id);
            }
        }
    },

    async deleteJob(id) {
        const { error } = await sb.from('jobs').delete().eq('id', id);
        if (error) throw error;
    },
    async updateJobStatus(id, status) {
        const { error } = await sb.from('jobs').update({ status }).eq('id', id);
        if (error) throw error;

        // If job is being published, send notifications
        if (status === 'published' || status === 'featured') {
            await autoNotifySubscribers(id);
        }
    },
    async getStats() {
        const { data, error } = await sb.rpc('get_stats');
        if (error) throw error;
        return data;
    },
    async getSubscribers() {
        const { data, error } = await sb.from('subscribers').select('*').order('created_at', { ascending: false });
        if (error) throw error;
        return data || [];
    },
    async getSettings() {
        const { data, error } = await sb.from('site_settings').select('*');
        if (error) throw error;
        const s = {};
        (data || []).forEach(r => s[r.key] = r.value);
        return s;
    },
    async saveSetting(key, value) {
        const { error } = await sb.from('site_settings').upsert({ key, value, updated_at: new Date().toISOString() });
        if (error) throw error;
    }
};

// ── AUTO NOTIFY SUBSCRIBERS when job published ─────────────────
async function autoNotifySubscribers(jobId) {
    try {
        // Get setting
        const { data: settings, error: settingsError } = await sb
            .from('email_settings')
            .select('value')
            .eq('key', 'auto_notify')
            .single();

        if (settingsError) {
            console.warn("Settings fetch error:", settingsError.message);
            return;
        }

        // ✅ Safe check (handles boolean + string)
        if (!settings || (settings.value !== true && settings.value !== 'true')) {
            return;
        }

        // Queue emails
        const { data: count, error } = await sb.rpc('queue_job_notification', {
            p_job_id: jobId
        });

        if (error) {
            console.warn('Failed to queue notifications:', error.message);
            return;
        }

        console.log(`📧 Queued ${count} email notifications for job ${jobId}`);

        // Call Edge Function
        const { error: fnErr } = await sb.functions.invoke('send-emails', {
            body: {}
        });

        if (fnErr) {
            console.warn('Edge Function not available:', fnErr.message);
        }

    } catch (e) {
        console.warn('Auto-notify error:', e.message);
    }
}
// ── SEND WELCOME EMAIL to new subscriber ──────────────────────
async function sendWelcomeEmail(email, name, categoryPref) {
    // Get welcome template
    const { data: tmpl } = await sb.from('email_templates').select('*').eq('name', 'welcome').eq('is_active', true).single();
    if (!tmpl) return;

    // Get site settings
    const { data: settings } = await sb.from('email_settings').select('*');
    const cfg = {};
    (settings || []).forEach(s => cfg[s.key] = s.value);

    const siteUrl = cfg.site_url || 'https://mycareerjob.in';
    const unsubUrl = cfg.unsubscribe_url || 'https://mycareerjob.in/unsubscribe.html';

    // Replace placeholders
    let html = tmpl.html_body
        .replace(/\{\{subscriber_name\}\}/g, name)
        .replace(/\{\{subscriber_email\}\}/g, email)
        .replace(/\{\{category_pref\}\}/g, categoryPref === 'all' ? 'All Categories' : categoryPref)
        .replace(/\{\{site_url\}\}/g, siteUrl)
        .replace(/\{\{unsubscribe_url\}\}/g, unsubUrl);

    let subject = tmpl.subject
        .replace(/\{\{subscriber_name\}\}/g, name);

    let text = (tmpl.text_body || '')
        .replace(/\{\{subscriber_name\}\}/g, name)
        .replace(/\{\{subscriber_email\}\}/g, email)
        .replace(/\{\{category_pref\}\}/g, categoryPref === 'all' ? 'All Categories' : categoryPref)
        .replace(/\{\{site_url\}\}/g, siteUrl)
        .replace(/\{\{unsubscribe_url\}\}/g, unsubUrl);

    // Add to queue
    await sb.from('email_queue').insert({
        to_email: email,
        to_name: name,
        subject,
        html_body: html,
        text_body: text || null,
        template_id: tmpl.id,
        status: 'pending'
    });

    // Try to send immediately
    try {
        await sb.functions.invoke('send-emails', { body: {} });
    } catch (e) {
        console.warn('Send function not available, email queued');
    }
}

// ── Helpers ──────────────────────────────────────────────────
function h(s = '') {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function timeAgo(d) {
    if (!d) return '';
    const s = (Date.now() - new Date(d)) / 1000;
    if (s < 60) return 'just now';
    if (s < 3600) return Math.floor(s / 60) + 'm ago';
    if (s < 86400) return Math.floor(s / 3600) + 'h ago';
    return new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
}

function slugify(t = '') {
    return t.toLowerCase().replace(/[^a-z0-9\s-]/g, '').replace(/\s+/g, '-').replace(/-+/g, '-').trim().slice(0, 80);
}

function toast(msg, type = '') {
    const c = document.getElementById('toast') || (() => {
        const el = document.createElement('div');
        el.id = 'toast';
        el.style.cssText = 'position:fixed;bottom:24px;right:24px;z-index:9999;display:flex;flex-direction:column;gap:8px;';
        document.body.appendChild(el);
        return el;
    })();
    const t = document.createElement('div');
    const colors = { success: '#22c55e', error: '#ef4444', info: '#3b82f6', '': '#FF6B00' };
    t.style.cssText = `background:white;border-left:4px solid ${colors[type]||colors['']};border-radius:10px;padding:12px 18px;box-shadow:0 8px 24px rgba(0,0,0,.15);font-size:.9rem;font-weight:500;min-width:240px;`;
    t.textContent = msg;
    c.appendChild(t);
    setTimeout(() => {
        t.style.opacity = '0';
        t.style.transition = 'opacity .3s';
        setTimeout(() => t.remove(), 300);
    }, 3000);
}

// Category config
const CATS = {
    'Govt': { emoji: '🏛️', color: '#2ECC71', bg: 'rgba(46,204,113,0.12)' },
    'IT': { emoji: '💻', color: '#3498DB', bg: 'rgba(52,152,219,0.12)' },
    'Private': { emoji: '🏢', color: '#9B59B6', bg: 'rgba(155,89,182,0.12)' },
    'Bank': { emoji: '🏦', color: '#F39C12', bg: 'rgba(243,156,18,0.12)' },
    'Railway': { emoji: '🚂', color: '#E74C3C', bg: 'rgba(231,76,60,0.12)' },
    'Defence': { emoji: '🎖️', color: '#1ABC9C', bg: 'rgba(26,188,156,0.12)' },
    'Health': { emoji: '🏥', color: '#E91E63', bg: 'rgba(233,30,99,0.12)' },
    'Education': { emoji: '🎓', color: '#FF9800', bg: 'rgba(255,152,0,0.12)' },
    'Police': { emoji: '👮', color: '#5D4E8A', bg: 'rgba(93,78,138,0.12)' },
    'Other': { emoji: '💼', color: '#FF6B00', bg: 'rgba(255,107,0,0.12)' },
};