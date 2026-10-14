#!/usr/bin/env bash
set -e

# Self-check for HLS media error auto-skip logic
node -e '
var window = globalThis;
var r, i, l = { F: { FATAL_HLS_ERROR: "FATAL_HLS_ERROR" } };
var fatalTriggered = false;
function y(e, t) { fatalTriggered = (t === l.F.FATAL_HLS_ERROR); }

// The exact replacement function from patch-jellyfin-web.sh
function m(e,t){var n,c,o=e._hlsPlayer;if(o){var a=Date.now();null!==(n=window.performance)&&void 0!==n&&n.now&&(a=performance.now()),c=e._mediaElement||(o&&o.media),!r||a-r>4e3?(r=a,i=0,console.debug("try to recover media Error ..."),o.recoverMediaError()):++i<=3?(console.warn("corrupt segment detected, skipping 2.5s ahead (attempt "+i+"/3)..."),c&&(c.currentTime+=2.5),o.recoverMediaError(),setTimeout((function(){c&&c.paused&&c.play().catch((function(){}))}),150)):(console.error("cannot recover, repeated media errors despite segment skip ..."),i=0,t?t():y(e,l.F.FATAL_HLS_ERROR))}}

var recoveryTimes = [];
var e = {
    _mediaElement: { currentTime: 425.17, paused: false, play: () => Promise.resolve() },
    _hlsPlayer: {
        recoverMediaError: () => { recoveryTimes.push(e._mediaElement.currentTime); }
    }
};

// 1. First error at corrupt frame (425.17s)
m(e);
if (recoveryTimes[0] !== 425.17) throw new Error("Attempt 1 did not recover at initial time");

// 2. Immediate error recur (decoder hits bad OBU again) -> should skip +2.5s to 427.67s
m(e);
if (Math.abs(recoveryTimes[1] - 427.67) > 0.001) throw new Error("Attempt 2 did not skip +2.5s ahead");

// 3. Third error within window -> skip another +2.5s to 430.17s
m(e);
if (Math.abs(recoveryTimes[2] - 430.17) > 0.001) throw new Error("Attempt 3 did not skip +2.5s ahead");

// 4. Fourth error within window -> skip another +2.5s to 432.67s
m(e);
if (Math.abs(recoveryTimes[3] - 432.67) > 0.001) throw new Error("Attempt 4 did not skip +2.5s ahead");

// 5. Fifth error -> must bail out with fatal error (no infinite loop)
m(e);
if (!fatalTriggered) throw new Error("Attempt 5 did not trigger FATAL_HLS_ERROR");

console.log("✓ All HLS error auto-skip self-checks passed!");
'
