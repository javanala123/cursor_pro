# 최적화 시스템 테스트 가이드

## 테스트 순서

### 1. 선물 심볼 최적화 테스트 (우선순위 1)

#### ES (E-mini S&P 500) 테스트

**MT5에서 실행:**
1. MetaTrader 5 실행
2. `mt5_optimizer/BollingerBands_Optimizer.mq5` 스크립트 열기
3. 입력 파라미터 설정:
   - OptimSymbol: "ES1!"
   - OptimTimeframe: PERIOD_H1
   - OptimStartDate: 2023.01.01
   - OptimEndDate: 2024.12.31
   - LongBBLengthMin: 10
   - LongBBLengthMax: 30
   - LongBBLengthStep: 2
   - LongBBDevMin: 1.5
   - LongBBDevMax: 3.0
   - LongBBDevStep: 0.2
   - (숏 파라미터도 동일하게 설정)
4. 스크립트 실행
5. 결과 확인 및 저장

**Python에서 실행:**
```bash
python run_optimization.py --symbol ES1! --timeframe H1 --method grid_search
```

#### NQ (E-mini NASDAQ) 테스트

```bash
python run_optimization.py --symbol NQ1! --timeframe H1 --method grid_search
```

#### GC (Gold) 테스트

```bash
python run_optimization.py --symbol GC1! --timeframe H1 --method grid_search
```

### 2. 암호화폐 심볼 최적화 테스트 (우선순위 2)

#### BTCUSD 테스트

```bash
python run_optimization.py --symbol BTCUSD --timeframe H1 --method random_search --iterations 1000
```

#### ETHUSD 테스트

```bash
python run_optimization.py --symbol ETHUSD --timeframe H1 --method random_search --iterations 1000
```

### 3. 외환 심볼 최적화 테스트 (우선순위 3)

#### EURUSD 테스트

```bash
python run_optimization.py --symbol EURUSD --timeframe H1 --method grid_search
```

#### GBPUSD 테스트

```bash
python run_optimization.py --symbol GBPUSD --timeframe H1 --method grid_search
```

## 카테고리별 일괄 테스트

### 선물 카테고리 전체 테스트

```bash
python run_optimization.py --category futures --timeframe H1 --method random_search --iterations 500
```

### 암호화폐 카테고리 전체 테스트

```bash
python run_optimization.py --category crypto --timeframe H1 --method random_search --iterations 500
```

### 외환 카테고리 전체 테스트

```bash
python run_optimization.py --category forex --timeframe H1 --method grid_search
```

## 결과 확인

### 결과 파일 위치
- JSON 결과: `results/{symbol}_{timeframe}_{timestamp}.json`
- 리포트: `results/reports/report_{symbol}_{timeframe}_{timestamp}.html`

### 리포트 생성

```bash
# 심볼별 리포트
python report_generator.py --symbol ES1! --timeframe H1

# 카테고리별 리포트
python report_generator.py --category futures
```

## 예상 소요 시간

- **그리드 서치**: 파라미터 조합 수에 따라 수 시간 ~ 수십 시간
- **랜덤 서치**: 반복 횟수에 따라 수 분 ~ 수 시간

## 주의사항

1. **MT5 Strategy Tester 설정**
   - 모델: "Every tick" 또는 "1 minute OHLC"
   - 최적화 모드: "Genetic Algorithm" (빠른 탐색) 또는 "Complete" (완전 탐색)

2. **메모리 관리**
   - 대량의 결과는 메모리 사용량이 클 수 있으므로 주의

3. **결과 검증**
   - 최적화된 파라미터는 Forward Testing으로 검증 필요

