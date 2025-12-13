# 빠른 시작 가이드

## 1. 설치

```bash
cd backtest_gui
pip install -r requirements.txt
```

## 2. 실행

```bash
python main.py
```

또는 Windows에서:
```bash
run.bat
```

## 3. 사용 방법

### 단계 1: 코드 입력
- 왼쪽 코드 에디터에 Pine Script 또는 MT5 코드를 입력합니다.

**예제 (Pine Script):**
```pinescript
//@version=5
strategy("Simple MA")

length = input.int(20, "Length", minval=10, maxval=50, step=2)
ma = ta.sma(close, length)

if ta.crossover(close, ma)
    strategy.entry("Long", strategy.long)
if ta.crossunder(close, ma)
    strategy.close("Long")
```

### 단계 2: 설정
- **환경 선택**: TradingView 또는 MT5 선택
- **심볼 선택**: 드롭다운에서 심볼 선택 (예: EURUSD, ES1!)
- **시간프레임 선택**: 체크박스로 선택 (예: M15, H1, H4)

### 단계 3: 파라미터 추출
- "자동 추출" 버튼을 클릭하여 코드에서 파라미터를 추출합니다.
- 파라미터 테이블에서 최소값, 최대값, 단계를 확인/수정할 수 있습니다.

### 단계 4: 백테스트 실행
- "백테스트 시작" 버튼을 클릭합니다.
- 진행률이 실시간으로 표시됩니다.
- 결과가 테이블에 자동으로 추가됩니다.

### 단계 5: 결과 확인
- 결과 테이블에서 상위 결과 확인
- 더블클릭으로 상세 정보 확인
- "차트 보기"로 시각화
- "결과 저장"으로 CSV/JSON 저장
- "리포트 생성"으로 HTML 리포트 생성

## 주요 기능

### 코드 에디터
- 구문 강조 (Pine Script / MT5)
- 코드 검증
- 파일 열기/저장 (Ctrl+O, Ctrl+S)

### 설정 패널
- 환경 선택 (TradingView / MT5)
- 심볼 선택 (선물/암호화폐/외환)
- 시간프레임 다중 선택
- 파라미터 범위 설정

### 결과 뷰
- 실시간 진행률 표시
- 정렬 가능한 결과 테이블
- 차트 시각화
- 결과 저장 (CSV/JSON)
- HTML 리포트 생성

## 팁

1. **파라미터 범위 설정**: 너무 넓은 범위는 시간이 오래 걸릴 수 있습니다. 적절한 범위로 시작하세요.

2. **시간프레임 선택**: 여러 시간프레임을 선택하면 각각에 대해 백테스트가 실행됩니다.

3. **결과 분석**: 수익률뿐만 아니라 승률, 샤프 비율도 함께 확인하세요.

4. **과최적화 주의**: 백테스트 결과가 좋다고 해서 실전에서도 좋은 것은 아닙니다. Forward Testing을 권장합니다.

## 문제 해결

### 프로그램이 실행되지 않음
- Python 버전 확인: `python --version` (3.7 이상 필요)
- 패키지 설치 확인: `pip list | grep PyQt5`

### 데이터를 가져올 수 없음
- 인터넷 연결 확인
- 심볼명이 올바른지 확인
- yfinance 업데이트: `pip install --upgrade yfinance`

### MT5 연결 실패
- MetaTrader 5가 설치되어 있는지 확인
- MT5가 실행 중인지 확인
- `MetaTrader5` 패키지 설치: `pip install MetaTrader5`

