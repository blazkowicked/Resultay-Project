#!/usr/bin/env bash
#
# =============================================================================
#  curl-commands.sh — CURL commands for the Portfolio Projects API
#
#  Covers every endpoint documented in the API spec:
#    ../module-02-api-architecture/spec-template/api-spec.md
#
#  Backend project : Track 2, module 03 (Supabase integration)
#  Base URL        : https://iwsfzylwsxuovnkapylo.supabase.co/rest/v1
#                    (Supabase PostgREST — matches the spec's base URL)
#
#  ---------------------------------------------------------------------------
#  Configuration (override via environment variables)
#  ---------------------------------------------------------------------------
#    BASE_URL - Supabase REST endpoint (defaults to this project's URL below).
#    ANON_KEY - Supabase anon key; safe to expose. Reads AND writes work with
#               it here because RLS is currently permissive on `projects`.
#    USER_JWT - optional signed-in user JWT. If set, write commands also send
#               `Authorization: Bearer <JWT>` as the spec requires.
#
#  Run (from the module folder):
#    bash examples/curl-commands.sh
#
#  On Windows, run this file from Git Bash or WSL.
#
#  Every command prints the response body followed by [HTTP <status>] so you
#  can compare it with the expected status documented in its comment block.
# =============================================================================
set -u

BASE_URL="${BASE_URL:-https://iwsfzylwsxuovnkapylo.supabase.co/rest/v1}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3c2Z6eWx3c3h1b3Zua2FweWxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkyODEzMjYsImV4cCI6MjEwNDg1NzMyNn0.m_pCTNuXsi0pmMYXXTHOlhfX7lluMZdm_BZC9exrdmU}"
USER_JWT="${USER_JWT:-}"

# Auth header used by write commands. The spec (section 1) requires a user JWT
# for writes; this project's open RLS policy means the anon key alone is
# enough right now, but the header is added automatically if USER_JWT is set.
AUTH_HEADERS=()
if [[ -n "$USER_JWT" ]]; then
  AUTH_HEADERS=(-H "Authorization: Bearer $USER_JWT")
fi

# POST payload. Uses only columns that exist on this project's `projects`
# table (title, description, category_id). The spec example payload also lists
# technologies/github_url/live_url, but those columns are not in this table,
# so sending them returns 400 (PGRST204 - column not found).
DEFAULT_PAYLOAD='{"title":"Weather Dashboard","description":"Live weather map for cities worldwide.","category_id":null}'

# Command                     Endpoint                   Expected status
# --------------------------- -------------------------- ---------------
# get_projects                GET  /projects             200
# get_projects_paged          GET  /projects?page&limit  200
# create_project              POST /projects             201
# get_project <id>            GET  /projects/:id         200
# patch_project <id>          PATCH /projects/:id        200
# delete_project <id>         DELETE /projects/:id       204
#   + two error-path checks (400 invalid body, 404/missing-id behaviour)

# -----------------------------------------------------------------------------
#  Helper: print the last line of the previous command's output, which curl
#  writes as '[HTTP <status>]'.
# -----------------------------------------------------------------------------
http_code() {
  printf '%s\n' "$1" | tail -n 1
}

# Helper: extract the first UUID-looking token from output. Used to capture a
# created project's id so the /:id commands can reuse it.
extract_id() {
  printf '%s\n' "$1" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -n 1
}

# -----------------------------------------------------------------------------
#  GET /projects
#    Method           : GET                (matches spec section 4.1)
#    Auth             : anon key only
#    Query parameters : page, limit, title (optional)
#    Expected status  : 200 OK
#    Expected shape   : spec envelope {"status":"success","data":[...],
#                        "pagination":{...}}; raw PostgREST returns a bare
#                        array of project objects instead.
# -----------------------------------------------------------------------------
get_projects() {
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -H "apikey: $ANON_KEY" \
    -H "Accept: application/json" \
    "$BASE_URL/projects"
}

# -----------------------------------------------------------------------------
#  GET /projects  (paged)
#    Same endpoint with pagination. Spec section 4.1 documents page/limit query
#    parameters; raw PostgREST does not know those names and rejects them with
#    400, so they are mapped to PostgREST's native limit/offset (page N => offset
#    (N-1)*limit).
#    Expected status : 200 OK     Expected shape : same as get_projects.
# -----------------------------------------------------------------------------
get_projects_paged() {
  local page="${1:-1}"
  local limit="${2:-10}"
  local offset=$(( (10#$page - 1) * 10#$limit ))
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -H "apikey: $ANON_KEY" \
    -H "Accept: application/json" \
    "$BASE_URL/projects?limit=$limit&offset=$offset"
}

# -----------------------------------------------------------------------------
#  POST /projects
#    Method           : POST               (matches spec section 4.2)
#    Auth             : anon key; Bearer <user JWT> if USER_JWT is set
#    Request body     : {"title" (required), "description", "category_id"}
#                       (spec section 5.2; restricted to this table's columns)
#    Expected status  : 201 Created
#    Expected shape   : spec envelope {"status":"success","data":{project}};
#                       raw PostgREST returns a bare array with the created
#                       row (requires "Prefer: return=representation").
# -----------------------------------------------------------------------------
create_project() {
  local payload="${1:-$DEFAULT_PAYLOAD}"
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -X POST \
    -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Prefer: return=representation" \
    "${AUTH_HEADERS[@]}" \
    -d "$payload" \
    "$BASE_URL/projects"
}

# -----------------------------------------------------------------------------
#  GET /projects/:id
#    Method           : GET                (matches spec section 4.3)
#    Auth             : anon key only
#    Path parameter   : id (uuid, expressed as PostgREST filter ?id=eq.UUID)
#    Expected status  : 200 OK
#    Expected shape   : spec envelope {"status":"success","data":{project}};
#                       raw PostgREST returns a bare array with the row.
#    NOTE: spec section 4.3 documents 404 for a missing id. Raw PostgREST
#    returns 200 with an empty array [] instead; a backend layer implementing
#    the envelope must translate that to the 404 {status:"error",...NOT_FOUND}.
# -----------------------------------------------------------------------------
get_project() {
  local id="${1:?usage: get_project <project-id>}"
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -H "apikey: $ANON_KEY" \
    -H "Accept: application/json" \
    "$BASE_URL/projects?id=eq.$id"
}

# -----------------------------------------------------------------------------
#  PATCH /projects/:id
#    Method           : PATCH              (matches spec section 4.4)
#    Auth             : anon key; Bearer <user JWT> if USER_JWT is set
#    Request body     : partial update of any writable field (spec section 5.3)
#    Expected status  : 200 OK
#    Expected shape   : spec envelope {"status":"success","data":{updated}};
#                       raw PostgREST returns a bare array with the updated row
#                       (requires "Prefer: return=representation").
# -----------------------------------------------------------------------------
patch_project() {
  local id="${1:?usage: patch_project <project-id>}"
  local payload="${2:-}"
  if [[ -z "$payload" ]]; then
    payload='{"description":"Updated via PATCH"}'
  fi
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -X PATCH \
    -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Prefer: return=representation" \
    "${AUTH_HEADERS[@]}" \
    -d "$payload" \
    "$BASE_URL/projects?id=eq.$id"
}

# -----------------------------------------------------------------------------
#  DELETE /projects/:id
#    Method           : DELETE             (matches spec section 4.5)
#    Auth             : anon key; Bearer <user JWT> if USER_JWT is set
#    Expected status  : 204 No Content
#    Expected shape   : empty body (spec and raw PostgREST agree here).
# -----------------------------------------------------------------------------
delete_project() {
  local id="${1:?usage: delete_project <project-id>}"
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -X DELETE \
    -H "apikey: $ANON_KEY" \
    -H "Accept: application/json" \
    "${AUTH_HEADERS[@]}" \
    "$BASE_URL/projects?id=eq.$id"
}

# =============================================================================
#  Run every command in sequence. This block only executes when this file is
#  run directly; it is skipped when the file is `source`d (e.g. by
#  run-curl-tests.sh).
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Base URL : $BASE_URL"
  echo

  echo "// 1) GET /projects  ..................................... expect 200"
  get_projects
  echo

  echo "// 2) GET /projects?page=1&limit=1  ....................... expect 200"
  get_projects_paged 1 1
  echo

  echo "// 3) POST /projects (valid body) ......................... expect 201"
  created="$(create_project)"
  echo "$created"
  project_id="$(extract_id "$created")"
  if [[ -n "$project_id" ]]; then
    echo "-> captured project id: $project_id"
  else
    echo "-> NOTE: could not capture a project id (check BASE_URL/keys)."
  fi
  echo

  echo "// 4) POST /projects (invalid body: missing title) ........ expect 400"
  create_project '{"description":"missing the required title field"}'
  echo

  echo "// 5) GET /projects/:id  .................................. expect 200"
  if [[ -n "${project_id:-}" ]]; then
    get_project "$project_id"
  else
    echo "   skipped (no project id)"
  fi
  echo

  echo "// 6) GET /projects/:id (nonexistent id) .................. expect 200 + [] (raw PostgREST); spec says 404"
  get_project "00000000-0000-0000-0000-000000000000"
  echo

  echo "// 7) PATCH /projects/:id  ................................ expect 200"
  if [[ -n "${project_id:-}" ]]; then
    patch_project "$project_id"
  else
    echo "   skipped (no project id)"
  fi
  echo

  echo "// 8) DELETE /projects/:id  ............................... expect 204"
  if [[ -n "${project_id:-}" ]]; then
    delete_project "$project_id"
  else
    echo "   skipped (no project id)"
  fi
  echo

  echo "// 9) GET /projects/:id (after delete) .................... expect 200 + [] (raw PostgREST); spec says 404"
  if [[ -n "${project_id:-}" ]]; then
    get_project "$project_id"
  else
    echo "   skipped (no project id)"
  fi
  echo
fi