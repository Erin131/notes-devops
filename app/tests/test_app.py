import pytest

from main import Note, User, create_app, db


@pytest.fixture(scope="session")
def app():
    app = create_app({
        "TESTING": True,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
        "WTF_CSRF_ENABLED": False,
        "SECRET_KEY": "test-secret",
        "DB_RETRIES": 1,
    })
    return app


@pytest.fixture()
def client(app):
    with app.app_context():
        db.drop_all()
        db.create_all()
    return app.test_client()


def register_and_login(client, username="alice", password="password123"):
    client.post("/register", data={"username": username, "password": password})
    return client.post("/login", data={"username": username, "password": password},
                       follow_redirects=True)


def api_token(client, username="bob", password="password123"):
    client.post("/api/register", json={"username": username, "password": password})
    return client.post("/api/login", json={"username": username, "password": password}).get_json()["token"]


def test_health_endpoints(client):
    assert client.get("/healthz").get_json()["status"] == "ok"
    assert client.get("/ready").status_code == 200


def test_metrics_endpoint(client):
    assert b"notes_created_total" in client.get("/metrics").data


def test_notes_page_requires_login(client):
    resp = client.get("/notes")
    assert resp.status_code == 302 and "/login" in resp.headers["Location"]


def test_register_login_and_crud(client):
    assert b"Add note" in register_and_login(client).data
    client.post("/notes", data={"title": "First", "content": "hello"})
    assert b"First" in client.get("/notes").data
    with client.application.app_context():
        note_id = Note.query.first().id
    client.post(f"/notes/{note_id}/edit", data={"title": "Edited", "content": "x"})
    assert b"Edited" in client.get("/notes").data
    client.post(f"/notes/{note_id}/delete")
    assert b"Edited" not in client.get("/notes").data


def test_wrong_password_rejected(client):
    client.post("/register", data={"username": "carol", "password": "password123"})
    resp = client.post("/login", data={"username": "carol", "password": "nope"})
    assert b"Invalid username or password" in resp.data


def test_password_is_hashed(client):
    client.post("/register", data={"username": "dave", "password": "password123"})
    with client.application.app_context():
        assert User.query.filter_by(username="dave").first().password_hash != "password123"


def test_registration_validation(client):
    resp = client.post("/register", data={"username": "a", "password": "short"})
    assert b"Username must be" in resp.data


def test_api_requires_token(client):
    assert client.get("/api/notes").status_code == 401
    assert client.get("/api/notes", headers={"Authorization": "Bearer junk"}).status_code == 401


def test_api_crud(client):
    h = {"Authorization": f"Bearer {api_token(client)}"}
    created = client.post("/api/notes", json={"title": "T", "content": "C"}, headers=h)
    assert created.status_code == 201
    nid = created.get_json()["id"]
    assert len(client.get("/api/notes", headers=h).get_json()["notes"]) == 1
    assert client.put(f"/api/notes/{nid}", json={"title": "T2"}, headers=h).get_json()["title"] == "T2"
    assert client.delete(f"/api/notes/{nid}", headers=h).status_code == 204
    assert client.get(f"/api/notes/{nid}", headers=h).status_code == 404


def test_api_validation_error(client):
    h = {"Authorization": f"Bearer {api_token(client)}"}
    resp = client.post("/api/notes", json={"title": ""}, headers=h)
    assert resp.status_code == 400 and "message" in resp.get_json()


def test_users_cannot_see_each_others_notes(client):
    h1 = {"Authorization": f"Bearer {api_token(client, 'user_one')}"}
    h2 = {"Authorization": f"Bearer {api_token(client, 'user_two')}"}
    nid = client.post("/api/notes", json={"title": "secret"}, headers=h1).get_json()["id"]
    assert client.get(f"/api/notes/{nid}", headers=h2).status_code == 404


def test_404_page(client):
    assert client.get("/does-not-exist").status_code == 404
    assert client.get("/api/nothing").get_json()["error"] == "Not Found"
