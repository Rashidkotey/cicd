from app import cicd/app

def test_home():
    client = app.test_client()

    response = client.get("/")

    assert response.status_code == 200
    assert response.data == b"Hello from Sample App!"

def test_health():
    client = app.test_client()

    response = client.get("/health")

    assert response.status_code == 200
    assert response.data == b"OK"
