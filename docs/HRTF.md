# Choosing a head response (HRTF)

Virtual surround works by filtering each speaker's sound the way a head and ears would, from that direction. The filter depends on
the shape of your head and ears, and everyone's differs. A set measured on someone whose ears resemble yours sounds convincing;
a mismatched one can sound flat, tinny, or put rear sounds in front of you. Tuxwell ships the **SADIE II** database
(University of York, Apache-2.0): **2 dummy heads (D1, D2; D1 is the default) and 18 people (H3 to H20)**. They download on demand (8 to 36 MB each) and
are checked against a pinned SHA-256.

## Find yours (about 5 minutes)
1. Turn the headset on and open Tuxwell. In **Audio**, pick a set under **Head response** and press **Play** under *Test sound*.
2. Listen to the two rounds:
   - **Round 1** walks a circle: front, front-right, right, back-right, back-left, left, front-left. It should feel like a ring around your head, outside it.
   - **Round 2** alternates front and back. A good match makes the back sounds clearly behind you. A poor one folds them to the front.
3. Try a handful (start with D1, D2 and three or four people). Keep the one where front and back are easiest to tell apart and the sound stays out of your head.
4. Confirm with something you know well (a film scene with rain or crowds, or a game with footsteps), then leave it for a few days.

5. Then try **Headphone correction** (step 3 in the app). With the Maxwell 2 data, *Neutral* is the one to start with; flip it on and off while something plays and keep it only if it sounds better to you. The change is gentle by design.

Command line: `tuxwell-hrtf list`, `tuxwell-hrtf use H5`, `tuxwell-test-sound`.

## Notes
- The result is subjective and personal. There is no single best set.
- Surround level and centre boost interact with the chosen set. The level was matched on D1; another set can sound a little louder or quieter. Use the *Surround level* slider.
- Switching restarts the surround for a second or two (audio blips).
