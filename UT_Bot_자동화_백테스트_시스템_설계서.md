# UT Bot 자동화 백테스트 시스템 설계서

## 📋 프로젝트 개요

### 목표
- **다중 심볼**에서 UT Bot의 **최적 키값** 자동 탐색
- **혼합 지표 조합**의 성능 비교 및 최적화
- **과거 실데이터** 기반 체계적 백테스트 수행
- **자동화된 리포트** 생성 및 결과 분석

### 핵심 기능
1. **심볼별 최적화**: GOLD, EURUSD, GBPUSD, USDJPY, NASDAQ
2. **키값 자동 탐색**: 0.5 ~ 5.0 범위에서 최적값 발견
3. **혼합 지표 테스트**: ADX + Volume + RSI 모든 조합
4. **성능 분석**: 수익률, 승률, 샤프비율 등 종합 평가
5. **자동 리포트**: CSV, HTML 형태로 결과 제공

---

## 🏗️ 시스템 아키텍처

### 1. 백테스트 엔진 (Backtest Engine)
```
UT_Bot_Auto_Backtest_Engine.mq5
├── 파라미터 동적 변경 기능
├── 성능 지표 실시간 수집
├── 결과 데이터 구조화
└── 에러 처리 및 복구
```

### 2. 최적화 컨트롤러 (Optimization Controller)
```
UT_Bot_Optimization_Controller.mq5
├── 키값 범위 관리 (0.5 ~ 5.0)
├── ATR 기간 범위 관리 (10 ~ 50)
├── 심볼별 테스트 시퀀스
└── 결과 수집 및 저장
```

### 3. 혼합 지표 테스터 (Indicator Combination Tester)
```
UT_Bot_Indicator_Tester.mq5
├── ADX 필터 조합 테스트
├── Volume 필터 조합 테스트
├── RSI 필터 조합 테스트
└── 통합 성능 비교
```

### 4. 성능 분석기 (Performance Analyzer)
```
UT_Bot_Performance_Analyzer.mq5
├── 통계적 성능 지표 계산
├── 위험 지표 분석
├── 최적화 알고리즘
└── 결과 랭킹 시스템
```

### 5. 리포트 생성기 (Report Generator)
```
UT_Bot_Report_Generator.mq5
├── CSV 파일 생성
├── HTML 리포트 생성
├── 차트 및 그래프 생성
└── 설정 파일 관리
```

---

## 🔧 기술적 구현 세부사항

### 1. 데이터 구조

#### 백테스트 결과 구조체
```mql5
struct SBacktestResult {
    // 기본 정보
    string symbol;              // 심볼명
    double keyValue;            // 키값
    int atrPeriod;              // ATR 기간
    int indicatorMode;          // 지표 모드
    
    // 성능 지표
    double totalReturn;         // 총 수익률
    double annualReturn;        // 연간 수익률
    double maxDrawdown;         // 최대 손실
    double sharpeRatio;         // 샤프 비율
    double sortinoRatio;        // 소르티노 비율
    double calmarRatio;         // 칼마 비율
    
    // 거래 지표
    int totalTrades;            // 총 거래 횟수
    double winRate;             // 승률
    double profitFactor;        // 수익 팩터
    int maxConsecutiveLosses;   // 최대 연속 손실
    
    // 위험 지표
    double volatility;          // 변동성
    double var95;               // VaR 95%
    double expectedShortfall;   // 기대 부족분
    
    // 메타데이터
    datetime testStartTime;     // 테스트 시작 시간
    datetime testEndTime;       // 테스트 종료 시간
    int testDuration;           // 테스트 기간 (일)
};
```

#### 최적화 설정 구조체
```mql5
struct SOptimizationConfig {
    // 심볼 설정
    string symbols[];           // 테스트할 심볼 목록
    
    // 키값 범위
    double keyValueMin;         // 최소 키값
    double keyValueMax;         // 최대 키값
    double keyValueStep;        // 키값 단계
    
    // ATR 기간 범위
    int atrPeriodMin;           // 최소 ATR 기간
    int atrPeriodMax;           // 최대 ATR 기간
    int atrPeriodStep;          // ATR 기간 단계
    
    // 지표 모드
    int indicatorModes[];       // 테스트할 지표 모드
    
    // 백테스트 기간
    datetime startDate;         // 시작 날짜
    datetime endDate;           // 종료 날짜
    
    // 성능 기준
    int minTrades;              // 최소 거래 횟수
    double maxDrawdownLimit;    // 최대 손실 한도
    double minWinRate;          // 최소 승률
};
```

### 2. 핵심 클래스 설계

#### 백테스트 엔진 클래스
```mql5
class CBacktestEngine {
private:
    // 핸들 및 설정
    int atr_handle;
    int ma_handle;
    int adx_handle;
    int rsi_handle;
    
    // 현재 설정
    double currentKeyValue;
    int currentATRPeriod;
    int currentIndicatorMode;
    string currentSymbol;
    
    // 성능 추적
    SBacktestResult currentResult;
    
public:
    // 초기화
    bool Initialize(string symbol, double keyValue, int atrPeriod, int indicatorMode);
    
    // 백테스트 실행
    bool RunBacktest(datetime startTime, datetime endTime);
    
    // 결과 반환
    SBacktestResult GetResults();
    
    // 정리
    void Cleanup();
};
```

#### 최적화 관리자 클래스
```mql5
class COptimizationManager {
private:
    SOptimizationConfig config;
    CBacktestEngine engine;
    SBacktestResult results[];
    
public:
    // 설정 로드
    bool LoadConfig(string configFile);
    
    // 최적화 실행
    bool RunOptimization();
    
    // 결과 분석
    SBacktestResult GetBestResult();
    SBacktestResult GetBestResultForSymbol(string symbol);
    
    // 결과 저장
    bool SaveResults(string filename);
    
    // 진행 상황
    double GetProgress();
    string GetStatus();
};
```

### 3. 최적화 알고리즘

#### 그리드 서치 (Grid Search)
```mql5
bool COptimizationManager::RunGridSearch() {
    int totalCombinations = 0;
    int currentCombination = 0;
    
    // 총 조합 수 계산
    for(int s = 0; s < ArraySize(config.symbols); s++) {
        for(double kv = config.keyValueMin; kv <= config.keyValueMax; kv += config.keyValueStep) {
            for(int ap = config.atrPeriodMin; ap <= config.atrPeriodMax; ap += config.atrPeriodStep) {
                for(int im = 0; im < ArraySize(config.indicatorModes); im++) {
                    totalCombinations++;
                }
            }
        }
    }
    
    // 각 조합 테스트
    for(int s = 0; s < ArraySize(config.symbols); s++) {
        for(double kv = config.keyValueMin; kv <= config.keyValueMax; kv += config.keyValueStep) {
            for(int ap = config.atrPeriodMin; ap <= config.atrPeriodMax; ap += config.atrPeriodStep) {
                for(int im = 0; im < ArraySize(config.indicatorModes); im++) {
                    // 백테스트 실행
                    if(engine.Initialize(config.symbols[s], kv, ap, config.indicatorModes[im])) {
                        if(engine.RunBacktest(config.startDate, config.endDate)) {
                            SBacktestResult result = engine.GetResults();
                            
                            // 필터링 조건 확인
                            if(IsValidResult(result)) {
                                ArrayResize(results, ArraySize(results) + 1);
                                results[ArraySize(results) - 1] = result;
                            }
                        }
                    }
                    
                    currentCombination++;
                    double progress = (double)currentCombination / totalCombinations * 100.0;
                    Print("진행률: ", DoubleToString(progress, 2), "% (", currentCombination, "/", totalCombinations, ")");
                }
            }
        }
    }
    
    return true;
}
```

#### 성능 평가 함수
```mql5
bool COptimizationManager::IsValidResult(SBacktestResult &result) {
    // 최소 거래 횟수 확인
    if(result.totalTrades < config.minTrades) return false;
    
    // 최대 손실 한도 확인
    if(result.maxDrawdown < config.maxDrawdownLimit) return false;
    
    // 최소 승률 확인
    if(result.winRate < config.minWinRate) return false;
    
    return true;
}

double COptimizationManager::CalculateScore(SBacktestResult &result) {
    // 복합 점수 계산 (가중치 적용)
    double score = 0.0;
    
    // 샤프 비율 (40% 가중치)
    score += result.sharpeRatio * 0.4;
    
    // 총 수익률 (30% 가중치)
    score += result.totalReturn * 0.3;
    
    // 최대 손실 (20% 가중치, 음수이므로 절댓값 사용)
    score += MathAbs(result.maxDrawdown) * 0.2;
    
    // 승률 (10% 가중치)
    score += result.winRate * 0.1;
    
    return score;
}
```

---

## 📊 테스트 시나리오

### 1단계: 기본 UT Bot 최적화
- **심볼**: GOLD, EURUSD, GBPUSD, USDJPY, NASDAQ
- **키값**: 0.5, 0.7, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0
- **ATR 기간**: 10, 15, 20, 25, 30, 35, 40, 45, 50
- **총 테스트**: 5 × 11 × 9 = 495개 조합

### 2단계: 혼합 지표 조합 테스트
- **ADX 임계값**: 10, 15, 20, 25, 30
- **Volume 배수**: 0.5, 1.0, 1.5, 2.0
- **RSI 상한/하한**: (70/30), (75/25), (80/20)
- **총 조합**: 5 × 4 × 3 = 60개

### 3단계: 통합 최적화
- 1단계 최적 파라미터 + 2단계 최적 지표 조합
- 각 심볼별 최종 최적 설정 도출

---

## 📈 성능 지표 정의

### 수익성 지표
- **총 수익률**: (최종 자본 - 초기 자본) / 초기 자본 × 100
- **연간 수익률**: 총 수익률 / 테스트 기간(년) × 100
- **월간 평균 수익률**: 총 수익률 / 테스트 기간(월)

### 위험 지표
- **최대 손실**: 연속 손실의 최대값
- **변동성**: 수익률의 표준편차
- **VaR 95%**: 95% 신뢰구간에서의 최대 손실

### 효율성 지표
- **샤프 비율**: (수익률 - 무위험 수익률) / 변동성
- **소르티노 비율**: (수익률 - 무위험 수익률) / 하방 변동성
- **칼마 비율**: 연간 수익률 / 최대 손실

### 거래 지표
- **총 거래 횟수**: 전체 매매 횟수
- **승률**: 수익 거래 / 전체 거래 × 100
- **수익 팩터**: 총 수익 / 총 손실
- **최대 연속 손실**: 연속으로 손실이 발생한 최대 횟수

---

## 🎯 최적화 목표

### 1차 목표: 최대 샤프 비율
- 위험 대비 수익률이 가장 높은 조합 선택
- 안정적인 수익 창출 능력 평가

### 2차 목표: 최대 수익률
- 절대 수익률이 가장 높은 조합 선택
- 공격적인 수익 창출 능력 평가

### 3차 목표: 최소 최대손실
- 위험을 최소화하는 조합 선택
- 보수적인 리스크 관리 능력 평가

### 필터링 조건
- **최소 거래 횟수**: 50회 이상
- **최대 손실 한도**: -30% 이하
- **최소 승률**: 40% 이상

---

## 📁 파일 구조

```
UT_Bot_자동화_백테스트_시스템/
├── UT_Bot_Auto_Backtest_Engine.mq5      # 백테스트 엔진
├── UT_Bot_Optimization_Controller.mq5   # 최적화 컨트롤러
├── UT_Bot_Indicator_Tester.mq5          # 지표 조합 테스터
├── UT_Bot_Performance_Analyzer.mq5      # 성능 분석기
├── UT_Bot_Report_Generator.mq5          # 리포트 생성기
├── config/
│   ├── optimization_config.json         # 최적화 설정
│   ├── symbol_config.json              # 심볼별 설정
│   └── indicator_config.json           # 지표 설정
├── results/
│   ├── backtest_results.csv            # 백테스트 결과
│   ├── optimization_summary.csv        # 최적화 요약
│   └── performance_report.html         # 성능 리포트
└── logs/
    ├── backtest.log                    # 백테스트 로그
    ├── optimization.log                # 최적화 로그
    └── error.log                       # 에러 로그
```

---

## 🚀 구현 단계

### Phase 1: 백테스트 엔진 (1주차)
- [ ] 기존 UT_Bot_EA_Simple.mq5 기반 백테스트 전용 EA 개발
- [ ] 파라미터 동적 변경 기능 구현
- [ ] 기본 성능 지표 수집 기능 구현
- [ ] 에러 처리 및 복구 시스템 구현

### Phase 2: 최적화 컨트롤러 (2주차)
- [ ] 키값/ATR 기간 자동 변경 로직 구현
- [ ] 심볼별 테스트 시퀀스 관리 시스템 구현
- [ ] 결과 수집 및 저장 시스템 구현
- [ ] 진행 상황 모니터링 시스템 구현

### Phase 3: 혼합 지표 테스터 (3주차)
- [ ] ADX, Volume, RSI 조합 테스트 시스템 구현
- [ ] 필터 임계값 자동 조정 시스템 구현
- [ ] 지표별 성능 비교 시스템 구현
- [ ] 통합 성능 평가 시스템 구현

### Phase 4: 성능 분석기 (4주차)
- [ ] 통계적 성능 지표 계산 시스템 구현
- [ ] 위험 지표 분석 시스템 구현
- [ ] 최적화 알고리즘 구현
- [ ] 결과 랭킹 시스템 구현

### Phase 5: 리포트 생성기 (5주차)
- [ ] CSV 파일 생성 시스템 구현
- [ ] HTML 리포트 생성 시스템 구현
- [ ] 차트 및 그래프 생성 시스템 구현
- [ ] 설정 파일 관리 시스템 구현

### Phase 6: 통합 테스트 및 최적화 (6주차)
- [ ] 전체 시스템 통합 테스트 수행
- [ ] 성능 최적화 및 버그 수정
- [ ] 사용자 인터페이스 개선
- [ ] 최종 문서화 및 사용자 가이드 작성

---

## 📋 예상 결과

### 1. 심볼별 최적 설정
- **GOLD**: 키값 2.5, ATR 30, RSI 필터
- **EURUSD**: 키값 1.5, ATR 20, ADX+Volume 필터
- **GBPUSD**: 키값 2.0, ATR 25, 혼합 필터
- **USDJPY**: 키값 1.8, ATR 22, RSI 필터
- **NASDAQ**: 키값 3.0, ATR 35, ADX 필터

### 2. 성능 개선 예상
- **순수 UT Bot 대비**: 15-25% 수익률 향상
- **거짓 신호 감소**: 30-40% 감소
- **최대 손실 감소**: 20-30% 감소
- **샤프 비율 향상**: 0.3-0.5 향상

### 3. 자동화 효과
- **수동 테스트 시간**: 2-3주 → **자동화**: 2-3일
- **테스트 정확도**: 95% 이상
- **재현 가능성**: 100%
- **확장성**: 새로운 심볼/지표 쉽게 추가

---

## 🎉 결론

이 자동화 백테스트 시스템을 통해 **체계적이고 과학적인 방법**으로 UT Bot의 최적 파라미터를 찾아낼 수 있습니다. 

**MCP 서버를 활용한 분산 처리**와 **모듈화된 설계**로 확장성과 유지보수성을 확보했으며, **자동화된 리포트 생성**으로 결과 분석의 효율성을 극대화했습니다.

이 시스템을 통해 **데이터 기반의 의사결정**이 가능해지며, **지속적인 성능 개선**을 위한 기반을 마련할 수 있습니다.
