# iPhone 0.1.3 UI verification

final result: blocked

## Findings

- [P1] A downward scroll did not fully dismiss the keyboard. Evidence: run #7 attempt 2, `ShipmentUITests.testSendKeyboardDismissalAndBottomAction`, activity `Swipe down "shipment.itemScroll" ScrollView` followed by the keyboard absence expectation timeout. The toolbar close, helper tap and bottom-action restoration assertions before this point passed. Fix: replace interactive dismissal with immediate dismissal when scrolling begins. Status: source fixed, runtime recheck pending.
- [P2] The inactive input outline, underline and example text were much fainter than the selected design. Helper text was also smaller. Evidence: `send-comparison.png`, source/implementation viewed together. Fix: system-gray borders, explicit dynamic primary color at 60% opacity for prompts/helpers, and 15-point helper text. Status: source fixed, recapture pending.

## Comparison evidence

- Source: `../generated_images/exec-dcdf9037-8d62-4ed7-8d8f-9e15f37e60c1.png`, private selected option 2 with `무엇을 보낼까요?`. Image bytes are not committed publicly.
- Implementation: `../deulgo-0.1.3/attempt2-tests/screens/Send-form-keyboard-closed.png` from the native test result for commit `5fa9c0f42268504f603a208ac58849ac8efc459a`.
- Full-view combined comparison: `../deulgo-0.1.3/attempt2-tests/screens/send-comparison.png`.
- Other inspected native captures: `Send-form-keyboard-open.png` and `Home-long-distance-entry.png` in the same folder.
- Source: 887 × 1774 px, no system status bar. Native: 1206 × 2622 px, 402 × 874 points at 3× density. Both were normalized to 402 px wide without changing aspect ratio. The source was offset 53 px down to approximately align navigation content; this is not a pixel-perfect device match.
- State: empty send form, light appearance, keyboard closed; separate native capture for keyboard open. Home capture shows the dedicated long-distance region and request entry above the fold.
- Focused comparison: pending after fixes. Current report does not claim a passed visual review from the full-view image alone.
- Browser-rendered evidence: not applicable to this native SwiftUI app. Evidence is from native simulator screenshots, not a website imitation.

## Fidelity surfaces

- Typography: native system font and semantic heading hierarchy retained. Helper type was visibly smaller than the reference and is increased; recapture required.
- Spacing/layout: plain white form, link-only box, external helpers, underlined item field, collapsed details and bottom action follow the selected arrangement. Native 24-point margins and platform navigation insets remain intentional. The tab-root screen has no mock back arrow because it is selected through the app tab.
- Colors: existing green brand token retained. Inactive boundaries/prompts required the P2 correction above. Dark appearance remains untested.
- Image/asset quality: this empty form uses text and system symbols, no decorative image assets. Existing native tab symbols and iOS 26 tab-bar material differ intentionally from the illustrative mock. They were not replaced with raster art.
- Copy/content: `무엇을 보낼까요?` and both helper sentences match the selected copy. Retry/paste controls are absent in the normal empty state. Home shows `가는 김에 · 장거리 운반` and `운반 요청 둘러보기`; it clearly says the public connection is in preparation.

## Interaction evidence

- 28 unit tests and the home request-board UI test passed; send UI test failed at scroll dismissal.
- Send test passed heading/normal-state checks, keyboard open without Next, no keyboard `입력 완료` button, toolbar close, Next restored to its original vertical position, helper tap to close, and typed-name preservation.
- Final Next-to-address navigation was not reached because the earlier scroll check failed. It remains in the test for the next run.
- Native logs contained no Swift compiler error. Xcode logged an LLDB version warning; this is separate from the recorded keyboard assertion failure. No browser console applies.

## Comparison history

1. Before first CI: blocked because native evidence was missing.
2. Run #7 attempt 1: runner acquisition failed; no app execution.
3. Run #7 attempt 2: native evidence obtained and compared; P1 scroll behavior and P2 input contrast/helper size recorded.
4. Source corrections applied. New screenshots and all 30 tests are still required before passing.

## Implementation checklist

1. Run the corrected source through protected CI.
2. Confirm all 30 tests including scroll dismissal and Next-to-address navigation pass.
3. Compare the recaptured empty form against the source in a combined full view and focused input-region view.
4. Inspect home and keyboard states; only then verify and deliver the new IPA.

## Remaining coverage gaps

Small screens, Dynamic Type, dark mode, VoiceOver, real listing responses and external navigation handoff require separate device checks. Actual public requests remain unconnected and are not represented by fake entries.
