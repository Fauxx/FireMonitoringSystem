import os, time, json, urllib.request
import jwt
from cryptography.hazmat.primitives import serialization

with open(os.environ["GITHUB_APP_PEM"], "rb") as f:
    private_key = serialization.load_pem_private_key(f.read(), password=None)

payload = {
    "iat": int(time.time()),
    "exp": int(time.time()) + 600,
    "iss": os.environ["GITHUB_APP_ID"]
}
encoded_jwt = jwt.encode(payload, private_key, algorithm="RS256")

req = urllib.request.Request(
    f"https://api.github.com/app/installations/{os.environ['GITHUB_APP_INSTALLATION_ID']}/access_tokens",
    method="POST",
    headers={
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {encoded_jwt}",
        "X-GitHub-Api-Version": "2022-11-28"
    }
)

with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read())
    print(data["token"])
