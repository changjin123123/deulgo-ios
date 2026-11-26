const commonCars = {
  현대: ['쏘나타', '아반떼', '그랜저', '싼타페', '투싼', '팰리세이드', '코나', '캐스퍼', '베뉴', '스타리아', '스타렉스', '아이오닉', '아이오닉 5', '아이오닉 6', '아이오닉 9', '넥쏘', '벨로스터', 'i30', 'i40', '엑센트'],
  기아: ['모닝', '레이', 'K3', 'K5', 'K8', '카니발', '쏘렌토', '스포티지', '셀토스', '니로', 'EV3', 'EV4', 'EV5', 'EV6', 'EV9', '쏘울', '스토닉', '스팅어', '모하비', '카렌스'],
  제네시스: ['G70', 'G80', 'G90', 'GV60', 'GV70', 'GV80'],
  쉐보레: ['스파크', '아베오', '크루즈', '말리부', '올란도', '트랙스', '트랙스 크로스오버', '트레일블레이저', '트래버스', '캡티바', '이쿼녹스', '카마로'],
  르노코리아: ['SM3', 'SM5', 'SM6', 'QM6', 'XM3', '아르카나', '캡처', '조에', '마스터'],
  KGM: ['티볼리', '코란도', '액티언', '토레스', '렉스턴', '렉스턴 스포츠', '무쏘 EV'],
  BMW: ['1시리즈', '2시리즈', '3시리즈', '4시리즈', '5시리즈', '6시리즈', '7시리즈', '8시리즈', 'X1', 'X2', 'X3', 'X4', 'X5', 'X6', 'X7', 'Z4', 'i3', 'i4', 'i5', 'i7', 'iX', 'iX1', 'iX2', 'iX3'],
  벤츠: ['A클래스', 'B클래스', 'C클래스', 'E클래스', 'S클래스', 'CLA', 'CLS', 'GLA', 'GLB', 'GLC', 'GLE', 'GLS', 'SL', 'SLK', 'SLC', 'EQB', 'EQC', 'EQE', 'EQE SUV', 'EQS'],
  아우디: ['A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'Q2', 'Q3', 'Q4 e-tron', 'Q5', 'Q7', 'Q8', 'Q8 e-tron', 'TT', 'R8', 'e-tron GT'],
  폭스바겐: ['골프', '티구안', '투아렉', '파사트', '제타', '아테온', '비틀', '폴로', 'ID.4'],
  볼보: ['S60', 'S80', 'S90', 'V40', 'V60', 'V90', 'XC40', 'XC60', 'XC90', 'EX30', 'EX40', 'EX90', 'EC40'],
  테슬라: ['모델 3', '모델 Y', '모델 S', '모델 X'],
  포르쉐: ['911', '718 박스터', '718 카이맨', '마칸', '카이엔', '타이칸'],
  미니: ['쿠퍼', '클럽맨', '컨트리맨'],
  렉서스: ['ES', 'IS', 'LS', 'NX', 'RX', 'UX', 'RZ', 'CT', 'GS'],
  토요타: ['캠리', '프리우스', 'RAV4', '아발론', '코롤라', 'GR86'],
  혼다: ['어코드', '시빅', 'CR-V', 'HR-V'],
  BYD: ['아토 3', '씰', '돌핀'],
  지프: ['랭글러', '레니게이드', '체로키', '그랜드 체로키', '글래디에이터'],
  랜드로버: ['레인지로버', '레인지로버 스포츠', '이보크', '디스커버리', '디스커버리 스포츠', '디펜더'],
};

const additionalModels = {
  bike: {
    혼다: ['PCX', '슈퍼커브', 'ADV350', '포르자 350', '비전 110'],
    야마하: ['NMAX', 'XMAX', '트리시티', 'TMAX'],
    대림: ['시티', 'VF100', 'UHR125'],
    스즈키: ['버그만', '어드레스'],
    SYM: ['조이맥스', '보이저'],
    킴코: ['다운타운', '딜라이트'],
    베스파: ['프리마베라', '스프린트', 'GTS'],
  },
  truck: {
    현대: ['포터 II', '마이티', '메가트럭', '파비스', '엑시언트', 'ST1', '스타리아 카고'],
    기아: ['봉고 III', 'PV5 카고'],
    타타대우: ['더쎈', '프리마', '맥쎈', '구쎈'],
    이스즈: ['엘프'],
    르노코리아: ['마스터'],
  },
};

const domesticReferences = [
  {
    "brand": "현대",
    "name": "베르나"
  },
  {
    "brand": "현대",
    "name": "아슬란"
  },
  {
    "brand": "현대",
    "name": "에쿠스"
  },
  {
    "brand": "현대",
    "name": "제네시스 세단"
  },
  {
    "brand": "현대",
    "name": "베라크루즈"
  },
  {
    "brand": "기아",
    "name": "K7"
  },
  {
    "brand": "기아",
    "name": "오피러스"
  },
  {
    "brand": "기아",
    "name": "K9"
  },
  {
    "brand": "제네시스",
    "name": "EQ900"
  },
  {
    "brand": "제네시스",
    "name": "GV90"
  },
  {
    "brand": "르노코리아",
    "name": "트위지"
  },
  {
    "brand": "KGM",
    "name": "체어맨 H"
  },
  {
    "brand": "KGM",
    "name": "체어맨 W"
  },
  {
    "brand": "KGM",
    "name": "토레스 EVX"
  },
  {
    "brand": "쉐보레",
    "name": "볼트 EV"
  },
  {
    "brand": "쉐보레",
    "name": "볼트 PHEV"
  },
  {
    "brand": "쉐보레",
    "name": "토스카"
  },
  {
    "brand": "쉐보레",
    "name": "알페온"
  },
  {
    "brand": "쉐보레",
    "name": "임팔라"
  },
  {
    "brand": "쉐보레",
    "name": "베리타스"
  },
  {
    "brand": "쉐보레",
    "name": "볼트 EUV"
  },
  {
    "brand": "쉐보레",
    "name": "타호"
  },
  {
    "brand": "마이브",
    "name": "M1"
  },
  {
    "brand": "쎄보모빌리티",
    "name": "CEVO-C"
  },
  {
    "brand": "어울림",
    "name": "스피라"
  }
];
const aliases = {
  '쏘나타': ['소나타', 'Sonata', 'DN8', 'LF'],
  '아반떼': ['아반테', 'Avante', 'Elantra', 'CN7', 'AD'],
  '싼타페': ['산타페', 'Santa Fe', 'MX5'],
  '그랜저': ['그렌저', 'Grandeur', 'GN7', 'IG'],
  '쏘렌토': ['소렌토', 'Sorento', 'MQ4'],
  '카니발': ['Carnival', 'KA4'],
  '모델 3': ['Model 3', '모델쓰리'],
  '모델 Y': ['Model Y', '모델와이'],
  '씨라이언 7': ['Sea Lion 7', 'Sealion 7'],
  'PCX': ['피씨엑스'],
  'NMAX': ['엔맥스'],
  'XMAX': ['엑스맥스'],
  '포터 II': ['포터2', 'Porter 2'],
  '봉고 III': ['봉고3', 'Bongo 3'],
};
const brandAliases = {
  'BMW': ['비엠더블유', '비엠'],
  '벤츠': ['메르세데스', '메르세데스벤츠', 'Mercedes'],
  '현대': ['현대자동차', 'Hyundai'],
  '기아': ['Kia'],
  'BYD': ['비야디', '비와이디'],
  'KGM': ['쌍용', '케이지엠'],
};

function fromGroups(groups) {
  return Object.entries(groups).flatMap(([brand, names]) => names.map(name => ({ brand, name })));
}

function vehicleModels(type, imports = []) {
  if (Object.hasOwn(additionalModels, type)) return fromGroups(additionalModels[type]);
  const vehicles = [...fromGroups(commonCars), ...domesticReferences, ...imports];
  const unique = new Map();
  for (const row of vehicles) {
    const brand = /메르세데스.*벤츠/.test(row.brand) ? '벤츠' : row.brand;
    const key = compact(brand) + ':' + compact(row.name);
    if (!unique.has(key)) unique.set(key, { brand, name: row.name });
  }
  return [...unique.values()];
}

const initials = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
function compact(value) {
  return value.normalize('NFC').toLowerCase()
    .replace(/[ᄀ-ᄒ]/g, letter => initials[letter.charCodeAt(0) - 0x1100])
    .replace(/[^\p{L}\p{N}]/gu, '');
}

function initialOf(letter) {
  const position = letter.charCodeAt(0) - 0xac00;
  return position >= 0 && position < 11172 ? initials[Math.floor(position / 588)] : letter;
}

function matchPosition(candidate, query) {
  for (let start = 0; start <= candidate.length - query.length; start++) {
    if ([...query].every((letter, index) => {
      const next = candidate[start + index];
      return letter === next || (initials.includes(letter) && letter === initialOf(next));
    })) return start;
  }
  return -1;
}

function findVehicleModels(rows, value) {
  const query = compact(value);
  if (!query) return rows;
  return rows.flatMap(row => {
    const names = [row.name, ...(aliases[row.name] || [])].map(compact);
    const brands = [row.brand, ...(brandAliases[row.brand] || [])].map(compact);
    const first = names.map(name => matchPosition(name, query)).filter(index => index >= 0);
    if (names.includes(query)) return [{ row, rank: 0 }];
    if (first.length) return [{ row, rank: first.includes(0) ? 1 : 2 }];
    if (brands.some(brand => names.some(name => matchPosition(brand + name, query) >= 0))) return [{ row, rank: 3 }];
    return [];
  }).sort((a, b) => a.rank - b.rank).map(result => result.row);
}

function nativeVehicleModels(kind, query, imports) { return findVehicleModels(vehicleModels(kind, imports || []), query); }
