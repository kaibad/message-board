# Build Stage
FROM python:3.12-alpine AS builder
WORKDIR /app

# Install build dependencies (Alpine way)
RUN apk add --no-cache \
    gcc \
    musl-dev \
    mariadb-dev \
    pkgconfig

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# Stage 2
FROM python:3.12-alpine
WORKDIR /app

# Runtime dependencies only
RUN apk add --no-cache \
    mariadb-connector-c

COPY --from=builder /install /usr/local
COPY . .
EXPOSE 5000
CMD ["python","app.py"]


