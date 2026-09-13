#!/usr/bin/env bash
#
# =============================================================================
#  curl-commands.sh
#
#  CURL commands covering every endpoint documented in the API spec at
#  ../spec-template/api-spec.md (Portfolio Projects API, Supabase-backed).
#
#  Base URL : https://your-project.supabase.co/rest/v1
#
#  ---------------------------------------------------------------------------
#  Configuration
#  ---------------------------------------------------------------------------
#  Edit the three values below, or set them as environment variables:
#
#    BASE_URL - your Supabase REST endpoint (or a backend that implements
#               this spec). Symmetric with the spec's base URL.
#    ANON_KEY - Supabase project anon key  (Dashboard -> Settings -> API).
#               Public reads only need this header.
#    USER_JWT - a signed-in user's JWT, required for the write operations
#               (POST / PATCH / DELETE). Obtain it by signing in via
#               Supabase Auth.
#
#  Run (from the module folder):
#    bash examples/curl-commands.sh
#
#  Every command prints the response body followed by [HTTP <status>] so you
#  can compare it with the expected status code in its comment block.
#  On Windows, run this file from Git Bash or WSL.
# =============================================================================
set -u

BASE_URL="${BASE_URL:-https://your-project.supabase.co/rest/v1}"
ANON_KEY="${ANON_KEY:-YOUR_ANON_KEY}"
USER_JWT="${USER_JWT:-YOUR_USER_JWT}"

# JSON payload used by the POST example. Matches the request schema in the
# spec (all fields optional except `title`).
DEFAULT_PAYLOAD='{"title":"Weather Dashboard","description":"Live weather map for cities worldwide.","technologies":["React","Supabase"],"github_url":"https://github.com/me/weather-dashboard","live_url":"https://weather-dashboard.vercel.app"}'

# Command                     Endpoint                   Expected status
# --------------------------- -------------------------- ---------------
# get_projects                GET  /projects             200
# get_projects_paged          GET  /projects?page&limit  200
# create_project              POST /projects             201
# get_project <id>            GET  /projects/:id         200
# patch_project <id>          PATCH /projects/:id        200
# delete_project <id>         DELETE /projects/:id       204
#   + two error-path checks (400 invalid body, 404 missing id)

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
#    Expected shape   : {"status":"success","data":[project,...],
#                        "pagination":{"page":1,"limit":10,"total":N}}
# -----------------------------------------------------------------------------
get_projects() {
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -H "apikey: $ANON_KEY" \
    -H "Accept: application/json" \
    "$BASE_URL/projects"
}

# -----------------------------------------------------------------------------
#  GET /projects  (paged)
#    Same as above with page/limit query parameters (spec section 4.1).
#    Expected status : 200 OK     Expected shape : success envelope +
#    pagination honoring page/limit.
# -----------------------------------------------------------------------------
get_projects_paged() {
  local page="${1:-1}"
  local limit="${2:-10}"
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -H "apikey: $ANON_KEY" \
    -H "Accept: application/json" \
    "$BASE_URL/projects?page=$page&limit=$limit"
}

# -----------------------------------------------------------------------------
#  POST /projects
#    Method           : POST               (matches spec section 4.2)
#    Auth             : Bearer <user JWT>
#    Request body     : see DEFAULT_PAYLOAD above and spec section 5.2
#                       (title required, <=100 chars; description <=500;
#                        technologies <=10 items; github_url/live_url valid)
#    Expected status  : 201 Created
#    Expected shape   : {"status":"success","data":{project with id,
#                        created_at, user_id}}
# -----------------------------------------------------------------------------
create_project() {
  local payload="${1:-$DEFAULT_PAYLOAD}"
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -X POST \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $USER_JWT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$payload" \
    "$BASE_URL/projects"
}

# -----------------------------------------------------------------------------
#  GET /projects/:id
#    Method           : GET                (matches spec section 4.3)
#    Auth             : anon key only
#    Path parameter   : id (uuid)
#    Expected status  : 200 OK
#    Expected shape   : {"status":"success","data":{project}}
#    NOTE: if you point this at raw Supabase (no backend layer), a missing
#    row returns 200 with an empty array; a backend implementing the spec
#    returns 404 with {"status":"error","code":"NOT_FOUND"}.
# -----------------------------------------------------------------------------
get_project() {
  local id="${1:?usage: get_project <project-id>}"
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -H "apikey: $ANON_KEY" \
    -H "Accept: application/json" \
    "$BASE_URL/projects/$id"
}

# -----------------------------------------------------------------------------
#  PATCH /projects/:id
#    Method           : PATCH              (matches spec section 4.4)
#    Auth             : Bearer <user JWT>  (must own the project)
#    Request body     : partial update, any writable field (spec section 5.3)
#    Expected status  : 200 OK
#    Expected shape   : {"status":"success","data":{updated project}}
# -----------------------------------------------------------------------------
patch_project() {
  local id="${1:?usage: patch_project <project-id>}"
  local payload="${2:-{\"description\":\"Updated via PATCH\"}}"
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -X PATCH \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $USER_JWT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$payload" \
    "$BASE_URL/projects/$id"
}

# -----------------------------------------------------------------------------
#  DELETE /projects/:id
#    Method           : DELETE             (matches spec section 4.5)
#    Auth             : Bearer <user JWT>  (must own the project)
#    Expected status  : 204 No Content
#    Expected shape   : empty body
# -----------------------------------------------------------------------------
delete_project() {
  local id="${1:?usage: delete_project <project-id>}"
  curl -sS -w '\n[HTTP %{http_code}]\n' \
    -X DELETE \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $USER_JWT" \
    "$BASE_URL/projects/$id"
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

  echo "// 6) GET /projects/:id (nonexistent id) .................. expect 404"
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

  echo "// 9) GET /projects/:id (after delete) .................... expect 404"
  if [[ -n "${project_id:-}" ]]; then
    get_project "$project_id"
  else
    echo "   skipped (no project id)"
  fi
  echo
fi