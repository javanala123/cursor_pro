# 볼린저 밴드 전략 파라미터 최적화 시스템

## 개요

이 시스템은 볼린저 밴드 돌파 전략의 파라미터를 자동으로 최적화하여 수익률이 가장 높은 파라미터 조합을 찾는 도구입니다.

## 주요 기능

- **MT5 환경 지원**: MT5 Strategy Tester를 활용한 자동 최적화
- **다중 심볼 지원**: 선물, 암호화폐, 외환 카테고리별 최적화
- **전략 파서**: Pine Script 및 MT5 코드에서 자동으로 파라미터 추출
- **결과 분석**: 수익률 기준 최적 파라미터 선정
- **리포트 생성**: HTML 형식의 상세 리포트

## 시스템 구조

```
optimization_system/
├── mt5_optimizer/
│   ├── BollingerBands_Strategy.mq5      # 볼린저 밴드 전략 EA
│   ├── BollingerBands_Optimizer.mq5    # 최적화 스크립트
│   └── ResultAnalyzer.mq5              # 결과 분석기
├── strategy_parser/
│   ├── pine_script_parser.py           # Pine Script 파서
│   └── mt5_code_parser.py              # MT5 코드 파서
├── config/
│   ├── optimization_config.yaml         # 최적화 설정
│   └── symbol_categories.yaml          # 심볼 카테고리 정의
├── results/
│   ├── futures/                         # 선물 최적화 결과
│   ├── crypto/                          # 암호화폐 최적화 결과
│   └── forex/                           # 외환 최적화 결과
├── run_optimization.py                  # 메인 실행 스크립트
└── report_generator.py                  # 리포트 생성기
```

## 설치 및 설정

### 1. 필수 요구사항

- Python 3.7 이상
- MetaTrader 5
- 필요한 Python 패키지:
  ```bash
  pip install pyyaml pandas matplotlib
  ```

### 2. 설정 파일 구성

`config/optimization_config.yaml` 파일에서 최적화 설정을 조정할 수 있습니다:

```yaml
optimization:
  target: "total_return"  # 최적화 목표: total_return, win_rate, sharpe_ratio
  method: "grid_search"   # 최적화 방법: grid_search, random_search
  min_trades: 10          # 최소 거래 횟수
  max_drawdown_limit: 50.0 # 최대 낙폭 제한 (%)
```

## 사용법

### 1. 단일 심볼 최적화

```bash
# 기본 사용법
python run_optimization.py --symbol ES --timeframe H1

# 그리드 서치 사용
python run_optimization.py --symbol ES --timeframe H1 --method grid_search

# 랜덤 서치 사용 (빠른 탐색)
python run_optimization.py --symbol ES --timeframe H1 --method random_search --iterations 1000

# 전략 파일 지정 (Pine Script 또는 MT5)
python run_optimization.py --symbol ES --timeframe H1 --strategy-file 볼린져밴드_돌파_선물전용_NoPOA_Full.pine
```

### 2. 카테고리별 최적화

```bash
# 선물 카테고리 전체 최적화
python run_optimization.py --category futures --timeframe H1

# 암호화폐 카테고리 최적화
python run_optimization.py --category crypto --timeframe H1

# 외환 카테고리 최적화
python run_optimization.py --category forex --timeframe H1
```

### 3. MT5에서 직접 최적화

1. MetaTrader 5를 실행합니다.
2. `mt5_optimizer/BollingerBands_Optimizer.mq5` 스크립트를 열습니다.
3. 입력 파라미터를 설정합니다:
   - 테스트 심볼
   - 시간프레임
   - 파라미터 범위
4. 스크립트를 실행합니다.
5. 결과는 CSV 파일로 저장됩니다.

### 4. 리포트 생성

```bash
# 심볼별 리포트
python report_generator.py --symbol ES --timeframe H1

# 카테고리별 리포트
python report_generator.py --category futures
```

## 최적화 파라미터

### 볼린저 밴드 파라미터

- **롱 길이 (LongBBLength)**: 10-30 (기본값: 15)
- **롱 편차 (LongBBDev)**: 1.5-3.0 (기본값: 2.0)
- **숏 길이 (ShortBBLength)**: 10-30 (기본값: 15)
- **숏 편차 (ShortBBDev)**: 1.5-3.0 (기본값: 2.0)

### 손절/익절 파라미터

- **롱 TP % (LongTPPerc)**: 1.0-5.0% (기본값: 2.0%)
- **롱 SL % (LongSLPerc)**: 3.0-10.0% (기본값: 7.0%)
- **숏 TP % (ShortTPPerc)**: 1.0-5.0% (기본값: 2.0%)
- **숏 SL % (ShortSLPerc)**: 3.0-10.0% (기본값: 7.0%)

## 결과 해석

최적화 결과는 다음 지표를 포함합니다:

- **총 수익률 (Total Return)**: 백테스트 기간 동안의 총 수익률 (%)
- **승률 (Win Rate)**: 승리 거래 비율 (%)
- **샤프 비율 (Sharpe Ratio)**: 위험 대비 수익률 지표
- **수익 팩터 (Profit Factor)**: 총 수익 / 총 손실
- **최대 낙폭 (Max Drawdown)**: 최대 손실 구간 (%)

## 주의사항

1. **과최적화 (Overfitting) 주의**
   - 백테스트 기간을 나누어 검증하세요 (In-sample / Out-sample)
   - 여러 심볼에서 테스트하여 일반화 가능성을 확인하세요

2. **최소 거래 횟수**
   - 최소 10회 이상의 거래가 있는 결과만 신뢰할 수 있습니다

3. **실전 적용 전 검증**
   - 최적화된 파라미터를 실제 거래에 적용하기 전에 Forward Testing을 수행하세요

## 향후 계획

- [ ] TradingView 환경 지원
- [ ] 베이지안 최적화 알고리즘 추가
- [ ] 실시간 모니터링 대시보드
- [ ] 자동 리포트 이메일 발송

## 라이선스

이 프로젝트는 개인 사용 목적으로 개발되었습니다.

## 문의

문제가 발생하거나 개선 사항이 있으면 이슈를 등록해주세요.

