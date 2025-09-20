# AI 트레이딩 시스템 프로젝트 통합 문서

**Last synced: 2025-01-15T20:30:00Z**

## 개요

Python FastAPI 기반의 실시간 AI 패턴 거래 시스템입니다. 5-10년 과거 데이터에서 성공 패턴을 추출하고, 실시간으로 차트를 분석하여 자동 거래를 실행하는 완전 자동화 시스템입니다.

### 핵심 특징
- **진짜 AI 패턴 추출**: 5-10년 과거 데이터에서 실제 수익 패턴만 추출
- **실시간 분석**: WebSocket 기반 실시간 차트 모니터링
- **자동 거래 실행**: Binance API 연동 자동 거래
- **웹 대시보드**: React 기반 실시간 모니터링 인터페이스
- **다중 거래소 지원**: MT5, Binance 연동

## 아키텍처

### 시스템 구조
```
Frontend (React)          Backend (Python FastAPI)          AI Modules
├── Dashboard             ├── main.py                      ├── pattern_extractor.py
├── Pattern Analysis      ├── ai_modules/                  ├── pattern_matcher.py
├── Trading Panel         │   ├── pattern_extractor.py     ├── real_time_analyzer.py
├── Performance          │   ├── pattern_matcher.py       └── ...
└── Settings              │   └── real_time_analyzer.py
                          ├── trading/
                          │   └── trade_executor.py
                          └── data/
                              └── data_manager.py
```

### 기술 스택
- **Frontend**: React 18, Ant Design, Recharts, Socket.io
- **Backend**: Python 3.13, FastAPI, WebSocket, Uvicorn
- **AI/ML**: TensorFlow, OpenCV, scikit-learn, NumPy, Pandas
- **Database**: Redis (캐싱), PostgreSQL (선택사항)
- **Trading**: CCXT (Binance, Yahoo Finance)
- **Image Processing**: Pillow, Matplotlib, Seaborn

### 파일 구조
```
ai_pattern_trading_system/
├── backend/
│   ├── main.py                    # 메인 서버 애플리케이션
│   ├── ai_modules/                # AI 모듈들
│   │   ├── pattern_extractor.py   # 패턴 추출기
│   │   ├── pattern_matcher.py     # 패턴 매칭기
│   │   └── real_time_analyzer.py  # 실시간 분석기
│   ├── trading/
│   │   └── trade_executor.py      # 거래 실행기
│   ├── data/
│   │   └── data_manager.py        # 데이터 관리자
│   └── requirements.txt           # Python 의존성
├── frontend/
│   ├── src/
│   │   ├── App.js                 # 메인 React 앱
│   │   └── components/
│   │       └── Dashboard.js       # 대시보드 컴포넌트
│   └── package.json               # Node.js 의존성
├── ai_trading_demo.html           # 데모 페이지
├── index.html                     # 메인 HTML
└── README.md                      # 프로젝트 문서
```

## 셋업

### 1. 백엔드 설정

```bash
# 프로젝트 디렉토리로 이동
cd ai_pattern_trading_system/backend

# 가상환경 생성 (Python 3.8+)
python -m venv venv

# 가상환경 활성화
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# 의존성 설치
pip install -r requirements.txt

# Redis 설치 (캐싱용)
# Windows: https://redis.io/docs/getting-started/installation/install-redis-on-windows/
# macOS: brew install redis
# Ubuntu: sudo apt install redis-server

# 백엔드 서버 실행
python main.py
```

### 2. 프론트엔드 설정

```bash
# 새 터미널에서 프론트엔드 디렉토리로 이동
cd ai_pattern_trading_system/frontend

# 의존성 설치
npm install

# 프론트엔드 서버 실행
npm start
```

### 3. 접속
- **프론트엔드**: http://localhost:3000
- **백엔드 API**: http://localhost:8000
- **API 문서**: http://localhost:8000/docs

### 4. API 키 설정

`backend/main.py`에서 실제 거래소 API 키를 설정:

```python
self.exchanges = {
    'binance': ccxt.binance({
        'apiKey': 'YOUR_API_KEY',
        'secret': 'YOUR_SECRET_KEY',
        'sandbox': True,  # 테스트 모드
    })
}
```

## 운영

### 1. 시스템 초기화
- 백엔드 서버 시작 시 자동으로 5년 과거 데이터에서 성공 패턴 추출
- 추출된 패턴은 메모리에 저장되어 실시간 분석에 사용
- Redis 캐싱으로 데이터 조회 속도 향상

### 2. 실시간 모니터링
- **대시보드**: 실시간 AI 분석 결과 확인
- **패턴 매칭**: 현재 차트와 저장된 패턴의 유사도 분석
- **거래 신호**: 90% 이상 유사한 패턴 감지 시 자동 거래 실행
- **성과 분석**: 실시간 수익률, 승률, 거래 통계

### 3. 자동 거래
- **진입 조건**: AI 신뢰도 80% 이상, 패턴 유사도 90% 이상
- **리스크 관리**: 손절매 2%, 익절매 4%
- **포지션 관리**: 최대 포지션 크기 제한
- **일일 거래 제한**: 과도한 거래 방지

### 4. AI 분석 파라미터 조정

`backend/ai_modules/`에서 AI 분석 파라미터를 조정:

- `similarity_threshold`: 패턴 유사도 임계값 (기본: 0.9)
- `confidence_threshold`: AI 신뢰도 임계값 (기본: 0.8)
- `min_profit_pips`: 최소 수익 목표 (기본: 50 pips)

## 트러블슈팅

### 일반적인 문제

#### 1. 서버 시작 실패
**문제**: `python main.py` 실행 시 오류
**해결**: 
- Python 버전 확인 (3.8+ 필요)
- 가상환경 활성화 확인
- 의존성 재설치: `pip install -r requirements.txt`

#### 2. Redis 연결 오류
**문제**: Redis 연결 실패
**해결**:
- Redis 서버 실행 확인
- 포트 6379 사용 가능한지 확인
- Redis 비밀번호 설정 확인

#### 3. API 키 오류
**문제**: 거래소 API 연결 실패
**해결**:
- API 키 및 시크릿 키 확인
- IP 화이트리스트 설정 확인
- 샌드박스 모드 활성화

#### 4. 프론트엔드 연결 실패
**문제**: React 앱에서 백엔드 API 호출 실패
**해결**:
- CORS 설정 확인
- 프록시 설정 확인 (`package.json`의 `proxy` 필드)
- 포트 충돌 확인

### 성능 최적화

#### 1. 메모리 사용량
- Redis 캐싱 활용
- 불필요한 데이터 정리
- 패턴 데이터 압축

#### 2. 실행 속도
- 비동기 처리 최적화
- 이미지 특징 추출 최적화
- 데이터베이스 쿼리 최적화

#### 3. 네트워크 최적화
- WebSocket 연결 안정화
- API 호출 최적화
- 캐싱 전략 개선

## 변경 이력

### v1.0.0 (2025-01-15)
- **메인 시스템 완성**: FastAPI + React 통합
- **AI 모듈 구현**: 패턴 추출, 매칭, 실시간 분석
- **자동 거래**: Binance API 연동
- **웹 대시보드**: 실시간 모니터링 인터페이스

### v0.9.0 (2025-01-10)
- **AI 강화**: 이미지 기반 패턴 분석
- **성능 최적화**: Redis 캐싱, 비동기 처리
- **UI 개선**: Ant Design 컴포넌트 적용

### v0.8.0 (2025-01-05)
- **백엔드 API**: FastAPI 기반 REST API
- **WebSocket**: 실시간 데이터 전송
- **기본 AI**: 패턴 추출 및 매칭

### v0.7.0 (2025-01-01)
- **프로젝트 초기화**: 기본 구조 설정
- **의존성 설정**: requirements.txt, package.json
- **개발 환경**: 가상환경, Docker 설정

---

**⚠️ 면책 조항**: 이 소프트웨어는 교육 및 연구 목적으로 제공됩니다. 실제 거래에서 발생하는 손실에 대해서는 사용자가 전적으로 책임집니다.
