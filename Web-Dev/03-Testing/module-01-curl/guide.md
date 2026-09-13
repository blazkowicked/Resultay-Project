# Module 01 — CURL for API Testing

## Learning Objective
After this module, you should be able to test any API endpoint using CURL from the command line.

## Concepts

### What CURL Is
CURL is a command-line tool for transferring data with URLs. It supports all HTTP methods and is pre-installed on most systems (macOS, Linux, WSL on Windows).

### Basic Syntax
```bash
curl https://example.com/api/endpoint
```

### HTTP Methods
| Method | Flag | Use Case |
|--------|------|----------|
| GET | (default) | Fetch data |
| POST | `-X POST` | Create a new resource |
| PUT | `-X PUT` | Fully update a resource |
| PATCH | `-X PATCH` | Partially update a resource |
| DELETE | `-X DELETE` | Remove a resource |

### Headers
Use `-H` to pass custom headers:
```bash
curl -H "Content-Type: application/json" https://api.example.com/data
curl -H "Authorization: Bearer YOUR_TOKEN" https://api.example.com/protected
```

You can chain headers:
```bash
curl -H "Content-Type: application/json" -H "Authorization: Bearer TOKEN" https://api.example.com/data
```

### Request Body
For POST/PATCH requests with JSON data:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"title":"My Project","description":"A test project"}' \
  https://api.example.com/projects
```

### Inspecting the Response
- `-i` includes response headers in the output.
- `-v` shows the full request/response negotiation (useful for debugging CORS).
- `-o filename` saves the response body to a file.
- `-w "\nHTTP Status: %{http_code}\n"` prints the status code.
- `-s` silences progress output (cleaner terminal).

### Testing Auth Flows
```bash
# Login request
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"secret"}' \
  https://api.example.com/auth/login

# Use the returned token in subsequent requests
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..." \
  https://api.example.com/protected
```

### Common CURL Snippets for Your API

**GET all projects:**
```bash
curl https://iwsfzylwsxuovnkapylo.supabase.co/rest/v1/
```

**GET single project by ID:**
```bash
curl https://your-project.supabase.co/rest/v1/projects?id=eq.UUID_HERE
```

**POST a new project:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "apikey: YOUR_API_KEY" \
  -d '{"title":"Test Project","description":"Testing"}' \
  https://iwsfzylwsxuovnkapylo.supabase.co/rest/v1/
```

**DELETE a project:**
```bash
curl -X DELETE \
  -H "apikey: YOUR_API_KEY" \
  eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3c2Z6eWx3c3h1b3Zua2FweWxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkyODEzMjYsImV4cCI6MjEwNDg1NzMyNn0.m_pCTNuXsi0pmMYXXTHOlhfX7lluMZdm_BZC9exrdmU
```

## Task
For your backend project (from Track 2, module 03):
1. Write CURL commands for every endpoint you documented in the API spec.
2. Save them in a file called `examples/curl-commands.sh`.
3. Run each command and verify the response matches what your API spec describes.
4. For each command, note the expected status code and response shape.

### Acceptance Criteria
- Every endpoint from your API spec has a corresponding CURL command.
- All GET commands return the expected status code.
- All POST commands return 201 (or appropriate success code).
- The curl-commands.sh file is documented with comments for each command.

## Stretch Goal
- Write a shell script that runs all CURL commands sequentially and prints a formatted pass/fail summary