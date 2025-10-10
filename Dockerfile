# 1단계: Proc-Macro 컴파일 환경 (Host Environment)
FROM rust:latest AS host_builder

WORKDIR /app
COPY Cargo.toml ./

# src/main.rs 더미 파일을 생성하고 의존성 캐시를 생성합니다.
RUN mkdir src/ && echo "fn main() {}" > src/main.rs && cargo check

# 2단계: 최종 정적 바이너리 빌드 환경 (Target Environment)
FROM rust:alpine AS builder

# ✅ 수정: Cargo 바이너리 복사 라인을 제거하고, target 캐시만 복사합니다.
# COPY --from=host_builder /usr/local/cargo /usr/local/cargo <--- 이 줄을 제거하세요!
COPY --from=host_builder /app/target /app/target

# MUSL 도구 및 환경 설정
RUN apk add --no-cache musl-dev
ENV RUSTFLAGS="-C target-feature=+crt-static"

# 작업 디렉토리 설정
WORKDIR /app

# Cargo.toml 복사
COPY Cargo.toml ./

# 의존성만 미리 빌드하여 캐시 (Cargo 명령어는 이제 정상 작동합니다)
RUN mkdir src/ && echo "fn main() {}" > src/main.rs && cargo build --release
RUN rm -rf target/release/deps/pinkcodeserver target/release/pinkcodeserver

# 전체 소스 코드 복사 및 최종 빌드
COPY . .

# 정적 바이너리 빌드 (최종 실행 파일 생성)
RUN cargo build --release

# --- 3단계: 실행 환경 (Runner) ---
FROM alpine:latest

# 런타임에 필요한 CA 인증서만 설치합니다.
RUN apk update && apk add ca-certificates && rm -rf /var/cache/apk/*

# Builder 단계에서 빌드된 실행 파일 복사
COPY --from=builder /app/target/release/pinkcodeserver /usr/local/bin/

# 환경 변수 설정
ENV PORT=8080

# 서버 실행 명령어
CMD ["/usr/local/bin/pinkcodeserver"]