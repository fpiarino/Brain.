#!/bin/bash
# Pubblica un riepilogo del log di xcodebuild sul branch "ci-logs",
# così si può leggere anche da strumenti che non scaricano gli artifact.
# Uso: publish-log.sh <file-log> <nome>
set -u
LOG="$1"
NAME="$2"
OUT=$(mktemp -d)

if [ -f "$LOG" ]; then
  grep -nE "error:|: warning:|failed|Test Case .* (passed|failed)|Executed [0-9]+ test|\*\* (TEST|BUILD) (SUCCEEDED|FAILED|INTERRUPTED)" "$LOG" | head -3000 > "$OUT/$NAME-summary.txt" || true
  tail -n 400 "$LOG" > "$OUT/$NAME-tail.txt"
  gzip -c "$LOG" > "$OUT/$NAME-full.log.gz"
else
  echo "Log non trovato: $LOG" > "$OUT/$NAME-summary.txt"
fi
echo "run ${GITHUB_RUN_ID:-?} commit ${GITHUB_SHA:-?}" > "$OUT/$NAME-run.txt"

cd "$OUT"
git init -q -b ci-logs
git remote add origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
# Parte dal branch esistente, se c'è, per non cancellare i log dell'altro job.
if git fetch -q --depth 1 origin ci-logs 2>/dev/null; then
  git reset -q FETCH_HEAD
fi
git add -- "$NAME"-*
git -c user.name="ci" -c user.email="ci@users.noreply.github.com" commit -qm "Log $NAME run ${GITHUB_RUN_ID:-?}" || true
git push -q -f origin HEAD:ci-logs
