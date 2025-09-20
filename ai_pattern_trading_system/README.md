# AI Pattern Trading System
## 진짜 AI 기반 패턴 거래 시스템

이 프로젝트는 **진짜 AI 기술**을 사용하여 5-10년 과거 데이터에서 성공 패턴을 추출하고, 실시간으로 차트를 분석하여 거래 신호를 생성하는 시스템입니다.

## 🎯 주요 기능

### 1. 진짜 AI 패턴 추출
- **5-10년 과거 데이터 분석**: 실제 수익을 낸 패턴만 추출
- **이미지 기반 패턴 인식**: OpenCV + CNN으로 차트 이미지 분석
- **벡터화된 패턴 저장**: AI가 인식할 수 있는 형태로 변환
- **성공률 기반 필터링**: 50+ pips 수익, 70%+ 성공률 패턴만 저장

### 2. 실시간 AI 분석
- **실시간 차트 모니터링**: WebSocket으로 실시간 데이터 수신
- **AI 패턴 매칭**: 코사인 유사도 + DTW 알고리즘
- **90% 이상 유사도**: 정확한 매칭만 거래 신호 생성
- **다중 기술적 지표**: RSI, MACD, ADX, 볼린저 밴드 등

### 3. 자동 거래 실행
- **실시간 거래 실행**: Binance API 연동
- **리스크 관리**: 손절매 2%, 익절매 4%
- **포지션 관리**: 최대 포지션 크기 제한
- **일일 거래 제한**: 과도한 거래 방지

## 🏗️ 시스템 아키텍처

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

## 🚀 설치 및 실행

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

## 🔧 설정

### API 키 설정
`backend/main.py`에서 실제 거래소 API 키를 설정하세요:

```python
self.exchanges = {
    'binance': ccxt.binance({
        'apiKey': 'YOUR_API_KEY',
        'secret': 'YOUR_SECRET_KEY',
        'sandbox': True,  # 테스트 모드
    })
}
```

### AI 설정
`backend/ai_modules/`에서 AI 분석 파라미터를 조정할 수 있습니다:

- `similarity_threshold`: 패턴 유사도 임계값 (기본: 0.9)
- `confidence_threshold`: AI 신뢰도 임계값 (기본: 0.8)
- `min_profit_pips`: 최소 수익 목표 (기본: 50 pips)

## 📊 사용법

### 1. 시스템 초기화
- 백엔드 서버 시작 시 자동으로 5년 과거 데이터에서 성공 패턴 추출
- 추출된 패턴은 메모리에 저장되어 실시간 분석에 사용

### 2. 실시간 모니터링
- 대시보드에서 실시간 AI 분석 결과 확인
- 패턴 매칭 상태, 신뢰도, 예상 수익률 모니터링

### 3. 자동 거래
- AI가 90% 이상 유사한 패턴을 감지하면 자동 거래 실행
- 수동으로 거래 시작/중지 가능

### 4. 성과 분석
- 실시간 수익률, 승률, 거래 통계 확인
- 패턴별 성과 분석

## ⚠️ 주의사항

### 1. 테스트 모드
- 기본적으로 샌드박스 모드로 설정되어 실제 거래가 실행되지 않음
- 실제 거래 전 충분한 백테스팅 권장

### 2. 리스크 관리
- AI 시스템이 100% 정확하지 않을 수 있음
- 손실 가능성을 고려하여 투자 금액 조절
- 정기적인 성과 모니터링 필요

### 3. 기술적 제한
- Pine Script와 달리 웹 환경에서는 제한이 적지만
- 네트워크 연결 상태에 따라 성능이 달라질 수 있음

## 🛠️ 개발 정보

### 기술 스택
- **Frontend**: React 18, Ant Design, Recharts
- **Backend**: Python 3.8+, FastAPI, WebSocket
- **AI/ML**: TensorFlow, OpenCV, scikit-learn
- **Database**: Redis (캐싱), PostgreSQL (선택사항)
- **Trading**: CCXT (Binance, Yahoo Finance)

### 성능 최적화
- Redis 캐싱으로 데이터 조회 속도 향상
- 비동기 처리로 실시간 성능 최적화
- 이미지 특징 추출 최적화

## 📈 향후 개선 계획

1. **더 많은 거래소 지원**: MT5, Interactive Brokers 등
2. **고급 AI 모델**: LSTM, Transformer 기반 예측
3. **실시간 알림**: 텔레그램, 슬랙 알림
4. **모바일 앱**: React Native 기반 모바일 앱
5. **클라우드 배포**: AWS, GCP 클라우드 배포

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 📞 문의

프로젝트에 대한 문의사항이 있으시면 이슈를 생성해주세요.

---

**⚠️ 면책 조항**: 이 소프트웨어는 교육 및 연구 목적으로 제공됩니다. 실제 거래에서 발생하는 손실에 대해서는 사용자가 전적으로 책임집니다.
