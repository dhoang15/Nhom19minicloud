# Hướng dẫn phối hợp cấu hình Load Balancer (Dành cho Thành viên 1 - API Gateway / Proxy)

Để giữ nguyên phạm vi trách nhiệm và không tự ý ghi đè thư mục `api-gateway-proxy-server/`, cấu hình dưới đây là phần tham chiếu để **Thành viên 1** tích hợp vào file `api-gateway-proxy-server/nginx.conf` khi kiểm thử **Yêu cầu mở rộng số 10 (Load Balancer Round Robin)**:

```nginx
events {}

http {
  # Khai báo cụm upstream gồm 2 Web Server theo thuật toán Round Robin (mặc định của Nginx)
  upstream web_frontend_cluster {
    server web-frontend-server1:80;
    server web-frontend-server2:80;
  }

  server {
    listen 80;

    # Định tuyến giao diện tĩnh và /blog/ qua cụm Load Balancer
    location / {
      proxy_pass http://web_frontend_cluster;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Các route /api/, /student/ và /auth/ do Thành viên 1 và nhóm Backend/Auth quản lý
  }
}
```

> **Lưu ý:** Trong `docker-compose.web-storage.yml`, container thứ nhất có network alias là cả `web-frontend-server` và `web-frontend-server1`, nên dù `nginx.conf` của Thành viên 1 gọi `web-frontend-server:80` (cơ bản) hay `web-frontend-server1:80` + `web-frontend-server2:80` (mở rộng Load Balancer) thì đều phân giải tên miền nội bộ thành công trên mạng `cloud-net`.
