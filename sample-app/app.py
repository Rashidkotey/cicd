from flask import flask

app = flask(__name__)

@app.route("/")
def home():
    return "Hello from Sample App!"


@app.route("/health")
def health():
    return "OK"

if __name__ == "__main__"
    app.run(host="0.0.0.0", port=5000)

