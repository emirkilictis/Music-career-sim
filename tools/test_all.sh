#!/bin/bash
# Every test, as the web build runs them before publishing (docs K309,
# K310). From the repository's root:  bash tools/test_all.sh
# Takes about half an hour; the game sessions are the long part.
set -u
cd "$(dirname "$0")/.."
fail=0
step() {
  echo "== $1"
  if ! (cd "$2" && eval "$3"); then
    echo "!! $1 FAILED"
    fail=1
  fi
}
flutter pub get >/dev/null
step 'simulation' packages/simulation_core 'dart analyze && dart test -r failures-only'
step 'saves' packages/persistence 'dart test -r failures-only'
step 'game sessions' packages/game 'dart analyze && dart test -r failures-only'
step 'app' app 'flutter analyze && flutter test'
if [ $fail = 0 ]; then echo 'ALL PASSED'; else echo 'SOMETHING FAILED (see above)'; fi
exit $fail
