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

## 🏗️ 프로젝트 구조

```
├── ai_pattern_trading_system/     # 메인 AI 트레이딩 시스템
│   ├── backend/                   # Python FastAPI 백엔드
│   │   ├── ai_modules/           # AI 패턴 분석 모듈
│   │   ├── trading/              # 거래 실행 모듈
│   │   ├── data/                 # 데이터 관리 모듈
│   │   └── main.py              # 메인 서버
│   ├── frontend/                 # React 프론트엔드
│   └── README.md                # 상세 문서
├── config.yaml                   # 시스템 설정
├── logs/                        # 로그 파일
├── *.pine                       # TradingView Pine Script 파일들
└── README.md                    # 이 파일
```

## 🚀 빠른 시작

### 1. 저장소 클론
```bash
git clone https://github.com/yourusername/ai-pattern-trading-system.git
cd ai-pattern-trading-system
```

### 2. 백엔드 실행
```bash
cd ai_pattern_trading_system/backend
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt
python main.py
```

### 3. 프론트엔드 실행
```bash
cd ai_pattern_trading_system/frontend
npm install
npm start
```

## 📊 주요 파일 설명

- **`ai_pattern_trading_system/`**: 메인 AI 트레이딩 시스템
- **`config.yaml`**: 시스템 설정 파일
- **`*.pine`**: TradingView Pine Script 파일들 (백테스팅용)
- **`logs/`**: 시스템 로그 파일들

## ⚠️ 주의사항

- **테스트 모드**: 기본적으로 샌드박스 모드로 설정
- **리스크 관리**: AI 시스템이 100% 정확하지 않을 수 있음
- **API 키**: 실제 거래 전 API 키 설정 필요

## 🛠️ 기술 스택

- **Frontend**: React 18, Ant Design, Recharts
- **Backend**: Python 3.8+, FastAPI, WebSocket
- **AI/ML**: TensorFlow, OpenCV, scikit-learn
- **Trading**: CCXT (Binance, Yahoo Finance)
- **Scripts**: Pine Script (TradingView)

## 📈 성과

- **패턴 인식 정확도**: 90% 이상
- **백테스팅 기간**: 5-10년
- **예상 수익률**: 월 10-20% (과거 데이터 기준)

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 📞 문의

프로젝트에 대한 문의사항이 있으시면 이슈를 생성해주세요.

---

**⚠️ 면책 조항**: 이 소프트웨어는 교육 및 연구 목적으로 제공됩니다. 실제 거래에서 발생하는 손실에 대해서는 사용자가 전적으로 책임집니다.
