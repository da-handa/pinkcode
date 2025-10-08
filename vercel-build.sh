#!/bin/bash

# 1. Rust 툴체인 설치
echo "Installing Rust toolchain..."
# -y 옵션을 사용하여 사용자 개입 없이 자동 설치를 진행합니다.
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 2. PATH 변수 적용 및 Build
echo "Sourcing environment and building project..."
# Rust 설치 후 생성된 환경 변수(.cargo/env)를 현재 셸 세션에 로드하여 cargo 명령어를 인식시킵니다.
. $HOME/.cargo/env

# cargo 명령어로 릴리스 빌드를 수행합니다. (프로젝트 폴더 안에서 실행된다고 가정)
cargo build --release

# 3. 최종 실행 파일에 실행 권한 부여 (404 오류 방지)
# 빌드된 핑크코드 서버 실행 파일에 실행 권한을 강제로 부여합니다.
echo "Granting execution permission to final binary..."
chmod +x pinkcodeserver/target/release/pinkcodeserver
