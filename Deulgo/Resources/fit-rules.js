/* Conservative axis-aligned bounding-box comparison; not a loading-path or safety solver. */
(function(root) {
  const permutations = [[0,1,2],[1,0,2],[0,2,1],[2,0,1],[1,2,0],[2,1,0]];
  const labels = ['가로', '깊이', '높이'];
  const positive = x => x !== '' && x !== null && Number.isFinite(Number(x)) && Number(x) > 0 && Number(x) <= 1000;
  function compare(input) {
    const v = input.vehicle || {}, pieces = input.pieces || [], missing = [];
    for (const [key, name] of [['openingWidth','입구 너비'],['openingHeight','입구 높이'],['insideWidth','실내 최소 너비'],['insideDepth','문을 닫은 실내 길이'],['insideHeight','실내 최소 높이']]) if (!positive(v[key])) missing.push(name);
    if (!pieces.length || pieces.length > 5) missing.push('물품 조각 1~5개');
    for (const [i,p] of pieces.entries()) {
      for (const [key,name] of [['w','가로'],['d','깊이'],['h','높이']]) if (!positive(p[key])) missing.push(`${i+1}번 물품 ${name}`);
      if (!Number.isInteger(Number(p.count)) || Number(p.count) < 1 || Number(p.count) > 10) missing.push(`${i+1}번 물품 수량`);
      if (!['any','upright','fixed'].includes(p.orientation)) missing.push(`${i+1}번 물품 운반 방향`);
    }
    const margin = Number(input.margin);
    if (input.margin === '' || !Number.isFinite(margin) || margin < 0 || margin > 20) missing.push('한쪽 여유 0~20cm');
    if (missing.length) return { status: 'incomplete', missing, pieces: [] };
    const results = pieces.map(p => {
      const dimensions = [Number(p.w), Number(p.d), Number(p.h)];
      const allowed = p.orientation === 'fixed' ? permutations.slice(0,1) : p.orientation === 'upright' ? permutations.slice(0,2) : permutations;
      const candidates = allowed.map(order => {
        const [w,d,h] = order.map(i=>dimensions[i]);
        const slack = { openingWidth: Number(v.openingWidth)-w-2*margin, openingHeight: Number(v.openingHeight)-h-2*margin, insideWidth: Number(v.insideWidth)-w-2*margin, insideDepth: Number(v.insideDepth)-d-2*margin, insideHeight: Number(v.insideHeight)-h-2*margin };
        return { order, width:w, depth:d, height:h, slack, minimum:Math.min(...Object.values(slack)), direction:`물품 ${labels[order[0]]}를 차량 너비, ${labels[order[1]]}를 차량 길이, ${labels[order[2]]}를 위쪽으로` };
      }).sort((a,b)=>b.minimum-a.minimum);
      return { label: String(p.label||'물품').slice(0,30), count:Number(p.count), fits:candidates[0].minimum >= -1e-8, placement:candidates[0] };
    });
    const multi = pieces.reduce((n,p)=>n+Number(p.count),0) > 1;
    return { status: results.every(p=>p.fits) ? (multi?'separate':'candidate') : 'exceeds', pieces:results, margin, multi };
  }
  const api = { compare };
  if (typeof module !== 'undefined') module.exports = api; else root.FitRules = api;
})(typeof window !== 'undefined' ? window : this);
