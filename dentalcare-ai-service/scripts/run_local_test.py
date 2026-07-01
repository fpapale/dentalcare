"""Test locale isolato: carica un'immagine su MinIO, lancia il job di inferenza,
attende il completamento, stampa le detections e scarica l'immagine annotata.

Uso:
    .venv/Scripts/python.exe scripts/run_local_test.py <path_immagine> [bucket]

Prerequisiti:
    - server uvicorn attivo su 127.0.0.1:8000
    - tunnel SSH a MinIO aperto (MINIO_ENDPOINT del .env raggiungibile)
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

# Permetti l'import dei moduli app/ eseguendo dalla root del servizio.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.config import get_settings  # noqa: E402
from app.minio_client import get_minio  # noqa: E402

BASE = "http://127.0.0.1:8000"


def main() -> None:
    if len(sys.argv) < 2:
        print("Uso: run_local_test.py <path_immagine> [bucket]")
        sys.exit(1)

    image_path = sys.argv[1]
    bucket = sys.argv[2] if len(sys.argv) > 2 else "dc-test"
    if not os.path.isfile(image_path):
        print(f"File non trovato: {image_path}")
        sys.exit(1)

    s = get_settings()
    object_key = os.path.basename(image_path)
    output_prefix = "ai/test/"

    # 1. Upload immagine su MinIO (crea bucket se manca).
    print(f"[1/4] Upload {image_path} -> {bucket}/{object_key}")
    get_minio().upload_file(bucket, object_key, image_path, "image/png")

    # 2. Token JWT firmato col secret condiviso col backend.
    token = jwt.encode(
        {"sub": "local-test", "iat": int(time.time()), "exp": int(time.time()) + 3600},
        s.jwt_secret, algorithm="HS256",
    )
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    # 3. Crea il job di inferenza.
    body = {
        "patient_id": "test-patient",
        "document_id": "test-doc",
        "analysis_id": "test-analysis",
        "schema_name": "t_9d754153",
        "image_bucket": bucket,
        "image_object_key": object_key,
        "output_bucket": bucket,
        "output_prefix": output_prefix,
        "save_annotated_image": True,
    }
    req = urllib.request.Request(
        f"{BASE}/api/v1/inference/jobs", method="POST",
        data=json.dumps(body).encode(), headers=headers,
    )
    created = json.load(urllib.request.urlopen(req))
    job_id = created["job_id"]
    print(f"[2/4] Job creato: {job_id} (status={created['status']})")

    # 4. Poll fino a completed/failed.
    print("[3/4] Attesa elaborazione...")
    status, doc = "queued", {}
    for _ in range(60):
        time.sleep(2)
        poll = urllib.request.Request(
            f"{BASE}/api/v1/inference/jobs/{job_id}?result_bucket={bucket}",
            headers={"Authorization": f"Bearer {token}"},
        )
        try:
            doc = json.load(urllib.request.urlopen(poll))
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                continue  # indice non ancora scritto
            raise
        status = doc.get("status", "?")
        if status in ("completed", "failed"):
            break
    print(f"      status finale: {status}")

    if status == "failed":
        print("ERRORE:", doc.get("error"))
        sys.exit(2)

    dets = doc.get("detections", [])
    print(f"[4/4] Detections: {len(dets)}")
    for d in dets:
        print(f"  - dente={d.get('tooth')} patologia={d.get('disease')} "
              f"conf={d.get('disease_confidence')} match={d.get('matching_method')} "
              f"review={d.get('needs_review')}")

    # Scarica immagine annotata.
    annotated_key = doc.get("annotated_image_object_key")
    if annotated_key:
        out = os.path.join("tmp", "annotated_out.png")
        os.makedirs("tmp", exist_ok=True)
        get_minio().download_object(bucket, annotated_key, out)
        print(f"\nImmagine annotata: {os.path.abspath(out)}")
        print(f"JSON risultati MinIO: {bucket}/{output_prefix}result.json")


if __name__ == "__main__":
    main()
