# UT_Bot_EA.mq5 수정 사항 보고서

## Sequential Thinking을 통한 발견된 문제점들

### 1. Critical Issues (컴파일 오류)

#### 1.1 누락된 변수 선언
**문제**: `g_prevSrc` 변수가 사용되지만 선언되지 않음
```mql5
// 기존 코드에서 누락
double g_prevSrc = 0.0;  // 이 변수가 선언되지 않음
```
**해결**: 전역 변수 섹션에 `g_prevSrc` 변수 추가

#### 1.2 함수 선언 순서 문제
**문제**: `OnTick()` 함수에서 `CalculateHeikinAshiClose()` 호출하지만 함수 정의가 이후에 위치
**해결**: 함수 전방 선언 추가
```mql5
// 전방 선언 추가
double CalculateHeikinAshiClose();
void CalculateATRTrailingStop(double src, double atr);
void CheckTradingSignals(double src);
// ... 기타 함수들
```

### 2. High Priority Issues (로직 버그)

#### 2.1 잘못된 변수 사용
**문제**: `CheckTradingSignals()` 함수에서 `g_prevClose` 대신 `g_prevSrc` 사용해야 함
```mql5
// 기존 (잘못됨)
bool above = (ema > g_xATRTrailingStop) && (g_prevClose <= g_prevATRTrailingStop);

// 수정됨
bool above = (ema > g_xATRTrailingStop) && (g_prevSrc <= g_prevATRTrailingStop);
```

#### 2.2 포지션 상태 업데이트 로직 불완전
**문제**: Pine Script의 `pos` 변수는 매 틱마다 업데이트되지만, 기존 코드에서는 신호가 있을 때만 업데이트
**해결**: `UpdatePositionState()` 함수 추가하여 매 틱마다 포지션 상태 업데이트

```mql5
// Pine Script 원본 로직 구현
void UpdatePositionState(double src)
{
    if(g_prevATRTrailingStop == 0.0)
        return;
    
    if(g_prevSrc < g_prevATRTrailingStop && src > g_prevATRTrailingStop)
    {
        g_pos = 1;  // Long position
    }
    else if(g_prevSrc > g_prevATRTrailingStop && src < g_prevATRTrailingStop)
    {
        g_pos = -1; // Short position
    }
}
```

#### 2.3 ATR 트레일링 스탑 계산에서 잘못된 변수 사용
**문제**: `CalculateATRTrailingStop()` 함수에서 `g_prevClose` 대신 `g_prevSrc` 사용해야 함
**해결**: 모든 계산에서 `src` 값 사용하도록 수정

### 3. Medium Priority Issues (개선 사항)

#### 3.1 초기화 로직 개선
**문제**: `g_prevSrc` 변수가 제대로 초기화되지 않음
**해결**: 첫 번째 틱에서 `src` 값으로 초기화

#### 3.2 오류 처리 강화
**해결**: 거래 실행 시 더 자세한 오류 정보 출력
```mql5
Print("UT Bot: Buy order failed. Error: ", trade.ResultRetcode(), 
      " Description: ", trade.ResultRetcodeDescription());
```

#### 3.3 디버깅 로그 개선
**해결**: 가격과 트레일링 스탑 값을 더 정확하게 표시
```mql5
Print("UT Bot: BUY signal detected at ", DoubleToString(src, _Digits), 
      " Trailing Stop: ", DoubleToString(g_xATRTrailingStop, _Digits));
```

## 수정된 파일: UT_Bot_EA_Fixed.mq5

### 주요 개선사항:

1. **컴파일 오류 해결**
   - 누락된 변수 선언 추가
   - 함수 전방 선언 추가

2. **Pine Script 로직 정확한 구현**
   - 포지션 상태 업데이트 로직 완전 구현
   - 올바른 변수 사용 (src vs close)
   - 크로스오버 감지 로직 수정

3. **코드 구조 개선**
   - 함수 분리 및 모듈화
   - 명확한 변수 초기화
   - 향상된 오류 처리

4. **디버깅 및 모니터링 강화**
   - 상세한 로그 출력
   - 정확한 가격 정보 표시
   - 오류 메시지 개선

## 테스트 권장사항:

1. **컴파일 테스트**
   - MetaEditor에서 컴파일 오류 없이 빌드되는지 확인

2. **백테스팅**
   - 다양한 시장 조건에서 전략 테스트
   - Pine Script 원본과 결과 비교

3. **데모 거래**
   - 실제 시장 조건에서 안전하게 테스트
   - 로그를 통한 동작 확인

4. **성능 모니터링**
   - 메모리 사용량 확인
   - CPU 사용률 모니터링

## 주의사항:

1. **Heikin Ashi 사용 시**
   - `UseHeikinAshi = true`로 설정할 때 올바른 계산이 이루어지는지 확인

2. **변동성 높은 시장**
   - KeyValue와 ATRPeriod 설정을 신중하게 조정

3. **리스크 관리**
   - RiskPercent 설정을 계좌 크기에 맞게 조정
   - 최대 손실 한도 설정

이 수정된 버전은 Pine Script 원본의 로직을 정확히 구현하면서 MQL5 환경에 최적화되어 있습니다.
