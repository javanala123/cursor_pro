# 🚀 고성능 병렬 백테스트 시스템

**수십 개의 전략을 동시에 병렬로 실행하여 빠른 결과를 제공하는 AI 트레이딩 백테스트 시스템**

## 📋 목차

- [시스템 개요](#시스템-개요)
- [주요 기능](#주요-기능)
- [설치 및 설정](#설치-및-설정)
- [사용 방법](#사용-방법)
- [전략 개발](#전략-개발)
- [성능 최적화](#성능-최적화)
- [API 문서](#api-문서)
- [문제 해결](#문제-해결)

## 🎯 시스템 개요

이 시스템은 **MT5 없이 독립적으로 동작**하는 고성능 병렬 백테스트 엔진입니다. 수십 개의 전략을 동시에 실행하여 빠른 결과를 제공하며, 실시간 웹 대시보드로 진행 상황을 모니터링할 수 있습니다.

### 핵심 특징

- ⚡ **병렬 처리**: CPU 코어 수만큼 동시 실행
- 🎯 **정확한 계산**: 실매매와 100% 동일한 계약 크기
- 📊 **실시간 모니터링**: 웹 대시보드로 진행 상황 확인
- 🔧 **전략 확장**: 새로운 전략 쉽게 추가
- 📈 **상세 분석**: 다양한 성과 지표 제공

## 🚀 주요 기능

### 1. 병렬 백테스트 엔진
- **멀티프로세싱**: CPU 코어 수만큼 동시 실행
- **정확한 계산**: 실매매 환경과 동일한 조건
- **메모리 최적화**: 대용량 데이터 효율적 처리

### 2. 전략 관리 시스템
- **내장 전략**: MA, RSI, 볼린저밴드, MACD, 스토캐스틱
- **동적 로딩**: 새로운 전략 실시간 추가
- **파라미터 최적화**: 자동 파라미터 조합 생성

### 3. 실시간 웹 대시보드
- **진행 상황 모니터링**: 실시간 진행률 표시
- **결과 분석**: 상세한 성과 통계
- **데이터 내보내기**: JSON, CSV, Excel 형식 지원

### 4. 결과 분석 시스템
- **성과 지표**: 승률, 수익팩터, 샤프비율, 최대낙폭
- **상위 성과자**: 최고 성과 전략 자동 선별
- **전략별 분석**: 전략별 성과 비교

## 🛠 설치 및 설정

### 1. 시스템 요구사항

```bash
# Python 3.8 이상
python --version

# 최소 4GB RAM 권장
# CPU 코어 수만큼 병렬 처리
```

### 2. 패키지 설치

```bash
# 의존성 설치
pip install -r requirements_parallel.txt

# 또는 개별 설치
pip install pandas numpy flask matplotlib yfinance openpyxl
```

### 3. 디렉토리 구조

```
parallel_backtest/
├── parallel_backtest_engine.py    # 핵심 엔진
├── strategy_loader.py             # 전략 로더
├── parallel_backtest_runner.py    # 실행기
├── realtime_dashboard.py          # 웹 대시보드
├── run_parallel_backtest.py       # 통합 실행기
├── config_parallel.yaml           # 설정 파일
├── requirements_parallel.txt      # 의존성
├── historical_data/               # 데이터 디렉토리
├── parallel_results/              # 결과 디렉토리
├── strategies/                    # 전략 디렉토리
└── templates/                     # 웹 템플릿
```

## 🎮 사용 방법

### 1. 빠른 시작

```bash
# 기본 실행 (빠른 테스트)
python run_parallel_backtest.py

# 웹 대시보드 실행
python run_parallel_backtest.py --dashboard

# 종합 테스트
python run_parallel_backtest.py --mode comprehensive
```

### 2. 명령행 옵션

```bash
# 기본 옵션
python run_parallel_backtest.py --mode quick --symbols BTC-USD --strategies ma_cross rsi --days 30

# 고성능 테스트
python run_parallel_backtest.py --mode comprehensive --workers 16 --symbols BTC-USD ETH-USD --strategies ma_cross rsi bollinger macd --days 90

# 웹 대시보드
python run_parallel_backtest.py --dashboard --port 5000
```

### 3. 설정 파일 사용

```yaml
# config_parallel.yaml 수정
system:
  max_workers: 8
  data_dir: "historical_data"
  results_dir: "parallel_results"

backtest:
  initial_balance: 1000.0
  leverage: 200
  commission_per_lot: 0.1
```

## 🔧 전략 개발

### 1. 기본 전략 구조

```python
from strategy_loader import BaseStrategy
import pandas as pd
from typing import Dict, Optional

class MyCustomStrategy(BaseStrategy):
    """사용자 정의 전략"""
    
    def __init__(self, param1: float = 10.0, param2: float = 20.0, **kwargs):
        super().__init__(param1=param1, param2=param2, **kwargs)
        self.param1 = param1
        self.param2 = param2
    
    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        """
        신호 생성 로직
        
        Returns:
            {'action': 'BUY', 'volume': 0.01}  # 매수 신호
            {'action': 'SELL', 'volume': 0.01} # 매도 신호
            {'action': 'CLOSE', 'volume': 0.01} # 포지션 청산
            None  # 신호 없음
        """
        # 여기에 전략 로직 구현
        return None
```

### 2. 전략 등록

```python
# strategies/ 디렉토리에 전략 파일 저장
# 예: strategies/my_strategy.py

# 자동으로 로드됨
```

### 3. 전략 테스트

```bash
# 특정 전략만 테스트
python run_parallel_backtest.py --strategies my_strategy --symbols BTC-USD
```

## ⚡ 성능 최적화

### 1. 워커 수 조정

```bash
# CPU 코어 수 확인
python -c "import multiprocessing; print(multiprocessing.cpu_count())"

# 워커 수 설정
python run_parallel_backtest.py --workers 16
```

### 2. 메모리 최적화

```yaml
# config_parallel.yaml
performance:
  chunk_size: 1000
  memory_limit: "4GB"
  cache_size: 1000
```

### 3. 데이터 최적화

```python
# 데이터 전처리
data = data.dropna()
data = data.resample('1H').agg({
    'Open': 'first',
    'High': 'max',
    'Low': 'min',
    'Close': 'last',
    'Volume': 'sum'
})
```

## 📊 API 문서

### 1. 백테스트 엔진 API

```python
from parallel_backtest_engine import ParallelBacktestEngine, BacktestConfig

# 엔진 초기화
engine = ParallelBacktestEngine(max_workers=8)

# 전략 등록
engine.register_strategy("my_strategy", my_strategy_function)

# 백테스트 실행
configs = [BacktestConfig(...)]
results = engine.run_parallel_backtests(configs)
```

### 2. 전략 로더 API

```python
from strategy_loader import StrategyLoader

# 로더 초기화
loader = StrategyLoader()

# 전략 생성
strategy = loader.create_strategy("ma_cross", fast_period=10, slow_period=20)

# 사용 가능한 전략 목록
strategies = loader.get_available_strategies()
```

### 3. 웹 대시보드 API

```bash
# 상태 확인
GET /api/status

# 결과 조회
GET /api/results

# 백테스트 시작
POST /api/start_backtest
{
    "symbols": ["BTC-USD"],
    "strategies": ["ma_cross"],
    "days": 30
}

# 결과 내보내기
POST /api/export_results
{
    "format": "json"
}
```

## 🔍 문제 해결

### 1. 일반적인 문제

**Q: 메모리 부족 오류**
```bash
# 워커 수 줄이기
python run_parallel_backtest.py --workers 4

# 데이터 크기 줄이기
python run_parallel_backtest.py --days 30
```

**Q: 데이터 다운로드 실패**
```bash
# 수동으로 데이터 다운로드
python -c "import yfinance as yf; yf.download('BTC-USD', start='2020-01-01').to_csv('BTC-USD.csv')"
```

**Q: 웹 대시보드 접속 불가**
```bash
# 포트 변경
python run_parallel_backtest.py --dashboard --port 8080

# 방화벽 확인
# Windows: netsh advfirewall firewall add rule name="Flask" dir=in action=allow protocol=TCP localport=5000
```

### 2. 성능 문제

**Q: 실행 속도가 느림**
```bash
# 워커 수 증가
python run_parallel_backtest.py --workers 16

# 전략 수 줄이기
python run_parallel_backtest.py --strategies ma_cross rsi
```

**Q: 메모리 사용량 높음**
```yaml
# config_parallel.yaml 수정
performance:
  chunk_size: 500
  memory_limit: "2GB"
```

### 3. 전략 문제

**Q: 전략이 로드되지 않음**
```python
# 전략 파일 확인
# strategies/ 디렉토리에 .py 파일이 있는지 확인
# BaseStrategy를 상속받았는지 확인
```

**Q: 신호가 생성되지 않음**
```python
# 데이터 길이 확인
if len(data) < required_period:
    return None

# 파라미터 범위 확인
# 너무 극단적인 값은 피하기
```

## 📈 성과 지표 설명

### 1. 기본 지표

- **승률 (Win Rate)**: 수익 거래 비율
- **수익팩터 (Profit Factor)**: 총 수익 / 총 손실
- **샤프비율 (Sharpe Ratio)**: 위험 대비 수익률
- **최대낙폭 (Max Drawdown)**: 최대 손실 폭

### 2. 고급 지표

- **칼마비율 (Calmar Ratio)**: 연간 수익률 / 최대낙폭
- **소르티노비율 (Sortino Ratio)**: 하방 위험 대비 수익률
- **VAR (Value at Risk)**: 위험 가치
- **CVAR (Conditional VaR)**: 조건부 위험 가치

## 🎯 사용 시나리오

### 1. 빠른 전략 검증 (1-2분)
```bash
python run_parallel_backtest.py --mode quick --symbols BTC-USD --strategies ma_cross rsi --days 30
```

### 2. 종합 전략 분석 (5-10분)
```bash
python run_parallel_backtest.py --mode comprehensive --symbols BTC-USD ETH-USD --strategies ma_cross rsi bollinger macd --days 90
```

### 3. 대규모 최적화 (30분-1시간)
```bash
python run_parallel_backtest.py --mode comprehensive --workers 16 --symbols BTC-USD ETH-USD EURUSD --strategies ma_cross rsi bollinger macd stochastic combined --days 180
```

### 4. 실시간 모니터링
```bash
# 터미널 1: 백테스트 실행
python run_parallel_backtest.py --mode comprehensive

# 터미널 2: 웹 대시보드
python run_parallel_backtest.py --dashboard
```

## 🔮 향후 계획

### 1. 단기 계획
- [ ] 더 많은 내장 전략 추가
- [ ] 실시간 데이터 연동
- [ ] 클라우드 배포 지원

### 2. 중기 계획
- [ ] 머신러닝 전략 통합
- [ ] 분산 처리 지원
- [ ] 모바일 앱 개발

### 3. 장기 계획
- [ ] 실매매 자동화
- [ ] 소셜 트레이딩 플랫폼
- [ ] AI 기반 전략 생성

## 📞 지원 및 문의

- **이슈 리포트**: GitHub Issues
- **기능 요청**: GitHub Discussions
- **문서 개선**: Pull Request

## 📄 라이선스

MIT License - 자유롭게 사용, 수정, 배포 가능

---

**🚀 이제 수십 개의 전략을 동시에 테스트하여 최고의 성과를 찾아보세요!**
