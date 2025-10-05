use axum::{
    routing::{get, post},
    http::{StatusCode, Method}, 
    response::IntoResponse,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::{net::SocketAddr, time::Duration}; // Duration 추가
use dotenvy::dotenv;
use tower_http::cors::{CorsLayer, Any}; 

// --- 1. 클라이언트 통신 데이터 구조체 ---

#[derive(Deserialize, Debug)]
struct MessageRequest { message: String, }

#[derive(Serialize, Debug)]
struct MessageResponse { response: String, }

// --- 2. Gemini API 통신 관련 데이터 구조체 ---

#[derive(Serialize, Debug)]
struct ContentPart { text: String, }

#[derive(Serialize, Debug)]
struct Content { parts: Vec<ContentPart>, }

#[derive(Serialize, Debug)]
struct GeminiRequest { contents: Vec<Content>, }

// AI 응답을 받아올 구조
#[derive(Deserialize, Debug)]
struct CandidatePart { text: String, }

#[derive(Deserialize, Debug)]
struct CandidateContent { parts: Vec<CandidatePart>, }

#[derive(Deserialize, Debug)]
struct Candidate { content: CandidateContent, }

#[derive(Deserialize, Debug)]
struct GeminiResponse { candidates: Vec<Candidate>, }

// --- 3. Axum 서버 및 라우팅 설정 ---

#[tokio::main]
async fn main() {
    // 1. 비밀번호 파일(.env) 로드
    dotenv().ok();
    
    // 2. 웹사이트와 통신할 수 있도록 보안 허가증 설정
    let cors = CorsLayer::new()
        .allow_origin(Any) // 모든 웹사이트 접근 허용 (개발용)
        .allow_methods([Method::GET, Method::POST]) // axum::http::Method 사용
        .allow_headers(Any);
    
    // 3. 서버 통신 경로(라우트) 설정
    let app = Router::new()
        .route("/", get(hello_world)) 
        .route("/chat", post(handle_chat)); 
        
    // CORS 레이어를 명확하게 적용 (타입 에러 해결)
    let app = app.layer(cors); 

    // 4. 서버 실행 주소 설정 (포트 3000번)
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    println!("Pink Code Rust Server listening on {}", addr);

    // 5. 서버 시작! (axum::Server::bind 대신 axum::serve 사용)
    // NOTE: 휴대폰 접속을 위해 0.0.0.0으로 바인딩합니다.
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app)
        .await
        .unwrap();
}

// 서버 생존 확인 메시지
async fn hello_world() -> &'static str {
    "Pink Code Rust Server is running and ready for chat!"
}

// 4. 메시지 처리 및 AI 응답 요청 함수
async fn handle_chat(Json(payload): Json<MessageRequest>) -> impl IntoResponse {
    // 1. 비밀번호(.env) 가져오기
    let api_key = match std::env::var("GEMINI_API_KEY") {
        Ok(key) => key,
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "API 키가 설정되지 않았습니다.".to_string()).into_response(),
    };

    let user_message = payload.message;
    
    // 2. AI 통신 주소 설정
    let model_name = "gemini-2.5-flash-preview-05-20";
    let api_url = format!("https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent?key={}", model_name, api_key);

    // 3. AI 코치 페르소나 설정 (대화형 유도로 변경됨)
    let system_prompt = "당신은 세계적인 연애 코치 'Pink Code'입니다. 답변은 **따뜻하고 친절한 공감** 후, 사용자가 더 많은 **정보를 제공하도록 유도하는 1~2가지 핵심 질문**만 던져 짧게 마무리합니다. **절대로 첫 답변에 길고 장황한 전략이나 코칭 내용을 제시하지 마세요.** 대화 형식으로만 진행하며, 답변은 한국어로 제공됩니다.";
    
    // 4. AI에 보낼 메시지 패키징 (시스템 페르소나 + 사용자 메시지)
    let gemini_request = GeminiRequest {
        contents: vec![
            Content { parts: vec![ContentPart { text: system_prompt.to_string() }], },
            Content { parts: vec![ContentPart { text: user_message.clone() }], },
        ],
    };

    // 5. AI에 요청을 보내고 응답을 기다림 (Timeout 45초 설정)
    let client = reqwest::Client::new();
    let res = match client.post(&api_url)
        .json(&gemini_request)
        .timeout(Duration::from_secs(45)) // 응답 지연 문제 해결을 위한 Timeout 설정
        .send().await 
    {
        Ok(r) => r,
        Err(e) => {
            // 타임아웃 발생 시 명시적인 에러 코드를 반환합니다.
            if e.is_timeout() {
                return (StatusCode::REQUEST_TIMEOUT, "AI 코치 응답 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.".to_string()).into_response();
            }
            return (StatusCode::INTERNAL_SERVER_ERROR, format!("AI 통신 실패: {}", e)).into_response();
        }
    };

    // 6. AI 응답을 받아서 텍스트만 추출
    let api_response: GeminiResponse = match res.json().await {
        Ok(json) => json,
        Err(_) => return (StatusCode::BAD_GATEWAY, "AI 응답을 처리하는 데 실패했습니다.".to_string()).into_response(),
    };

    let ai_text = api_response.candidates
        .get(0).and_then(|c| c.content.parts.get(0))
        .map(|p| p.text.clone())
        .unwrap_or_else(|| "AI 응답 추출 실패.".to_string());

    // 7. 웹사이트에 최종 응답을 보냄
    (StatusCode::OK, Json(MessageResponse { response: ai_text, })).into_response()
}