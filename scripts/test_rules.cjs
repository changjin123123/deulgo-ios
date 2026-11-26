const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');
const root = join(__dirname,'../Deulgo/Resources');
const context = vm.createContext({URL});
for (const file of ['vehicle-models.js','listing-rules.js','fit-rules.js']) vm.runInContext(readFileSync(join(root,file),'utf8'),context);
test('all five marketplaces accept product links and remove tracking',()=>{
  for(const [input,platform,host] of [
    ['https://www.daangn.com/articles/1295039589?share=true','당근','www.daangn.com'],
    ['https://go.bgzt.link/hio9lhf','번개장터','go.bgzt.link'],
    ['https://joongna.com/product/12345','중고나라','web.joongna.com'],
    ['https://www.hellomarket.com/item/185286509?listType=recomm_item','헬로마켓','www.hellomarket.com'],
    ['https://fruitsfamily.com/product/6ki7m/나이키-반팔티?share=true#details','후루츠패밀리','fruitsfamily.com'],
    ['https://production.fruitsfamily.com/product/70hv3/휴무-및-상품-발송-안내','후루츠패밀리','fruitsfamily.com']
  ]){
    const link=context.normalizeLink(input), url=new URL(link.url);
    assert.equal(link.platform,platform); assert.equal(url.hostname,host);
    assert.equal(url.search,''); assert.equal(url.hash,'');
  }
});
test('marketplace links exclude non-products, impersonation and unsafe URLs',()=>{
  for(const input of [
    'https://www.charan.style/item/5299705',
    'https://www.hellomarket.com/search','https://www.hellomarket.com/item/undefined',
    'https://fruitsfamily.com/brand/Nike','https://fruitsfamily.com/product/','https://fruitsfamily.com/product/6ki7m/name/extra',
    'https://www.hellomarket.com.evil.test/item/185286509','https://evil.hellomarket.com/item/185286509',
    'https://fruitsfamily.com@evil.test/product/6ki7m/nike','https://user:pass@www.hellomarket.com/item/185286509',
    'https://www.hellomarket.com:8443/item/185286509','http://fruitsfamily.com/product/6ki7m/nike',
    'https://fruitsfamily.com/product/6ki7m/nike https://www.hellomarket.com/item/185286509',
    'https://realty.daangn.com/articles/5152225','https://www.daangn.com.evil.test/articles/1'
  ]) assert.throws(()=>context.normalizeLink(input),undefined,input);
});
test('new marketplace share introductions do not replace the product name',()=>{
  for(const platform of ['헬로마켓','후루츠패밀리']){
    const preview=context.parseSharedText(`${platform}에서 상품을 확인해보세요!\n상품명: 나이키 반팔티\n30,000원`);
    assert.equal(preview.title,'나이키 반팔티'); assert(!preview.description.includes('30,000'));
    assert.equal(preview.dimensions,null);
  }
});
test('native rules have no DOM dependency and match Hangul initials',()=>{
  assert(context.nativeVehicleModels('car','ㅆㄴㅌ',[]).some(v=>v.name==='쏘나타'));
  assert(context.nativeVehicleModels('car','소나타',[]).some(v=>v.name==='쏘나타'));
  assert(context.nativeVehicleModels('bike','ㅍㅆㅇㅅ',[]).some(v=>v.name==='PCX'));
});
test('pasted information excludes price and requires labeled units for dimensions',()=>{
  const p=context.parseSharedText('물품명: 테이블\n150,000원\n가로 60 깊이 40 높이 80cm');
  assert.equal(p.title,'테이블'); assert(!p.description.includes('150,000'));
  assert.equal(p.dimensions.w,60); assert.equal(p.dimensions.d,40); assert.equal(p.dimensions.h,80);
  assert.equal(context.dimensionsFromText('60 x 40 x 80'),null);
});
test('missing measurements and litre values cannot produce a fit',()=>{
  const r=context.FitRules.compare({vehicle:{liters:500},pieces:[{w:30,d:40,h:50,count:1,orientation:'any'}],margin:2});
  assert.equal(r.status,'incomplete');
});
test('opening and interior must permit the same orientation',()=>{
  const r=context.FitRules.compare({vehicle:{openingWidth:45,openingHeight:35,insideWidth:35,insideDepth:55,insideHeight:45},pieces:[{w:30,d:40,h:50,count:1,orientation:'any'}],margin:2});
  assert.equal(r.status,'exceeds');
});
test('multiple objects are only compared individually',()=>{
  const r=context.FitRules.compare({vehicle:{openingWidth:100,openingHeight:100,insideWidth:100,insideDepth:100,insideHeight:100},pieces:[{w:30,d:40,h:50,count:2,orientation:'any'}],margin:2});
  assert.equal(r.status,'separate');
});
test('catalog keeps capacity source and separate dimension conditions',()=>{
  const catalog=JSON.parse(readFileSync(join(root,'vehicle-cargo-2010.json')));
  assert(catalog.models.length>0);
  for(const model of catalog.models){
    assert(model.id && model.brand && model.model);
    for(const variant of model.variants){
      assert(variant.source.url.startsWith('https://'));
      for(const value of variant.capacities)assert(value.liters.length && value.liters.every(v=>Number.isFinite(v)&&v>0));
    }
  }
});
