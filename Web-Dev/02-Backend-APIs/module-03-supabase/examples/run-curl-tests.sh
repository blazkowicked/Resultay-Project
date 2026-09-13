#!/usr/bin/env bash
#
# =============================================================================
#  run-curl-tests.sh
#
#  Stretch goal — runs every CURL command from curl-commands.sh sequentially,
#  verifies each one against the API spec:
#    * the HTTP status code matches the expected code, and
#    * the response body contains the expected shape markers.
#  Prints a formatted PASS/FAIL/SKIP summary.
#
#  Usage:
#    bash examples/run-curl-tests.sh
#  Optionally override the connection defaults:
#    BASE_URL=... ANON_KEY=... USER_JWT=... bash examples/run-curl-tests.sh
#
#  On Windows, run from Git Bash or WSL.
# =============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=curl-commands.sh
source "$SCRIPT_DIR/curl-commands.sh"

PASS=0
FAIL=0
SKIP=0
failures=()

# -----------------------------------------------------------------------------
#  check <name> <expected_code> <full_output> <marker> [<marker> ...]
#  Verifies the last line of $3 matches "[HTTP <expected_code>]" and that the
#  body contains every marker (literal substring, grep -F).
# -----------------------------------------------------------------------------
check() {
  local name="$1" expected="$2" out="$3"
  shift 3
  local code body ok=1
  code="$(printf '%s\n' "$out" | tail -n 1)"
  body="$(printf '%s\n' "$out" | sed '$d')"
  if [[ "$code" != "[HTTP $expected]" ]]; then ok=0; fi
  for marker in "$@"; do
    if ! printf '%s' "$body" | grep -qF -- "$marker"; then ok=0; fi
  done
  if (( ok )); then
    PASS=$((PASS + 1))
    printf '  [PASS]  %-52s %s\n' "$name" "$code"
  else
    FAIL=$((FAIL + 1))
    printf '  [FAIL]  %-52s expected [HTTP %s], got %s\n' "$name" "$expected" "$code"
    failures+=("$name (expected HTTP $expected, got $code)")
  fi
}

skip() {
  SKIP=$((SKIP + 1))
  printf '  [SKIP]  %-52s no project id captured (check BASE_URL/keys)\n' "$1"
}

printf '%s\n' "== API contract checks (module-03-supabase backend) =="
echo

# --- 1) GET /projects .................................. expect 200
# Shape: bare PostgREST array -> marker '[' (a spec-compliant backend would
# return {"status":"success","data":[...],"pagination":{...}}).
out="$(get_projects)"
check "GET /projects" 200 "$out" "["

# --- 2) GET /projects?page=1&limit=1 ................... expect 200
out="$(get_projects_paged 1 1)"
check "GET /projects (paged)" 200 "$out" "["

# --- 3) POST /projects (valid) ......................... expect 201
out="$(create_project)"
check "POST /projects" 201 "$out" '"id"' '"title"'
PROJECT_ID="$(extract_id "$out")"

# --- 4) POST /projects (invalid: missing required title) expect 400
out="$(create_project '{"description":"missing the required title field"}')"
check "POST /projects (invalid body)" 400 "$out" 'not-null constraint'

# --- 5) GET /projects/:id (nonexistent id) ............. expect raw 200 + [] (spec: 404 via backend)
out="$(get_project '00000000-0000-0000-0000-000000000000')"
check "GET /projects/:id (missing id)" 200 "$out" "[]"

echo
echo "--- id-dependent checks (use PROJECT_ID from the POST above) ---"
if [[ -z "$PROJECT_ID" ]]; then
  skip "GET /projects/:id"
  skip "PATCH /projects/:id"
  skip "DELETE /projects/:id"
  skip "GET /projects/:id after delete"
else
  ProjectId="$PROJECT_ID"

  # --- 6) GET /projects/:id ............................ expect 200
  out="$(get_project "$ProjectId")"
  check "GET /projects/:id" 200 "$out" "$ProjectId" '"title"'

  # --- 7) PATCH /projects/:id .......................... expect 200
  out="$(patch_project "$ProjectId" '{"description":"Updated via PATCH"}')"
  check "PATCH /projects/:id" 200 "$out" '"description":"Updated via PATCH"'

  # --- 8) DELETE /projects/:id ......................... expect 204
  out="$(delete_project "$ProjectId")"
  check "DELETE /projects/:id" 204 "$out"

  # --- 9) GET /projects/:id after delete ............... expect raw 200 + [] (spec: 404 via backend)
  out="$(get_project "$ProjectId")"
  check "GET /projects/:id after delete" 200 "$out" "[]"
fi

echo
printf '%s\n' "=============================="
printf '  PASS: %d   FAIL: %d   SKIP: %d\n' "$PASS" "$FAIL" "$SKIP"
printf '%s\n' "=============================="
if (( FAIL > 0 )); then
  printf '%s\n' "Failed checks:"
  for f in ${failures[@]+"${failures[@]}"}; do
    printf '  - %s\n' "$f"
  done
fi
exit $(( FAIL > 0 ? 1 : 0 ))