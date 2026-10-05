import urllib.request, json, time, base64
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.backends import default_backend

with open("/home/zett/Downloads/zet-infra-manager.2026-05-18.private-key.pem", "rb") as f:
    pem = f.read()

header = base64.urlsafe_b64encode(json.dumps({"alg":"RS256","typ":"JWT"}).encode()).rstrip(b"=")
now = int(time.time())
payload = base64.urlsafe_b64encode(
    json.dumps({"iat": now - 60, "exp": now + 540, "iss": "3682870"}).encode()
).rstrip(b"=")
msg = header + b"." + payload
key = serialization.load_pem_private_key(pem, password=None, backend=default_backend())
sig = key.sign(msg, padding.PKCS1v15(), hashes.SHA256())
jwt = (msg + b"." + base64.urlsafe_b64encode(sig).rstrip(b"=")).decode()

req = urllib.request.Request(
    "https://api.github.com/app/installations/131567407/access_tokens",
    method="POST",
    headers={
        "Accept":               "application/vnd.github+json",
        "Authorization":        f"Bearer {jwt}",
        "X-GitHub-Api-Version": "2022-11-28",
    }
)
try:
    with urllib.request.urlopen(req) as resp:
        print(json.loads(resp.read())["token"])
except Exception as e:
    print("ERROR:", e)
