# Phối hợp Load Balancer

Cấu hình đang chạy được quản lý tập trung tại [api-gateway-proxy-server/nginx.conf](../api-gateway-proxy-server/nginx.conf) và [docker-compose.yml](../docker-compose.yml). Không cần chép một cấu hình upstream thứ hai vào thư mục web.

Hai upstream là `web-frontend-server1` và `web-frontend-server2`; Nginx dùng Round Robin mặc định. Mỗi web server trả header `X-Served-By`, để kiểm chứng:

```powershell
1..6 | ForEach-Object {
  (Invoke-WebRequest http://localhost/ -UseBasicParsing).Headers['X-Served-By']
}
```

Chạy lệnh nhiều lần và xác nhận giá trị luân phiên giữa hai node. Cả hai web server cũng có thể kiểm tra trực tiếp tại `http://localhost:18080` và `http://localhost:18082`.
