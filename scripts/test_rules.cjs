const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');
const root = join(__dirname,'../Deulgo/Resources');
const context = vm.createContext({});
for (const file of ['vehicle-models.js','listing-rules.js','fit-rules.js']) vm.runInContext(readFileSync(join(root,file),'utf8'),context);
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
