# 1단계: 정적 빌드 환경 (Rust Alpine 사용)
FROM rust:latest-alpine AS builder

# MUSL 도구 설치 및 빌드 환경 설정
RUN apk add --no-cache musl-dev
ENV RUSTFLAGS="-C target-feature=+crt-static"

# 작업 디렉토리 설정
WORKDIR /app

# Cargo.toml만 복사 (Cargo.lock은 로컬에서 삭제했으므로)
COPY Cargo.toml ./

# 의존성만 미리 빌드하여 캐시 (빌드가 느린 musl 환경에선 필수)
RUN mkdir src/ && echo "fn main() {}" > src/main.rs && cargo build --release
RUN rm -rf target/release/deps/pinkcodeserver target/release/pinkcodeserver

# 전체 소스 코드 복사 및 최종 빌드
COPY . .

# 정적 바이너리 빌드 (최종 실행 파일 생성)
RUN cargo build --release

# --- 2단계: 실행 환경 (Runner) ---
# 라이브러리 의존성이 없는 가벼운 Alpine 리눅스만 사용
FROM alpine:latest

# 런타임에 필요한 CA 인증서만 설치합니다.
RUN apk update && apk add ca-certificates && rm -rf /var/cache/apk/*

# Builder 단계에서 빌드된 실행 파일 복사
# target/release 경로는 rust:latest-alpine 환경의 기본 경로입니다.
COPY --from=builder /app/target/release/pinkcodeserver /usr/local/bin/

# 환경 변수 설정
ENV PORT=8080

# 서버 실행 명령어
CMD ["/usr/local/bin/pinkcodeserver"]