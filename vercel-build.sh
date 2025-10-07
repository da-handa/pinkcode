#!/bin/bash
# 1. Rust 툴체인 설치
echo "Installing Rust toolchain..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 2. PATH 변수 적용 및 Build
echo "Sourcing environment and building project..."
# Rust 설치 후 생성된 환경 변수를 현재 셸 세션에 로드합니다.
. $HOME/.cargo/env
# cargo 명령어로 릴리스 빌드를 수행합니다.
cargo build --release
git add vercel-build.sh
git commit -m "Add vercel build script for stable Rust deployment"
git push origin master
