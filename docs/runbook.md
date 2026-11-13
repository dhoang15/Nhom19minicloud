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
Invoke-RestMethod http://localhost/api/students-db
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

Database tự tạo schema khi volume mới khởi tạo. SQL có 5 bản ghi mẫu; `/student` trả các dòng từ database và `/api/students-db` qua Gateway trả toàn bộ cột cùng dữ liệu trong bảng. Endpoint backend trực tiếp là `http://localhost:18085/students-db`. Nếu volume đã được khởi tạo trong lúc SQL lỗi, cần chạy lại file seed bằng MariaDB client rồi xác nhận `/student` trả đúng 5 dòng. Hoàn thiện họ tên bản ghi `SV005` trước khi chụp minh chứng.

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

Trước khi push, sửa `DOCKERHUB_USERNAME` trong `.env` thành đúng username Docker Hub hoặc namespace organization mà tài khoản của bạn có quyền **write**. Giá trị mẫu `your-dockerhub-username` không dùng để push. Nếu dùng organization, cần quyền ghi vào từng repository (hoặc tạo các repository trong organization trước).

```powershell
$dockerHubUser = 'your-dockerhub-username'
docker login --username $dockerHubUser
docker compose --env-file .env config --images
docker compose --env-file .env build web-frontend-server web-frontend-server2 application-backend-server object-storage-server api-gateway-proxy-server keycloak-user-init
docker compose --env-file .env push web-frontend-server web-frontend-server2 application-backend-server object-storage-server api-gateway-proxy-server keycloak-user-init
```

Khi `docker login` hỏi password, dùng Docker Hub Personal Access Token có quyền **Read & Write**; không ghi token vào `.env`, lệnh, hay Git. Kiểm tra danh sách `config --images`: tất cả image tùy chỉnh phải bắt đầu bằng namespace bạn có quyền ghi. `insufficient_scope` nghĩa là credentials hiện tại không được phép push tới namespace/repository được tag; xác thực lại đúng account hoặc nhờ chủ organization cấp quyền ghi.

Triển khai EC2 cần tài khoản/quyền AWS và thông tin Docker Hub của nhóm. Trên EC2: cài Docker Engine/Compose, chép `.env` an toàn, dùng tag image đã push thay cho build nếu cần, bật Security Group cho SSH giới hạn IP và HTTP/HTTPS; không public các cổng quản trị được bind loopback. Ghi lại public URL, ảnh test và log sau khi tự chạy thực tế.

## Trạng thái phần mở rộng

Đối chiếu với mã nguồn hiện tại:

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| API Gateway và cân bằng tải Round Robin cho hai web node | Đã cấu hình, đã ghi nhận kiểm thử local | Kiểm tra header `X-Served-By` bằng lệnh ở trên. |
| Keycloak OIDC và Flask xác thực JWT tại `/secure` | Đã cấu hình, đã ghi nhận kiểm thử local | Realm, client và user init đã có; cấu hình hiện phù hợp demo local. |
| DNS nội bộ cho zone `cloud.local` | Đã cấu hình, đã ghi nhận kiểm thử local | BIND phục vụ zone riêng; Docker DNS vẫn phân giải service name cho các container. |
| MinIO với các bucket mẫu | Đã cấu hình, đã ghi nhận kiểm thử local | `index.html` và `avatar.jpg` đã nạp; PDF báo cáo còn thiếu. |
| Prometheus/Grafana | Đã cấu hình, đã ghi nhận kiểm thử local | Đang scrape Node Exporter, hai Nginx Exporter và Prometheus; chưa giám sát mọi ứng dụng/database. |
| HTTPS/TLS, phân quyền role, backup/restore, failover theo healthcheck, container metrics và quản lý secret | Chưa triển khai | Đây là hướng mở rộng tiếp theo, không nên ghi là chức năng đã hoàn thành. |
| Push Docker Hub, triển khai AWS EC2 và ảnh/video minh chứng | Chưa thực hiện | Cần tài khoản/quyền của nhóm và phải bổ sung kết quả chạy thực tế. |

Lưu ý khi chốt báo cáo: file SQL hiện tại khai báo **4** sinh viên mẫu. Hãy kiểm tra số dòng thực tế qua `/student` trước khi ghi số liệu hoặc chụp minh chứng; named volume cũ có thể giữ dữ liệu khác với script khởi tạo hiện tại.
