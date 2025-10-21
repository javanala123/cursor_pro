//+------------------------------------------------------------------+
//|                                UT_Bot_Performance_Analyzer.mq5 |
//|                        Copyright 2024, MetaTrader Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaTrader Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "UT Bot 성능 분석기 - 통계적 성능 지표 계산 및 결과 분석"

#include "UT_Bot_Auto_Backtest_Engine.mq5"

//+------------------------------------------------------------------+
//| 성능 분석 결과 구조체                                             |
//+------------------------------------------------------------------+
struct SPerformanceAnalysis {
    // 기본 통계
    int totalResults;           // 총 결과 수
    double averageReturn;       // 평균 수익률
    double medianReturn;        // 중간값 수익률
    double stdDevReturn;        // 수익률 표준편차
    double minReturn;           // 최소 수익률
    double maxReturn;           // 최대 수익률
    
    // 위험 지표
    double averageDrawdown;     // 평균 최대손실
    double maxDrawdown;         // 전체 최대 손실
    double averageVolatility;   // 평균 변동성
    double var95;               // 95% VaR
    double expectedShortfall;   // 기대 부족분
    
    // 효율성 지표
    double averageSharpeRatio;  // 평균 샤프 비율
    double medianSharpeRatio;   // 중간값 샤프 비율
    double maxSharpeRatio;      // 최대 샤프 비율
    double averageSortinoRatio; // 평균 소르티노 비율
    double averageCalmarRatio;  // 평균 칼마 비율
    
    // 거래 지표
    double averageWinRate;      // 평균 승률
    double averageProfitFactor; // 평균 수익 팩터
    int averageTrades;          // 평균 거래 횟수
    
    // 심볼별 분석
    string bestSymbol;          // 최고 성과 심볼
    string worstSymbol;         // 최저 성과 심볼
    double symbolReturns[10];   // 심볼별 평균 수익률
    int symbolCounts[10];       // 심볼별 결과 수
    
    // 키값별 분석
    double keyValueReturns[50]; // 키값별 평균 수익률
    int keyValueCounts[50];     // 키값별 결과 수
    double bestKeyValue;        // 최적 키값
    double worstKeyValue;       // 최악 키값
    
    // ATR 기간별 분석
    double atrPeriodReturns[20]; // ATR 기간별 평균 수익률
    int atrPeriodCounts[20];     // ATR 기간별 결과 수
    int bestATRPeriod;           // 최적 ATR 기간
    int worstATRPeriod;          // 최악 ATR 기간
    
    // 지표 모드별 분석
    double indicatorModeReturns[5]; // 지표 모드별 평균 수익률
    int indicatorModeCounts[5];     // 지표 모드별 결과 수
    int bestIndicatorMode;          // 최적 지표 모드
    int worstIndicatorMode;         // 최악 지표 모드
    
    // 상관관계 분석
    double keyValueATRCorrelation;  // 키값-ATR 상관관계
    double returnVolatilityCorrelation; // 수익률-변동성 상관관계
    double sharpeWinRateCorrelation;    // 샤프비율-승률 상관관계
};

//+------------------------------------------------------------------+
//| 성능 분석기 클래스                                               |
//+------------------------------------------------------------------+
class CPerformanceAnalyzer {
private:
    SBacktestResult results[];
    int resultCount;
    SPerformanceAnalysis analysis;
    
    // 통계 계산용 임시 배열
    double tempReturns[];
    double tempSharpeRatios[];
    double tempDrawdowns[];
    double tempVolatilities[];
    
public:
    // 생성자
    CPerformanceAnalyzer();
    
    // 소멸자
    ~CPerformanceAnalyzer();
    
    // 데이터 로드
    bool LoadResults(SBacktestResult &results[], int count);
    bool LoadResultsFromCSV(string filename);
    
    // 분석 실행
    bool RunAnalysis();
    bool RunDetailedAnalysis();
    
    // 결과 반환
    SPerformanceAnalysis GetAnalysis();
    
    // 특정 분석
    bool AnalyzeBySymbol();
    bool AnalyzeByKeyValue();
    bool AnalyzeByATRPeriod();
    bool AnalyzeByIndicatorMode();
    bool AnalyzeCorrelations();
    
    // 통계 함수
    double CalculateMean(double &data[], int count);
    double CalculateMedian(double &data[], int count);
    double CalculateStdDev(double &data[], int count, double mean);
    double CalculateCorrelation(double &x[], double &y[], int count);
    double CalculatePercentile(double &data[], int count, double percentile);
    
    // 결과 출력
    void PrintAnalysis();
    void PrintSymbolAnalysis();
    void PrintKeyValueAnalysis();
    void PrintATRPeriodAnalysis();
    void PrintIndicatorModeAnalysis();
    void PrintCorrelationAnalysis();
    
    // 파일 저장
    bool SaveAnalysisToFile(string filename);
    bool SaveDetailedReport(string filename);
    
private:
    // 내부 함수들
    void SortArray(double &data[], int count);
    void InitializeAnalysis();
    void CalculateBasicStatistics();
    void CalculateRiskMetrics();
    void CalculateEfficiencyMetrics();
    void CalculateTradingMetrics();
    string GetSymbolName(int index);
    string GetIndicatorModeName(int mode);
};

//+------------------------------------------------------------------+
//| 생성자                                                           |
//+------------------------------------------------------------------+
CPerformanceAnalyzer::CPerformanceAnalyzer() {
    resultCount = 0;
    ArrayResize(results, 10000);
    ZeroMemory(analysis);
    
    // 임시 배열 초기화
    ArrayResize(tempReturns, 10000);
    ArrayResize(tempSharpeRatios, 10000);
    ArrayResize(tempDrawdowns, 10000);
    ArrayResize(tempVolatilities, 10000);
}

//+------------------------------------------------------------------+
//| 소멸자                                                           |
//+------------------------------------------------------------------+
CPerformanceAnalyzer::~CPerformanceAnalyzer() {
    // 동적 배열 정리
    ArrayFree(results);
    ArrayFree(tempReturns);
    ArrayFree(tempSharpeRatios);
    ArrayFree(tempDrawdowns);
    ArrayFree(tempVolatilities);
}

//+------------------------------------------------------------------+
//| 결과 로드                                                        |
//+------------------------------------------------------------------+
bool CPerformanceAnalyzer::LoadResults(SBacktestResult &inputResults[], int count) {
    if(count <= 0 || count > 10000) {
        Print("❌ 잘못된 결과 개수: ", count);
        return false;
    }
    
    resultCount = count;
    
    // 결과 복사
    for(int i = 0; i < count; i++) {
        results[i] = inputResults[i];
    }
    
    Print("✅ ", count, "개 결과 로드 완료");
    return true;
}

//+------------------------------------------------------------------+
//| CSV에서 결과 로드                                                |
//+------------------------------------------------------------------+
bool CPerformanceAnalyzer::LoadResultsFromCSV(string filename) {
    int handle = FileOpen(filename, FILE_READ | FILE_CSV);
    if(handle == INVALID_HANDLE) {
        Print("❌ CSV 파일 열기 실패: ", filename);
        return false;
    }
    
    resultCount = 0;
    
    // 헤더 건너뛰기
    FileReadString(handle);
    
    // 데이터 읽기
    while(!FileIsEnding(handle) && resultCount < 10000) {
        string line = FileReadString(handle);
        if(line == "") break;
        
        // CSV 파싱 (간단한 구현)
        string parts[];
        StringSplit(line, ',', parts);
        
        if(ArraySize(parts) >= 12) {
            results[resultCount].symbol = parts[0];
            results[resultCount].keyValue = StringToDouble(parts[1]);
            results[resultCount].atrPeriod = (int)StringToInteger(parts[2]);
            results[resultCount].totalReturn = StringToDouble(parts[4]);
            results[resultCount].annualReturn = StringToDouble(parts[5]);
            results[resultCount].maxDrawdown = StringToDouble(parts[6]);
            results[resultCount].sharpeRatio = StringToDouble(parts[7]);
            results[resultCount].totalTrades = (int)StringToInteger(parts[8]);
            results[resultCount].winRate = StringToDouble(parts[9]);
            results[resultCount].profitFactor = StringToDouble(parts[10]);
            results[resultCount].volatility = StringToDouble(parts[11]);
            
            resultCount++;
        }
    }
    
    FileClose(handle);
    Print("✅ CSV에서 ", resultCount, "개 결과 로드 완료");
    return true;
}

//+------------------------------------------------------------------+
//| 분석 실행                                                        |
//+------------------------------------------------------------------+
bool CPerformanceAnalyzer::RunAnalysis() {
    if(resultCount == 0) {
        Print("❌ 분석할 결과가 없습니다");
        return false;
    }
    
    Print("📊 성능 분석 시작 - ", resultCount, "개 결과");
    
    // 분석 초기화
    InitializeAnalysis();
    
    // 기본 통계 계산
    CalculateBasicStatistics();
    
    // 위험 지표 계산
    CalculateRiskMetrics();
    
    // 효율성 지표 계산
    CalculateEfficiencyMetrics();
    
    // 거래 지표 계산
    CalculateTradingMetrics();
    
    // 상세 분석
    AnalyzeBySymbol();
    AnalyzeByKeyValue();
    AnalyzeByATRPeriod();
    AnalyzeByIndicatorMode();
    AnalyzeCorrelations();
    
    Print("✅ 성능 분석 완료");
    return true;
}

//+------------------------------------------------------------------+
//| 분석 초기화                                                      |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::InitializeAnalysis() {
    ZeroMemory(analysis);
    analysis.totalResults = resultCount;
    
    // 배열 초기화
    for(int i = 0; i < 10; i++) {
        analysis.symbolReturns[i] = 0.0;
        analysis.symbolCounts[i] = 0;
    }
    
    for(int i = 0; i < 50; i++) {
        analysis.keyValueReturns[i] = 0.0;
        analysis.keyValueCounts[i] = 0;
    }
    
    for(int i = 0; i < 20; i++) {
        analysis.atrPeriodReturns[i] = 0.0;
        analysis.atrPeriodCounts[i] = 0;
    }
    
    for(int i = 0; i < 5; i++) {
        analysis.indicatorModeReturns[i] = 0.0;
        analysis.indicatorModeCounts[i] = 0;
    }
}

//+------------------------------------------------------------------+
//| 기본 통계 계산                                                   |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::CalculateBasicStatistics() {
    // 수익률 배열 생성
    for(int i = 0; i < resultCount; i++) {
        tempReturns[i] = results[i].totalReturn;
    }
    
    // 기본 통계 계산
    analysis.averageReturn = CalculateMean(tempReturns, resultCount);
    analysis.medianReturn = CalculateMedian(tempReturns, resultCount);
    analysis.stdDevReturn = CalculateStdDev(tempReturns, resultCount, analysis.averageReturn);
    
    // 최소/최대 수익률
    analysis.minReturn = tempReturns[0];
    analysis.maxReturn = tempReturns[0];
    for(int i = 1; i < resultCount; i++) {
        if(tempReturns[i] < analysis.minReturn) analysis.minReturn = tempReturns[i];
        if(tempReturns[i] > analysis.maxReturn) analysis.maxReturn = tempReturns[i];
    }
}

//+------------------------------------------------------------------+
//| 위험 지표 계산                                                   |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::CalculateRiskMetrics() {
    // 최대손실 배열 생성
    for(int i = 0; i < resultCount; i++) {
        tempDrawdowns[i] = results[i].maxDrawdown;
    }
    
    analysis.averageDrawdown = CalculateMean(tempDrawdowns, resultCount);
    analysis.maxDrawdown = tempDrawdowns[0];
    for(int i = 1; i < resultCount; i++) {
        if(tempDrawdowns[i] < analysis.maxDrawdown) analysis.maxDrawdown = tempDrawdowns[i];
    }
    
    // 변동성 배열 생성
    for(int i = 0; i < resultCount; i++) {
        tempVolatilities[i] = results[i].volatility;
    }
    
    analysis.averageVolatility = CalculateMean(tempVolatilities, resultCount);
    
    // VaR 95% 계산
    analysis.var95 = CalculatePercentile(tempReturns, resultCount, 0.05);
    
    // 기대 부족분 계산
    double sum = 0.0;
    int count = 0;
    for(int i = 0; i < resultCount; i++) {
        if(tempReturns[i] <= analysis.var95) {
            sum += tempReturns[i];
            count++;
        }
    }
    analysis.expectedShortfall = count > 0 ? sum / count : 0.0;
}

//+------------------------------------------------------------------+
//| 효율성 지표 계산                                                 |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::CalculateEfficiencyMetrics() {
    // 샤프 비율 배열 생성
    for(int i = 0; i < resultCount; i++) {
        tempSharpeRatios[i] = results[i].sharpeRatio;
    }
    
    analysis.averageSharpeRatio = CalculateMean(tempSharpeRatios, resultCount);
    analysis.medianSharpeRatio = CalculateMedian(tempSharpeRatios, resultCount);
    analysis.maxSharpeRatio = tempSharpeRatios[0];
    for(int i = 1; i < resultCount; i++) {
        if(tempSharpeRatios[i] > analysis.maxSharpeRatio) analysis.maxSharpeRatio = tempSharpeRatios[i];
    }
    
    // 소르티노 비율과 칼마 비율 평균 계산
    double sortinoSum = 0.0, calmarSum = 0.0;
    for(int i = 0; i < resultCount; i++) {
        sortinoSum += results[i].sortinoRatio;
        calmarSum += results[i].calmarRatio;
    }
    analysis.averageSortinoRatio = sortinoSum / resultCount;
    analysis.averageCalmarRatio = calmarSum / resultCount;
}

//+------------------------------------------------------------------+
//| 거래 지표 계산                                                   |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::CalculateTradingMetrics() {
    double winRateSum = 0.0, profitFactorSum = 0.0;
    int totalTradesSum = 0;
    
    for(int i = 0; i < resultCount; i++) {
        winRateSum += results[i].winRate;
        profitFactorSum += results[i].profitFactor;
        totalTradesSum += results[i].totalTrades;
    }
    
    analysis.averageWinRate = winRateSum / resultCount;
    analysis.averageProfitFactor = profitFactorSum / resultCount;
    analysis.averageTrades = totalTradesSum / resultCount;
}

//+------------------------------------------------------------------+
//| 심볼별 분석                                                      |
//+------------------------------------------------------------------+
bool CPerformanceAnalyzer::AnalyzeBySymbol() {
    string symbols[10] = {"XAUUSD", "EURUSD", "GBPUSD", "USDJPY", "NASDAQ", "GBPJPY", "EURJPY", "AUDUSD", "USDCAD", "NZDUSD"};
    
    for(int s = 0; s < 10; s++) {
        double sum = 0.0;
        int count = 0;
        
        for(int i = 0; i < resultCount; i++) {
            if(results[i].symbol == symbols[s]) {
                sum += results[i].totalReturn;
                count++;
            }
        }
        
        if(count > 0) {
            analysis.symbolReturns[s] = sum / count;
            analysis.symbolCounts[s] = count;
        }
    }
    
    // 최고/최저 성과 심볼 찾기
    double bestReturn = -999999.0, worstReturn = 999999.0;
    for(int s = 0; s < 10; s++) {
        if(analysis.symbolCounts[s] > 0) {
            if(analysis.symbolReturns[s] > bestReturn) {
                bestReturn = analysis.symbolReturns[s];
                analysis.bestSymbol = symbols[s];
            }
            if(analysis.symbolReturns[s] < worstReturn) {
                worstReturn = analysis.symbolReturns[s];
                analysis.worstSymbol = symbols[s];
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 키값별 분석                                                      |
//+------------------------------------------------------------------+
bool CPerformanceAnalyzer::AnalyzeByKeyValue() {
    for(int i = 0; i < resultCount; i++) {
        int index = (int)((results[i].keyValue - 0.5) / 0.1); // 0.5부터 0.1 단위
        if(index >= 0 && index < 50) {
            analysis.keyValueReturns[index] += results[i].totalReturn;
            analysis.keyValueCounts[index]++;
        }
    }
    
    // 평균 계산
    for(int i = 0; i < 50; i++) {
        if(analysis.keyValueCounts[i] > 0) {
            analysis.keyValueReturns[i] /= analysis.keyValueCounts[i];
        }
    }
    
    // 최고/최저 키값 찾기
    double bestReturn = -999999.0, worstReturn = 999999.0;
    for(int i = 0; i < 50; i++) {
        if(analysis.keyValueCounts[i] > 0) {
            if(analysis.keyValueReturns[i] > bestReturn) {
                bestReturn = analysis.keyValueReturns[i];
                analysis.bestKeyValue = 0.5 + i * 0.1;
            }
            if(analysis.keyValueReturns[i] < worstReturn) {
                worstReturn = analysis.keyValueReturns[i];
                analysis.worstKeyValue = 0.5 + i * 0.1;
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| ATR 기간별 분석                                                  |
//+------------------------------------------------------------------+
bool CPerformanceAnalyzer::AnalyzeByATRPeriod() {
    for(int i = 0; i < resultCount; i++) {
        int index = (results[i].atrPeriod - 10) / 5; // 10부터 5 단위
        if(index >= 0 && index < 20) {
            analysis.atrPeriodReturns[index] += results[i].totalReturn;
            analysis.atrPeriodCounts[index]++;
        }
    }
    
    // 평균 계산
    for(int i = 0; i < 20; i++) {
        if(analysis.atrPeriodCounts[i] > 0) {
            analysis.atrPeriodReturns[i] /= analysis.atrPeriodCounts[i];
        }
    }
    
    // 최고/최저 ATR 기간 찾기
    double bestReturn = -999999.0, worstReturn = 999999.0;
    for(int i = 0; i < 20; i++) {
        if(analysis.atrPeriodCounts[i] > 0) {
            if(analysis.atrPeriodReturns[i] > bestReturn) {
                bestReturn = analysis.atrPeriodReturns[i];
                analysis.bestATRPeriod = 10 + i * 5;
            }
            if(analysis.atrPeriodReturns[i] < worstReturn) {
                worstReturn = analysis.atrPeriodReturns[i];
                analysis.worstATRPeriod = 10 + i * 5;
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 지표 모드별 분석                                                 |
//+------------------------------------------------------------------+
bool CPerformanceAnalyzer::AnalyzeByIndicatorMode() {
    for(int i = 0; i < resultCount; i++) {
        if(results[i].indicatorMode >= 0 && results[i].indicatorMode < 5) {
            analysis.indicatorModeReturns[results[i].indicatorMode] += results[i].totalReturn;
            analysis.indicatorModeCounts[results[i].indicatorMode]++;
        }
    }
    
    // 평균 계산
    for(int i = 0; i < 5; i++) {
        if(analysis.indicatorModeCounts[i] > 0) {
            analysis.indicatorModeReturns[i] /= analysis.indicatorModeCounts[i];
        }
    }
    
    // 최고/최저 지표 모드 찾기
    double bestReturn = -999999.0, worstReturn = 999999.0;
    for(int i = 0; i < 5; i++) {
        if(analysis.indicatorModeCounts[i] > 0) {
            if(analysis.indicatorModeReturns[i] > bestReturn) {
                bestReturn = analysis.indicatorModeReturns[i];
                analysis.bestIndicatorMode = i;
            }
            if(analysis.indicatorModeReturns[i] < worstReturn) {
                worstReturn = analysis.indicatorModeReturns[i];
                analysis.worstIndicatorMode = i;
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| 상관관계 분석                                                    |
//+------------------------------------------------------------------+
bool CPerformanceAnalyzer::AnalyzeCorrelations() {
    // 키값-ATR 상관관계
    double keyValues[], atrPeriods[];
    ArrayResize(keyValues, resultCount);
    ArrayResize(atrPeriods, resultCount);
    
    for(int i = 0; i < resultCount; i++) {
        keyValues[i] = results[i].keyValue;
        atrPeriods[i] = (double)results[i].atrPeriod;
    }
    
    analysis.keyValueATRCorrelation = CalculateCorrelation(keyValues, atrPeriods, resultCount);
    
    // 수익률-변동성 상관관계
    analysis.returnVolatilityCorrelation = CalculateCorrelation(tempReturns, tempVolatilities, resultCount);
    
    // 샤프비율-승률 상관관계
    double winRates[];
    ArrayResize(winRates, resultCount);
    for(int i = 0; i < resultCount; i++) {
        winRates[i] = results[i].winRate;
    }
    
    analysis.sharpeWinRateCorrelation = CalculateCorrelation(tempSharpeRatios, winRates, resultCount);
    
    return true;
}

//+------------------------------------------------------------------+
//| 통계 함수들                                                      |
//+------------------------------------------------------------------+
double CPerformanceAnalyzer::CalculateMean(double &data[], int count) {
    if(count == 0) return 0.0;
    
    double sum = 0.0;
    for(int i = 0; i < count; i++) {
        sum += data[i];
    }
    
    return sum / count;
}

double CPerformanceAnalyzer::CalculateMedian(double &data[], int count) {
    if(count == 0) return 0.0;
    
    // 배열 복사 및 정렬
    double sorted[];
    ArrayResize(sorted, count);
    for(int i = 0; i < count; i++) {
        sorted[i] = data[i];
    }
    SortArray(sorted, count);
    
    if(count % 2 == 0) {
        return (sorted[count/2 - 1] + sorted[count/2]) / 2.0;
    } else {
        return sorted[count/2];
    }
}

double CPerformanceAnalyzer::CalculateStdDev(double &data[], int count, double mean) {
    if(count <= 1) return 0.0;
    
    double sum = 0.0;
    for(int i = 0; i < count; i++) {
        sum += MathPow(data[i] - mean, 2);
    }
    
    return MathSqrt(sum / (count - 1));
}

double CPerformanceAnalyzer::CalculateCorrelation(double &x[], double &y[], int count) {
    if(count <= 1) return 0.0;
    
    double meanX = CalculateMean(x, count);
    double meanY = CalculateMean(y, count);
    
    double numerator = 0.0, sumX = 0.0, sumY = 0.0;
    
    for(int i = 0; i < count; i++) {
        double diffX = x[i] - meanX;
        double diffY = y[i] - meanY;
        
        numerator += diffX * diffY;
        sumX += diffX * diffX;
        sumY += diffY * diffY;
    }
    
    if(sumX == 0.0 || sumY == 0.0) return 0.0;
    
    return numerator / MathSqrt(sumX * sumY);
}

double CPerformanceAnalyzer::CalculatePercentile(double &data[], int count, double percentile) {
    if(count == 0) return 0.0;
    
    // 배열 복사 및 정렬
    double sorted[];
    ArrayResize(sorted, count);
    for(int i = 0; i < count; i++) {
        sorted[i] = data[i];
    }
    SortArray(sorted, count);
    
    int index = (int)(count * percentile);
    if(index >= count) index = count - 1;
    if(index < 0) index = 0;
    
    return sorted[index];
}

//+------------------------------------------------------------------+
//| 배열 정렬                                                        |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::SortArray(double &data[], int count) {
    // 간단한 버블 정렬
    for(int i = 0; i < count - 1; i++) {
        for(int j = 0; j < count - i - 1; j++) {
            if(data[j] > data[j + 1]) {
                double temp = data[j];
                data[j] = data[j + 1];
                data[j + 1] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 분석 결과 출력                                                   |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::PrintAnalysis() {
    Print("=== UT Bot 성능 분석 결과 ===");
    Print("총 결과 수: ", analysis.totalResults);
    Print("");
    
    Print("📊 기본 통계:");
    Print("  평균 수익률: ", DoubleToString(analysis.averageReturn * 100, 2), "%");
    Print("  중간값 수익률: ", DoubleToString(analysis.medianReturn * 100, 2), "%");
    Print("  표준편차: ", DoubleToString(analysis.stdDevReturn * 100, 2), "%");
    Print("  최소 수익률: ", DoubleToString(analysis.minReturn * 100, 2), "%");
    Print("  최대 수익률: ", DoubleToString(analysis.maxReturn * 100, 2), "%");
    Print("");
    
    Print("⚠️ 위험 지표:");
    Print("  평균 최대손실: ", DoubleToString(analysis.averageDrawdown * 100, 2), "%");
    Print("  전체 최대 손실: ", DoubleToString(analysis.maxDrawdown * 100, 2), "%");
    Print("  평균 변동성: ", DoubleToString(analysis.averageVolatility * 100, 2), "%");
    Print("  VaR 95%: ", DoubleToString(analysis.var95 * 100, 2), "%");
    Print("  기대 부족분: ", DoubleToString(analysis.expectedShortfall * 100, 2), "%");
    Print("");
    
    Print("📈 효율성 지표:");
    Print("  평균 샤프 비율: ", DoubleToString(analysis.averageSharpeRatio, 3));
    Print("  중간값 샤프 비율: ", DoubleToString(analysis.medianSharpeRatio, 3));
    Print("  최대 샤프 비율: ", DoubleToString(analysis.maxSharpeRatio, 3));
    Print("  평균 소르티노 비율: ", DoubleToString(analysis.averageSortinoRatio, 3));
    Print("  평균 칼마 비율: ", DoubleToString(analysis.averageCalmarRatio, 3));
    Print("");
    
    Print("💼 거래 지표:");
    Print("  평균 승률: ", DoubleToString(analysis.averageWinRate * 100, 2), "%");
    Print("  평균 수익 팩터: ", DoubleToString(analysis.averageProfitFactor, 2));
    Print("  평균 거래 횟수: ", analysis.averageTrades);
}

//+------------------------------------------------------------------+
//| 심볼별 분석 출력                                                 |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::PrintSymbolAnalysis() {
    Print("=== 심볼별 분석 ===");
    string symbols[10] = {"XAUUSD", "EURUSD", "GBPUSD", "USDJPY", "NASDAQ", "GBPJPY", "EURJPY", "AUDUSD", "USDCAD", "NZDUSD"};
    
    for(int i = 0; i < 10; i++) {
        if(analysis.symbolCounts[i] > 0) {
            Print(symbols[i], ": ", DoubleToString(analysis.symbolReturns[i] * 100, 2), "% (", analysis.symbolCounts[i], "개 결과)");
        }
    }
    
    Print("");
    Print("최고 성과 심볼: ", analysis.bestSymbol);
    Print("최저 성과 심볼: ", analysis.worstSymbol);
}

//+------------------------------------------------------------------+
//| 키값별 분석 출력                                                 |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::PrintKeyValueAnalysis() {
    Print("=== 키값별 분석 ===");
    Print("최적 키값: ", DoubleToString(analysis.bestKeyValue, 1));
    Print("최악 키값: ", DoubleToString(analysis.worstKeyValue, 1));
    Print("");
    
    Print("키값별 평균 수익률:");
    for(int i = 0; i < 50; i++) {
        if(analysis.keyValueCounts[i] > 0) {
            double keyValue = 0.5 + i * 0.1;
            Print("  ", DoubleToString(keyValue, 1), ": ", DoubleToString(analysis.keyValueReturns[i] * 100, 2), "% (", analysis.keyValueCounts[i], "개)");
        }
    }
}

//+------------------------------------------------------------------+
//| ATR 기간별 분석 출력                                             |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::PrintATRPeriodAnalysis() {
    Print("=== ATR 기간별 분석 ===");
    Print("최적 ATR 기간: ", analysis.bestATRPeriod);
    Print("최악 ATR 기간: ", analysis.worstATRPeriod);
    Print("");
    
    Print("ATR 기간별 평균 수익률:");
    for(int i = 0; i < 20; i++) {
        if(analysis.atrPeriodCounts[i] > 0) {
            int atrPeriod = 10 + i * 5;
            Print("  ", atrPeriod, ": ", DoubleToString(analysis.atrPeriodReturns[i] * 100, 2), "% (", analysis.atrPeriodCounts[i], "개)");
        }
    }
}

//+------------------------------------------------------------------+
//| 지표 모드별 분석 출력                                            |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::PrintIndicatorModeAnalysis() {
    Print("=== 지표 모드별 분석 ===");
    string modeNames[5] = {"UT Bot Only", "UT Bot + ADX", "UT Bot + Volume", "UT Bot + RSI", "UT Bot + Enhanced"};
    
    Print("최적 지표 모드: ", modeNames[analysis.bestIndicatorMode]);
    Print("최악 지표 모드: ", modeNames[analysis.worstIndicatorMode]);
    Print("");
    
    Print("지표 모드별 평균 수익률:");
    for(int i = 0; i < 5; i++) {
        if(analysis.indicatorModeCounts[i] > 0) {
            Print("  ", modeNames[i], ": ", DoubleToString(analysis.indicatorModeReturns[i] * 100, 2), "% (", analysis.indicatorModeCounts[i], "개)");
        }
    }
}

//+------------------------------------------------------------------+
//| 상관관계 분석 출력                                               |
//+------------------------------------------------------------------+
void CPerformanceAnalyzer::PrintCorrelationAnalysis() {
    Print("=== 상관관계 분석 ===");
    Print("키값-ATR 기간 상관관계: ", DoubleToString(analysis.keyValueATRCorrelation, 3));
    Print("수익률-변동성 상관관계: ", DoubleToString(analysis.returnVolatilityCorrelation, 3));
    Print("샤프비율-승률 상관관계: ", DoubleToString(analysis.sharpeWinRateCorrelation, 3));
}

//+------------------------------------------------------------------+
//| 분석 결과 반환                                                   |
//+------------------------------------------------------------------+
SPerformanceAnalysis CPerformanceAnalyzer::GetAnalysis() {
    return analysis;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("✅ UT Bot 성능 분석기 시작");
    
    // 성능 분석기 생성
    CPerformanceAnalyzer analyzer;
    
    // CSV에서 결과 로드
    if(!analyzer.LoadResultsFromCSV("UT_Bot_Optimization_Results.csv")) {
        Print("❌ 결과 파일 로드 실패");
        return INIT_FAILED;
    }
    
    // 분석 실행
    if(!analyzer.RunAnalysis()) {
        Print("❌ 분석 실행 실패");
        return INIT_FAILED;
    }
    
    // 결과 출력
    analyzer.PrintAnalysis();
    analyzer.PrintSymbolAnalysis();
    analyzer.PrintKeyValueAnalysis();
    analyzer.PrintATRPeriodAnalysis();
    analyzer.PrintIndicatorModeAnalysis();
    analyzer.PrintCorrelationAnalysis();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("✅ UT Bot 성능 분석기 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // 분석은 OnInit에서 실행됨
}
