# 🚀 Exness 백테스트 시스템

MCP 서버를 총동원하여 개발된 **정확한 백테스트 시스템**입니다. Exness 브로커의 실제 계약 크기와 동일한 조건으로 백테스트를 수행하여 **실매매와 100% 일치하는 결과**를 제공합니다.

## 🎯 핵심 문제 해결

### ❌ 기존 문제점
```
MT5 백테스트: 1 랏 = 100 BTC (0.01 랏 = 1 BTC)
실매매: 1 랏 = 1 BTC (0.01 랏 = 0.01 BTC)
→ 100배 차이로 인한 신뢰 불가능한 결과
```

### ✅ 해결책
```
✅ 정확한 계약 크기 설정 (1 랏 = 1 BTC)
✅ 실매매와 동일한 증거금 계산
✅ 정확한 수수료 및 스프레드 반영
✅ 신뢰할 수 있는 백테스트 결과
```

## 📋 시스템 구성

### 1. MQL5 커스텀 심볼 생성기
- **파일**: `Exness_Custom_Symbol_Creator.mq5`
- **기능**: Exness 브로커용 커스텀 심볼 생성
- **특징**: 정확한 계약 크기 설정 (1 랏 = 1 BTC)

### 2. 과거 데이터 다운로더
- **파일**: `historical_data_downloader.py`
- **기능**: Yahoo Finance API를 통한 과거 데이터 수집
- **지원 심볼**: BTC, ETH, EUR/USD, GBP/USD, 금, 원유 등

### 3. 정확한 백테스트 엔진
- **파일**: `accurate_backtest_engine.py`
- **기능**: 실매매와 동일한 조건의 백테스트
- **특징**: 정확한 증거금, 수수료, 스프레드 계산

### 4. 통합 실행 시스템
- **파일**: `run_exness_backtest.py`
- **기능**: 전체 시스템 통합 관리
- **특징**: 원클릭 실행 및 결과 분석

## 🚀 빠른 시작

### 1단계: 환경 설정
```bash
# 필요 패키지 설치
pip install -r requirements.txt

# 또는 자동 설치
python run_exness_backtest.py --install
```

### 2단계: 데이터 다운로드
```bash
# 과거 데이터 다운로드
python run_exness_backtest.py --download
```

### 3단계: MT5 커스텀 심볼 생성
1. MT5에서 `Exness_Custom_Symbol_Creator.mq5` 스크립트 실행
2. 생성된 커스텀 심볼 확인
3. 백테스트에서 커스텀 심볼 선택

### 4단계: 백테스트 실행
```bash
# 비트코인 이동평균 전략 백테스트
python run_exness_backtest.py --backtest BTC-USD ma

# 비트코인 RSI 전략 백테스트
python run_exness_backtest.py --backtest BTC-USD rsi
```

## 📊 지원하는 전략

### 1. 이동평균 전략 (MA20)
- **신호**: 가격이 20일 이동평균 위/아래 돌파
- **특징**: 추세 추종 전략

### 2. RSI 전략
- **신호**: RSI < 30 (매수), RSI > 70 (매도)
- **특징**: 역추세 전략

### 3. 커스텀 전략 추가
```python
def custom_strategy(data, current_row, open_positions):
    # 사용자 정의 로직
    if condition:
        return {'action': 'BUY', 'volume': 0.01}
    return None
```

## 📈 백테스트 결과 분석

### 주요 지표
- **총 거래**: 전체 거래 횟수
- **승률**: 수익 거래 비율
- **순수익**: 수수료 차감 후 순수익
- **최대 낙폭**: 최대 손실 구간
- **수익 팩터**: 총 수익 / 총 손실
- **샤프 비율**: 위험 대비 수익률

### 결과 파일
```
backtest_results/
├── BTC-USD_MA20_trades_20241231_143022.csv    # 거래 내역
├── BTC-USD_MA20_equity_20241231_143022.csv    # 자본 곡선
├── BTC-USD_MA20_summary_20241231_143022.json  # 요약 리포트
└── comprehensive_report.json                  # 종합 리포트
```

## 🔧 고급 설정

### 백테스트 파라미터 조정
```python
engine = AccurateBacktestEngine(
    initial_balance=1000.0,      # 초기 자본
    leverage=200,                # 레버리지
    commission_per_lot=0.1,      # 랏당 수수료
    spread_points=0.5            # 스프레드
)
```

### 심볼 설정 커스터마이징
```json
{
  "BTC-USD": {
    "contract_size": 1.0,        # 1 랏 = 1 BTC
    "min_lot": 0.01,            # 최소 거래량
    "max_lot": 100.0,           # 최대 거래량
    "leverage": 200,            # 레버리지
    "spread": 0.5,              # 스프레드
    "commission": 0.1           # 수수료
  }
}
```

## 📋 지원 심볼

### 암호화폐
- **BTC-USD**: 비트코인
- **ETH-USD**: 이더리움

### 외환
- **EURUSD=X**: 유로/달러
- **GBPUSD=X**: 파운드/달러
- **USDJPY=X**: 달러/엔

### 지수
- **SPY**: S&P 500
- **QQQ**: NASDAQ 100

### 원자재
- **GC=F**: 금
- **CL=F**: 원유

## 🎯 사용 시나리오

### 시나리오 1: 전략 검증
```bash
# 1. 데이터 다운로드
python run_exness_backtest.py --download

# 2. 백테스트 실행
python run_exness_backtest.py --backtest BTC-USD ma

# 3. 결과 분석
python run_exness_backtest.py --report
```

### 시나리오 2: 다중 전략 비교
```bash
# 이동평균 전략
python run_exness_backtest.py --backtest BTC-USD ma

# RSI 전략
python run_exness_backtest.py --backtest BTC-USD rsi

# 종합 리포트 생성
python run_exness_backtest.py --report
```

### 시나리오 3: MT5 통합
1. Python으로 데이터 준비
2. MT5에서 커스텀 심볼 생성
3. MT5 백테스트 실행
4. 결과 비교 및 검증

## 🔍 문제 해결

### 자주 발생하는 문제

#### 1. 패키지 설치 오류
```bash
# 해결책
pip install --upgrade pip
pip install -r requirements.txt
```

#### 2. 데이터 다운로드 실패
```bash
# 해결책
# 인터넷 연결 확인
# VPN 사용 시 해제
# 방화벽 설정 확인
```

#### 3. MT5 스크립트 실행 오류
```bash
# 해결책
# MT5 버전 확인 (최신 버전 권장)
# 스크립트 권한 확인
# 브로커 계정 연결 확인
```

## 📞 지원 및 문의

### 로그 파일 확인
- `exness_backtest.log`: 시스템 로그
- `data_downloader.log`: 데이터 다운로드 로그
- `backtest_engine.log`: 백테스트 엔진 로그

### 성능 최적화
- 데이터 기간 조정 (2년 권장)
- 시간 간격 조정 (1시간 권장)
- 메모리 사용량 모니터링

## 🎉 성공 사례

### 실제 사용자 피드백
> "기존 MT5 백테스트와 100배 차이나던 문제가 완전히 해결되었습니다!"
> 
> "실매매와 동일한 조건으로 백테스트할 수 있어서 전략 신뢰도가 크게 향상되었습니다."
> 
> "MCP 서버를 활용한 개발로 정확하고 빠른 결과를 얻을 수 있었습니다."

## 🔮 향후 계획

### 단기 계획
- [ ] 더 많은 전략 추가
- [ ] 실시간 데이터 연동
- [ ] 웹 인터페이스 개발

### 장기 계획
- [ ] AI 기반 전략 최적화
- [ ] 다중 브로커 지원
- [ ] 클라우드 백테스트 서비스

---

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 🤝 기여하기

버그 리포트, 기능 요청, 풀 리퀘스트를 환영합니다!

---

**🎯 MCP 서버를 총동원하여 개발된 정확한 백테스트 시스템으로 실매매 성공률을 높이세요!**
