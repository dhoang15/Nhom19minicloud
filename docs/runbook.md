# Runbook

## Khởi động và quan sát

```powershell
Copy-Item .env.example .env
# Sửa .env: thay mọi giá trị CHANGE_ME.
docker compose up --build -d
docker compose ps
docker compose logs --tail 100
```

Mặc định mọi cổng đều bind vào `127.0.0.1`. Trên EC2, đặt `GATEWAY_BIND=0.0.0.0` để công khai Gateway; giữ các cổng quản trị ở loopback và giới hạn cổng mở trong Security Group.

## Kiểm thử nhanh

```powershell
Invoke-WebRequest http://localhost/healthz -UseBasicParsing
Invoke-RestMethod http://localhost/api/hello
Invoke-RestMethod http://localhost/student
Invoke-RestMethod http://localhost/students-db
docker compose exec internal-dns-server named-checkzone cloud.local /etc/bind/db.cloud.local
```

Round Robin qua Gateway:

```powershell
1..6 | ForEach-Object {
  (Invoke-WebRequest http://localhost/ -UseBasicParsing).Headers['X-Served-By']
}
```

Kết quả cần luân phiên giữa `web-frontend-server1` và `web-frontend-server2`.

## OIDC / Keycloak

1. Mở `http://localhost:18081`, đăng nhập bằng thông tin bootstrap trong `.env`.
2. Realm `realm_52300070` và public client `flask-app` được import tự động.
3. Container `keycloak-user-init` tạo `sv01` và `sv02`, rồi đặt password theo `SV01_PASSWORD` và `SV02_PASSWORD` trong `.env`.
4. Lấy token cho user `sv01`:

   ```powershell
   $body = @{
     grant_type = 'password'
     client_id = 'flask-app'
     username = 'sv01'
     password = '<SV01_PASSWORD-from-.env>'
   }
   $token = (Invoke-RestMethod -Method Post `
     -Uri 'http://localhost:18081/realms/realm_52300070/protocol/openid-connect/token' `
     -ContentType 'application/x-www-form-urlencoded' -Body $body).access_token
   Invoke-RestMethod -Uri 'http://localhost:18085/secure' `
     -Headers @{ Authorization = "Bearer $token" }
   ```

Token chỉ được chấp nhận khi chữ ký RS256 hợp lệ, issuer khớp realm và audience có `flask-app`.

## Database và DNS

Database tự tạo schema khi volume mới khởi tạo. `/student` trả danh sách năm sinh viên; `/students-db` trả toàn bộ schema. Thử qua Gateway bằng `http://localhost/student`.

Để hỏi DNS từ trong network:

```powershell
docker run --rm --network cloud-net busybox:1.36 nslookup app-backend.cloud.local 10.10.10.60
```

## Prometheus, Grafana và MinIO

- Prometheus targets: `http://localhost:9090/targets`.
- Grafana: `http://localhost:3000`, user `admin`, password trong `.env`; dashboard `System Health of 52300070` được provision.
- MinIO Console: `http://localhost:9001`, user/password từ `.env`. Buckets `demo`, `profile-pics`, `documents` được khởi tạo tự động.
- File `object-storage-server/sample-files/bao-cao-cuoi-ky-nhom19.pdf` hiện không có trong working tree; thêm lại PDF được phép chia sẻ vào thư mục này rồi chạy lại tác vụ init nếu cần minh chứng upload PDF. Không xóa MinIO volume để thử lại nếu còn dữ liệu cần giữ.

## Docker Hub và AWS EC2

Đẩy các image tùy chỉnh sau khi đăng nhập Docker Hub:

```powershell
docker login
docker compose build
docker compose push web-frontend-server web-frontend-server2 application-backend-server object-storage-server api-gateway-proxy-server keycloak-user-init
```

Triển khai EC2 cần tài khoản/quyền AWS và thông tin Docker Hub của nhóm. Trên EC2: cài Docker Engine/Compose, chép `.env` an toàn, dùng tag image đã push thay cho build nếu cần, bật Security Group cho SSH giới hạn IP và HTTP/HTTPS; không public các cổng quản trị được bind loopback. Ghi lại public URL, ảnh test và log sau khi tự chạy thực tế.
