# iPhone 0.1.3 UI verification

final result: passed

## Findings

No actionable P0/P1/P2 findings remain for the inspected sending form and home entry on iPhone 17 Pro in light appearance. This passes native screen/interaction QA, not public-server readiness, device installation or every accessibility configuration. IPA packaging succeeded after owner approval at 03:11 KST on 2026-11-27; the downloaded 0.1.3 (4) file passed version, arm64, native-key-presence and integrity checks.

- Resolved P1: downward swipe did not dismiss the keyboard in run #7 attempt 2. The original failure recording also showed the keyboard still visible after the swipe. Immediate scroll dismissal is now verified by the passing run #9 test and `Send-form-scroll-dismissed.png`.
- Resolved P2: faint input boundaries/prompts and small helper text. System-gray borders, explicit 60%-primary prompts/helpers and 15-point helpers were recaptured in runs #8 and #9. Combined full and focused comparisons show legible fields and reference-aligned hierarchy.
- Run #8 separately failed the toolbar-close expectation although its recording showed the keyboard closed and Next restored. A single accessibility query took about 4.3 seconds of a 5-second budget. The test now performs fresh queries with a 15-second limit; the keyboard-absence assertion and all other conditions remain intact. Run #9 passed them all. Timing/query behavior was the suspected test issue; the successful rerun does not establish a wider platform diagnosis.

## Comparison evidence

- Source visual: `../generated_images/exec-dcdf9037-8d62-4ed7-8d8f-9e15f37e60c1.png`, selected option 2 with `무엇을 보낼까요?`. Private reference bytes are not committed publicly.
- Implementation source: `21a733219b5d2f409476ddde398422c740786ddc`, run #9.
- Implementation screen: `../deulgo-0.1.3/run9-tests/screens/Send-form-keyboard-closed.png`.
- Full-view combined comparison: `../deulgo-0.1.3/run9-tests/screens/send-comparison.png`.
- Focused input-region comparison: `../deulgo-0.1.3/run9-tests/screens/send-focused.png`.
- Interaction/home contact sheet: `../deulgo-0.1.3/run9-tests/screens/interaction-states.png`; originals are in the same folder.
- Source: 887 × 1774 px, no status bar. Native: 1206 × 2622 px, 402 × 874 points at 3×, iPhone 17 Pro / iOS 26.4.1.
- Both images were proportionally normalized to 402 px width. Full-view source offset is 53 px to approximately align navigation. Focused crops use source y=120–505 and native y=195–580. This is not a pixel-perfect viewport match; system bars and tab-root navigation differ.
- Matching comparison state: empty send form, light appearance, keyboard closed. Additional native states: keyboard open, toolbar dismissed, scroll dismissed with `Test parcel` preserved, home and request preparation.
- Browser-rendered evidence is not applicable to the requested native SwiftUI application. Actual native simulator screens were captured; no website imitation substitutes for the app.

## Required fidelity surfaces

- Fonts/typography: native system family, semibold link label, bold item heading and semantic 15-point helpers preserve the reference hierarchy. Prompts and helper sentences remain readable without clipping or unwanted wrapping. Native rendering/optical weight is an accepted platform difference.
- Spacing/layout: plain white form, link-only box, external link helper, separate item helper, underlined item entry, collapsed optional details and bottom CTA match the selected composition. Native 24-point margins, platform navigation insets and no back arrow on the tab-root screen are intentional. Full/focused views show no hidden persistent controls or changed content density requiring a fix.
- Colors/tokens: existing flat brand green is retained rather than the mock's illustrated texture. Dynamic primary helper colors and system-gray inactive boundaries resolve the earlier contrast issue. Green disclosure text follows the native interaction tint. Dark appearance remains untested.
- Image/asset quality: the form has no decorative image assets. Existing system symbols, native tab icons and iOS 26 tab material are intentional platform elements; no raster mock was embedded in the app. Real listing thumbnails were outside this empty-state comparison.
- Copy/content: exact `무엇을 보낼까요?`, both helper sentences and optional-link/detail labels are present. Retry/paste controls stay absent in the ordinary empty state. Home has `가는 김에 · 장거리 운반` and `운반 요청 둘러보기`, with truthful preparation status for the unconnected public service.

## Interaction and runtime evidence

- Run #9: 28 unit tests + 2 UI tests passed, failures 0, skipped 0; six JavaScript rule tests also passed.
- Send test: keyboard opens, Next is absent while typing, no keyboard `입력 완료` button, toolbar close works, Next returns to its original y position (within 3 points), helper tap closes keyboard, typed name survives, downward swipe closes keyboard, Next reaches the address step.
- Home test: direct board entry opens `공개 요청 목록 준비 중` without diverting through vehicle registration.
- Native captures visibly confirm keyboard dismissal/Next restoration and home region layout. Separate simulator app launch/home capture also succeeded.
- Xcode emitted support-framework copy diagnostics saying exit code 0 produced no output, and debugger-version warnings; final compilation, tests and capture succeeded. Browser console does not apply.

## Comparison history

1. Initial QA blocked: native rendered evidence missing.
2. Run #7 attempt 1: hosted Mac runner acquisition failure, no app execution.
3. Run #7 attempt 2: 29/30 tests; scroll failure and input-contrast P2 recorded from native evidence.
4. Run #8: contrast recapture passed, but toolbar-close expectation timed out despite visible dismissal. Tests still 29/30. Overall QA remained blocked.
5. Fresh-query/15-second expectation correction, retaining all assertions. Run #9: 30/30 tests, fresh full/focused comparison and keyboard/home captures inspected. P1/P2 resolved; result passed.

## Implementation checklist

- [x] Compare full and focused native form captures with the selected design.
- [x] Verify corrected contrast, keyboard controls, scroll dismissal and Next/address flow.
- [x] Verify dedicated long-distance home entry and truthful public-request state.
- [x] Obtain owner approval for key-using package job and verify the generated IPA before delivery.

## Remaining coverage gaps

Small screens, Dynamic Type, dark mode, VoiceOver, real listing responses, Sideloadly updates/data retention and external navigation handoff require separate checks. Actual public requests remain unconnected and are not represented by fake entries.
