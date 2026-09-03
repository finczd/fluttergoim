/**
 *  查询 JianXin / LanXin / YunXin 的 .com / .app / .im  3后缀（共9条）
 *  官方 WHOIS 服务器：
 *    .com  -> whois.verisign-grs.com    (43 port)
 *    .app  -> whois.nic.app            (Donuts)
 *    .im   -> whois.nic.im             (Isle of Man registry)
 *
 *  输出: "No match / NOT FOUND" = 可注册；其他 = 已注册
 */
const net = require('net');

const QUERIES = [
  // .com
  { domain: 'jianxin.com', server: 'whois.verisign-grs.com', label: 'JIANXIN.COM  ' },
  { domain: 'lanxin.com',  server: 'whois.verisign-grs.com', label: 'LANXIN.COM   ' },
  { domain: 'yunxin.com',  server: 'whois.verisign-grs.com', label: 'YUNXIN.COM   ' },
  // .app
  { domain: 'jianxin.app', server: 'whois.nic.app',         label: 'JIANXIN.APP  ' },
  { domain: 'lanxin.app',  server: 'whois.nic.app',         label: 'LANXIN.APP   ' },
  { domain: 'yunxin.app',  server: 'whois.nic.app',         label: 'YUNXIN.APP   ' },
  // .im
  { domain: 'jianxin.im',  server: 'whois.nic.im',          label: 'JIANXIN.IM   ' },
  { domain: 'lanxin.im',   server: 'whois.nic.im',          label: 'LANXIN.IM    ' },
  { domain: 'yunxin.im',   server: 'whois.nic.im',          label: 'YUNXIN.IM    ' },
];

function queryOne(q) {
  return new Promise(resolve => {
    let data = '';
    let done = false;
    const finish = () => { if (done) return; done = true; resolve(parseResult(q, data)); }
    const sock = net.createConnection(43, q.server, () => {
      sock.setEncoding('utf-8');
      sock.setTimeout(12000);
      sock.write(q.domain + '\r\n');
    });
    sock.on('data', c => { data += c; });
    sock.on('end', finish);
    sock.on('timeout', () => { sock.destroy(); finish(); });
    sock.on('error', err => { data = `ERROR:${err.message}`; finish(); });
  });
}

function parseResult(q, data) {
  if (!data) return { label: q.label, status: '查询超时或无响应', detail: '' };
  if (data.startsWith('ERROR:')) return { label: q.label, status: '查询失败', detail: data };
  // Verisign(.com):  NO MATCH => 可注册
  const text = data.toUpperCase();
  if (/NO (DATA(BASE)? )?(ENTRIES|FOUND|MATCH)/.test(text) ||
      /^%ERROR:101/.test(data) ||
      text.includes('NOT FOUND IN DATABASE') ||
      text.includes('DOMAIN NOT FOUND') ||
      (q.server === 'whois.nic.im' && (
        text.includes('STATUS: FREE') ||
        /IS\s+NOT\s+REGISTERED/.test(text) ||
        text.includes('NO DOMAIN')
      )) ||
      (q.server === 'whois.nic.app' && text.includes('NO OBJECT FOUND'))) {
    return { label: q.label, status: '可注册', detail: '注册局返回空数据 / NO MATCH' };
  }
  // 找到创建日期或注册商 = 已注册；顺带提取注册商、到期日（若存在）
  const m = [
    /(?:Registrar|Sponsoring Registrar):\s*([^\r\n]+)/i,
    /(?:Creation Date|Created):\s*([^\r\n]+)/i,
    /(?:Registry Expiry Date|Expire.*Date):\s*([^\r\n]+)/i,
    /(?:Registrant Organization|Registrant):\s*([^\r\n]+)/i,
  ].map(re => (re.exec(data)||[])[1]).filter(Boolean);
  const extra = m.length ? m.map(s=>s.trim()).join(' | ') : '已注册（注册局WHOIS详情需查完整条目）';
  return { label: q.label, status: '已注册', detail: extra };
}

(async () => {
  const cols = process.stdout.columns || 80;
  console.log('='.repeat(cols));
  console.log('  9 域名可注册性查询结果（来自各注册局 WHOIS 43 端口，最权威）');
  console.log('='.repeat(cols));
  for (const q of QUERIES) {
    const r = await queryOne(q);
    const icon = r.status === '可注册' ? 'YES' : r.status === '已注册' ? 'NO ' : ' ? ';
    console.log(`  [${icon}]  ${r.label}   ${r.status.padEnd(6)}   ${r.detail}`);
  }
  console.log('='.repeat(cols));
})();
