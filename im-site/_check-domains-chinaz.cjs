/**
 *  通过站长之家 whois.chinaz.com 官方门户查询 9 条域名。
 *  接口：https://whois.chinaz.com/<域名> HTML解析 / 或者使用其公开 ajax JSON 查询接口。
 *  直接请求 HTML 页面；用正则提取 "No matching record"/"Not Found"/"已存在/注册时间/到期时间/注册商" 等关键字段。
 */
const HTTPS = require('https');

const DOMAINS = [
  'jianxin.com','lanxin.com','yunxin.com',
  'jianxin.app','lanxin.app','yunxin.app',
  'jianxin.im', 'lanxin.im', 'yunxin.im',
];

function fetchHtml(domain) {
  return new Promise(resolve => {
    const opt = {
      host: 'whois.chinaz.com', path: '/' + encodeURIComponent(domain), method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Cache-Control': 'no-cache',
      }, timeout: 20000,
    };
    const req = HTTPS.request(opt, r => {
      let d = '';
      r.setEncoding('utf-8');
      r.on('data', c => d += c);
      r.on('end', () => resolve({ code: r.statusCode, html: d }));
    });
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', e => resolve({ code: -1, html: '', error: e.message }));
    req.end();
  });
}

function parse(domain, r) {
  if (r.code === -1) return { label: domain.padEnd(12), status: '网络失败', detail: r.error };
  if (r.code !== 200) return { label: domain.padEnd(12), status: 'HTTP ' + r.code, detail: '' };
  const h = r.html;
  // 1. 站长之家如果域名未注册，会显示 "未找到相关的Whois信息" / "该域名暂未被注册" / "No match for" / "No entries found"
  const freeKeywords = [
    '暂未被注册', '未找到相关的whois信息', '未找到相关的Whois信息', '该域名可能未注册',
    'No match for', 'NO MATCH', 'No entries found', 'No Data Found', 'NOT FOUND',
    'No objects found', 'This domain name is not registered', '该域名尚未注册',
  ];
  if (freeKeywords.some(k => h.includes(k))) {
    return { label: domain.padEnd(12), status: '可注册', detail: '站长之家返回未注册/无Whois数据' };
  }
  // 2. 已注册，提取核心字段
  let info = [];
  const reg = /注册商(?:名称)?\s*[:：]\s*<[^>]+>\s*([^<\n\r]+)/i;
  const reg2 = h.match(reg);
  if (reg2) info.push(reg2[1].trim().replace(/\s+/g, ' ').slice(0, 40));

  const createdRe = h.match(/(?:创建时间|注册时间|Registration Time)\s*[:：]\s*<[^>]+>\s*([^<\n\r]+)/i);
  if (createdRe) info.push('注册 ' + createdRe[1].trim().slice(0, 19));
  const expRe = h.match(/(?:到期时间|过期时间|Expiration Time)\s*[:：]\s*<[^>]+>\s*([^<\n\r]+)/i);
  if (expRe) info.push('到期 ' + expRe[1].trim().slice(0, 19));

  // 兼容 .app .im 可能用英文模板：Registrar / Created / Registrar Registration Expiration Date
  if (info.length === 0) {
    const rR = h.match(/Registrar\s*:\s*([^\r\n<]+)/i);
    const cR = h.match(/Creation Date\s*:\s*([^\r\n<]+)/i);
    const eR = h.match(/(?:Registrar Registration Expiration|Expir\w+ Date)\s*:\s*([^\r\n<]+)/i);
    if (rR) info.push(rR[1].trim().slice(0, 40));
    if (cR) info.push('注册 ' + cR[1].trim().slice(0, 19));
    if (eR) info.push('到期 ' + eR[1].trim().slice(0, 19));
  }
  // 如果仍然空，但是页面没说未注册 → 就是某种已注册
  const extra = info.length ? info.join(' · ') : '已注册（站长之家数据未解析，可手动打开 whois.chinaz.com/' + domain + ' 查看）';
  return { label: domain.padEnd(12), status: '已注册', detail: extra };
}

(async () => {
  const c = process.stdout.columns || 80;
  console.log('='.repeat(c));
  console.log('  JianXin / LanXin / YunXin  .com / .app / .im   可注册性查询');
  console.log('  数据源：站长之家 WHOIS（whois.chinaz.com）');
  console.log('='.repeat(c));
  for (const d of DOMAINS) {
    const r = await fetchHtml(d);
    const h = parse(d, r);
    const mark = h.status === '可注册' ? 'YES' : h.status === '已注册' ? 'NO ' : ' ? ';
    console.log(`  [${mark}]  ${h.label.toUpperCase()}   ${h.status.padEnd(8)}   ${h.detail}`);
  }
  console.log('='.repeat(c));
  console.log('  YES = 能注册；NO = 已经被人持有；? = 查询异常');
  console.log('='.repeat(c));
})();
