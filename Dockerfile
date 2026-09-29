# ═══════════════════════════════════════════════════════════════════
# CP2 — Dockerfile production: multi-stage, slim, non-root, healthcheck
#
# Build: docker build -t day12-agent:prod .
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài dependency vào /install, stage này bị vứt đi ──
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Chỉ copy requirements trước: code đổi thì layer pip install vẫn dùng cache
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

# ── Stage 2: runtime — chỉ mang kết quả cài đặt + source code ──
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# User thường, không có quyền root
RUN useradd --create-home --uid 10001 appuser

COPY --from=builder /install /usr/local

WORKDIR /app
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8000') + '/health').read()" || exit 1

# 0.0.0.0 để bên ngoài container gọi vào được; PORT do platform cloud gán.
# `exec` để uvicorn thay thế sh và thành PID 1 → nhận được SIGTERM trực tiếp
# (sh không chuyển tiếp tín hiệu cho process con → graceful shutdown vô hiệu).
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
