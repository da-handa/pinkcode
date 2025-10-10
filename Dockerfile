# 1단계: Proc-Macro 컴파일 환경 (Host Environment)
FROM rust:latest AS host_builder

WORKDIR /app
COPY Cargo.toml ./

# proc-macro 캐시를 target_proc 디렉토리에 생성합니다.
# **--target=x86_64-unknown-linux-gnu**는 host 환경과 동일하여 proc-macro가 실행될 수 있게 합니다.
RUN mkdir src/ && echo "fn main() {}" > src/main.rs && cargo check --target=x86_64-unknown-linux-gnu

# 2단계: 최종 정적 바이너리 빌드 환경 (Target Environment)
FROM rust:alpine AS builder

# ✅ 수정: target 캐시만 가져옵니다. target 디렉토리 이름을 지정합니다.
# proc-macro 캐시만 target/x86_64-unknown-linux-gnu에 복사됩니다.
COPY --from=host_builder /app/target /app/target

# MUSL 도구 및 환경 설정
RUN apk add --no-cache musl-dev
ENV RUSTFLAGS="-C target-feature=+crt-static"

# 작업 디렉토리 설정
WORKDIR /app

# Cargo.toml 복사
COPY Cargo.toml ./

# 의존성만 미리 빌드하여 캐시 (이전 단계에서 proc-macro 캐시를 이미 가져왔습니다.)
# 이 단계는 이제 proc-macro를 무시하고 일반 의존성 빌드만 진행할 것입니다.
# Cargo는 복사해온 proc-macro 캐시를 사용하고, MUSL 타겟에 맞는 일반 의존성만 컴파일합니다.
RUN mkdir src/ && echo "fn main() {}" > src/main.rs && cargo build --release --target=x86_64-unknown-linux-musl
RUN rm -rf target/x86_64-unknown-linux-musl/release/deps/pinkcodeserver target/x86_64-unknown-linux-musl/release/pinkcodeserver

# 전체 소스 코드 복사 및 최종 빌드
COPY . .

# 정적 바이너리 빌드 (최종 실행 파일 생성)
RUN cargo build --release --target=x86_64-unknown-linux-musl

# --- 3단계: 실행 환경 (Runner) ---
FROM alpine:latest

# 런타임에 필요한 CA 인증서만 설치합니다.
RUN apk update && apk add ca-certificates && rm -rf /var/cache/apk/*

# Builder 단계에서 빌드된 실행 파일 복사
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/pinkcodeserver /usr/local/bin/

# 환경 변수 설정
ENV PORT=8080

# 서버 실행 명령어
CMD ["/usr/local/bin/pinkcodeserver"]