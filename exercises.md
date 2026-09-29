# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder dưới mỗi câu bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Phạm Minh Hiếu  Mã học viên: 2A202602630

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Giả sử deploy bản mới lên Railway. Trong lúc dọn tab Variables của service, biến bị đổi tên thành AGENT_APIKEY (thiếu dấu gạch dưới), nên container không còn nhận được AGENT_API_KEY.

Nếu có mặc định "changeme", app vẫn khởi động bình thường. Railway gọi healthcheck /health, nhận 200, đánh dấu deployment là Active rồi gỡ bản cũ. Log build và deploy đều xanh. Sau đó có hai khả năng, tùy key dùng để làm gì:

Key xác thực request đi vào agent: endpoint giờ chấp nhận X-API-Key: changeme. Chuỗi này nằm công khai trong source code, trong README, trong .env.example. Domain *.up.railway.app lại truy cập được từ Internet, nên ai đọc được repo, hoặc chỉ cần đoán chuỗi mặc định phổ biến, là gọi được agent và đọc được dữ liệu phía sau nó. Không có lỗi hay cảnh báo nào, vì với app thì mọi thứ vẫn "đúng". Bạn chỉ biết khi có sự cố bảo mật.
Key dùng để gọi API upstream (LLM, dịch vụ nội bộ): mọi request tới upstream đều trả 401. Nếu code có retry, fallback hoặc try/except nuốt lỗi, người dùng chỉ thấy agent trả lời rỗng hoặc "xin lỗi, có lỗi xảy ra". Vài giờ sau mới có người báo, và bạn phải lội qua Deploy Logs trên Railway để tìm ra nguyên nhân là thiếu một biến môi trường.

Trong cả hai trường hợp, lỗi xảy ra xa thời điểm gây ra nó, cả về thời gian lẫn vị trí trong hệ thống.

Nếu không có mặc định (chết sớm), Settings() ném ValidationError: agent_api_key — Field required ngay dòng đầu khi khởi động. Process thoát, /health không bao giờ phản hồi, và Railway đánh dấu deployment là Failed hoặc Crashed. Khi đã cấu hình healthcheck path /health, Railway không chuyển traffic sang bản mới, nên bản cũ vẫn phục vụ và người dùng không bị ảnh hưởng. Người deploy thấy lỗi trong Deploy Logs sau vài chục giây, với thông báo chỉ đúng tên biến bị thiếu, và sửa lại trong tab Variables là xong. Railway sẽ tự redeploy khi biến thay đổi.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật lấy từ `docker compose logs agent` sau khi gọi `/ask`:
>
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T03:34:39.917361+00:00", "user_id": "sv01", "tokens_in": 392, "tokens_out": 43, "cost_usd": 8.46e-05}
> ```
>
> Hai việc làm được với dòng này mà `print("đã trả lời xong")` không làm được:
>
> 1. **Tổng hợp chi phí theo user.** Mỗi dòng có sẵn `user_id` và `cost_usd` dạng số,
>    nên lọc `event == "ask_completed"` rồi cộng `cost_usd` theo `user_id` là biết ngay
>    ai tiêu nhiều tiền nhất hôm nay. Với `print` thì chỉ có một câu chữ, không có
>    user nào, không có con số nào để cộng.
> 2. **Đếm lỗi và đặt cảnh báo theo thời gian.** Có `level` và `timestamp` chuẩn ISO nên
>    công cụ log của cloud đếm được số dòng `level == "error"` trong 5 phút gần nhất và
>    bắn cảnh báo khi vượt ngưỡng. Còn nhìn `tokens_in` tăng dần (392 ở lượt này vì
>    lịch sử hội thoại dài ra) còn phát hiện được prompt đang phình to.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1730 MB (1.73GB) |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Phần chênh lệch khoảng 1.46GB là những thứ chỉ cần lúc cài đặt, không cần lúc chạy:
>
> - **Base image:** `python:3.11` bản đầy đủ dựa trên Debian có sẵn gcc, make, các thư viện
>   `-dev` và header C, git, curl... để biên dịch package. Riêng base này đã hơn 1GB, trong
>   khi `python:3.11-slim` chỉ khoảng 189MB (mình đo được bằng `docker images`).
> - **Cache của pip:** bản 1 stage chạy `pip install` không có `--no-cache-dir`, nên file
>   wheel tải về còn nằm lại trong image.
> - **File thừa:** bản 1 stage `COPY . .` nên mang theo cả tests, tài liệu... còn bản
>   multi-stage chỉ copy `app/` và `utils/`.
>
> Với multi-stage, stage `builder` cài dependency vào `/install` rồi bị bỏ đi, stage runtime
> chỉ `COPY --from=builder /install /usr/local` lên nền slim. Image cuối chỉ còn Python,
> thư viện đã cài và code: 271MB, nhỏ hơn khoảng 6 lần.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Dockerfile của mình có thứ tự ở stage runtime: `useradd` → `COPY --from=builder /install`
> → `COPY app` → `COPY utils`, còn stage builder là `COPY requirements.txt` → `RUN pip install`.
>
> Sửa một ký tự trong `app/main.py` rồi build lại thì Docker báo `CACHED` cho toàn bộ stage
> builder (`COPY requirements.txt`, `pip install`) và cho `useradd`, `COPY --from=builder`
> ở stage runtime, vì requirements.txt không đổi. Chỉ từ layer `COPY app ./app` trở xuống
> là chạy lại, mà layer đó chỉ là copy vài file nên build lại mất vài giây.
>
> Nếu đặt `COPY . .` lên trước `RUN pip install` thì checksum của layer `COPY` thay đổi
> mỗi khi bất kỳ file nào đổi, và Docker huỷ cache từ layer đổi đầu tiên trở xuống. Kết
> quả là mỗi lần sửa code, `pip install` chạy lại từ đầu, tải và cài lại fastapi, uvicorn,
> redis... Với mạng chập chờn như lúc mình làm lab (pull image từ Docker Hub bị đứt nhiều
> lần), mỗi lần build lại sẽ mất vài phút thay vì vài giây.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện khi container chạy bằng root:
>
> 1. Code Python có lỗ hổng cho phép chạy lệnh tùy ý (ví dụ một thư viện bị lỗi
>    deserialization, hoặc mình lỡ đưa input của user vào `subprocess`).
> 2. Kẻ tấn công có shell trong container, và vì process chạy uid 0 nên shell đó là
>    **root trong container**: đọc được mọi file, sửa được code app, cài thêm công cụ.
> 3. Từ root trong container, họ tìm đường thoát ra: một lỗi kernel (container dùng chung
>    kernel với host), một volume mount nhạy cảm như `/var/run/docker.sock` hay thư mục
>    của host, hoặc container chạy `--privileged`. uid 0 trong container cũng là uid 0 trên
>    host nếu không bật user namespace, nên thoát ra được là thành **root trên host**.
>
> Lệnh `USER appuser` cắt chuỗi này ở bước 2: kẻ tấn công vào được nhưng chỉ là user
> uid 10001, không ghi được vào thư mục hệ thống, không cài được gói, và hầu hết các kỹ
> thuật thoát container đều cần quyền root nên không dùng được. Mình kiểm tra lại bằng
> `docker compose exec agent whoami` và kết quả là `appuser`.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request trong 2 giây**.
>
> Cách đạt được: với hạn mức 10/phút đếm theo phút đồng hồ, bộ đếm reset đúng giây :00.
> Người dùng gửi 10 request lúc 10:00:59 (hết quota của phút 10:00), rồi đến 10:01:00
> bộ đếm về 0, gửi tiếp 10 request lúc 10:01:01. Cả 20 request đều hợp lệ, nhưng thực
> tế nằm trong 2 giây, gấp đôi mức mình muốn cho phép.
>
> Với sliding window của mình, lúc 10:01:01 hàm `hit_count` chỉ xoá các entry cũ hơn
> `now - 60` (tức trước 10:00:01), nên 10 request lúc 10:00:59 vẫn còn trong ZSET và
> request thứ 11 bị 429 ngay. Khi test trên Railway, gửi 15 request liên tiếp thì kết quả
> đúng là 10 lần `200` rồi 5 lần `429`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> **Rate limit** giới hạn *tốc độ*: bao nhiêu request trong 60 giây gần nhất, không quan tâm
> request đó to hay nhỏ. **Cost guard** giới hạn *tổng tiền*: cộng dồn `cost_usd` của user
> trong cả tháng, không quan tâm gọi nhanh hay chậm. Một cái chống spam/lạm dụng tức thời,
> một cái chống hoá đơn tăng dần.
>
> - **Rate limit cho qua, cost guard chặn:** một user gọi rất đều đặn 8–9 request/phút,
>   không bao giờ chạm mức 10/phút, nhưng mỗi request dán vào một tài liệu dài hàng chục
>   nghìn token và gọi liên tục cả ngày. Không lần nào bị 429, nhưng tổng chi phí vượt
>   $10 của tháng, từ lúc đó `guard.check` trả 402.
> - **Cost guard cho qua, rate limit chặn:** một script lỗi vòng lặp gửi 100 request/giây
>   toàn câu hỏi ngắn kiểu "test". Mỗi request chỉ tốn khoảng $0.00002 nên ngân sách tháng
>   gần như không đổi, nhưng từ request thứ 11 trong phút đã bị 429. Nếu không có rate
>   limit thì script này vẫn chiếm hết tài nguyên server của người khác.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Nếu gộp làm một và cho nó kiểm tra Redis, khi Redis mất kết nối 30 giây:
>
> 1. **Giây 0:** Redis mất kết nối. Cả 3 container vẫn sống, vẫn trả lời được, chỉ không
>    đọc/ghi được lịch sử.
> 2. **Vài giây sau:** health check của cả 3 container cùng gọi Redis, cùng thất bại, cùng
>    trả 503.
> 3. **Sau vài lần thất bại liên tiếp** (ví dụ `retries: 3` × `interval: 10s`): orchestrator
>    kết luận cả 3 container đều "chết" và **restart cả 3 cùng lúc**.
> 4. **Giây 30:** Redis quay lại, nhưng lúc này cả 3 container đang khởi động lại. Không có
>    container nào nhận traffic, người dùng thấy 502/503 cho toàn bộ hệ thống.
> 5. Nếu container mới lên trước khi Redis ổn định thì nó lại fail health, lại bị restart,
>    có thể rơi vào vòng lặp restart.
>
> Một sự cố 30 giây của Redis thành sự cố sập cả hệ thống, lâu hơn 30 giây. Tách ra thì
> `/health` vẫn 200 (process còn sống, không restart), chỉ `/ready` trả 503 để load
> balancer tạm ngừng gửi request. Redis lên lại thì `/ready` về 200 và traffic tự quay lại,
> không container nào bị restart.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Mình chạy `docker compose up -d --scale agent=3` (compose map dải cổng `8000-8002`),
> rồi gọi `/ask` luân phiên 8000 → 8001 → 8002 → 8000 → 8001 → 8002 với cùng
> `X-User-Id: sv-scale2`. Kết quả `history_length`:
>
> ```
> luot 1 -> port 8000: history_length = 0
> luot 2 -> port 8001: history_length = 2
> luot 3 -> port 8002: history_length = 4
> luot 4 -> port 8000: history_length = 6
> luot 5 -> port 8001: history_length = 8
> luot 6 -> port 8002: history_length = 10
> ```
>
> Gọi qua nginx (cổng 8088) cũng vậy, log cho thấy mỗi container nhận đúng 2 request và
> con số vẫn tăng đều 0 → 10. Lý do là cả 3 container cùng đọc/ghi `history:<user>` trên
> một Redis.
>
> Nếu lịch sử nằm trong dict Python thì mỗi container có một dict riêng trong RAM. Với
> thứ tự gọi luân phiên như trên, con số sẽ là **0, 0, 0, 2, 2, 2**: mỗi container chỉ nhớ
> những lượt đi vào chính nó. Qua nginx thì còn tệ hơn vì không đoán trước được request
> vào container nào, agent sẽ "mất trí nhớ" ngẫu nhiên. Và chỉ cần một container restart là
> lịch sử của nó mất hết.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi:** graceful shutdown không hoạt động trong container. Mọi test CP4 đều pass,
> nhưng khi mình `docker stop` một container agent thì:
>
> ```
> exit code: 137
> ```
>
> và log dừng ở dòng `POST /ask 200 OK` cuối cùng, không có `Shutting down` hay
> `service_stopped`. Exit 137 = 128 + 9, tức container bị **SIGKILL**, không phải tự tắt.
>
> **Cách tìm nguyên nhân:** mình xem process nào là PID 1 trong container:
>
> ```
> docker exec <container> cat /proc/1/cmdline
> 1: sh -c uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
> 7: /usr/local/bin/python3.11 /usr/local/bin/uvicorn app.main:app ...
> ```
>
> PID 1 là `sh`, uvicorn chỉ là process con (PID 7). Docker gửi SIGTERM cho PID 1, nhưng
> `sh` không chuyển tiếp tín hiệu cho process con, nên handler trong `lifecycle.py` không
> bao giờ chạy. Hết thời gian chờ, Docker SIGKILL. Test không bắt được lỗi này vì test gọi
> `request_shutdown` trực tiếp, không đi qua Docker.
>
> **Cách sửa:**
> 1. Dockerfile: `CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]`.
>    `exec` làm uvicorn thay thế `sh` và trở thành PID 1, vẫn giữ được `${PORT}`.
> 2. `docker-compose.yml`: thêm `stop_grace_period: 30s` cho có đủ thời gian xử lý nốt request.
> 3. `railway.toml`: xoá dòng `startCommand = "uvicorn ..."` vì nó ghi đè CMD của Dockerfile
>    và sẽ gây lại đúng lỗi này trên Railway.
>
> Sau khi sửa, `/proc/1/cmdline` là uvicorn, `docker stop` cho `exit code: 0` và log có đủ
> `Shutting down` → `service_stopped` → `Finished server process [1]`. Trên Railway log cũng
> hiện `Started server process [1]` và `Uvicorn running on http://0.0.0.0:8080`, tức là app
> đọc đúng `$PORT` do Railway cấp.
