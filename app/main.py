"""Notes application: Flask + PostgreSQL, with web UI and REST API."""
import logging
import os
import re
import sys
import time
from datetime import datetime, timezone
from functools import wraps
from urllib.parse import quote_plus

from flask import (Blueprint, Flask, current_app, flash, g, jsonify, redirect,
                   render_template, request, url_for)
from flask_login import (LoginManager, UserMixin, current_user, login_required,
                         login_user, logout_user)
from flask_sqlalchemy import SQLAlchemy
from flask_wtf.csrf import CSRFProtect
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from prometheus_client import Counter
from prometheus_flask_exporter import PrometheusMetrics
from sqlalchemy import text
from werkzeug.exceptions import HTTPException
from werkzeug.security import check_password_hash, generate_password_hash

db = SQLAlchemy()
login_manager = LoginManager()
login_manager.login_view = "login"
csrf = CSRFProtect()
NOTES_CREATED = Counter("notes_created_total", "Total notes created")
USERNAME_RE = re.compile(r"^[A-Za-z0-9_]{3,30}$")


def utcnow():
    return datetime.now(timezone.utc)


# ----------------------------------------------------------------- models
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(30), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime(timezone=True), default=utcnow)
    notes = db.relationship("Note", backref="owner", cascade="all, delete-orphan")


class Note(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=False, default="")
    created_at = db.Column(db.DateTime(timezone=True), default=utcnow)
    updated_at = db.Column(db.DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False, index=True)

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "content": self.content,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }


@login_manager.user_loader
def load_user(user_id):
    return db.session.get(User, int(user_id))


# ---------------------------------------------------------------- helpers
def build_db_uri():
    url = os.environ.get("DATABASE_URL")
    if url:
        return url
    host = os.environ.get("POSTGRES_HOST")
    if host:
        user = quote_plus(os.environ.get("POSTGRES_USER", "notes"))
        pw = quote_plus(os.environ.get("POSTGRES_PASSWORD", "notespass"))
        name = os.environ.get("POSTGRES_DB", "notes")
        port = os.environ.get("POSTGRES_PORT", "5432")
        return f"postgresql+psycopg2://{user}:{pw}@{host}:{port}/{name}"
    return "sqlite:///notes.db"


def init_db(app, retries=30, delay=2):
    """Create tables; retry because the database container may start later."""
    for attempt in range(1, retries + 1):
        try:
            with app.app_context():
                db.create_all()
            app.logger.info("Database ready")
            return
        except Exception as exc:  # noqa: BLE001
            app.logger.warning("Database not ready (%s/%s): %s", attempt, retries, exc)
            time.sleep(delay)
    raise RuntimeError("Could not connect to the database")


def validate_note(title, content):
    if not title or len(title) > 100:
        return "Title is required (max 100 characters)."
    if len(content) > 5000:
        return "Content is too long (max 5000 characters)."
    return None


def validate_credentials(username, password):
    if not USERNAME_RE.match(username or ""):
        return "Username must be 3-30 letters, numbers or underscores."
    if len(password or "") < 8:
        return "Password must be at least 8 characters."
    return None


def token_serializer():
    return URLSafeTimedSerializer(current_app.config["SECRET_KEY"], salt="api-token")


def token_required(view):
    @wraps(view)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return jsonify(error="Unauthorized", message="Missing bearer token"), 401
        try:
            data = token_serializer().loads(
                header[7:], max_age=current_app.config["TOKEN_MAX_AGE"])
        except SignatureExpired:
            return jsonify(error="Unauthorized", message="Token expired"), 401
        except BadSignature:
            return jsonify(error="Unauthorized", message="Invalid token"), 401
        user = db.session.get(User, data.get("uid"))
        if user is None:
            return jsonify(error="Unauthorized", message="Unknown user"), 401
        g.api_user = user
        return view(*args, **kwargs)
    return wrapper


# -------------------------------------------------------------- REST API
api = Blueprint("api", __name__, url_prefix="/api")


@api.post("/register")
def api_register():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""
    err = validate_credentials(username, password)
    if err:
        return jsonify(error="Bad Request", message=err), 400
    if User.query.filter_by(username=username).first():
        return jsonify(error="Conflict", message="Username already taken"), 409
    db.session.add(User(username=username, password_hash=generate_password_hash(password)))
    db.session.commit()
    return jsonify(message="User created"), 201


@api.post("/login")
def api_login():
    data = request.get_json(silent=True) or {}
    user = User.query.filter_by(username=(data.get("username") or "").strip()).first()
    if not user or not check_password_hash(user.password_hash, data.get("password") or ""):
        current_app.logger.warning("API login failed for %r", data.get("username"))
        return jsonify(error="Unauthorized", message="Invalid credentials"), 401
    token = token_serializer().dumps({"uid": user.id})
    return jsonify(token=token, expires_in=current_app.config["TOKEN_MAX_AGE"])


@api.get("/notes")
@token_required
def api_list():
    notes = (Note.query.filter_by(user_id=g.api_user.id)
             .order_by(Note.updated_at.desc()).all())
    return jsonify(notes=[n.to_dict() for n in notes])


@api.post("/notes")
@token_required
def api_create():
    data = request.get_json(silent=True) or {}
    title = (data.get("title") or "").strip()
    content = data.get("content") or ""
    err = validate_note(title, content)
    if err:
        return jsonify(error="Bad Request", message=err), 400
    note = Note(title=title, content=content, user_id=g.api_user.id)
    db.session.add(note)
    db.session.commit()
    NOTES_CREATED.inc()
    return jsonify(note.to_dict()), 201


def _own_note_or_404(note_id):
    return Note.query.filter_by(id=note_id, user_id=g.api_user.id).first_or_404()


@api.get("/notes/<int:note_id>")
@token_required
def api_get(note_id):
    return jsonify(_own_note_or_404(note_id).to_dict())


@api.put("/notes/<int:note_id>")
@token_required
def api_update(note_id):
    note = _own_note_or_404(note_id)
    data = request.get_json(silent=True) or {}
    title = (data.get("title", note.title) or "").strip()
    content = data.get("content", note.content) or ""
    err = validate_note(title, content)
    if err:
        return jsonify(error="Bad Request", message=err), 400
    note.title, note.content = title, content
    db.session.commit()
    return jsonify(note.to_dict())


@api.delete("/notes/<int:note_id>")
@token_required
def api_delete(note_id):
    db.session.delete(_own_note_or_404(note_id))
    db.session.commit()
    return "", 204


# ----------------------------------------------------------- app factory
def create_app(test_config=None):
    app = Flask(__name__)
    app.config.update(
        SECRET_KEY=os.environ.get("SECRET_KEY", "dev-only-change-me"),
        SQLALCHEMY_DATABASE_URI=build_db_uri(),
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        TOKEN_MAX_AGE=3600,
    )
    if test_config:
        app.config.update(test_config)

    logging.basicConfig(
        stream=sys.stdout, level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s")
    if app.config["SECRET_KEY"] == "dev-only-change-me":
        app.logger.warning("Using the default SECRET_KEY - set SECRET_KEY in production")

    db.init_app(app)
    login_manager.init_app(app)
    csrf.init_app(app)
    csrf.exempt(api)  # API uses bearer tokens, not cookies
    app.register_blueprint(api)

    metrics = PrometheusMetrics(app, path="/metrics")
    metrics.info("notes_app_info", "Application info", version="1.0")

    @app.context_processor
    def inject_globals():
        color = os.environ.get("APP_COLOR", "local")
        nav = {"blue": "bg-primary", "green": "bg-success"}.get(color, "bg-dark")
        return {"app_color": color, "nav_class": nav}

    # ---- health endpoints (used by Docker and Kubernetes probes)
    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok", color=os.environ.get("APP_COLOR", "local"))

    @app.get("/ready")
    def ready():
        try:
            db.session.execute(text("SELECT 1"))
            return jsonify(status="ready")
        except Exception:  # noqa: BLE001
            app.logger.exception("Readiness check failed")
            return jsonify(status="database unavailable"), 503

    # ---- web UI
    @app.get("/")
    def index():
        return redirect(url_for("notes" if current_user.is_authenticated else "login"))

    @app.route("/register", methods=["GET", "POST"])
    def register():
        if request.method == "POST":
            username = request.form.get("username", "").strip()
            password = request.form.get("password", "")
            err = validate_credentials(username, password)
            if not err and User.query.filter_by(username=username).first():
                err = "That username is already taken."
            if err:
                flash(err, "danger")
            else:
                db.session.add(User(username=username,
                                    password_hash=generate_password_hash(password)))
                db.session.commit()
                app.logger.info("New user registered: %s", username)
                flash("Account created. Please log in.", "success")
                return redirect(url_for("login"))
        return render_template("register.html")

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if request.method == "POST":
            username = request.form.get("username", "").strip()
            user = User.query.filter_by(username=username).first()
            if user and check_password_hash(user.password_hash, request.form.get("password", "")):
                login_user(user)
                app.logger.info("User logged in: %s", username)
                return redirect(url_for("notes"))
            app.logger.warning("Failed login for %r", username)
            flash("Invalid username or password.", "danger")
        return render_template("login.html")

    @app.post("/logout")
    @login_required
    def logout():
        logout_user()
        return redirect(url_for("login"))

    @app.route("/notes", methods=["GET", "POST"])
    @login_required
    def notes():
        if request.method == "POST":
            title = request.form.get("title", "").strip()
            content = request.form.get("content", "")
            err = validate_note(title, content)
            if err:
                flash(err, "danger")
            else:
                db.session.add(Note(title=title, content=content, user_id=current_user.id))
                db.session.commit()
                NOTES_CREATED.inc()
                flash("Note added.", "success")
            return redirect(url_for("notes"))
        items = (Note.query.filter_by(user_id=current_user.id)
                 .order_by(Note.updated_at.desc()).all())
        return render_template("notes.html", notes=items)

    @app.route("/notes/<int:note_id>/edit", methods=["GET", "POST"])
    @login_required
    def edit_note(note_id):
        note = Note.query.filter_by(id=note_id, user_id=current_user.id).first_or_404()
        if request.method == "POST":
            title = request.form.get("title", "").strip()
            content = request.form.get("content", "")
            err = validate_note(title, content)
            if err:
                flash(err, "danger")
            else:
                note.title, note.content = title, content
                db.session.commit()
                flash("Note updated.", "success")
                return redirect(url_for("notes"))
        return render_template("edit.html", note=note)

    @app.post("/notes/<int:note_id>/delete")
    @login_required
    def delete_note(note_id):
        note = Note.query.filter_by(id=note_id, user_id=current_user.id).first_or_404()
        db.session.delete(note)
        db.session.commit()
        flash("Note deleted.", "info")
        return redirect(url_for("notes"))

    # ---- error handling
    @app.errorhandler(HTTPException)
    def handle_http(err):
        if request.path.startswith("/api/"):
            return jsonify(error=err.name, message=err.description), err.code
        return render_template("error.html", code=err.code, name=err.name,
                               message=err.description), err.code

    @app.errorhandler(Exception)
    def handle_unexpected(err):
        app.logger.exception("Unhandled error: %s", err)
        db.session.rollback()
        if request.path.startswith("/api/"):
            return jsonify(error="Internal Server Error", message="Something went wrong"), 500
        return render_template("error.html", code=500, name="Internal Server Error",
                               message="Something went wrong on our side."), 500

    init_db(app, retries=app.config.get("DB_RETRIES", 30))
    return app


if __name__ == "__main__":
    create_app().run(host="0.0.0.0", port=5000)
