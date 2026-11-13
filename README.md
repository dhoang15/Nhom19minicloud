# MyMiniCloud — Nhóm 19

MiniCloud mô phỏng 9 vai trò máy chủ bằng Docker Compose: Web, Application, Database, Identity, Object Storage, DNS, Monitoring, Grafana và API Gateway. Hai web node, Node Exporter, Nginx Exporter và tác vụ khởi tạo MinIO là các container phụ trợ để kiểm thử và vận hành.

## Cấu trúc

- Mỗi service có thư mục riêng với source/configuration/Dockerfile của service đó.
- `docker-compose.yml`, `.env.example` và `README.md` ở thư mục gốc là điểm vào chung.
- Compose phụ cho demo Web/Storage nằm trong `web-frontend-server/`; compose Monitoring nằm trong `monitoring-grafana-dashboard-server/`. Dùng compose gốc để chạy toàn stack.
- SQL khởi tạo nằm trong `relational-database-server/init/`.
- Hướng dẫn, kiến trúc và báo cáo nằm trong `docs/`.
- Đề bài gốc `Báo Cáo Cuối Kỳ.docx` được giữ nguyên ở thư mục gốc; tài liệu dự án nằm trong `docs/`.

## Chạy local (PowerShell)

1. Tạo `.env` từ `.env.example`, sau đó thay mọi giá trị `CHANGE_ME` bằng giá trị riêng:

   ```powershell
   Copy-Item .env.example .env
   ```

   Cổng host mặc định dùng dải `180xx` vì Windows có thể dành riêng `8080`–`8085`; đổi lại trong `.env` nếu hệ điều hành của bạn cho phép dùng cổng mẫu trong đề.

2. Khởi động toàn bộ stack:

   ```powershell
   docker compose up --build -d
   docker compose ps
   ```

3. Kiểm tra API, route qua Gateway và cân bằng tải:

   ```powershell
   Invoke-RestMethod http://localhost:18085/hello
   Invoke-RestMethod http://localhost/api/hello
   Invoke-RestMethod http://localhost/student
   1..6 | ForEach-Object {
     (Invoke-WebRequest http://localhost/ -UseBasicParsing).Headers['X-Served-By']
   }
   ```

Các địa chỉ local:

| Thành phần | URL |
|---|---|
| Gateway (điểm vào chung) | `http://localhost/` |
| Web node 1 / 2 | `http://localhost:18080` / `http://localhost:18082` |
| Backend trực tiếp | `http://localhost:18085` |
| Keycloak Admin | `http://localhost:18081` |
| MinIO API / Console | `http://localhost:9000` / `http://localhost:9001` |
| Prometheus / Grafana | `http://localhost:9090` / `http://localhost:3000` |

Các cổng được bind vào loopback theo mặc định để chỉ máy local truy cập được. Khi triển khai EC2, đặt `GATEWAY_BIND=0.0.0.0` và chỉ mở cổng 80/443 cùng SSH giới hạn theo IP quản trị trong Security Group; không public các cổng quản trị.

## Kiểm thử các dịch vụ

- Database/API: `/student` và `/students-db` đọc từ `studentdb`.
- OIDC: xem hướng dẫn trong [docs/runbook.md](docs/runbook.md); realm được import từ `authentication-identity-server/realm/`.
- DNS: kiểm tra zone với `docker compose exec internal-dns-server named-checkzone cloud.local /etc/bind/db.cloud.local`.
- Prometheus: `http://localhost:9090/targets`; job `node`, `web-nginx` và `prometheus` phải `UP`.
- Grafana: dashboard được provision tự động; cấu hình trong `monitoring-grafana-dashboard-server/provisioning/`.
- MinIO: `object-storage-init` tạo bucket và nạp file mẫu. Nếu file PDF mẫu chưa có, log cảnh báo và bucket `documents` sẽ không có PDF.

## Vòng đời dữ liệu

```powershell
docker compose down
```

Lệnh này dừng stack nhưng giữ named volumes và dữ liệu MinIO. Không thêm `-v` nếu không chủ ý xóa dữ liệu.

Chi tiết kiến trúc, kiểm thử và nội dung báo cáo: [docs/final-report.md](docs/final-report.md).
