# Thông Tin Deploy — Checkpoint 5

> `pytest tests/test_cp5.py` đọc file này để tìm địa chỉ service và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, không ghi giá trị API key.**

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Phạm Minh Hiếu |
| Mã học viên | 2A202602630 |
| Repo | https://github.com/hieulovecat/K4-L3B-DAY12-PhamMinhHieu-2A202602630-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://agent-production-a8a3.up.railway.app |
| Platform | Railway (build từ `Dockerfile`, cấu hình trong `railway.toml`) |
| Ngày deploy | 2026-09-29 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Railway tự gán (log: `Uvicorn running on http://0.0.0.0:8080`) |
| `AGENT_API_KEY` | ✅ | đặt qua Railway Variables, khóa riêng cho cloud, không nằm trong repo |
| `REDIS_URL` | ✅ | tham chiếu `${{Redis.REDIS_URL}}` tới Redis service của Railway |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Chạy ngày 2026-09-29 vào `https://agent-production-a8a3.up.railway.app`:

```
$ curl -i <URL>/health
HTTP/1.1 200 OK
{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i <URL>/ready
HTTP/1.1 200 OK
{"status":"ready","redis":true}

$ curl -i -X POST <URL>/ask   (không có API key)
HTTP/1.1 401 Unauthorized
{"detail":"invalid or missing API key"}

$ curl -i -X POST <URL>/ask   (có API key)
HTTP/1.1 200 OK
{"answer":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.","user_id":"sv-test","history_length":0,"cost_usd":2.145e-05,"tokens":{"in":3,"out":35}}

$ rate limit: 15 request liên tiếp
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429
```

Ghi chú: trên Git Bash (Windows), lệnh 4 với `-d '...là gì?'` trả 400 vì terminal
gửi ký tự tiếng Việt không phải UTF-8. Gửi body từ file UTF-8
(`--data-binary @body.json`) thì trả 200 như trên.

## Ảnh Chụp Màn Hình

- `screenshots/dashboard.png` — trang service `agent` trên Railway (deployment SUCCESS)
- `screenshots/health.png` — kết quả gọi `/health` trên Public URL
