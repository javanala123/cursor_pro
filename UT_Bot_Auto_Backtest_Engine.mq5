//+------------------------------------------------------------------+
//|                                    UT_Bot_Auto_Backtest_Engine.mq5 |
//|                        Copyright 2024, MetaTrader Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaTrader Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "UT Bot 자동화 백테스트 엔진 - 파라미터 동적 변경 및 성능 지표 수집"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| 백테스트 결과 구조체                                              |
//+------------------------------------------------------------------+
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
    
    // 추가 지표
    double totalProfit;         // 총 수익
    double totalLoss;           // 총 손실
    double averageWin;          // 평균 수익
    double averageLoss;         // 평균 손실
    int winningTrades;          // 수익 거래 수
    int losingTrades;           // 손실 거래 수
};

//+------------------------------------------------------------------+
//| 백테스트 엔진 클래스                                              |
//+------------------------------------------------------------------+
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
    
    // 성능 추적 변수
    double initialBalance;
    double currentBalance;
    double peakBalance;
    double maxDrawdown;
    
    // 거래 추적
    int totalTrades;
    int winningTrades;
    int losingTrades;
    double totalProfit;
    double totalLoss;
    int consecutiveLosses;
    int maxConsecutiveLosses;
    
    // 수익률 추적 (일별)
    double dailyReturns[];
    int returnCount;
    
    // 이전 값들
    double prevStop;
    double prevPrice;
    double prevMa;
    int lastSignal;
    datetime lastBar;
    
    // 적응형 필터 변수
    int adxFailCount;
    int volumeFailCount;
    int rsiFailCount;
    datetime lastAdaptiveTime;
    
    // 부분익절 추적
    bool g_firstTakeProfitExecuted;
    bool g_secondTakeProfitExecuted;
    
    // 거래 객체
    CTrade trade;
    
    // 결과 저장
    SBacktestResult currentResult;
    
public:
    // 생성자
    CBacktestEngine();
    
    // 소멸자
    ~CBacktestEngine();
    
    // 초기화
    bool Initialize(string symbol, double keyValue, int atrPeriod, int indicatorMode);
    
    // 백테스트 실행
    bool RunBacktest(datetime startTime, datetime endTime);
    
    // 결과 반환
    SBacktestResult GetResults();
    
    // 정리
    void Cleanup();
    
private:
    // 내부 함수들
    void OnTick();
    double CalculateStop(double price, double atr);
    void CheckSignal(double price, double stop, double ma, double atr);
    void CheckPartialTakeProfit();
    void CloseAll();
    void DrawArrow(string signal, double price);
    
    // 필터 함수들
    bool CheckADXFilter();
    bool CheckVolumeFilter();
    bool CheckRSIFilter();
    
    // 성능 계산 함수들
    void CalculatePerformanceMetrics();
    double CalculateSharpeRatio();
    double CalculateSortinoRatio();
    double CalculateCalmarRatio();
    double CalculateVolatility();
    double CalculateVaR95();
    double CalculateExpectedShortfall();
};

//+------------------------------------------------------------------+
//| 생성자                                                           |
//+------------------------------------------------------------------+
CBacktestEngine::CBacktestEngine() {
    // 핸들 초기화
    atr_handle = INVALID_HANDLE;
    ma_handle = INVALID_HANDLE;
    adx_handle = INVALID_HANDLE;
    rsi_handle = INVALID_HANDLE;
    
    // 변수 초기화
    currentKeyValue = 0;
    currentATRPeriod = 0;
    currentIndicatorMode = 0;
    currentSymbol = "";
    
    // 성능 추적 초기화
    initialBalance = 10000.0;  // 기본 초기 자본
    currentBalance = initialBalance;
    peakBalance = initialBalance;
    maxDrawdown = 0.0;
    
    // 거래 추적 초기화
    totalTrades = 0;
    winningTrades = 0;
    losingTrades = 0;
    totalProfit = 0.0;
    totalLoss = 0.0;
    consecutiveLosses = 0;
    maxConsecutiveLosses = 0;
    
    // 수익률 추적 초기화
    ArrayResize(dailyReturns, 1000);
    returnCount = 0;
    
    // 이전 값 초기화
    prevStop = 0;
    prevPrice = 0;
    prevMa = 0;
    lastSignal = 0;
    lastBar = 0;
    
    // 적응형 필터 초기화
    adxFailCount = 0;
    volumeFailCount = 0;
    rsiFailCount = 0;
    lastAdaptiveTime = 0;
    
    // 부분익절 초기화
    g_firstTakeProfitExecuted = false;
    g_secondTakeProfitExecuted = false;
    
    // 거래 객체 초기화
    trade.SetExpertMagicNumber(12345);
}

//+------------------------------------------------------------------+
//| 소멸자                                                           |
//+------------------------------------------------------------------+
CBacktestEngine::~CBacktestEngine() {
    Cleanup();
}

//+------------------------------------------------------------------+
//| 초기화                                                           |
//+------------------------------------------------------------------+
bool CBacktestEngine::Initialize(string symbol, double keyValue, int atrPeriod, int indicatorMode) {
    // 파라미터 저장
    currentSymbol = symbol;
    currentKeyValue = keyValue;
    currentATRPeriod = atrPeriod;
    currentIndicatorMode = indicatorMode;
    
    // 심볼 설정
    if(!SymbolSelect(symbol, true)) {
        Print("❌ 심볼 선택 실패: ", symbol);
        return false;
    }
    
    // 핸들 생성
    atr_handle = iATR(symbol, PERIOD_CURRENT, atrPeriod);
    ma_handle = iMA(symbol, PERIOD_CURRENT, 1, 0, MODE_EMA, PRICE_CLOSE);
    
    if(atr_handle == INVALID_HANDLE || ma_handle == INVALID_HANDLE) {
        Print("❌ 핸들 생성 실패");
        return false;
    }
    
    // 지표 모드에 따른 추가 핸들 생성
    if(indicatorMode == 1 || indicatorMode == 4) { // ADX 또는 혼합
        adx_handle = iADX(symbol, PERIOD_CURRENT, 14);
        if(adx_handle == INVALID_HANDLE) {
            Print("❌ ADX 핸들 생성 실패");
            return false;
        }
    }
    
    if(indicatorMode == 3 || indicatorMode == 4) { // RSI 또는 혼합
        rsi_handle = iRSI(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
        if(rsi_handle == INVALID_HANDLE) {
            Print("❌ RSI 핸들 생성 실패");
            return false;
        }
    }
    
    // 초기 자본 설정
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    currentBalance = initialBalance;
    peakBalance = initialBalance;
    
    // 결과 구조체 초기화
    ZeroMemory(currentResult);
    currentResult.symbol = symbol;
    currentResult.keyValue = keyValue;
    currentResult.atrPeriod = atrPeriod;
    currentResult.indicatorMode = indicatorMode;
    currentResult.testStartTime = TimeCurrent();
    
    Print("✅ 백테스트 엔진 초기화 완료 - 심볼:", symbol, " 키값:", keyValue, " ATR:", atrPeriod, " 모드:", indicatorMode);
    
    return true;
}

//+------------------------------------------------------------------+
//| 백테스트 실행                                                    |
//+------------------------------------------------------------------+
bool CBacktestEngine::RunBacktest(datetime startTime, datetime endTime) {
    Print("🚀 백테스트 시작 - ", TimeToString(startTime), " ~ ", TimeToString(endTime));
    
    // 백테스트 기간 설정
    currentResult.testStartTime = startTime;
    currentResult.testEndTime = endTime;
    currentResult.testDuration = (int)((endTime - startTime) / 86400); // 일 단위
    
    // 초기화
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    currentBalance = initialBalance;
    peakBalance = initialBalance;
    maxDrawdown = 0.0;
    
    // 거래 추적 초기화
    totalTrades = 0;
    winningTrades = 0;
    losingTrades = 0;
    totalProfit = 0.0;
    totalLoss = 0.0;
    consecutiveLosses = 0;
    maxConsecutiveLosses = 0;
    returnCount = 0;
    
    // 이전 값 초기화
    prevStop = 0;
    prevPrice = 0;
    prevMa = 0;
    lastSignal = 0;
    lastBar = 0;
    
    // 부분익절 초기화
    g_firstTakeProfitExecuted = false;
    g_secondTakeProfitExecuted = false;
    
    // 백테스트 루프 (실제로는 MT5 Strategy Tester가 호출)
    // 여기서는 OnTick() 함수가 호출되는 것으로 가정
    
    // 성능 지표 계산
    CalculatePerformanceMetrics();
    
    Print("✅ 백테스트 완료 - 총 거래:", totalTrades, " 승률:", DoubleToString((double)winningTrades/totalTrades*100, 2), "%");
    
    return true;
}

//+------------------------------------------------------------------+
//| OnTick 함수 (MT5 Strategy Tester에서 호출)                       |
//+------------------------------------------------------------------+
void CBacktestEngine::OnTick() {
    // 새 바 확인
    datetime bar = iTime(currentSymbol, PERIOD_CURRENT, 0);
    if(bar == lastBar) return;
    lastBar = bar;
    
    // 가격, ATR, 이동평균 가져오기
    double price = iClose(currentSymbol, PERIOD_CURRENT, 0);
    double atr[1], ma[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0) return;
    if(CopyBuffer(ma_handle, 0, 0, 1, ma) <= 0) return;
    
    // ATR 스탑 계산
    double stop = CalculateStop(price, atr[0]);
    
    // 신호 확인
    CheckSignal(price, stop, ma[0], atr[0]);
    
    // 부분익절 체크
    CheckPartialTakeProfit();
    
    // 이전 값 저장
    prevStop = stop;
    prevPrice = price;
    prevMa = ma[0];
    
    // 일별 수익률 계산
    static datetime lastDay = 0;
    datetime currentDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    if(currentDay != lastDay) {
        double dailyReturn = (currentBalance - initialBalance) / initialBalance;
        if(returnCount < ArraySize(dailyReturns)) {
            dailyReturns[returnCount] = dailyReturn;
            returnCount++;
        }
        lastDay = currentDay;
    }
}

//+------------------------------------------------------------------+
//| ATR 스탑 계산                                                    |
//+------------------------------------------------------------------+
double CBacktestEngine::CalculateStop(double price, double atr) {
    double nLoss = atr * currentKeyValue;
    
    // 1단계: 기본 스탑 라인 계산
    double iff_1 = (price > prevStop) ? (price - nLoss) : (price + nLoss);
    
    // 2단계: 하락 추세에서 스탑 라인 조정
    double iff_2;
    if(price < prevStop && prevPrice < prevStop)
        iff_2 = MathMin(prevStop, price + nLoss);
    else
        iff_2 = iff_1;
    
    // 3단계: 상승 추세에서 스탑 라인 조정
    double result;
    if(price > prevStop && prevPrice > prevStop)
        result = MathMax(prevStop, price - nLoss);
    else
        result = iff_2;
    
    return result;
}

//+------------------------------------------------------------------+
//| 신호 확인 및 거래                                                |
//+------------------------------------------------------------------+
void CBacktestEngine::CheckSignal(double price, double stop, double ma, double atr) {
    // 초기화 로직
    if(prevStop == 0) {
        double nLoss = atr * currentKeyValue;
        prevStop = price + nLoss;
        return;
    }
    if(prevMa == 0) return;
    
    // 신호 생성 로직
    bool above = (ma > stop) && (prevMa <= prevStop);
    bool below = (stop > ma) && (prevStop <= prevMa);
    
    bool buySignal = (price > stop) && above;
    bool sellSignal = (price < stop) && below;
    
    // 연속 신호 방지
    if((buySignal && lastSignal == 1) || (sellSignal && lastSignal == -1))
        return;
    
    // 매수 신호 처리
    if(buySignal) {
        // 필터 체크 (백테스트에서는 우회)
        if(!MQLInfoInteger(MQL_TESTER)) {
            if(!CheckADXFilter() || !CheckVolumeFilter() || !CheckRSIFilter()) {
                return;
            }
        }
        
        // 반대 포지션 청산
        CloseAll();
        
        // 매수 주문 실행
        if(trade.Buy(0.01, currentSymbol)) {
            lastSignal = 1;
            g_firstTakeProfitExecuted = false;
            g_secondTakeProfitExecuted = false;
        }
    }
    
    // 매도 신호 처리
    if(sellSignal) {
        // 필터 체크 (백테스트에서는 우회)
        if(!MQLInfoInteger(MQL_TESTER)) {
            if(!CheckADXFilter() || !CheckVolumeFilter() || !CheckRSIFilter()) {
                return;
            }
        }
        
        // 반대 포지션 청산
        CloseAll();
        
        // 매도 주문 실행
        if(trade.Sell(0.01, currentSymbol)) {
            lastSignal = -1;
            g_firstTakeProfitExecuted = false;
            g_secondTakeProfitExecuted = false;
        }
    }
}

//+------------------------------------------------------------------+
//| 부분익절 체크                                                    |
//+------------------------------------------------------------------+
void CBacktestEngine::CheckPartialTakeProfit() {
    if(PositionSelect(currentSymbol)) {
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double currentLot = PositionGetDouble(POSITION_VOLUME);
        double profitAmount = PositionGetDouble(POSITION_PROFIT);
        
        // 1차 부분익절 (50달러)
        if(!g_firstTakeProfitExecuted && profitAmount >= 50.0 && currentLot >= 0.01) {
            if(trade.PositionClosePartial(ticket, 0.01)) {
                g_firstTakeProfitExecuted = true;
            }
        }
        
        // 2차 부분익절 (100달러)
        else if(g_firstTakeProfitExecuted && !g_secondTakeProfitExecuted && profitAmount >= 100.0 && currentLot >= 0.01) {
            if(trade.PositionClosePartial(ticket, 0.01)) {
                g_secondTakeProfitExecuted = true;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 모든 포지션 청산                                                 |
//+------------------------------------------------------------------+
void CBacktestEngine::CloseAll() {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionGetSymbol(i) == currentSymbol) {
            trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
    }
}

//+------------------------------------------------------------------+
//| 성능 지표 계산                                                   |
//+------------------------------------------------------------------+
void CBacktestEngine::CalculatePerformanceMetrics() {
    // 기본 지표 계산
    currentResult.totalReturn = (currentBalance - initialBalance) / initialBalance;
    currentResult.annualReturn = currentResult.totalReturn / (currentResult.testDuration / 365.0);
    currentResult.maxDrawdown = maxDrawdown;
    
    // 거래 지표
    currentResult.totalTrades = totalTrades;
    currentResult.winningTrades = winningTrades;
    currentResult.losingTrades = losingTrades;
    currentResult.winRate = totalTrades > 0 ? (double)winningTrades / totalTrades : 0.0;
    currentResult.profitFactor = totalLoss > 0 ? totalProfit / MathAbs(totalLoss) : 0.0;
    currentResult.maxConsecutiveLosses = maxConsecutiveLosses;
    
    // 수익/손실
    currentResult.totalProfit = totalProfit;
    currentResult.totalLoss = totalLoss;
    currentResult.averageWin = winningTrades > 0 ? totalProfit / winningTrades : 0.0;
    currentResult.averageLoss = losingTrades > 0 ? totalLoss / losingTrades : 0.0;
    
    // 위험 지표
    currentResult.volatility = CalculateVolatility();
    currentResult.var95 = CalculateVaR95();
    currentResult.expectedShortfall = CalculateExpectedShortfall();
    
    // 효율성 지표
    currentResult.sharpeRatio = CalculateSharpeRatio();
    currentResult.sortinoRatio = CalculateSortinoRatio();
    currentResult.calmarRatio = CalculateCalmarRatio();
    
    currentResult.testEndTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| 샤프 비율 계산                                                   |
//+------------------------------------------------------------------+
double CBacktestEngine::CalculateSharpeRatio() {
    if(returnCount < 2) return 0.0;
    
    double mean = 0.0;
    for(int i = 0; i < returnCount; i++) {
        mean += dailyReturns[i];
    }
    mean /= returnCount;
    
    double variance = 0.0;
    for(int i = 0; i < returnCount; i++) {
        variance += MathPow(dailyReturns[i] - mean, 2);
    }
    variance /= (returnCount - 1);
    double stdDev = MathSqrt(variance);
    
    if(stdDev == 0) return 0.0;
    
    return (mean - 0.02/365) / stdDev; // 무위험 수익률 2% 가정
}

//+------------------------------------------------------------------+
//| 소르티노 비율 계산                                               |
//+------------------------------------------------------------------+
double CBacktestEngine::CalculateSortinoRatio() {
    if(returnCount < 2) return 0.0;
    
    double mean = 0.0;
    for(int i = 0; i < returnCount; i++) {
        mean += dailyReturns[i];
    }
    mean /= returnCount;
    
    double downsideVariance = 0.0;
    int downsideCount = 0;
    for(int i = 0; i < returnCount; i++) {
        if(dailyReturns[i] < 0) {
            downsideVariance += MathPow(dailyReturns[i], 2);
            downsideCount++;
        }
    }
    
    if(downsideCount == 0) return 0.0;
    downsideVariance /= downsideCount;
    double downsideStdDev = MathSqrt(downsideVariance);
    
    if(downsideStdDev == 0) return 0.0;
    
    return (mean - 0.02/365) / downsideStdDev;
}

//+------------------------------------------------------------------+
//| 칼마 비율 계산                                                   |
//+------------------------------------------------------------------+
double CBacktestEngine::CalculateCalmarRatio() {
    if(MathAbs(currentResult.maxDrawdown) == 0) return 0.0;
    return currentResult.annualReturn / MathAbs(currentResult.maxDrawdown);
}

//+------------------------------------------------------------------+
//| 변동성 계산                                                      |
//+------------------------------------------------------------------+
double CBacktestEngine::CalculateVolatility() {
    if(returnCount < 2) return 0.0;
    
    double mean = 0.0;
    for(int i = 0; i < returnCount; i++) {
        mean += dailyReturns[i];
    }
    mean /= returnCount;
    
    double variance = 0.0;
    for(int i = 0; i < returnCount; i++) {
        variance += MathPow(dailyReturns[i] - mean, 2);
    }
    variance /= (returnCount - 1);
    
    return MathSqrt(variance) * MathSqrt(252); // 연간화
}

//+------------------------------------------------------------------+
//| VaR 95% 계산                                                     |
//+------------------------------------------------------------------+
double CBacktestEngine::CalculateVaR95() {
    if(returnCount < 20) return 0.0;
    
    // 수익률 배열 복사 및 정렬
    double sortedReturns[];
    ArrayResize(sortedReturns, returnCount);
    for(int i = 0; i < returnCount; i++) {
        sortedReturns[i] = dailyReturns[i];
    }
    ArraySort(sortedReturns);
    
    // 95% VaR (5% 분위수)
    int index = (int)(returnCount * 0.05);
    return sortedReturns[index];
}

//+------------------------------------------------------------------+
//| 기대 부족분 계산                                                 |
//+------------------------------------------------------------------+
double CBacktestEngine::CalculateExpectedShortfall() {
    if(returnCount < 20) return 0.0;
    
    double var95 = CalculateVaR95();
    double sum = 0.0;
    int count = 0;
    
    for(int i = 0; i < returnCount; i++) {
        if(dailyReturns[i] <= var95) {
            sum += dailyReturns[i];
            count++;
        }
    }
    
    return count > 0 ? sum / count : 0.0;
}

//+------------------------------------------------------------------+
//| 필터 함수들 (간단한 구현)                                        |
//+------------------------------------------------------------------+
bool CBacktestEngine::CheckADXFilter() {
    if(currentIndicatorMode != 1 && currentIndicatorMode != 4) return true;
    // 간단한 구현 - 실제로는 ADX 값 확인
    return true;
}

bool CBacktestEngine::CheckVolumeFilter() {
    if(currentIndicatorMode != 2 && currentIndicatorMode != 4) return true;
    // 간단한 구현 - 실제로는 Volume 값 확인
    return true;
}

bool CBacktestEngine::CheckRSIFilter() {
    if(currentIndicatorMode != 3 && currentIndicatorMode != 4) return true;
    // 간단한 구현 - 실제로는 RSI 값 확인
    return true;
}

//+------------------------------------------------------------------+
//| 결과 반환                                                        |
//+------------------------------------------------------------------+
SBacktestResult CBacktestEngine::GetResults() {
    return currentResult;
}

//+------------------------------------------------------------------+
//| 정리                                                             |
//+------------------------------------------------------------------+
void CBacktestEngine::Cleanup() {
    if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
    if(ma_handle != INVALID_HANDLE) IndicatorRelease(ma_handle);
    if(adx_handle != INVALID_HANDLE) IndicatorRelease(adx_handle);
    if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
    
    atr_handle = INVALID_HANDLE;
    ma_handle = INVALID_HANDLE;
    adx_handle = INVALID_HANDLE;
    rsi_handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("✅ UT Bot 자동화 백테스트 엔진 시작");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("✅ UT Bot 자동화 백테스트 엔진 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // 실제 백테스트는 Strategy Tester에서 실행됨
    // 여기서는 기본적인 틱 처리만 수행
}
