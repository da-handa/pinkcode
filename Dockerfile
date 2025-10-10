# 1단계: 정적 빌드 환경 (MUSL)
# Alpine 리눅스를 기반으로 하며, 정적 빌드에 최적화된 이미지를 사용합니다.
FROM ekidd/rust-musl-builder:latest AS builder

# 작업 디렉토리 설정
WORKDIR /home/rust/src

# Cargo.toml 및 Cargo.lock 복사
COPY Cargo.toml ./

# 의존성만 미리 빌드하여 캐시합니다.
# 임시 main.rs 파일로 의존성만 빌드하여 캐시합니다.
RUN mkdir src/ && echo "fn main() {}" > src/main.rs && cargo build --release
RUN rm -rf target/x86_64-unknown-linux-musl/release/deps/pinkcodeserver target/x86_64-unknown-linux-musl/release/pinkcodeserver

# 전체 소스 코드 복사 및 최종 빌드
COPY . .

# 정적 바이너리 빌드 (MUSL)
# ⚠️ 실행 파일 이름은 Cargo.toml에 정의된 "pinkcodeserver"를 따라야 합니다.
RUN cargo build --release

# --- 2단계: 실행 환경 (Runner) ---
# 라이브러리 의존성이 적은 가벼운 Alpine 리눅스를 사용합니다.
FROM alpine:latest

# 런타임에 필요한 CA 인증서만 설치합니다. (OpenSSL은 정적 빌드에 포함됨)
RUN apk update && apk add ca-certificates && rm -rf /var/cache/apk/*

# Builder 단계에서 빌드된 실행 파일만 복사합니다.
# 실행 파일 경로는 musl 빌드 환경에 맞게 변경되었습니다.
COPY --from=builder /home/rust/src/target/x86_64-unknown-linux-musl/release/pinkcodeserver /usr/local/bin/

# 환경 변수 설정
ENV PORT=8080

# 서버 실행 명령어
CMD ["/usr/local/bin/pinkcodeserver"]