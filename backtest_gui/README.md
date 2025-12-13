# 백테스트 GUI 프로그램

독립적인 백테스트 프로그램으로, 전략 코드를 입력하고 파라미터를 최적화하여 최적의 거래 전략을 찾는 도구입니다.

## 주요 기능

- **전략 코드 입력**: Pine Script 또는 MT5 코드를 텍스트 에디터에 입력
- **테스트 환경 선택**: TradingView 또는 MT5 선택
- **심볼 선택**: 드롭다운에서 심볼 선택 (선물/암호화폐/외환)
- **시간프레임 선택**: 다중 시간프레임 선택 가능
- **자동 파라미터 최적화**: 입력된 코드에서 파라미터 추출 후 자동 조합
- **백테스트 실행**: 선택한 환경에서 자동으로 백테스트 실행
- **결과 표시**: 테이블 및 차트로 결과 시각화

## 설치

### 1. 필수 요구사항

- Python 3.7 이상
- Windows 10 이상

### 2. 패키지 설치

```bash
cd backtest_gui
pip install -r requirements.txt
```

### 3. 실행

```bash
python main.py
```

또는

```bash
python -m backtest_gui.main
```

## 사용 방법

### 1. 코드 입력

- 왼쪽 코드 에디터에 Pine Script 또는 MT5 코드를 입력합니다.
- 구문 강조가 자동으로 적용됩니다.

### 2. 설정

- **환경 선택**: TradingView 또는 MT5 선택
- **심볼 선택**: 드롭다운에서 거래할 심볼 선택
- **시간프레임 선택**: 테스트할 시간프레임을 체크박스로 선택

### 3. 파라미터 설정

- **자동 추출**: 코드에서 파라미터를 자동으로 추출
- **수동 설정**: 파라미터 테이블에서 직접 값 수정

### 4. 백테스트 실행

- "백테스트 시작" 버튼을 클릭합니다.
- 진행률이 실시간으로 표시됩니다.
- 결과가 테이블에 자동으로 추가됩니다.

### 5. 결과 확인

- 결과 테이블에서 상위 결과 확인
- 더블클릭으로 상세 정보 확인
- "차트 보기"로 시각화
- "결과 저장"으로 CSV/JSON 저장
- "리포트 생성"으로 HTML 리포트 생성

## 파일 구조

```
backtest_gui/
├── main.py                 # 메인 진입점
├── gui/                     # GUI 컴포넌트
│   ├── main_window.py      # 메인 윈도우
│   ├── code_editor.py      # 코드 에디터
│   ├── settings_panel.py   # 설정 패널
│   ├── results_view.py     # 결과 뷰
│   └── chart_view.py       # 차트 뷰
├── backtest_engine/         # 백테스트 엔진
│   ├── base_engine.py     # 기본 엔진 인터페이스
│   ├── tradingview_engine.py  # TradingView 엔진
│   └── mt5_engine.py      # MT5 엔진
├── parsers/                # 코드 파서
│   ├── pine_parser.py     # Pine Script 파서
│   └── mt5_parser.py      # MT5 파서
└── config/                # 설정 파일
    ├── symbols.yaml       # 심볼 목록
    └── settings.yaml      # 기본 설정
```

## 주의사항

1. **MT5 연결**: MT5 엔진을 사용하려면 MetaTrader 5가 설치되어 있어야 합니다.
2. **데이터 소스**: TradingView 엔진은 yfinance를 사용하여 데이터를 가져옵니다.
3. **성능**: 대량의 파라미터 조합은 시간이 오래 걸릴 수 있습니다.

## 문제 해결

### MT5 연결 실패
- MetaTrader 5가 설치되어 있는지 확인
- MT5가 실행 중인지 확인
- `MetaTrader5` 패키지가 설치되어 있는지 확인: `pip install MetaTrader5`

### 데이터 가져오기 실패
- 인터넷 연결 확인
- 심볼명이 올바른지 확인
- yfinance 패키지 업데이트: `pip install --upgrade yfinance`

## 라이선스

이 프로젝트는 개인 사용 목적으로 개발되었습니다.

