/**
 *  权威 RDAP 查询（HTTPS + JSON）：
 *    .app  → https://rdap.googleapis.com/v1/domain/XXX.app    (Google Registry)
 *    .im   → https://rdap.nic.im/domain/XXX.im                (Isle of Man Registry)
 *  Verisign .com RDAP: https://rdap.verisign.com/com/v1/domain/
 */
const HTTPS = require('https');
const URL = require('url');

const QUERIES = [
  {
    label: 'JIANXIN.APP  ',
    rdap: 'https://rdap.googleapis.com/v1/domain/jianxin.app'
  },
  {
    label: 'LANXIN.APP   ',
    rdap: 'https://rdap.googleapis.com/v1/domain/lanxin.app'
  },
  {
    label: 'YUNXIN.APP   ',
    rdap: 'https://rdap.googleapis.com/v1/domain/yunxin.app'
  },
  {
    label: 'JIANXIN.IM   ',
    rdap: 'https://rdap.nic.im/domain/jianxin.im'
  },
  {
    label: 'LANXIN.IM    ',
    rdap: 'https://rdap.nic.im/domain/lanxin.im'
  },
  {
    label: 'YUNXIN.IM    ',
    rdap: 'https://rdap.nic.im/domain/yunxin.im'
  },
];

function fetchJson(u) {
  return new Promise((resolve) => {
    const opt = URL.parse(u);
    opt.headers = { 'Accept': 'application/rdap+json, application/json', 'User-Agent': 'node RDAP check' };
    opt.timeout = 15000;
    const req = HTTPS.get(opt, (res) => {
      let data = '';
      res.setEncoding('utf-8');
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, data: { raw: data.slice(0,500) } }); }
      });
    });
    req.on('timeout', () => { req.destroy(new Error('timeout')); });
    req.on('error', (e) => resolve({ status: -1, error: e.message }));
  });
}

function describe(r) {
  if (r.status === -1) return { status: '网络失败', detail: r.error };
  if (r.status === 404) return { status: '可注册', detail: 'RDAP 返回 404（注册局无此条目）' };
  if (r.status === 200 || r.status === 204) {
    const o = r.data || {};
    // 注册商
    const entity = (o.entities||[]).find(e => (e.roles||[]).includes('registrar'));
    const registrar = entity?.vcardArray?.[1]?.find(r=>r[0]==='fn')?.[3] || '';
    // 到期日
    const events = o.events || [];
    const reg = events.find(e => e.eventAction === 'registration')?.eventDate?.slice(0,10) || '';
    const exp = events.find(e => e.eventAction === 'expiration')?.eventDate?.slice(0,10) || '';
    const note = [registrar, reg && '注册'+reg, exp && '到期'+exp].filter(Boolean).join(' · ');
    return { status: '已注册', detail: note };
  }
  if (r.status >= 400 && r.status < 500) {
    const note = r.data?.title || r.data?.error || 'RDAP ' + r.status;
    if (/not found|no domain|object does not exist/i.test(String(note))) {
      return { status: '可注册', detail: note };
    }
    return { status: r.status + ' ?', detail: note };
  }
  return { status: 'RDAP ' + r.status, detail: (typeof r.data === 'string' ? r.data : r.data?.title)?.slice(0,60) || '' };
}

(async () => {
  const cols = process.stdout.columns || 80;
  console.log('='.repeat(cols));
  console.log('  RDAP（ICANN 官方）查询 .APP / .IM 域名可注册性');
  console.log('='.repeat(cols));
  for (const q of QUERIES) {
    const r = await fetchJson(q.rdap);
    const d = describe(r);
    const icon = d.status === '可注册' ? 'YES' : d.status === '已注册' ? 'NO ' : ' ? ';
    console.log(`  [${icon}]  ${q.label}   ${d.status.padEnd(6)}   ${d.detail}`);
  }
  console.log('='.repeat(cols));
})();
