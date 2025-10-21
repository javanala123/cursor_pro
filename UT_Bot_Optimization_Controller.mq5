//+------------------------------------------------------------------+
//|                              UT_Bot_Optimization_Controller.mq5 |
//|                        Copyright 2024, MetaTrader Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaTrader Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "UT Bot 최적화 컨트롤러 - 키값/ATR 기간 자동 변경 및 결과 수집"

#include "UT_Bot_Auto_Backtest_Engine.mq5"

//+------------------------------------------------------------------+
//| 최적화 설정 구조체                                                |
//+------------------------------------------------------------------+
struct SOptimizationConfig {
    // 심볼 설정
    string symbols[10];         // 테스트할 심볼 목록
    int symbolCount;            // 심볼 개수
    
    // 키값 범위
    double keyValueMin;         // 최소 키값
    double keyValueMax;         // 최대 키값
    double keyValueStep;        // 키값 단계
    
    // ATR 기간 범위
    int atrPeriodMin;           // 최소 ATR 기간
    int atrPeriodMax;           // 최대 ATR 기간
    int atrPeriodStep;          // ATR 기간 단계
    
    // 지표 모드
    int indicatorModes[5];      // 테스트할 지표 모드
    int indicatorModeCount;     // 지표 모드 개수
    
    // 백테스트 기간
    datetime startDate;         // 시작 날짜
    datetime endDate;           // 종료 날짜
    
    // 성능 기준
    int minTrades;              // 최소 거래 횟수
    double maxDrawdownLimit;    // 최대 손실 한도
    double minWinRate;          // 최소 승률
    
    // 최적화 목표
    int optimizationTarget;     // 0: 샤프비율, 1: 수익률, 2: 최소손실
};

//+------------------------------------------------------------------+
//| 최적화 관리자 클래스                                              |
//+------------------------------------------------------------------+
class COptimizationManager {
private:
    SOptimizationConfig config;
    CBacktestEngine engine;
    SBacktestResult results[];
    int resultCount;
    
    // 진행 상황 추적
    int totalCombinations;
    int currentCombination;
    datetime startTime;
    
    // 최적 결과 추적
    SBacktestResult bestOverallResult;
    SBacktestResult bestResultsBySymbol[10];
    int bestResultsCount;
    
    // 파일 핸들
    int csvHandle;
    int logHandle;
    
public:
    // 생성자
    COptimizationManager();
    
    // 소멸자
    ~COptimizationManager();
    
    // 설정 로드
    bool LoadConfig(string configFile = "");
    bool LoadDefaultConfig();
    
    // 최적화 실행
    bool RunOptimization();
    bool RunGridSearch();
    bool RunRandomSearch(int iterations = 1000);
    
    // 결과 분석
    SBacktestResult GetBestResult();
    SBacktestResult GetBestResultForSymbol(string symbol);
    SBacktestResult GetBestResultByTarget(int target);
    
    // 결과 저장
    bool SaveResults(string filename = "");
    bool SaveSummary(string filename = "");
    bool ExportToCSV(string filename = "");
    
    // 진행 상황
    double GetProgress();
    string GetStatus();
    int GetRemainingTime();
    
    // 통계
    int GetTotalResults();
    double GetAverageReturn();
    double GetAverageSharpeRatio();
    
private:
    // 내부 함수들
    bool InitializeFiles();
    void CloseFiles();
    bool IsValidResult(SBacktestResult &result);
    double CalculateScore(SBacktestResult &result);
    void UpdateBestResults(SBacktestResult &result);
    void LogProgress();
    void LogResult(SBacktestResult &result);
    string GetIndicatorModeName(int mode);
    string GetOptimizationTargetName(int target);
};

//+------------------------------------------------------------------+
//| 생성자                                                           |
//+------------------------------------------------------------------+
COptimizationManager::COptimizationManager() {
    // 설정 초기화
    ZeroMemory(config);
    config.symbolCount = 0;
    config.indicatorModeCount = 0;
    config.bestResultsCount = 0;
    
    // 결과 초기화
    ArrayResize(results, 10000); // 최대 10000개 결과 저장
    resultCount = 0;
    
    // 진행 상황 초기화
    totalCombinations = 0;
    currentCombination = 0;
    startTime = 0;
    
    // 최적 결과 초기화
    ZeroMemory(bestOverallResult);
    for(int i = 0; i < 10; i++) {
        ZeroMemory(bestResultsBySymbol[i]);
    }
    
    // 파일 핸들 초기화
    csvHandle = INVALID_HANDLE;
    logHandle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| 소멸자                                                           |
//+------------------------------------------------------------------+
COptimizationManager::~COptimizationManager() {
    CloseFiles();
}

//+------------------------------------------------------------------+
//| 기본 설정 로드                                                   |
//+------------------------------------------------------------------+
bool COptimizationManager::LoadDefaultConfig() {
    Print("📋 기본 최적화 설정 로드 중...");
    
    // 심볼 설정
    config.symbols[0] = "XAUUSD";    // GOLD
    config.symbols[1] = "EURUSD";    // EUR/USD
    config.symbols[2] = "GBPUSD";    // GBP/USD
    config.symbols[3] = "USDJPY";    // USD/JPY
    config.symbols[4] = "NASDAQ";    // NASDAQ
    config.symbolCount = 5;
    
    // 키값 범위
    config.keyValueMin = 0.5;
    config.keyValueMax = 5.0;
    config.keyValueStep = 0.1;
    
    // ATR 기간 범위
    config.atrPeriodMin = 10;
    config.atrPeriodMax = 50;
    config.atrPeriodStep = 5;
    
    // 지표 모드
    config.indicatorModes[0] = 0;    // UT Bot Only
    config.indicatorModes[1] = 1;    // UT Bot + ADX
    config.indicatorModes[2] = 2;    // UT Bot + Volume
    config.indicatorModes[3] = 3;    // UT Bot + RSI
    config.indicatorModes[4] = 4;    // UT Bot + Enhanced
    config.indicatorModeCount = 5;
    
    // 백테스트 기간 (최근 1년)
    config.startDate = StringToTime("2024.01.01 00:00");
    config.endDate = StringToTime("2024.12.31 23:59");
    
    // 성능 기준
    config.minTrades = 50;
    config.maxDrawdownLimit = -0.30;  // -30%
    config.minWinRate = 0.40;         // 40%
    
    // 최적화 목표
    config.optimizationTarget = 0;    // 샤프 비율
    
    // 총 조합 수 계산
    totalCombinations = config.symbolCount * 
                       (int)((config.keyValueMax - config.keyValueMin) / config.keyValueStep + 1) *
                       (int)((config.atrPeriodMax - config.atrPeriodMin) / config.atrPeriodStep + 1) *
                       config.indicatorModeCount;
    
    Print("✅ 기본 설정 로드 완료");
    Print("   - 심볼 개수: ", config.symbolCount);
    Print("   - 키값 범위: ", config.keyValueMin, " ~ ", config.keyValueMax, " (", config.keyValueStep, ")");
    Print("   - ATR 기간: ", config.atrPeriodMin, " ~ ", config.atrPeriodMax, " (", config.atrPeriodStep, ")");
    Print("   - 지표 모드: ", config.indicatorModeCount, "개");
    Print("   - 총 조합: ", totalCombinations, "개");
    
    return true;
}

//+------------------------------------------------------------------+
//| 최적화 실행                                                      |
//+------------------------------------------------------------------+
bool COptimizationManager::RunOptimization() {
    Print("🚀 최적화 시작 - 총 ", totalCombinations, "개 조합 테스트");
    
    startTime = TimeCurrent();
    
    // 파일 초기화
    if(!InitializeFiles()) {
        Print("❌ 파일 초기화 실패");
        return false;
    }
    
    // 그리드 서치 실행
    bool success = RunGridSearch();
    
    // 파일 정리
    CloseFiles();
    
    // 최종 결과 출력
    Print("✅ 최적화 완료");
    Print("   - 총 결과: ", resultCount, "개");
    Print("   - 소요 시간: ", (TimeCurrent() - startTime) / 60, "분");
    
    if(resultCount > 0) {
        SBacktestResult best = GetBestResult();
        Print("   - 최고 성과: ", best.symbol, " 키값:", best.keyValue, " ATR:", best.atrPeriod);
        Print("   - 수익률: ", DoubleToString(best.totalReturn * 100, 2), "%");
        Print("   - 샤프비율: ", DoubleToString(best.sharpeRatio, 3));
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| 그리드 서치 실행                                                 |
//+------------------------------------------------------------------+
bool COptimizationManager::RunGridSearch() {
    currentCombination = 0;
    
    // 각 심볼별로 테스트
    for(int s = 0; s < config.symbolCount; s++) {
        string symbol = config.symbols[s];
        Print("📊 심볼 테스트 중: ", symbol, " (", s+1, "/", config.symbolCount, ")");
        
        // 키값 범위 테스트
        for(double kv = config.keyValueMin; kv <= config.keyValueMax; kv += config.keyValueStep) {
            // ATR 기간 범위 테스트
            for(int ap = config.atrPeriodMin; ap <= config.atrPeriodMax; ap += config.atrPeriodStep) {
                // 지표 모드 테스트
                for(int im = 0; im < config.indicatorModeCount; im++) {
                    int indicatorMode = config.indicatorModes[im];
                    
                    // 백테스트 엔진 초기화
                    if(engine.Initialize(symbol, kv, ap, indicatorMode)) {
                        // 백테스트 실행
                        if(engine.RunBacktest(config.startDate, config.endDate)) {
                            SBacktestResult result = engine.GetResults();
                            
                            // 결과 유효성 검사
                            if(IsValidResult(result)) {
                                // 결과 저장
                                results[resultCount] = result;
                                resultCount++;
                                
                                // 최적 결과 업데이트
                                UpdateBestResults(result);
                                
                                // 로그 기록
                                LogResult(result);
                            }
                        }
                        
                        // 엔진 정리
                        engine.Cleanup();
                    }
                    
                    currentCombination++;
                    
                    // 진행 상황 로그 (100개마다)
                    if(currentCombination % 100 == 0) {
                        LogProgress();
                    }
                }
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 랜덤 서치 실행                                                   |
//+------------------------------------------------------------------+
bool COptimizationManager::RunRandomSearch(int iterations = 1000) {
    Print("🎲 랜덤 서치 시작 - ", iterations, "회 반복");
    
    currentCombination = 0;
    totalCombinations = iterations;
    
    for(int i = 0; i < iterations; i++) {
        // 랜덤 파라미터 생성
        int symbolIndex = (int)(MathRand() % config.symbolCount);
        string symbol = config.symbols[symbolIndex];
        
        double kv = config.keyValueMin + (config.keyValueMax - config.keyValueMin) * MathRand() / 32767.0;
        kv = MathRound(kv / config.keyValueStep) * config.keyValueStep; // 단계에 맞춤
        
        int ap = config.atrPeriodMin + (int)((config.atrPeriodMax - config.atrPeriodMin) * MathRand() / 32767.0);
        ap = (ap / config.atrPeriodStep) * config.atrPeriodStep; // 단계에 맞춤
        
        int indicatorMode = config.indicatorModes[(int)(MathRand() % config.indicatorModeCount)];
        
        // 백테스트 실행
        if(engine.Initialize(symbol, kv, ap, indicatorMode)) {
            if(engine.RunBacktest(config.startDate, config.endDate)) {
                SBacktestResult result = engine.GetResults();
                
                if(IsValidResult(result)) {
                    results[resultCount] = result;
                    resultCount++;
                    UpdateBestResults(result);
                    LogResult(result);
                }
            }
            engine.Cleanup();
        }
        
        currentCombination++;
        
        if(currentCombination % 50 == 0) {
            LogProgress();
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 결과 유효성 검사                                                 |
//+------------------------------------------------------------------+
bool COptimizationManager::IsValidResult(SBacktestResult &result) {
    // 최소 거래 횟수 확인
    if(result.totalTrades < config.minTrades) return false;
    
    // 최대 손실 한도 확인
    if(result.maxDrawdown < config.maxDrawdownLimit) return false;
    
    // 최소 승률 확인
    if(result.winRate < config.minWinRate) return false;
    
    // NaN 또는 무한대 값 확인
    if(!MathIsValidNumber(result.totalReturn) || !MathIsValidNumber(result.sharpeRatio)) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| 점수 계산                                                        |
//+------------------------------------------------------------------+
double COptimizationManager::CalculateScore(SBacktestResult &result) {
    double score = 0.0;
    
    switch(config.optimizationTarget) {
        case 0: // 샤프 비율
            score = result.sharpeRatio;
            break;
        case 1: // 수익률
            score = result.totalReturn;
            break;
        case 2: // 최소 손실 (음수이므로 절댓값)
            score = MathAbs(result.maxDrawdown);
            break;
        default:
            // 복합 점수 (가중치 적용)
            score = result.sharpeRatio * 0.4 + 
                   result.totalReturn * 0.3 + 
                   MathAbs(result.maxDrawdown) * 0.2 + 
                   result.winRate * 0.1;
            break;
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| 최적 결과 업데이트                                               |
//+------------------------------------------------------------------+
void COptimizationManager::UpdateBestResults(SBacktestResult &result) {
    double currentScore = CalculateScore(result);
    
    // 전체 최적 결과 업데이트
    if(resultCount == 1 || currentScore > CalculateScore(bestOverallResult)) {
        bestOverallResult = result;
    }
    
    // 심볼별 최적 결과 업데이트
    for(int i = 0; i < config.symbolCount; i++) {
        if(config.symbols[i] == result.symbol) {
            if(bestResultsCount == 0 || currentScore > CalculateScore(bestResultsBySymbol[i])) {
                bestResultsBySymbol[i] = result;
                if(bestResultsCount < config.symbolCount) bestResultsCount++;
            }
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| 최적 결과 반환                                                   |
//+------------------------------------------------------------------+
SBacktestResult COptimizationManager::GetBestResult() {
    return bestOverallResult;
}

//+------------------------------------------------------------------+
//| 심볼별 최적 결과 반환                                            |
//+------------------------------------------------------------------+
SBacktestResult COptimizationManager::GetBestResultForSymbol(string symbol) {
    for(int i = 0; i < config.symbolCount; i++) {
        if(config.symbols[i] == symbol) {
            return bestResultsBySymbol[i];
        }
    }
    
    SBacktestResult empty;
    ZeroMemory(empty);
    return empty;
}

//+------------------------------------------------------------------+
//| 목표별 최적 결과 반환                                            |
//+------------------------------------------------------------------+
SBacktestResult COptimizationManager::GetBestResultByTarget(int target) {
    SBacktestResult best;
    ZeroMemory(best);
    double bestScore = -999999.0;
    
    for(int i = 0; i < resultCount; i++) {
        double score = 0.0;
        
        switch(target) {
            case 0: score = results[i].sharpeRatio; break;
            case 1: score = results[i].totalReturn; break;
            case 2: score = MathAbs(results[i].maxDrawdown); break;
        }
        
        if(score > bestScore) {
            bestScore = score;
            best = results[i];
        }
    }
    
    return best;
}

//+------------------------------------------------------------------+
//| 진행 상황 반환                                                   |
//+------------------------------------------------------------------+
double COptimizationManager::GetProgress() {
    if(totalCombinations == 0) return 0.0;
    return (double)currentCombination / totalCombinations * 100.0;
}

//+------------------------------------------------------------------+
//| 상태 반환                                                        |
//+------------------------------------------------------------------+
string COptimizationManager::GetStatus() {
    double progress = GetProgress();
    int remaining = GetRemainingTime();
    
    return StringFormat("진행률: %.1f%% (%d/%d) | 남은 시간: %d분 | 결과: %d개", 
                       progress, currentCombination, totalCombinations, remaining, resultCount);
}

//+------------------------------------------------------------------+
//| 남은 시간 계산                                                   |
//+------------------------------------------------------------------+
int COptimizationManager::GetRemainingTime() {
    if(currentCombination == 0) return 0;
    
    datetime elapsed = TimeCurrent() - startTime;
    double avgTimePerCombination = (double)elapsed / currentCombination;
    int remaining = (int)((totalCombinations - currentCombination) * avgTimePerCombination / 60);
    
    return remaining;
}

//+------------------------------------------------------------------+
//| 파일 초기화                                                      |
//+------------------------------------------------------------------+
bool COptimizationManager::InitializeFiles() {
    // CSV 파일 생성
    csvHandle = FileOpen("UT_Bot_Optimization_Results.csv", FILE_WRITE | FILE_CSV);
    if(csvHandle == INVALID_HANDLE) {
        Print("❌ CSV 파일 생성 실패");
        return false;
    }
    
    // CSV 헤더 작성
    FileWrite(csvHandle, "Symbol", "KeyValue", "ATRPeriod", "IndicatorMode", 
              "TotalReturn", "AnnualReturn", "MaxDrawdown", "SharpeRatio", 
              "TotalTrades", "WinRate", "ProfitFactor", "Volatility");
    
    // 로그 파일 생성
    logHandle = FileOpen("UT_Bot_Optimization.log", FILE_WRITE | FILE_TXT);
    if(logHandle == INVALID_HANDLE) {
        Print("❌ 로그 파일 생성 실패");
        FileClose(csvHandle);
        return false;
    }
    
    FileWrite(logHandle, "=== UT Bot 최적화 시작 ===");
    FileWrite(logHandle, "시작 시간: ", TimeToString(TimeCurrent()));
    FileWrite(logHandle, "총 조합: ", totalCombinations);
    
    return true;
}

//+------------------------------------------------------------------+
//| 파일 정리                                                        |
//+------------------------------------------------------------------+
void COptimizationManager::CloseFiles() {
    if(csvHandle != INVALID_HANDLE) {
        FileWrite(csvHandle, "=== 최적화 완료 ===");
        FileClose(csvHandle);
        csvHandle = INVALID_HANDLE;
    }
    
    if(logHandle != INVALID_HANDLE) {
        FileWrite(logHandle, "=== 최적화 완료 ===");
        FileWrite(logHandle, "완료 시간: ", TimeToString(TimeCurrent()));
        FileWrite(logHandle, "총 결과: ", resultCount);
        FileClose(logHandle);
        logHandle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| 진행 상황 로그                                                   |
//+------------------------------------------------------------------+
void COptimizationManager::LogProgress() {
    string status = GetStatus();
    Print(status);
    
    if(logHandle != INVALID_HANDLE) {
        FileWrite(logHandle, TimeToString(TimeCurrent()), " - ", status);
    }
}

//+------------------------------------------------------------------+
//| 결과 로그                                                        |
//+------------------------------------------------------------------+
void COptimizationManager::LogResult(SBacktestResult &result) {
    // CSV 파일에 기록
    if(csvHandle != INVALID_HANDLE) {
        FileWrite(csvHandle, result.symbol, result.keyValue, result.atrPeriod, 
                  GetIndicatorModeName(result.indicatorMode),
                  result.totalReturn, result.annualReturn, result.maxDrawdown, result.sharpeRatio,
                  result.totalTrades, result.winRate, result.profitFactor, result.volatility);
    }
    
    // 로그 파일에 기록
    if(logHandle != INVALID_HANDLE) {
        FileWrite(logHandle, StringFormat("결과: %s | 키값:%.1f | ATR:%d | 수익률:%.2f%% | 샤프:%.3f", 
                  result.symbol, result.keyValue, result.atrPeriod, 
                  result.totalReturn * 100, result.sharpeRatio));
    }
}

//+------------------------------------------------------------------+
//| 지표 모드 이름 반환                                              |
//+------------------------------------------------------------------+
string COptimizationManager::GetIndicatorModeName(int mode) {
    switch(mode) {
        case 0: return "UT_Bot_Only";
        case 1: return "UT_Bot_ADX";
        case 2: return "UT_Bot_Volume";
        case 3: return "UT_Bot_RSI";
        case 4: return "UT_Bot_Enhanced";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| 최적화 목표 이름 반환                                            |
//+------------------------------------------------------------------+
string COptimizationManager::GetOptimizationTargetName(int target) {
    switch(target) {
        case 0: return "Sharpe_Ratio";
        case 1: return "Total_Return";
        case 2: return "Min_Drawdown";
        default: return "Composite";
    }
}

//+------------------------------------------------------------------+
//| 통계 함수들                                                      |
//+------------------------------------------------------------------+
int COptimizationManager::GetTotalResults() {
    return resultCount;
}

double COptimizationManager::GetAverageReturn() {
    if(resultCount == 0) return 0.0;
    
    double sum = 0.0;
    for(int i = 0; i < resultCount; i++) {
        sum += results[i].totalReturn;
    }
    
    return sum / resultCount;
}

double COptimizationManager::GetAverageSharpeRatio() {
    if(resultCount == 0) return 0.0;
    
    double sum = 0.0;
    for(int i = 0; i < resultCount; i++) {
        sum += results[i].sharpeRatio;
    }
    
    return sum / resultCount;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("✅ UT Bot 최적화 컨트롤러 시작");
    
    // 최적화 관리자 생성 및 기본 설정 로드
    COptimizationManager optimizer;
    if(!optimizer.LoadDefaultConfig()) {
        Print("❌ 기본 설정 로드 실패");
        return INIT_FAILED;
    }
    
    // 최적화 실행
    if(!optimizer.RunOptimization()) {
        Print("❌ 최적화 실행 실패");
        return INIT_FAILED;
    }
    
    // 결과 출력
    SBacktestResult best = optimizer.GetBestResult();
    Print("🏆 최적 결과:");
    Print("   - 심볼: ", best.symbol);
    Print("   - 키값: ", best.keyValue);
    Print("   - ATR 기간: ", best.atrPeriod);
    Print("   - 수익률: ", DoubleToString(best.totalReturn * 100, 2), "%");
    Print("   - 샤프 비율: ", DoubleToString(best.sharpeRatio, 3));
    Print("   - 승률: ", DoubleToString(best.winRate * 100, 2), "%");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("✅ UT Bot 최적화 컨트롤러 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // 최적화는 OnInit에서 실행됨
}
