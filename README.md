# 들고 · iPhone 앱

물건을 보내는 사람과 가는 길에 운반하는 사람을 위한 SwiftUI 앱의 첫 통합 구현이다. iPhone부터 완성하고 Android는 그다음 진행한다.

0.1.1 (2)는 **iPhone 기기용 빌드 성공 · XCTest 21개 및 규칙 검사 6개 통과 · 시뮬레이터 홈 화면 실행 확인** 상태다. 보내기 순서 변경과 보호된 환경의 카카오 키가 새 IPA에 반영됐고, 키 값 출력 없이 설정 포함 검사를 통과했다. 외부 내비 앱의 실제 목적지 전달은 아직 확인 전이며, 실제 이용자 간 배차·결제 서비스는 아직 아니다.

[성공한 빌드와 산출물](https://github.com/changjin123123/deulgo-ios/actions/runs/45841591387) · [Windows에서 iPhone 테스트 설치](INSTALL.md) · [검증 범위](VALIDATION.md)

## 이번 구현

| 화면 | 동작 |
|---|---|
| 홈 | 보내기·운반하기 진입, 최근 저장 요청 |
| 보내기 | 첫 단계에서 중고거래 링크(선택) → 무엇을 보내나요? 순서, 이후 주소 → 최종 확인, 요청 기기 저장 |
| 거래글 | 공식 상품 링크 검증, Apple LinkPresentation 공개 미리보기 조회, 복사한 내용 적용, 사진·제목 중심 접힌 설명 |
| 주소 | Apple 지도 검색 결과 확인, 수동 주소 입력, 상세주소 분리, 주소 저장·재사용 |
| 운반하기 | 차량 등록·수정·삭제, 차종 초성/별칭 검색, 2010년 이후 연식 또는 몰라요, 간단한 적재 방식 선택 |
| 차량 자료 | 기존 2010년 이후 적재 용량 자료의 L 값·출처·판본·상세 치수 조건 표시 |
| 조건 비교 | 직접 입력한 치수·무게·인원·장비 비교, 누락값은 확인 필요로 표시 |
| 내역 | 저장한 요청 조회·검색·수정·삭제, 확인된 좌표를 길 안내로 전달 |
| 내 정보 | 기기 저장 상태·주소록·현재 이용 범위 |
| 길 안내 | 카카오내비·네이버지도 목적지 전달, 미설치·실패 안내 |

물품 가격 입력은 없다. 차량 제원은 운반자 화면에만 있다. 차량 이름을 따로 붙일 필요 없이 모델명으로 표시한다. 치수는 선택 입력이다. L 용량을 차량 내부 치수로 환산하거나 적재 가능 판정에 사용하지 않는다.

## 지금 할 수 없는 것

- 로그인·본인 확인, 다른 기기/기존 웹과 동기화
- 실제 요청 공개, 운반자 매칭·수락, 12시간 게시 만료·택배 전환
- 배송비 확정·결제·정산·보험 가입·운반 자격 검증
- 서버 주문 상태·실제 픽업/배송 완료 처리
- 모든 거래글의 자동 조회 보장

기존 웹의 서버 인증을 iPhone에 그대로 복사하거나 소유자 토큰을 앱에 넣지 않았다. 요청 저장을 실제 주문 접수로 표시하지 않는다. 샘플 요청을 다른 이용자의 실시간 요청처럼 표시하지 않는다.

## 데이터와 동작 경계

요청·주소·차량은 이 기기의 Application Support 보호 파일에 원자적으로 저장하며 iCloud 백업 대상에서 제외한다. 저장 실패 시 화면 상태를 저장 성공 상태로 바꾸지 않는다. 읽을 수 없는 기존 파일도 새 빈 파일로 덮어쓰지 않는다. 기기 변경·앱 삭제 전에 데이터 이동 기능이 별도로 필요하다.

주소의 기본 텍스트를 수정하면 기존 좌표를 무효화한다. 상세주소는 내비 앱에 전송하지 않는다. 검색어만 Apple 지도에 전송하고 사용자가 지도·주소를 확인한 결과만 목적지로 사용한다. 기본 위치 권한은 요청하지 않으며 운전 시작 위치는 외부 내비가 처리한다.

거래글은 버튼을 눌렀을 때 Apple의 LinkPresentation으로 공개 정보를 요청한다. 기존 웹 서버의 공개 메타데이터 조회와 다른 경로이므로 실제 플랫폼별 성공 여부는 iPhone에서 재확인해야 한다. 당근부동산·카페·허용되지 않은 호스트는 상품 조회 대상으로 받지 않는다. 불러오지 못하면 복사한 내용 또는 직접 입력을 사용한다. 가격은 요청 필드로 가져오지 않는다. 미리보기 적용 시 기존 입력을 바꾸는 경우 확인을 받는다.

운반자 준수사항은 기존 시제품 문구를 **검토안** 표시와 함께 유지했다. 법적 효력·처벌·보험 보장 확정을 의미하지 않는다.

## 개발 구조

- `DeulgoRootView.swift`: 앱 탭·홈·내 정보
- `ShipmentEditor.swift`: 요청 폼·주소록
- `CarrierViews.swift`: 차량 등록·모델 선택·적재 자료
- `RequestHistory.swift`: 요청 내역·조건 비교
- `AppStore.swift`: 기기 저장
- `ListingImport.swift`: 상품 링크 검증·공개 미리보기
- `ReferenceData.swift`, `Resources/`: 기존 순수 규칙과 차량 참고 자료
- `Navigation*.swift`, `ExternalNavigation.swift`, `PlaceSearch.swift`: 목적지와 내비 연결
- `DeulgoTests/`: XCTest 21개 (실행 통과)
- `scripts/test_rules.cjs`: 실제 번들 규칙을 DOM 없는 JavaScript 환경에서 검증

차량 카탈로그는 기존 시제품 자료를 복사한 것으로 이번 작업에서 개별 제원을 재조사하지 않았다. 미확보값은 그대로 유지하며 판본·좌석 상태·시장 차이를 숨기지 않는다. 현재 물품 요청은 같은 크기 물품 1종, 수량 1~10개다. 기존 웹의 여러 종류/분해 조각 입력은 후속 이식 항목이다.

## 빌드

Xcode 26+, iOS 17+가 필요하다. `Deulgo.xcodeproj`를 열고 공유 Scheme `Deulgo`를 사용한다.

```sh
python3 scripts/check_structure.py
node --test scripts/test_rules.cjs
xcodebuild test -project Deulgo.xcodeproj -scheme Deulgo \
  -destination 'platform=iOS Simulator,name=<설치된 iPhone 시뮬레이터 이름>'
```

`.github/workflows/ios-check.yml`은 원본 저장소의 `main`에서 수동 실행한다. `ios-release` 환경의 본인 승인 후 XCTest 결과 개수 확인, 시뮬레이터 앱 실행·캡처, 기기용 Release 빌드와 unsigned IPA 생성을 진행한다. 2026-11-27 00:01 KST에 성공한 실행 #5의 기준판은 0.1.1 (2), 커밋 `69415e4a42310dfe1e55bf5fc4fa338f997befbb`다. unsigned IPA는 서명/재서명 후 설치해야 하며 그대로 설치되는 파일은 아니다. GitHub Actions 산출물 보관 기간은 7일이다.

`Config/Local.xcconfig.example`을 `Config/Local.xcconfig`로 복사해 Apple 팀·확정 번들 ID·카카오 Native app key를 설정한다. 임시 번들 ID는 `com.deulgo.delivery`이며 등록·소유권 확인을 의미하지 않는다. 실제 설치 번들 ID와 카카오 iOS 설정값은 일치해야 한다. REST API/Admin 키는 앱에 넣지 않는다.

카카오 앱과 iOS 번들 ID 등록은 완료했다. GitHub의 `ios-release` 환경 비밀값 `KAKAO_NATIVE_APP_KEY`를 Release 빌드 직전에만 주입한다. 키가 없거나 잘못되면 배포용 빌드를 중단하고, 산출물에 키와 번들 ID가 올바르게 반영됐는지 값 출력 없이 검사한다. 네이버지도 부분은 Ncloud REST API 키 없이 테스트할 수 있다. 로컬 빌드의 카카오 키 공란은 앱에서 준비 안내로 처리한다.

### 키를 사용하는 빌드 승인

- 환경 `ios-release`: 저장소 소유자를 필수 승인자로 지정, 관리자 승인 우회 해제, `main` 브랜치만 허용.
- 키는 일반 Repository secret에 중복 저장하지 않는다. 워크플로에서 환경 참조를 빼면 환경 비밀값도 받을 수 없다.
- Actions 실행의 `Review deployments`에서 변경 코드와 실행 커밋을 확인한 뒤 승인한다. 단독 소유자가 직접 실행한 빌드도 승인할 수 있도록 self-review는 허용한다.
- 외부 공동작업자는 2026-11-26 확인 시 0명이다. 추후 권한 부여 및 설치 앱·토큰 관리 시 별도 검토가 필요하다.
- 환경 승인은 계정 탈취나 관리자의 보호 설정 변경까지 막지는 않는다. 공개 소스에 키를 기록하지 않지만 완성된 IPA에는 네이티브 앱 키가 포함되므로 추출 가능하다. 어드민 키·서버 비밀값은 앱에 포함하지 않는다.

앱 아이콘·스토어 설명·개인정보 정책·Apple 배포 설정·서버 기능은 출시 전에 추가해야 한다.

## 다음 완료 조건

1. 실제 iPhone에 서명 설치하고 작은 화면·큰 글자·다크 모드·VoiceOver, 요청 저장과 복원 확인.
2. 당근·번개장터·중고나라 공개 링크, 차단/앱 전용 링크의 실패 안내 확인.
3. 키를 반영한 새 IPA로 두 내비 앱 설치/미설치 및 목적지 전달 확인.
4. 계정·서버 주문·배차·결제·자격/보험 절차를 단계적으로 연결.

## 공식 문서

- [Apple LinkPresentation](https://developer.apple.com/documentation/linkpresentation)
- [Apple MKLocalSearch](https://developer.apple.com/documentation/mapkit/mklocalsearch)
- [카카오내비 iOS](https://developers.kakao.com/docs/ko/kakaonavi/ios)
- [카카오 iOS SDK](https://developers.kakao.com/docs/ko/ios/getting-started)
- [네이버지도 앱 연결](https://guide.ncloud-docs.com/docs/application-maps-url-scheme-vpc)
