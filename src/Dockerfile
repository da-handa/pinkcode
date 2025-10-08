# --- 1단계: 빌드 환경 (Builder) ---
FROM rust:latest AS builder

# 작업 디렉토리 설정
WORKDIR /app

# 의존성 미리 캐시 및 빌드
COPY Cargo.toml Cargo.lock ./
# 임시 main.rs 파일로 의존성만 빌드하여 캐시합니다.
RUN mkdir src/ && echo "fn main() {}" > src/main.rs && cargo build --release
RUN rm -rf target/release/deps/pinkcodeserver target/release/pinkcodeserver

# 전체 소스 코드 복사 및 최종 빌드
COPY . .
# 실행 파일 이름이 'pinkcodeserver'이라고 가정합니다.
RUN cargo build --release

# --- 2단계: 실행 환경 (Runner) ---
FROM debian:stable-slim

# 🛠️ 수정: libssl3 설치 및 APT 캐시 제거 (중요!)
RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
    
# ... (나머지 코드 유지) ...

# Builder 단계에서 빌드된 실행 파일만 복사합니다.
COPY --from=builder /app/target/release/pink-code-server /usr/local/bin/

# 환경 변수 설정 (Fly.io에서 기본적으로 8080 포트를 사용하도록 설정했는지 확인)
ENV PORT=8080

# 서버 실행 명령어
CMD ["/usr/local/bin/pink-code-server"]