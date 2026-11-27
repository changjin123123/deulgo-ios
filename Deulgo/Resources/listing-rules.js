function normalizeLink(input) {
  const matches = String(input || '').match(/https?:\/\/[^\s<>"']+/g) || [];
  if (matches.length !== 1) throw new Error('거래글 링크를 하나만 붙여넣어주세요.');
  let u;
  try { u = new URL(matches[0].replace(/[)\],.]+$/, '')); } catch { throw new Error('링크 형식을 확인해주세요.'); }
  if (u.protocol !== 'https:' || u.username || u.password || u.port) throw new Error('공식 HTTPS 거래글 링크가 필요해요.');
  const host = u.hostname.toLowerCase();
  let path;
  try { path = decodeURIComponent(u.pathname); } catch { throw new Error('링크 형식을 확인해주세요.'); }
  let platform = '';
  if (['daangn.com', 'www.daangn.com'].includes(host) && (/^\/articles\/\d+\/?$/.test(path) || /^\/kr\/buy-sell\/(?!all\/?$|s\/?$)[^/]+\/?$/.test(path))) {
    platform = '당근'; u.hostname = 'www.daangn.com';
  } else if (['bunjang.co.kr', 'www.bunjang.co.kr', 'm.bunjang.co.kr'].includes(host) && /^\/products\/\d+\/?$/.test(path)) {
    platform = '번개장터'; u.hostname = 'm.bunjang.co.kr';
  } else if (host === 'go.bgzt.link' && /^\/[A-Za-z0-9_-]{4,128}\/?$/.test(path)) {
    platform = '번개장터';
  } else if (['joongna.com', 'web.joongna.com'].includes(host) && /^\/product\/\d+\/?$/.test(path)) {
    platform = '중고나라'; u.hostname = 'web.joongna.com';
  } else if (['hellomarket.com', 'www.hellomarket.com'].includes(host) && /^\/item\/\d+\/?$/.test(path)) {
    platform = '헬로마켓'; u.hostname = 'www.hellomarket.com';
  } else if (['fruitsfamily.com', 'www.fruitsfamily.com', 'production.fruitsfamily.com'].includes(host) && /^\/product\/[A-Za-z0-9]+(?:\/[^/]+)?\/?$/.test(path)) {
    platform = '후루츠패밀리'; u.hostname = 'fruitsfamily.com';
  } else if (host === 'fruitsfamilyapp.onelink.me' && /^\/Agm2\/[A-Za-z0-9_-]{4,128}\/?$/.test(path)) {
    platform = '후루츠패밀리';
  } else throw new Error('지원하는 중고거래 사이트의 상품 링크를 넣어주세요. 홈·검색·부동산·카페 주소는 사용할 수 없어요.');
  u.hash = ''; u.search = '';
  return { url: u.href, platform };
}
function storedLink(input) {
  try { return { ...normalizeLink(input), supported:true }; } catch {}
  const links=String(input||'').match(/https?:\/\/[^\s<>"']+/g)||[];
  if(links.length!==1)throw new Error('HTTPS 링크를 하나만 입력하거나, 링크를 지우고 물품 정보를 직접 입력해주세요.');
  let u; try{u=new URL(links[0].replace(/[)\],.]+$/,''));}catch{throw new Error('링크 형식을 확인해주세요.');}
  if(u.protocol!=='https:'||u.username||u.password||u.port)throw new Error('계정 정보가 포함되지 않은 HTTPS 링크를 사용해주세요.');
  return {url:u.href,platform:u.hostname,supported:false};
}
function dimensionsFromText(text) {
  // A unit and axis order are required. Unlabelled numbers and photos are never measurements.
  const t = String(text || '').slice(0, 5000);
  const m = t.match(/가로\s*[:：]?\s*(\d+(?:\.\d+)?)\s*(mm|cm)?\s*[,×xX*·/\s]*\s*(?:세로|깊이)\s*[:：]?\s*(\d+(?:\.\d+)?)\s*(mm|cm)?\s*[,×xX*·/\s]*\s*높이\s*[:：]?\s*(\d+(?:\.\d+)?)\s*(mm|cm)/i);
  if (!m) return null;
  const units = [m[2] || m[6], m[4] || m[6], m[6]];
  const dims = [m[1], m[3], m[5]].map((n, i) => Number(n) / (units[i].toLowerCase() === 'mm' ? 10 : 1));
  if (dims.some(n => n <= 0 || n > 1000)) return null;
  return { w: dims[0], d: dims[1], h: dims[2] };
}
function previewImage(input, baseUrl) {
  if (typeof input !== 'string' || !input.trim() || input.length > 4000) return '';
  try {
    const u = new URL(input, baseUrl);
    const host = u.hostname.toLowerCase();
    if (u.protocol !== 'https:' || u.username || u.password || u.port || !host.includes('.') || /[:\[\]]/.test(host) || /^[\d.]+$/.test(host) || /\.(?:localhost|local|internal|test|invalid|onion)$/.test(host)) return '';
    return u.href;
  } catch { return ''; }
}
function parseSharedText(input) {
  const text = String(input || '').trim().slice(0, 5000);
  const withoutLinks = text.replace(/https?:\/\/\S+/g, '').trim();
  const lines = withoutLinks.split(/\n/).map(s => s.trim()).filter(Boolean);
  const title = (lines.find(s => !/^(?:당근에서|번개장터에서|중고나라에서|헬로마켓에서|후루츠패밀리에서|https?:|가격\s*[:：]|[\d,]+\s*원|가로\s*\d)/.test(s)) || '').replace(/^(?:물품명|상품명|제목)\s*[:：]\s*/, '').slice(0, 70);
  const description = lines.filter(line => line.replace(/^(?:물품명|상품명|제목)\s*[:：]\s*/, '').slice(0, 70) !== title && !/^(?:가격|판매가|금액)\s*[:：]|^[\d,]+\s*원\s*$/.test(line)).join('\n').slice(0, 2000);
  return { title, dimensions: dimensionsFromText(withoutLinks), source: 'pasted', description, image: '' };
}
