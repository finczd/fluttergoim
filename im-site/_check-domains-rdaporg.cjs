const HTTPS = require('https');
const Q = [
  ['JIANXIN.APP  ', 'https://rdap.org/domain/jianxin.app'],
  ['LANXIN.APP   ', 'https://rdap.org/domain/lanxin.app'],
  ['YUNXIN.APP   ', 'https://rdap.org/domain/yunxin.app'],
  ['JIANXIN.IM   ', 'https://rdap.org/domain/jianxin.im'],
  ['LANXIN.IM    ', 'https://rdap.org/domain/lanxin.im'],
  ['YUNXIN.IM    ', 'https://rdap.org/domain/yunxin.im'],
  ['JIANXIN.COM  ', 'https://rdap.org/domain/jianxin.com'],
  ['LANXIN.COM   ', 'https://rdap.org/domain/lanxin.com'],
  ['YUNXIN.COM   ', 'https://rdap.org/domain/yunxin.com'],
];
function get(u) {
  return new Promise(res => {
    const url = new URL(u);
    const opt = {
      host: url.host, path: url.pathname + url.search, method: 'GET',
      headers: { Accept: 'application/rdap+json,application/json,*/*' }, timeout: 20000,
    };
    const req = HTTPS.request(opt, r => {
      let d = ''; r.setEncoding('utf-8');
      r.on('data', c => d += c);
      r.on('end', () => {
        try { res({ code: r.statusCode, json: JSON.parse(d.slice(d.indexOf('{')), d.slice(0,d.indexOf('{'))) }); }
        catch { res({ code: r.statusCode, raw: d.slice(0,400) }); }
      });
    });
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', e => res({ code: -1, err: e.message }));
    req.end();
  });
}
function hit(code, o) {
  if (code === 404) return { s: '可注册', d: 'RDAP 返回 404' };
  if (code === -1) return { s: '网络失败', d: String(o.err || '') };
  if (code >= 200 && code < 300) {
    const ent = (o.entities || []).find(e => (e.roles || []).includes('registrar'));
    const reg = ent?.vcardArray?.[1]?.find(r => r[0] === 'fn')?.[3] || '';
    const evs = o.events || [];
    const a = evs.find(e => e.eventAction === 'registration')?.eventDate?.slice(0, 10);
    const b = evs.find(e => e.eventAction === 'expiration')?.eventDate?.slice(0, 10);
    return { s: '已注册', d: [reg, a && ('注册'+a), b && ('到期'+b)].filter(Boolean).join(' · ') };
  }
  if (o && typeof o === 'object' && o.title) {
    if (/not found|does not exist/i.test(o.title)) return { s: '可注册', d: o.title };
  }
  return { s: '状态未知(code '+code+')', d: (o.title || String(o.raw||'')).slice(0, 60) };
}
(async () => {
  const c = process.stdout.columns || 80;
  console.log('='.repeat(c));
  console.log('  9 条域名 .COM / .APP / .IM 可注册性（rdap.org 公共权威节点）');
  console.log('='.repeat(c));
  for (const [label, url] of Q) {
    const r = await get(url);
    const h = hit(r.code, r.json || r);
    const mark = h.s === '可注册' ? 'YES' : h.s === '已注册' ? 'NO ' : ' ? ';
    console.log(`  [${mark}]  ${label}   ${h.s.padEnd(8)}   ${h.d}`);
  }
  console.log('='.repeat(c));
})();
