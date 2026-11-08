# Native capture fallback

## Fixed reproduction and acceptance

Capture a full-resolution image of the ordinary GPU-rendered Windows game and a short sequence of its actual moving settlers, after real keyboard/mouse input. Retain an exact source/artifact identity. Each capture attempt must finish within 30 seconds or be terminated externally. Keep capture readbacks outside the timed frame-pacing windows. An owned native window must close after the test; unrelated applications remain untouched.

## Disqualifiers

Reject a headless dummy-renderer image as native GPU evidence, a reconstructed mockup, a gameplay-state mutation posing as real input, measurements that include expensive screenshot readback, an unbounded timeout in the same blocked event loop, or a result requiring termination of unrelated processes. Browser captures can establish responsive layouts but cannot alone establish Windows executable behavior.

## Attempts

The Windows computer-use screenshot bridge stalled twice: approximately 821 seconds in the first call and 407 seconds in the second. The second used screenshot-only capture, Promise.race and a node timeout, but the native bridge prevented those in-process timers from firing. Both attempts were interrupted; owned native process watchdogs had already closed their game windows. No more screenshot-bridge retries are planned. Real-key actions succeeded and the read-only GPU observer completed, so the failure does not establish a game rendering problem.

A separate renderer-level capture is being evaluated: the read-only observer saves the ordinary viewport texture after a rendered frame, without mutating gameplay. A fresh reviewer will check the mechanism and its false-pass risks; native execution and artifact inspection remain necessary.

## Final disposition

A later key-only bridge call also hung for 183.9 seconds, so native OS-input delivery is not accepted as verified. No further bridge retry or alternative shell UI automation was used. The original real-OS-input capture criterion above remains unmet. Independent capture-review.md accepts the bounded fallback only for its stated purpose: the matching official native engine loads the unchanged export pack, ordinary Godot input events drive production controls, and a read-only post-draw observer records rendered positions, clocks and viewport PNGs. External watchdogs bound runs and close owned processes. Screenshot readback and recovery are outside timed samples. The final fallback passes the native GPU workload and visual checks recorded in acceptance.md and native-regions-acceptance.json; browser tests separately exercise real keyboard and mouse controls. No compositor timing or natural-cadence video claim is made.
