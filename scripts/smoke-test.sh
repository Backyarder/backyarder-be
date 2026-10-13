#!/usr/bin/env bash
# Smoke test a deployed (or local) Backyarder stack.
#
#   bash scripts/smoke-test.sh <API_BASE_URL> [FRONTEND_URL]
#
#   API_BASE_URL  e.g. https://backyarder-be.onrender.com/api/v1  (no trailing slash)
#   FRONTEND_URL  e.g. https://backyarder.vercel.app  (optional)
#
# Set SKIP_PERENUAL=1 to skip the checks that may call Perenual (detail and
# search). Each run of those costs up to 2 calls on a cold cache against the
# free tier's 100/day budget; use this flag for routine deploy checks.
#
# Checks the API is up, the garden is seeded, mock plant data loads, and the
# Perenual-backed search and detail endpoints return real data. If a frontend
# URL is given, also checks the deployed bundle points at this API.
# Exits non-zero on the first failure.

set -u
API="${1:?usage: smoke-test.sh <API_BASE_URL> [FRONTEND_URL]}"
FRONTEND="${2:-}"
API="${API%/}"
TIMEOUT=90   # free-tier hosts cold start slowly
PASS=0; FAIL=0

say()  { printf '%s\n' "$*"; }
ok()   { PASS=$((PASS+1)); say "  PASS  $1"; }
bad()  { FAIL=$((FAIL+1)); say "  FAIL  $1"; [ -n "${2:-}" ] && say "        $2"; }

# get <path> -> sets BODY and CODE
get() {
  local out
  out=$(curl -sS -m "$TIMEOUT" -w $'\n%{http_code}' "$API$1" 2>&1) || { BODY="$out"; CODE="000"; return; }
  CODE="${out##*$'\n'}"
  BODY="${out%$'\n'*}"
}

# count_data -> number of items in {"data":[...]} using python (present on dev machines and CI)
count_data() { printf '%s' "$BODY" | python -c 'import sys,json; d=json.load(sys.stdin)["data"]; print(len(d) if isinstance(d,list) else 1)' 2>/dev/null || echo "-1"; }
json_get()   { printf '%s' "$BODY" | python -c "import sys,json; v=json.load(sys.stdin); print($1)" 2>/dev/null; }

say "Smoke testing API at $API"

# 1. root
get "/"
if [ "$CODE" = "200" ] && [[ "$BODY" == *"Welcome to Backyarder"* ]]; then ok "GET / is up"; else bad "GET / (HTTP $CODE)" "$(printf '%s' "$BODY" | head -c 200)"; fi

# 2. garden seeded with 100 cells
get "/garden"
n=$(count_data)
if [ "$CODE" = "200" ] && [ "$n" = "100" ]; then ok "GET /garden returns 100 cells"; else bad "GET /garden (HTTP $CODE, $n cells; expected 100)"; fi

# 3. plant list (mock json, no third party)
get "/plants"
n=$(count_data)
if [ "$CODE" = "200" ] && [ "$n" -gt 0 ] 2>/dev/null; then ok "GET /plants returns $n plants"; else bad "GET /plants (HTTP $CODE, $n plants)"; fi

# 4. decor list
get "/decor"
n=$(count_data)
if [ "$CODE" = "200" ] && [ "$n" -gt 0 ] 2>/dev/null; then ok "GET /decor returns $n items"; else bad "GET /decor (HTTP $CODE, $n items)"; fi

# 5/6. Perenual-backed endpoints (cached after first use; skippable)
if [ "${SKIP_PERENUAL:-0}" = "1" ]; then
  say "  SKIP  GET /plants/1 and /search/maple (SKIP_PERENUAL=1)"
else
get "/plants/1"
name=$(json_get 'v["data"]["attributes"]["name"]')
typ=$(json_get 'v["data"]["attributes"]["type"]')
secs=$(json_get 'len(v["data"]["attributes"]["section"])')
if [ "$CODE" = "200" ] && [ -n "$name" ] && [ "$typ" != "None" ] && [ "${secs:-0}" -gt 0 ] 2>/dev/null; then ok "GET /plants/1 -> $name ($typ, $secs care sections)"; else bad "GET /plants/1 (HTTP $CODE) - Perenual detail data missing" "$(printf '%s' "$BODY" | head -c 200)"; fi

# 6. search (Perenual v1 care guide + v2 details)
get "/search/maple"
n=$(count_data)
first=$(json_get 'v["data"][0]["attributes"]["name"]')
wat=$(json_get 'v["data"][0]["attributes"]["watering"]')
if [ "$CODE" = "200" ] && [ "$n" -gt 0 ] 2>/dev/null && [ "$wat" != "None" ]; then ok "GET /search/maple -> $n results, first: $first (watering: $wat)"; else bad "GET /search/maple (HTTP $CODE, $n results, watering=$wat)" "$(printf '%s' "$BODY" | head -c 200)"; fi
fi

# Perenual budget visibility
get "/perenual-usage"
used=$(json_get 'v["count"]'); lim=$(json_get 'v["limit"]')
if [ "$CODE" = "200" ] && [ -n "$used" ]; then ok "GET /perenual-usage -> $used of $lim calls used today"; else bad "GET /perenual-usage (HTTP $CODE)"; fi

# 7. garden stats (should be valid JSON even when empty)
get "/garden-stats"
if [ "$CODE" = "200" ] && printf '%s' "$BODY" | python -c 'import sys,json; json.load(sys.stdin)' 2>/dev/null; then ok "GET /garden-stats returns JSON"; else bad "GET /garden-stats (HTTP $CODE)" "$(printf '%s' "$BODY" | head -c 200)"; fi

# 8. CORS header present for a browser origin
hdr=$(curl -sS -m "$TIMEOUT" -i "$API/garden" -H "Origin: ${FRONTEND:-http://localhost:3001}" 2>/dev/null | grep -i "^access-control-allow-origin" | tr -d '\r')
if [ -n "$hdr" ]; then ok "CORS: $hdr"; else bad "CORS: no access-control-allow-origin header for origin ${FRONTEND:-http://localhost:3001}"; fi

# 9. frontend bundle points at this API
if [ -n "$FRONTEND" ]; then
  FRONTEND="${FRONTEND%/}"
  html=$(curl -sS -m "$TIMEOUT" "$FRONTEND/" 2>&1)
  if [[ "$html" == *"<title>BackYarder</title>"* ]]; then ok "Frontend $FRONTEND serves the app"; else bad "Frontend $FRONTEND did not return the BackYarder page"; fi
  # find main js bundle(s) and look for the API host
  host="${API#*://}"; host="${host%%/*}"
  found=0
  for js in $(printf '%s' "$html" | grep -o 'src="[^"]*\.js"' | sed 's/src="//; s/"$//'); do
    case "$js" in http*) url="$js";; /*) url="$FRONTEND$js";; *) url="$FRONTEND/$js";; esac
    if curl -sS -m "$TIMEOUT" "$url" 2>/dev/null | grep -q "$host"; then found=1; break; fi
  done
  if [ "$found" = "1" ]; then ok "Frontend bundle references $host"; else bad "Frontend bundle does not reference $host" "Set REACT_APP_API_URL=$API in the frontend host (Vercel) and redeploy."; fi
fi

say ""
say "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
