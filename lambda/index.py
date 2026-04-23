import json
import os
import random
import string
import boto3
from botocore.exceptions import ClientError

s3 = boto3.client("s3")
BUCKET = os.environ["S3_BUCKET"]
BASE_URL = os.environ.get("BASE_URL", "https://example.com")


def _short_code():
    return "".join(random.choices(string.ascii_letters + string.digits, k=6))


def create_short_url(long_url: str) -> dict:
    code = _short_code()
    s3.put_object(
        Bucket=BUCKET,
        Key=f"urls/{code}",
        Body=long_url.encode(),
        ContentType="text/plain",
    )
    return {"code": code, "short_url": f"{BASE_URL}/{code}"}


def resolve_short_url(code: str) -> str | None:
    try:
        resp = s3.get_object(Bucket=BUCKET, Key=f"urls/{code}")
        return resp["Body"].read().decode()
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchKey":
            return None
        raise


def handler(event, context):
    method = event.get("httpMethod", "")
    path = event.get("path", "/")

    if method == "POST" and path == "/shorten":
        body = json.loads(event.get("body") or "{}")
        long_url = body.get("url")
        if not long_url:
            return _resp(400, {"error": "url is required"})
        result = create_short_url(long_url)
        return _resp(201, result)

    if method == "GET" and path.startswith("/"):
        code = path.lstrip("/")
        if not code:
            return _resp(200, {"status": "ok"})
        long_url = resolve_short_url(code)
        if long_url is None:
            return _resp(404, {"error": "not found"})
        return {
            "statusCode": 301,
            "headers": {"Location": long_url},
            "body": "",
        }

    return _resp(405, {"error": "method not allowed"})


def _resp(status: int, body: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
