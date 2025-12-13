//+------------------------------------------------------------------+
//|                                        ResultAnalyzer.mq5       |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//| 결과 분석기 - 백테스트 결과를 분석하여 최적 파라미터 선정            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| 결과 분석 구조체                                                  |
//+------------------------------------------------------------------+
struct SResultAnalysis
{
    double bestTotalReturn;           // 최고 수익률
    double bestWinRate;               // 최고 승률
    double bestSharpeRatio;           // 최고 샤프 비율
    double bestProfitFactor;          // 최고 수익 팩터
    double avgTotalReturn;            // 평균 수익률
    double avgWinRate;                // 평균 승률
    int totalValidResults;            // 유효한 결과 수
    int totalInvalidResults;          // 무효한 결과 수
};

//+------------------------------------------------------------------+
//| 결과 분석 함수                                                    |
//+------------------------------------------------------------------+
SResultAnalysis AnalyzeResults(SOptimizationResult &results[], int count)
{
    SResultAnalysis analysis;
    ZeroMemory(analysis);
    
    if(count == 0)
        return analysis;
    
    double totalReturnSum = 0.0;
    double winRateSum = 0.0;
    double sharpeSum = 0.0;
    double profitFactorSum = 0.0;
    int validCount = 0;
    
    for(int i = 0; i < count; i++)
    {
        if(results[i].totalTrades >= 10) // 최소 거래 횟수 체크
        {
            validCount++;
            
            totalReturnSum += results[i].totalReturn;
            winRateSum += results[i].winRate;
            sharpeSum += results[i].sharpeRatio;
            profitFactorSum += results[i].profitFactor;
            
            // 최고값 업데이트
            if(i == 0 || results[i].totalReturn > analysis.bestTotalReturn)
                analysis.bestTotalReturn = results[i].totalReturn;
            
            if(i == 0 || results[i].winRate > analysis.bestWinRate)
                analysis.bestWinRate = results[i].winRate;
            
            if(i == 0 || results[i].sharpeRatio > analysis.bestSharpeRatio)
                analysis.bestSharpeRatio = results[i].sharpeRatio;
            
            if(i == 0 || results[i].profitFactor > analysis.bestProfitFactor)
                analysis.bestProfitFactor = results[i].profitFactor;
        }
        else
        {
            analysis.totalInvalidResults++;
        }
    }
    
    analysis.totalValidResults = validCount;
    
    if(validCount > 0)
    {
        analysis.avgTotalReturn = totalReturnSum / validCount;
        analysis.avgWinRate = winRateSum / validCount;
        analysis.avgSharpeRatio = sharpeSum / validCount;
        analysis.avgProfitFactor = profitFactorSum / validCount;
    }
    
    return analysis;
}

//+------------------------------------------------------------------+
//| 최적 파라미터 선정 (수익률 기준)                                  |
//+------------------------------------------------------------------+
SOptimizationResult SelectBestByReturn(SOptimizationResult &results[], int count)
{
    SOptimizationResult best;
    ZeroMemory(best);
    
    if(count == 0)
        return best;
    
    best = results[0];
    
    for(int i = 1; i < count; i++)
    {
        if(results[i].totalReturn > best.totalReturn)
            best = results[i];
    }
    
    return best;
}

//+------------------------------------------------------------------+
//| 최적 파라미터 선정 (승률 기준)                                    |
//+------------------------------------------------------------------+
SOptimizationResult SelectBestByWinRate(SOptimizationResult &results[], int count)
{
    SOptimizationResult best;
    ZeroMemory(best);
    
    if(count == 0)
        return best;
    
    best = results[0];
    
    for(int i = 1; i < count; i++)
    {
        if(results[i].winRate > best.winRate)
            best = results[i];
    }
    
    return best;
}

//+------------------------------------------------------------------+
//| 최적 파라미터 선정 (샤프 비율 기준)                                |
//+------------------------------------------------------------------+
SOptimizationResult SelectBestBySharpe(SOptimizationResult &results[], int count)
{
    SOptimizationResult best;
    ZeroMemory(best);
    
    if(count == 0)
        return best;
    
    best = results[0];
    
    for(int i = 1; i < count; i++)
    {
        if(results[i].sharpeRatio > best.sharpeRatio)
            best = results[i];
    }
    
    return best;
}

//+------------------------------------------------------------------+
//| 복합 점수 계산 (수익률 + 승률 + 샤프 비율)                         |
//+------------------------------------------------------------------+
double CalculateCompositeScore(SOptimizationResult &result)
{
    // 정규화된 점수 계산
    double returnScore = result.totalReturn / 100.0;  // 수익률을 0-1 범위로
    double winRateScore = result.winRate / 100.0;     // 승률을 0-1 범위로
    double sharpeScore = result.sharpeRatio / 3.0;    // 샤프 비율을 0-1 범위로 (3을 최대값으로 가정)
    
    // 가중 평균 (수익률 50%, 승률 30%, 샤프 비율 20%)
    return returnScore * 0.5 + winRateScore * 0.3 + sharpeScore * 0.2;
}

//+------------------------------------------------------------------+
//| 최적 파라미터 선정 (복합 점수 기준)                                |
//+------------------------------------------------------------------+
SOptimizationResult SelectBestByComposite(SOptimizationResult &results[], int count)
{
    SOptimizationResult best;
    ZeroMemory(best);
    
    if(count == 0)
        return best;
    
    best = results[0];
    double bestScore = CalculateCompositeScore(best);
    
    for(int i = 1; i < count; i++)
    {
        double score = CalculateCompositeScore(results[i]);
        if(score > bestScore)
        {
            best = results[i];
            bestScore = score;
        }
    }
    
    return best;
}

