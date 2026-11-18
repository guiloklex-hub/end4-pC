#!/usr/bin/env python3
"""Send a streaming Messages request, expanding local image/PDF attachments."""

import argparse
import base64
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

MAX_REQUEST_BYTES = 32_000_000
MAX_IMAGE_BASE64_BYTES = 10_000_000


def attachment_block(filename):
    path = Path(filename).expanduser()
    if not path.is_file():
        raise ValueError(f"Anexo não encontrado: {path.name}. Restaure o arquivo ou inicie uma nova conversa.")
    if path.stat().st_size > MAX_REQUEST_BYTES:
        raise ValueError(f"O anexo {path.name} excede o limite da requisição (32 MB).")
    data = path.read_bytes()
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        media_type = "image/png"
    elif data.startswith(b"\xff\xd8\xff"):
        media_type = "image/jpeg"
    elif data.startswith((b"GIF87a", b"GIF89a")):
        media_type = "image/gif"
    elif data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        media_type = "image/webp"
    elif b"%PDF-" in data[:1024]:
        media_type = "application/pdf"
    else:
        raise ValueError(f"Formato não suportado: {path.name}. Use PNG, JPEG, GIF, WebP ou PDF.")
    encoded = base64.b64encode(data).decode("ascii")
    if media_type.startswith("image/") and len(encoded) > MAX_IMAGE_BASE64_BYTES:
        raise ValueError(f"A imagem {path.name} excede 10 MB em base64. Reduza a imagem.")
    return {
        "type": "document" if media_type == "application/pdf" else "image",
        "source": {"type": "base64", "media_type": media_type, "data": encoded},
    }


def encode_request(payload):
    for message in payload.get("messages", []):
        content = message.get("content")
        if isinstance(content, list):
            message["content"] = [
                attachment_block(block["path"]) if block.get("type") == "local_file" else block
                for block in content
            ]
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if len(body) > MAX_REQUEST_BYTES:
        raise ValueError("A conversa e os anexos excedem 32 MB. Inicie uma nova conversa ou use arquivos menores.")
    return body


def emit_error(message):
    event = {"type": "error", "error": {"type": "request_error", "message": message}}
    print("data: " + json.dumps(event, ensure_ascii=False), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", default="https://api.anthropic.com/v1/messages")
    args = parser.parse_args()
    try:
        body = encode_request(json.load(sys.stdin))
        key = os.environ.get("API_KEY", "")
        if not key:
            raise ValueError("Cadastre sua chave Anthropic com /key antes de enviar.")
        request = urllib.request.Request(args.endpoint, data=body, headers={
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
        })
        with urllib.request.urlopen(request, timeout=180) as response:
            for line in response:
                sys.stdout.buffer.write(line)
                sys.stdout.buffer.flush()
        return 0
    except urllib.error.HTTPError as error:
        try:
            detail = json.loads(error.read()).get("error", {}).get("message", str(error))
        except (ValueError, AttributeError):
            detail = str(error)
        emit_error(detail)
    except (OSError, ValueError, urllib.error.URLError) as error:
        emit_error(str(error))
    return 1


if __name__ == "__main__":
    sys.exit(main())
