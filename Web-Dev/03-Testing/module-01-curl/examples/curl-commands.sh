#!/bin/bash
# CURL commands for your API endpoints
# Replace YOUR_PROJECT_URL with your actual Supabase URL

PROJECT_URL="https://iwsfzylwsxuovnkapylo.supabase.co/rest/v1/"

# GET all projects
curl -s "$PROJECT_URL/projects" -o /dev/null -w "GET /projects -> %{http_code}\n"

# GET single project
curl -s "$PROJECT_URL/projects?id=eq.SOME_UUID" -o /dev/null -w "GET /projects/:id -> %{http_code}\n"

# POST a new project
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"A test project"}' \
  "$PROJECT_URL/projects" -o /dev/null -w "POST /projects -> %{http_code}\n"

# DELETE a project
curl -s -X DELETE \
  "$PROJECT_URL/projects?id=eq.SOME_UUID" \
  -o /dev/null -w "DELETE /projects/:id -> %{http_code}\n"