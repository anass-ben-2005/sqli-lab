import os, MySQLdb
from flask import (Flask, request, session, redirect,
                   url_for, render_template, g, flash)
from functools import wraps

app = Flask(__name__)
app.secret_key = "lab_insecure_key"  # hardcoded on purpose

DB = dict(host=os.getenv("DB_HOST","db"), user=os.getenv("DB_USER","libraryuser"),
          passwd=os.getenv("DB_PASS","librarypass"), db=os.getenv("DB_NAME","librarydb"))

def get_db():
    if "db" not in g:
        g.db = MySQLdb.connect(**DB)
    return g.db

@app.teardown_appcontext
def close_db(e):
    db = g.pop("db", None)
    if db: db.close()

# ── Decorators ──────────────────────────────────────────────────
def require_login(f):
    @wraps(f)
    def dec(*a, **kw):
        if "user" not in session: return redirect(url_for("login"))
        return f(*a, **kw)
    return dec

def require_admin(f):
    @wraps(f)
    def dec(*a, **kw):
        if "user" not in session: return redirect(url_for("login"))
        if session.get("role") not in ("admin","super_admin"):
            flash("Admin access required.", "error")
            return redirect(url_for("dashboard"))
        return f(*a, **kw)
    return dec

def require_superadmin(f):
    @wraps(f)
    def dec(*a, **kw):
        if "user" not in session: return redirect(url_for("login"))
        if session.get("role") != "super_admin":
            flash("Super-admin access required.", "error")
            return redirect(url_for("dashboard"))
        return f(*a, **kw)
    return dec

# ── Routes ──────────────────────────────────────────────────────
@app.route("/")
def index():
    return redirect(url_for("dashboard" if "user" in session else "login"))

@app.route("/login", methods=["GET","POST"])
def login():
    raw_query = None
    error = None
    if request.method == "POST":
        username = request.form.get("username","")
        password = request.form.get("password","")

        # ╔══════════════════════════════════════════════════════╗
        # ║  ⚠  DELIBERATELY VULNERABLE — string concatenation  ║
        # ║  Never do this in production.                       ║
        # ╚══════════════════════════════════════════════════════╝
        query = (
            "SELECT id, username, role FROM members "
            "WHERE username = '" + username + "' "
            "AND password = '"   + password + "'"
        )
        raw_query = query   # expose for the UI debug panel

        try:
            cur = get_db().cursor()
            cur.execute(query)          # ← raw unsanitised string
            row = cur.fetchone()
            cur.close()
        except MySQLdb.ProgrammingError as e:
            return render_template("login.html", error=str(e), raw_query=raw_query)

        if row:
            session["user"]      = row[1]
            session["user_id"]   = row[0]
            session["role"]      = row[2]
            session["last_query"]= query
            return redirect(url_for("dashboard"))
        error = "Invalid credentials."

    return render_template("login.html", error=error, raw_query=raw_query)

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))

@app.route("/dashboard")
@require_login
def dashboard():
    db = get_db()
    cur = db.cursor()
    cur.execute("SELECT COUNT(*) FROM books")
    books = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM members")
    members = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM loans WHERE returned_at IS NULL")
    loans = cur.fetchone()[0]
    cur.close()
    last_query = session.pop("last_query", None)
    return render_template("dashboard.html",
                           book_count=books, member_count=members,
                           active_loans=loans, last_query=last_query)

@app.route("/books")
@require_login
def books():
    cur = get_db().cursor()
    cur.execute("SELECT id,title,author,genre,year,copies FROM books ORDER BY title")
    books = cur.fetchall()
    cur.close()
    return render_template("books.html", books=books)

@app.route("/loans")
@require_login
def loans():
    cur = get_db().cursor()
    if session.get("role") in ("admin","super_admin"):
        cur.execute("""SELECT l.id,m.username,b.title,l.loaned_at,l.due_at,l.returned_at
                       FROM loans l JOIN members m ON l.member_id=m.id
                                    JOIN books   b ON l.book_id=b.id
                       ORDER BY l.loaned_at DESC""")
    else:
        cur.execute("""SELECT l.id,m.username,b.title,l.loaned_at,l.due_at,l.returned_at
                       FROM loans l JOIN members m ON l.member_id=m.id
                                    JOIN books   b ON l.book_id=b.id
                       WHERE l.member_id=%s ORDER BY l.loaned_at DESC""",
                    (session["user_id"],))
    loans = cur.fetchall()
    cur.close()
    return render_template("loans.html", loans=loans)

@app.route("/members")
@require_admin
def members():
    cur = get_db().cursor()
    cur.execute("SELECT id,username,email,role,created_at FROM members ORDER BY id")
    members = cur.fetchall()
    cur.close()
    return render_template("members.html", members=members)

@app.route("/secrets")
@require_superadmin
def secrets():
    cur = get_db().cursor()
    cur.execute("SELECT id,username,email,role FROM members")
    members = cur.fetchall()
    cur.close()
    return render_template("secrets.html", members=members)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)