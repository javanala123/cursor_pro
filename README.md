# cursor_pro
커셔에서 개발되는 프로젝트 코드들

## 자동매매봇 (Automated Trading Bot)

간단한 주식 자동매매 시스템입니다. 이동평균 기반의 매매 전략을 사용하여 자동으로 주식을 매수/매도합니다.

### 주요 기능
- 이동평균 기반 매매 신호 분석 (5일선, 20일선)
- 자동 매수/매도 실행
- 포트폴리오 관리 및 현황 출력
- 설정 파일을 통한 유연한 설정 관리
- 로깅 기능

### 설치 및 실행

1. 필요한 패키지 설치:
```bash
pip install -r requirements.txt
```

2. 데모 실행 (10초간 시뮬레이션):
```bash
python demo.py
```

3. 자동매매봇 실행:
```bash
python trading_bot.py
```

4. 테스트 실행:
```bash
python test_bot.py
```

5. 중단하려면 `Ctrl+C`를 누르세요.

### 설정 파일 (config.json)
- `initial_cash`: 초기 자금 (기본: 1,000,000원)
- `watchlist`: 감시할 주식 목록
- `trading_interval`: 매매 주기 (초 단위, 기본: 30초)
- `max_position_size`: 최대 포지션 크기 (총 자금의 비율, 기본: 0.2)
- `stop_loss_percent`: 손절선 (기본: 5%)
- `take_profit_percent`: 익절선 (기본: 10%)

### 주의사항
- 이 봇은 **시뮬레이션 목적**으로 제작되었습니다
- 실제 거래에 사용하기 전에 충분한 테스트와 검증이 필요합니다
- 투자 손실에 대한 책임은 사용자에게 있습니다

### 로그 파일
실행 중 모든 매매 기록은 `trading_bot.log` 파일에 저장됩니다.
