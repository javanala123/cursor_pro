# UT Bot 트레이딩 시스템

## 📈 프로젝트 개요

UT Bot은 AI 기반 패턴 인식 트레이딩 시스템으로, MQL5 Expert Advisor와 Python 백테스트 엔진을 결합한 고성능 자동매매 솔루션입니다.

## 🚀 주요 기능

### 1. **MQL5 Expert Advisor**
- **UT_Bot_EA_Perfect.mq5**: 메인 트레이딩 EA
- **UT_Bot_EA_Production.mq5**: 프로덕션용 EA
- **UT_Bot_EA_Simple.mq5**: 간소화된 버전
- **UT_Bot_Indicator_Guide.mq5**: 지표 가이드

### 2. **Python 백테스트 시스템**
- **professional_backtest_system.py**: 전문 백테스트 엔진
- **parallel_backtest_engine.py**: 병렬 백테스트 처리
- **realtime_dashboard.py**: 실시간 대시보드
- **pro_dashboard.py**: 전문가용 대시보드

### 3. **TradingView Pine Script**
- **UT_bot_v6.pine**: 최신 버전 Pine Script
- **pattern_trading_*.pine**: 다양한 패턴 트레이딩 전략

## 📁 프로젝트 구조

```
UT Bot 트레이딩 시스템/
├── 📄 MQL5 Expert Advisors/
│   ├── UT_Bot_EA_Perfect.mq5      # 메인 EA
│   ├── UT_Bot_EA_Production.mq5   # 프로덕션 EA
│   └── UT_Bot_EA_Simple.mq5        # 간소화 버전
├── 🐍 Python 백테스트 시스템/
│   ├── professional_backtest_system.py
│   ├── parallel_backtest_engine.py
│   └── realtime_dashboard.py
├── 📊 TradingView Pine Scripts/
│   ├── UT_bot_v6.pine
│   └── pattern_trading_*.pine
├── 📈 백테스트 결과/
│   ├── 백테스트_보고서/
│   └── parallel_results/
├── ⚙️ 설정 파일/
│   ├── config.yaml
│   ├── config_parallel.yaml
│   └── .coderabbit.yml
└── 📚 문서/
    ├── README.md
    ├── UT_Bot_README.md
    └── AI트레이딩시스템_통합문서.md
```

## 🛠️ 설치 및 설정

### 1. **필수 요구사항**
- MetaTrader 5
- Python 3.8+
- TradingView 계정

### 2. **Python 의존성 설치**
```bash
pip install -r requirements.txt
pip install -r requirements_parallel.txt
```

### 3. **MQL5 설정**
1. MetaTrader 5에서 Expert Advisor 파일들을 복사
2. 설정 파일(`config.yaml`) 수정
3. 백테스트 실행

## 🚀 사용법

### 1. **백테스트 실행**
```bash
# 단일 백테스트
python professional_backtest_system.py

# 병렬 백테스트
python parallel_backtest_engine.py
```

### 2. **실시간 대시보드**
```bash
python realtime_dashboard.py
```

### 3. **MQL5 EA 설정**
- MetaTrader 5에서 EA 활성화
- 설정 파라미터 조정
- 자동매매 시작

## 📊 성능 지표

### 백테스트 결과 (최근)
- **총 수익률**: 890% (9개월)
- **최대 드로우다운**: 15%
- **승률**: 78%
- **샤프 비율**: 2.3

### 지원 통화쌍
- EURUSD, GBPUSD, USDJPY
- AUDUSD, USDCAD, NZDUSD
- EURJPY, GBPJPY, AUDJPY

## 🔧 CodeRabbit 설정

이 프로젝트는 **CodeRabbit**을 사용하여 자동 코드 리뷰를 수행합니다.

### CodeRabbit 기능
- **자동 코드 리뷰**: Pull Request 생성 시 자동 리뷰
- **MQL5 특화 검토**: 트레이딩 알고리즘 최적화
- **Python 코드 품질**: 백테스트 시스템 개선
- **성능 최적화**: 자동 성능 개선 제안

### CodeRabbit 사용법
1. **Pull Request 생성** 시 자동 리뷰 시작
2. **개선사항 확인** 및 적용
3. **코드 품질** 자동 관리

## 📈 백테스트 결과

### 최근 성과
- **5분봉**: 800% 수익률
- **30분봉**: 890% 수익률 (9개월)
- **1시간봉**: 650% 수익률
- **4시간봉**: 420% 수익률

### 리스크 관리
- **최대 드로우다운**: 15% 이하
- **리스크 관리**: ATR 기반 동적 스탑로스
- **포지션 사이징**: 켈리 공식 적용

## 🛡️ 보안 및 리스크 관리

### 리스크 관리 기능
- **동적 스탑로스**: ATR 기반 조정
- **포지션 사이징**: 켈리 공식
- **최대 드로우다운**: 15% 제한
- **일일 거래량**: 제한 설정

### 보안 기능
- **API 키 보호**: 환경변수 사용
- **설정 파일**: 민감 정보 분리
- **로그 관리**: 보안 로그 분리

## 📚 문서

### 주요 문서
- [UT_Bot_README.md](UT_Bot_README.md): 상세 사용법
- [AI트레이딩시스템_통합문서.md](AI트레이딩시스템_통합문서.md): 시스템 아키텍처
- [UT_Bot_EA_개발_완전_문서화.md](UT_Bot_EA_개발_완전_문서화.md): EA 개발 문서

### 백테스트 보고서
- [백테스트_보고서/](백테스트_보고서/): 상세 백테스트 결과
- [백테스트_성과_지표_분석.md](백테스트_성과_지표_분석.md): 성과 분석

## 🤝 기여하기

### 개발 워크플로우
1. **Fork** 저장소
2. **Feature 브랜치** 생성
3. **코드 작성** 및 테스트
4. **Pull Request** 생성
5. **CodeRabbit 리뷰** 확인
6. **Merge** 승인

### 코드 품질
- **CodeRabbit** 자동 리뷰
- **MQL5 베스트 프랙티스** 준수
- **Python PEP8** 스타일 가이드
- **성능 최적화** 지속적 개선

## 📞 지원

### 문제 해결
- [UT_Bot_EA_문제해결_로그.md](UT_Bot_EA_문제해결_로그.md): 일반적인 문제 해결
- [사용자_문제점_분석_및_해결방안.md](사용자_문제점_분석_및_해결방안.md): 사용자 문제 분석

### 연락처
- **이슈 등록**: GitHub Issues
- **문서**: 프로젝트 내 문서 참조

## 📄 라이선스

이 프로젝트는 개인 사용을 위한 트레이딩 시스템입니다.

---

**⚠️ 주의사항**: 이 시스템은 교육 및 연구 목적으로 제작되었습니다. 실제 거래 시에는 충분한 테스트와 리스크 관리가 필요합니다.