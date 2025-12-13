# 설치 가이드

## 필수 요구사항

- Python 3.7 이상
- Windows 10 이상
- 인터넷 연결 (데이터 다운로드용)

## 설치 단계

### 1. Python 설치 확인

```bash
python --version
```

Python 3.7 이상이 설치되어 있어야 합니다.

### 2. 패키지 설치

```bash
cd backtest_gui
pip install -r requirements.txt
```

### 3. 실행

#### 방법 1: Python으로 직접 실행
```bash
python main.py
```

#### 방법 2: 배치 파일 사용 (Windows)
```bash
run.bat
```

## 문제 해결

### PyQt5 설치 오류

```bash
pip install --upgrade pip
pip install PyQt5
```

### matplotlib 설치 오류

```bash
pip install matplotlib
```

### MetaTrader5 설치 오류

MT5 엔진을 사용하지 않는다면 설치하지 않아도 됩니다.

```bash
pip install MetaTrader5
```

### 한글 폰트 문제

matplotlib에서 한글이 깨지는 경우:

1. Windows에 한글 폰트가 설치되어 있는지 확인
2. 또는 `gui/chart_view.py`에서 폰트 설정 변경

## 첫 실행

1. 프로그램 실행
2. 코드 에디터에 전략 코드 입력 (Pine Script 또는 MT5)
3. 환경 선택 (TradingView 또는 MT5)
4. 심볼 선택
5. 시간프레임 선택
6. "자동 추출" 버튼으로 파라미터 추출
7. "백테스트 시작" 버튼 클릭

## 예제 코드

### Pine Script 예제

```pinescript
//@version=5
strategy("Simple MA Strategy")

length = input.int(20, "Length", minval=1, maxval=100)
ma = ta.sma(close, length)

if ta.crossover(close, ma)
    strategy.entry("Long", strategy.long)

if ta.crossunder(close, ma)
    strategy.close("Long")
```

### MT5 예제

```cpp
input int Length = 20;  // min=10 max=50 step=2
input double LotSize = 0.1;

// 간단한 이동평균 전략
double ma = iMA(_Symbol, PERIOD_CURRENT, Length, 0, MODE_SMA, PRICE_CLOSE);
```

