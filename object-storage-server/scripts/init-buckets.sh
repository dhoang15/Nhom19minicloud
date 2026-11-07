#!/bin/sh
set -e

echo "[MinIO Init] Waiting for object-storage-server:9000 to be ready..."
until mc alias set myminio http://object-storage-server:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"; do
  echo "[MinIO Init] MinIO is not ready yet, retrying in 2 seconds..."
  sleep 2
done

echo "[MinIO Init] Creating required buckets (demo, profile-pics, documents)..."
mc mb --ignore-existing myminio/demo
mc mb --ignore-existing myminio/profile-pics
mc mb --ignore-existing myminio/documents

echo "[MinIO Init] Setting anonymous download (public read) policy on bucket profile-pics and demo..."
mc anonymous set download myminio/profile-pics
mc anonymous set download myminio/demo

if [ -f /sample-files/index.html ]; then
  echo "[MinIO Init] Uploading index.html to bucket demo..."
  mc cp /sample-files/index.html myminio/demo/index.html
fi

if [ -f /sample-files/avatar.jpg ]; then
  echo "[MinIO Init] Uploading avatar.jpg to bucket profile-pics..."
  mc cp /sample-files/avatar.jpg myminio/profile-pics/avatar.jpg
fi

if [ -f /sample-files/bao-cao-cuoi-ky-nhom19.pdf ]; then
  echo "[MinIO Init] Uploading bao-cao-cuoi-ky-nhom19.pdf to bucket documents..."
  mc cp /sample-files/bao-cao-cuoi-ky-nhom19.pdf myminio/documents/bao-cao-cuoi-ky-nhom19.pdf
fi

echo "[MinIO Init] Listing buckets and objects:"
mc ls myminio/demo
mc ls myminio/profile-pics
mc ls myminio/documents
echo "[MinIO Init] Completed successfully!"
