//+------------------------------------------------------------------+
//|                              BollingerBands_Optimizer.mq5      |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//| 볼린저 밴드 전략 파라미터 최적화 스크립트                          |
//|                                                                  |
//| 기능:                                                            |
//| - 파라미터 조합 자동 생성                                        |
//| - Strategy Tester 자동 실행                                     |
//| - 결과 수집 및 분석                                              |
//| - 최적 파라미터 선정 (수익률 기준)                               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| 최적화 설정 구조체                                                |
//+------------------------------------------------------------------+
struct SOptimizationConfig
{
    // 심볼 설정
    string symbol;                    // 테스트할 심볼
    ENUM_TIMEFRAMES timeframe;         // 시간프레임
    
    // 볼린저 밴드 파라미터 범위
    int longBBLengthMin;              // 롱 길이 최소값
    int longBBLengthMax;               // 롱 길이 최대값
    int longBBLengthStep;              // 롱 길이 단계
    double longBBDevMin;               // 롱 편차 최소값
    double longBBDevMax;               // 롱 편차 최대값
    double longBBDevStep;              // 롱 편차 단계
    
    int shortBBLengthMin;             // 숏 길이 최소값
    int shortBBLengthMax;             // 숏 길이 최대값
    int shortBBLengthStep;            // 숏 길이 단계
    double shortBBDevMin;              // 숏 편차 최소값
    double shortBBDevMax;              // 숏 편차 최대값
    double shortBBDevStep;            // 숏 편차 단계
    
    // 손절/익절 파라미터 범위
    double longTPPercMin;              // 롱 TP % 최소값
    double longTPPercMax;            // 롱 TP % 최대값
    double longTPPercStep;            // 롱 TP % 단계
    double longSLPercMin;             // 롱 SL % 최소값
    double longSLPercMax;             // 롱 SL % 최대값
    double longSLPercStep;            // 롱 SL % 단계
    
    // 백테스트 기간
    datetime startDate;                // 시작 날짜
    datetime endDate;                  // 종료 날짜
    
    // 성능 기준
    int minTrades;                    // 최소 거래 횟수
    double maxDrawdownLimit;          // 최대 낙폭 제한 (%)
};

//+------------------------------------------------------------------+
//| 최적화 결과 구조체                                                |
//+------------------------------------------------------------------+
struct SOptimizationResult
{
    // 파라미터
    int longBBLength;
    double longBBDev;
    int shortBBLength;
    double shortBBDev;
    double longTPPerc;
    double longSLPerc;
    
    // 성과 지표
    double totalReturn;               // 총 수익률 (%)
    int totalTrades;                   // 총 거래 횟수
    int winningTrades;                // 승리 거래 수
    double winRate;                   // 승률 (%)
    double maxDrawdown;               // 최대 낙폭 (%)
    double profitFactor;              // 수익 팩터
    double sharpeRatio;               // 샤프 비율
};

//+------------------------------------------------------------------+
//| 입력 파라미터                                                     |
//+------------------------------------------------------------------+
input group "=== 최적화 기본 설정 ==="
input string OptimSymbol = "EURUSD";              // 테스트 심볼
input ENUM_TIMEFRAMES OptimTimeframe = PERIOD_H1;  // 시간프레임
input datetime OptimStartDate = D'2023.01.01';     // 시작 날짜
input datetime OptimEndDate = D'2024.12.31';       // 종료 날짜

input group "=== 볼린저 밴드 파라미터 범위 ==="
input int LongBBLengthMin = 10;                    // 롱 길이 최소
input int LongBBLengthMax = 30;                    // 롱 길이 최대
input int LongBBLengthStep = 2;                  // 롱 길이 단계
input double LongBBDevMin = 1.5;                   // 롱 편차 최소
input double LongBBDevMax = 3.0;                   // 롱 편차 최대
input double LongBBDevStep = 0.2;                 // 롱 편차 단계

input int ShortBBLengthMin = 10;                  // 숏 길이 최소
input int ShortBBLengthMax = 30;                  // 숏 길이 최대
input int ShortBBLengthStep = 2;                  // 숏 길이 단계
input double ShortBBDevMin = 1.5;                 // 숏 편차 최소
input double ShortBBDevMax = 3.0;                 // 숏 편차 최대
input double ShortBBDevStep = 0.2;                // 숏 편차 단계

input group "=== 손절/익절 파라미터 범위 ==="
input double LongTPPercMin = 1.0;                 // 롱 TP % 최소
input double LongTPPercMax = 5.0;                 // 롱 TP % 최대
input double LongTPPercStep = 0.5;                // 롱 TP % 단계
input double LongSLPercMin = 3.0;                 // 롱 SL % 최소
input double LongSLPercMax = 10.0;                // 롱 SL % 최대
input double LongSLPercStep = 1.0;                // 롱 SL % 단계

input group "=== 성능 기준 ==="
input int MinTrades = 10;                          // 최소 거래 횟수
input double MaxDrawdownLimit = 50.0;              // 최대 낙폭 제한 (%)

input group "=== 최적화 방법 ==="
input bool UseGridSearch = true;                  // 그리드 서치 사용
input int RandomSearchIterations = 1000;           // 랜덤 서치 반복 횟수

//+------------------------------------------------------------------+
//| 전역 변수                                                         |
//+------------------------------------------------------------------+
SOptimizationResult g_results[];                  // 결과 배열
int g_resultCount = 0;                            // 결과 개수
SOptimizationResult g_bestResult;                 // 최적 결과

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("========================================");
    Print("볼린저 밴드 전략 최적화 시작");
    Print("========================================");
    
    // 최적화 설정 구성
    SOptimizationConfig config;
    config.symbol = OptimSymbol;
    config.timeframe = OptimTimeframe;
    config.startDate = OptimStartDate;
    config.endDate = OptimEndDate;
    
    config.longBBLengthMin = LongBBLengthMin;
    config.longBBLengthMax = LongBBLengthMax;
    config.longBBLengthStep = LongBBLengthStep;
    config.longBBDevMin = LongBBDevMin;
    config.longBBDevMax = LongBBDevMax;
    config.longBBDevStep = LongBBDevStep;
    
    config.shortBBLengthMin = ShortBBLengthMin;
    config.shortBBLengthMax = ShortBBLengthMax;
    config.shortBBLengthStep = ShortBBLengthStep;
    config.shortBBDevMin = ShortBBDevMin;
    config.shortBBDevMax = ShortBBDevMax;
    config.shortBBDevStep = ShortBBDevStep;
    
    config.longTPPercMin = LongTPPercMin;
    config.longTPPercMax = LongTPPercMax;
    config.longTPPercStep = LongTPPercStep;
    config.longSLPercMin = LongSLPercMin;
    config.longSLPercMax = LongSLPercMax;
    config.longSLPercStep = LongSLPercStep;
    
    config.minTrades = MinTrades;
    config.maxDrawdownLimit = MaxDrawdownLimit;
    
    // 최적화 실행
    if(UseGridSearch)
        RunGridSearch(config);
    else
        RunRandomSearch(config, RandomSearchIterations);
    
    // 결과 분석 및 출력
    AnalyzeResults();
    
    // 결과 저장
    SaveResults();
    
    Print("========================================");
    Print("최적화 완료!");
    Print("========================================");
}

//+------------------------------------------------------------------+
//| 그리드 서치 실행                                                  |
//+------------------------------------------------------------------+
void RunGridSearch(SOptimizationConfig &config)
{
    Print("그리드 서치 시작...");
    
    // 파라미터 조합 생성
    int totalCombinations = CalculateTotalCombinations(config);
    Print("총 조합 수: ", totalCombinations);
    
    int currentCombination = 0;
    
    // 롱 길이 루프
    for(int longLen = config.longBBLengthMin; longLen <= config.longBBLengthMax; longLen += config.longBBLengthStep)
    {
        // 롱 편차 루프
        for(double longDev = config.longBBDevMin; longDev <= config.longBBDevMax; longDev += config.longBBDevStep)
        {
            // 숏 길이 루프
            for(int shortLen = config.shortBBLengthMin; shortLen <= config.shortBBLengthMax; shortLen += config.shortBBLengthStep)
            {
                // 숏 편차 루프
                for(double shortDev = config.shortBBDevMin; shortDev <= config.shortBBDevMax; shortDev += config.shortBBDevStep)
                {
                    // 롱 TP % 루프
                    for(double longTP = config.longTPPercMin; longTP <= config.longTPPercMax; longTP += config.longTPPercStep)
                    {
                        // 롱 SL % 루프
                        for(double longSL = config.longSLPercMin; longSL <= config.longSLPercMax; longSL += config.longSLPercStep)
                        {
                            currentCombination++;
                            
                            // 진행률 출력
                            if(currentCombination % 100 == 0)
                            {
                                double progress = (double)currentCombination / totalCombinations * 100.0;
                                Print("진행률: ", DoubleToString(progress, 2), "% (", currentCombination, "/", totalCombinations, ")");
                            }
                            
                            // 백테스트 실행
                            SOptimizationResult result;
                            result.longBBLength = longLen;
                            result.longBBDev = longDev;
                            result.shortBBLength = shortLen;
                            result.shortBBDev = shortDev;
                            result.longTPPerc = longTP;
                            result.longSLPerc = longSL;
                            
                            if(RunBacktest(config, result))
                            {
                                // 결과 유효성 검사
                                if(IsValidResult(result, config))
                                {
                                    ArrayResize(g_results, g_resultCount + 1);
                                    g_results[g_resultCount] = result;
                                    g_resultCount++;
                                    
                                    // 최적 결과 업데이트
                                    if(g_resultCount == 1 || result.totalReturn > g_bestResult.totalReturn)
                                        g_bestResult = result;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    Print("그리드 서치 완료. 총 ", g_resultCount, "개의 유효한 결과 발견");
}

//+------------------------------------------------------------------+
//| 랜덤 서치 실행                                                    |
//+------------------------------------------------------------------+
void RunRandomSearch(SOptimizationConfig &config, int iterations)
{
    Print("랜덤 서치 시작... (", iterations, "회 반복)");
    
    MathSrand(GetTickCount()); // 랜덤 시드 설정
    
    for(int i = 0; i < iterations; i++)
    {
        if(i % 100 == 0)
        {
            double progress = (double)i / iterations * 100.0;
            Print("진행률: ", DoubleToString(progress, 2), "% (", i, "/", iterations, ")");
        }
        
        // 랜덤 파라미터 생성
        SOptimizationResult result;
        result.longBBLength = (int)(config.longBBLengthMin + 
                                    (config.longBBLengthMax - config.longBBLengthMin) * 
                                    (double)MathRand() / 32767.0);
        result.longBBLength = (result.longBBLength / config.longBBLengthStep) * config.longBBLengthStep;
        
        result.longBBDev = config.longBBDevMin + 
                          (config.longBBDevMax - config.longBBDevMin) * 
                          (double)MathRand() / 32767.0;
        result.longBBDev = ((int)(result.longBBDev / config.longBBDevStep)) * config.longBBDevStep;
        
        result.shortBBLength = (int)(config.shortBBLengthMin + 
                                    (config.shortBBLengthMax - config.shortBBLengthMin) * 
                                    (double)MathRand() / 32767.0);
        result.shortBBLength = (result.shortBBLength / config.shortBBLengthStep) * config.shortBBLengthStep;
        
        result.shortBBDev = config.shortBBDevMin + 
                          (config.shortBBDevMax - config.shortBBDevMin) * 
                          (double)MathRand() / 32767.0;
        result.shortBBDev = ((int)(result.shortBBDev / config.shortBBDevStep)) * config.shortBBDevStep;
        
        result.longTPPerc = config.longTPPercMin + 
                           (config.longTPPercMax - config.longTPPercMin) * 
                           (double)MathRand() / 32767.0;
        result.longTPPerc = ((int)(result.longTPPerc / config.longTPPercStep)) * config.longTPPercStep;
        
        result.longSLPerc = config.longSLPercMin + 
                           (config.longSLPercMax - config.longSLPercMin) * 
                           (double)MathRand() / 32767.0;
        result.longSLPerc = ((int)(result.longSLPerc / config.longSLPercStep)) * config.longSLPercStep;
        
        // 백테스트 실행
        if(RunBacktest(config, result))
        {
            if(IsValidResult(result, config))
            {
                ArrayResize(g_results, g_resultCount + 1);
                g_results[g_resultCount] = result;
                g_resultCount++;
                
                if(g_resultCount == 1 || result.totalReturn > g_bestResult.totalReturn)
                    g_bestResult = result;
            }
        }
    }
    
    Print("랜덤 서치 완료. 총 ", g_resultCount, "개의 유효한 결과 발견");
}

//+------------------------------------------------------------------+
//| 총 조합 수 계산                                                   |
//+------------------------------------------------------------------+
int CalculateTotalCombinations(SOptimizationConfig &config)
{
    int longLenCount = (config.longBBLengthMax - config.longBBLengthMin) / config.longBBLengthStep + 1;
    int longDevCount = (int)((config.longBBDevMax - config.longBBDevMin) / config.longBBDevStep) + 1;
    int shortLenCount = (config.shortBBLengthMax - config.shortBBLengthMin) / config.shortBBLengthStep + 1;
    int shortDevCount = (int)((config.shortBBDevMax - config.shortBBDevMin) / config.shortBBDevStep) + 1;
    int longTPCount = (int)((config.longTPPercMax - config.longTPPercMin) / config.longTPPercStep) + 1;
    int longSLCount = (int)((config.longSLPercMax - config.longSLPercMin) / config.longSLPercStep) + 1;
    
    return longLenCount * longDevCount * shortLenCount * shortDevCount * longTPCount * longSLCount;
}

//+------------------------------------------------------------------+
//| 백테스트 실행                                                     |
//+------------------------------------------------------------------+
bool RunBacktest(SOptimizationConfig &config, SOptimizationResult &result)
{
    // Strategy Tester를 통한 백테스트 실행
    // 실제 구현 시 MT5 Strategy Tester API 사용
    
    // 여기서는 시뮬레이션 (실제 구현 필요)
    // 실제로는 Strategy Tester를 자동으로 실행하고 결과를 가져와야 함
    
    // 임시로 랜덤 값 생성 (실제 구현 시 제거)
    result.totalReturn = (double)MathRand() / 32767.0 * 100.0 - 50.0;
    result.totalTrades = (int)(MathRand() / 32767.0 * 100);
    result.winningTrades = (int)(result.totalTrades * 0.5);
    result.winRate = result.totalTrades > 0 ? (double)result.winningTrades / result.totalTrades * 100.0 : 0.0;
    result.maxDrawdown = (double)MathRand() / 32767.0 * 30.0;
    result.profitFactor = (double)MathRand() / 32767.0 * 2.0;
    result.sharpeRatio = (double)MathRand() / 32767.0 * 3.0;
    
    return true;
}

//+------------------------------------------------------------------+
//| 결과 유효성 검사                                                   |
//+------------------------------------------------------------------+
bool IsValidResult(SOptimizationResult &result, SOptimizationConfig &config)
{
    if(result.totalTrades < config.minTrades)
        return false;
    
    if(result.maxDrawdown > config.maxDrawdownLimit)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| 결과 분석                                                         |
//+------------------------------------------------------------------+
void AnalyzeResults()
{
    if(g_resultCount == 0)
    {
        Print("분석할 결과가 없습니다.");
        return;
    }
    
    Print("========================================");
    Print("최적화 결과 분석");
    Print("========================================");
    Print("총 유효한 결과: ", g_resultCount);
    Print("");
    Print("=== 최적 파라미터 (수익률 기준) ===");
    Print("롱 길이: ", g_bestResult.longBBLength);
    Print("롱 편차: ", DoubleToString(g_bestResult.longBBDev, 2));
    Print("숏 길이: ", g_bestResult.shortBBLength);
    Print("숏 편차: ", DoubleToString(g_bestResult.shortBBDev, 2));
    Print("롱 TP %: ", DoubleToString(g_bestResult.longTPPerc, 2));
    Print("롱 SL %: ", DoubleToString(g_bestResult.longSLPerc, 2));
    Print("");
    Print("=== 성과 지표 ===");
    Print("총 수익률: ", DoubleToString(g_bestResult.totalReturn, 2), "%");
    Print("총 거래 횟수: ", g_bestResult.totalTrades);
    Print("승률: ", DoubleToString(g_bestResult.winRate, 2), "%");
    Print("최대 낙폭: ", DoubleToString(g_bestResult.maxDrawdown, 2), "%");
    Print("수익 팩터: ", DoubleToString(g_bestResult.profitFactor, 2));
    Print("샤프 비율: ", DoubleToString(g_bestResult.sharpeRatio, 2));
    Print("========================================");
}

//+------------------------------------------------------------------+
//| 결과 저장                                                         |
//+------------------------------------------------------------------+
void SaveResults()
{
    string filename = "optimization_results_" + OptimSymbol + "_" + 
                     TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ".csv";
    filename = StringReplace(filename, ":", "_");
    filename = StringReplace(filename, ".", "_");
    filename = StringReplace(filename, " ", "_");
    
    int fileHandle = FileOpen(filename, FILE_WRITE|FILE_CSV);
    if(fileHandle == INVALID_HANDLE)
    {
        Print("파일 저장 실패: ", filename);
        return;
    }
    
    // 헤더 작성
    FileWrite(fileHandle, "LongBBLength", "LongBBDev", "ShortBBLength", "ShortBBDev",
              "LongTPPerc", "LongSLPerc", "TotalReturn", "TotalTrades", 
              "WinRate", "MaxDrawdown", "ProfitFactor", "SharpeRatio");
    
    // 결과 작성
    for(int i = 0; i < g_resultCount; i++)
    {
        FileWrite(fileHandle,
                  g_results[i].longBBLength,
                  DoubleToString(g_results[i].longBBDev, 2),
                  g_results[i].shortBBLength,
                  DoubleToString(g_results[i].shortBBDev, 2),
                  DoubleToString(g_results[i].longTPPerc, 2),
                  DoubleToString(g_results[i].longSLPerc, 2),
                  DoubleToString(g_results[i].totalReturn, 2),
                  g_results[i].totalTrades,
                  DoubleToString(g_results[i].winRate, 2),
                  DoubleToString(g_results[i].maxDrawdown, 2),
                  DoubleToString(g_results[i].profitFactor, 2),
                  DoubleToString(g_results[i].sharpeRatio, 2));
    }
    
    FileClose(fileHandle);
    Print("결과 저장 완료: ", filename);
}

