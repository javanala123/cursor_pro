//+------------------------------------------------------------------+
//|                                    UT_Bot_Report_Generator.mq5 |
//|                        Copyright 2024, MetaTrader Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaTrader Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "UT Bot 리포트 생성기 - HTML 리포트 및 CSV 내보내기"

#include "UT_Bot_Performance_Analyzer.mq5"

//+------------------------------------------------------------------+
//| 리포트 생성기 클래스                                              |
//+------------------------------------------------------------------+
class CReportGenerator {
private:
    SBacktestResult results[];
    SPerformanceAnalysis analysis;
    int resultCount;
    
    // 파일 핸들
    int htmlHandle;
    int csvHandle;
    int summaryHandle;
    
public:
    // 생성자
    CReportGenerator();
    
    // 소멸자
    ~CReportGenerator();
    
    // 데이터 설정
    bool SetData(SBacktestResult &inputResults[], int count, SPerformanceAnalysis &inputAnalysis);
    
    // 리포트 생성
    bool GenerateHTMLReport(string filename = "");
    bool GenerateCSVReport(string filename = "");
    bool GenerateSummaryReport(string filename = "");
    bool GenerateAllReports();
    
    // HTML 생성 함수들
    bool WriteHTMLHeader();
    bool WriteHTMLSummary();
    bool WriteHTMLStatistics();
    bool WriteHTMLSymbolAnalysis();
    bool WriteHTMLParameterAnalysis();
    bool WriteHTMLCorrelationAnalysis();
    bool WriteHTMLFooter();
    
    // CSV 생성 함수들
    bool WriteCSVHeader();
    bool WriteCSVData();
    bool WriteCSVSummary();
    
    // 유틸리티 함수들
    string FormatNumber(double value, int decimals = 2);
    string FormatPercentage(double value, int decimals = 2);
    string GetIndicatorModeName(int mode);
    string GetOptimizationTargetName(int target);
    string GetCurrentDateTime();
    
private:
    // 내부 함수들
    void CloseAllFiles();
    bool OpenHTMLFile(string filename);
    bool OpenCSVFile(string filename);
    bool OpenSummaryFile(string filename);
    void WriteHTMLTableHeader(string headers[]);
    void WriteHTMLTableRow(string values[]);
    void WriteHTMLChart(string chartType, string data);
};

//+------------------------------------------------------------------+
//| 생성자                                                           |
//+------------------------------------------------------------------+
CReportGenerator::CReportGenerator() {
    resultCount = 0;
    htmlHandle = INVALID_HANDLE;
    csvHandle = INVALID_HANDLE;
    summaryHandle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| 소멸자                                                           |
//+------------------------------------------------------------------+
CReportGenerator::~CReportGenerator() {
    CloseAllFiles();
}

//+------------------------------------------------------------------+
//| 데이터 설정                                                       |
//+------------------------------------------------------------------+
bool CReportGenerator::SetData(SBacktestResult &inputResults[], int count, SPerformanceAnalysis &inputAnalysis) {
    if(count <= 0 || count > 10000) {
        Print("❌ 잘못된 결과 개수: ", count);
        return false;
    }
    
    resultCount = count;
    analysis = inputAnalysis;
    
    // 결과 복사
    ArrayResize(results, count);
    for(int i = 0; i < count; i++) {
        results[i] = inputResults[i];
    }
    
    Print("✅ 리포트 데이터 설정 완료 - ", count, "개 결과");
    return true;
}

//+------------------------------------------------------------------+
//| 모든 리포트 생성                                                  |
//+------------------------------------------------------------------+
bool CReportGenerator::GenerateAllReports() {
    Print("📊 모든 리포트 생성 시작");
    
    bool success = true;
    
    // HTML 리포트 생성
    if(!GenerateHTMLReport()) {
        Print("❌ HTML 리포트 생성 실패");
        success = false;
    }
    
    // CSV 리포트 생성
    if(!GenerateCSVReport()) {
        Print("❌ CSV 리포트 생성 실패");
        success = false;
    }
    
    // 요약 리포트 생성
    if(!GenerateSummaryReport()) {
        Print("❌ 요약 리포트 생성 실패");
        success = false;
    }
    
    if(success) {
        Print("✅ 모든 리포트 생성 완료");
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| HTML 리포트 생성                                                  |
//+------------------------------------------------------------------+
bool CReportGenerator::GenerateHTMLReport(string filename = "") {
    if(filename == "") {
        filename = "UT_Bot_Performance_Report.html";
    }
    
    Print("📄 HTML 리포트 생성 중: ", filename);
    
    if(!OpenHTMLFile(filename)) {
        return false;
    }
    
    // HTML 헤더 작성
    WriteHTMLHeader();
    
    // 요약 섹션
    WriteHTMLSummary();
    
    // 통계 섹션
    WriteHTMLStatistics();
    
    // 심볼별 분석 섹션
    WriteHTMLSymbolAnalysis();
    
    // 파라미터별 분석 섹션
    WriteHTMLParameterAnalysis();
    
    // 상관관계 분석 섹션
    WriteHTMLCorrelationAnalysis();
    
    // HTML 푸터 작성
    WriteHTMLFooter();
    
    FileClose(htmlHandle);
    htmlHandle = INVALID_HANDLE;
    
    Print("✅ HTML 리포트 생성 완료");
    return true;
}

//+------------------------------------------------------------------+
//| HTML 헤더 작성                                                   |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteHTMLHeader() {
    if(htmlHandle == INVALID_HANDLE) return false;
    
    string html = "<!DOCTYPE html>\n";
    html += "<html lang=\"ko\">\n";
    html += "<head>\n";
    html += "    <meta charset=\"UTF-8\">\n";
    html += "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n";
    html += "    <title>UT Bot 성능 분석 리포트</title>\n";
    html += "    <style>\n";
    html += "        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }\n";
    html += "        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }\n";
    html += "        h1 { color: #2c3e50; text-align: center; margin-bottom: 30px; border-bottom: 3px solid #3498db; padding-bottom: 10px; }\n";
    html += "        h2 { color: #34495e; margin-top: 30px; margin-bottom: 15px; border-left: 4px solid #3498db; padding-left: 15px; }\n";
    html += "        h3 { color: #7f8c8d; margin-top: 20px; margin-bottom: 10px; }\n";
    html += "        table { width: 100%; border-collapse: collapse; margin: 15px 0; }\n";
    html += "        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }\n";
    html += "        th { background-color: #3498db; color: white; font-weight: bold; }\n";
    html += "        tr:nth-child(even) { background-color: #f2f2f2; }\n";
    html += "        tr:hover { background-color: #e8f4f8; }\n";
    html += "        .metric { display: inline-block; margin: 10px; padding: 15px; background-color: #ecf0f1; border-radius: 5px; text-align: center; min-width: 120px; }\n";
    html += "        .metric-value { font-size: 24px; font-weight: bold; color: #2c3e50; }\n";
    html += "        .metric-label { font-size: 12px; color: #7f8c8d; margin-top: 5px; }\n";
    html += "        .positive { color: #27ae60; }\n";
    html += "        .negative { color: #e74c3c; }\n";
    html += "        .neutral { color: #f39c12; }\n";
    html += "        .footer { text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; }\n";
    html += "    </style>\n";
    html += "</head>\n";
    html += "<body>\n";
    html += "    <div class=\"container\">\n";
    html += "        <h1>🚀 UT Bot 자동화 백테스트 성능 분석 리포트</h1>\n";
    html += "        <p style=\"text-align: center; color: #7f8c8d; font-size: 14px;\">생성 시간: " + GetCurrentDateTime() + "</p>\n";
    
    FileWriteString(htmlHandle, html);
    return true;
}

//+------------------------------------------------------------------+
//| HTML 요약 섹션 작성                                              |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteHTMLSummary() {
    if(htmlHandle == INVALID_HANDLE) return false;
    
    string html = "        <h2>📊 분석 요약</h2>\n";
    html += "        <div style=\"display: flex; flex-wrap: wrap; justify-content: center;\">\n";
    
    // 주요 지표들
    html += "            <div class=\"metric\">\n";
    html += "                <div class=\"metric-value " + (analysis.averageReturn >= 0 ? "positive" : "negative") + "\">" + FormatPercentage(analysis.averageReturn) + "</div>\n";
    html += "                <div class=\"metric-label\">평균 수익률</div>\n";
    html += "            </div>\n";
    
    html += "            <div class=\"metric\">\n";
    html += "                <div class=\"metric-value " + (analysis.averageSharpeRatio >= 1.0 ? "positive" : (analysis.averageSharpeRatio >= 0.5 ? "neutral" : "negative")) + "\">" + FormatNumber(analysis.averageSharpeRatio, 3) + "</div>\n";
    html += "                <div class=\"metric-label\">평균 샤프 비율</div>\n";
    html += "            </div>\n";
    
    html += "            <div class=\"metric\">\n";
    html += "                <div class=\"metric-value " + (analysis.averageWinRate >= 0.5 ? "positive" : (analysis.averageWinRate >= 0.4 ? "neutral" : "negative")) + "\">" + FormatPercentage(analysis.averageWinRate) + "</div>\n";
    html += "                <div class=\"metric-label\">평균 승률</div>\n";
    html += "            </div>\n";
    
    html += "            <div class=\"metric\">\n";
    html += "                <div class=\"metric-value negative\">" + FormatPercentage(analysis.maxDrawdown) + "</div>\n";
    html += "                <div class=\"metric-label\">최대 손실</div>\n";
    html += "            </div>\n";
    
    html += "            <div class=\"metric\">\n";
    html += "                <div class=\"metric-value neutral\">" + IntegerToString(analysis.totalResults) + "</div>\n";
    html += "                <div class=\"metric-label\">총 테스트 수</div>\n";
    html += "            </div>\n";
    
    html += "            <div class=\"metric\">\n";
    html += "                <div class=\"metric-value positive\">" + analysis.bestSymbol + "</div>\n";
    html += "                <div class=\"metric-label\">최고 성과 심볼</div>\n";
    html += "            </div>\n";
    
    html += "        </div>\n";
    
    FileWriteString(htmlHandle, html);
    return true;
}

//+------------------------------------------------------------------+
//| HTML 통계 섹션 작성                                              |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteHTMLStatistics() {
    if(htmlHandle == INVALID_HANDLE) return false;
    
    string html = "        <h2>📈 상세 통계</h2>\n";
    
    // 기본 통계 테이블
    html += "        <h3>기본 통계</h3>\n";
    html += "        <table>\n";
    html += "            <tr><th>지표</th><th>값</th><th>설명</th></tr>\n";
    html += "            <tr><td>평균 수익률</td><td>" + FormatPercentage(analysis.averageReturn) + "</td><td>모든 테스트의 평균 수익률</td></tr>\n";
    html += "            <tr><td>중간값 수익률</td><td>" + FormatPercentage(analysis.medianReturn) + "</td><td>수익률의 중간값</td></tr>\n";
    html += "            <tr><td>표준편차</td><td>" + FormatPercentage(analysis.stdDevReturn) + "</td><td>수익률의 변동성</td></tr>\n";
    html += "            <tr><td>최소 수익률</td><td>" + FormatPercentage(analysis.minReturn) + "</td><td>가장 낮은 수익률</td></tr>\n";
    html += "            <tr><td>최대 수익률</td><td>" + FormatPercentage(analysis.maxReturn) + "</td><td>가장 높은 수익률</td></tr>\n";
    html += "        </table>\n";
    
    // 위험 지표 테이블
    html += "        <h3>위험 지표</h3>\n";
    html += "        <table>\n";
    html += "            <tr><th>지표</th><th>값</th><th>설명</th></tr>\n";
    html += "            <tr><td>평균 최대손실</td><td>" + FormatPercentage(analysis.averageDrawdown) + "</td><td>평균적인 최대 손실</td></tr>\n";
    html += "            <tr><td>전체 최대 손실</td><td>" + FormatPercentage(analysis.maxDrawdown) + "</td><td>가장 큰 손실</td></tr>\n";
    html += "            <tr><td>평균 변동성</td><td>" + FormatPercentage(analysis.averageVolatility) + "</td><td>평균적인 가격 변동성</td></tr>\n";
    html += "            <tr><td>VaR 95%</td><td>" + FormatPercentage(analysis.var95) + "</td><td>95% 신뢰구간에서의 최대 손실</td></tr>\n";
    html += "            <tr><td>기대 부족분</td><td>" + FormatPercentage(analysis.expectedShortfall) + "</td><td>VaR 초과 시 기대 손실</td></tr>\n";
    html += "        </table>\n";
    
    // 효율성 지표 테이블
    html += "        <h3>효율성 지표</h3>\n";
    html += "        <table>\n";
    html += "            <tr><th>지표</th><th>값</th><th>설명</th></tr>\n";
    html += "            <tr><td>평균 샤프 비율</td><td>" + FormatNumber(analysis.averageSharpeRatio, 3) + "</td><td>위험 대비 수익률</td></tr>\n";
    html += "            <tr><td>중간값 샤프 비율</td><td>" + FormatNumber(analysis.medianSharpeRatio, 3) + "</td><td>샤프 비율의 중간값</td></tr>\n";
    html += "            <tr><td>최대 샤프 비율</td><td>" + FormatNumber(analysis.maxSharpeRatio, 3) + "</td><td>가장 높은 샤프 비율</td></tr>\n";
    html += "            <tr><td>평균 소르티노 비율</td><td>" + FormatNumber(analysis.averageSortinoRatio, 3) + "</td><td>하방 위험 대비 수익률</td></tr>\n";
    html += "            <tr><td>평균 칼마 비율</td><td>" + FormatNumber(analysis.averageCalmarRatio, 3) + "</td><td>최대손실 대비 연간 수익률</td></tr>\n";
    html += "        </table>\n";
    
    // 거래 지표 테이블
    html += "        <h3>거래 지표</h3>\n";
    html += "        <table>\n";
    html += "            <tr><th>지표</th><th>값</th><th>설명</th></tr>\n";
    html += "            <tr><td>평균 승률</td><td>" + FormatPercentage(analysis.averageWinRate) + "</td><td>수익 거래의 비율</td></tr>\n";
    html += "            <tr><td>평균 수익 팩터</td><td>" + FormatNumber(analysis.averageProfitFactor, 2) + "</td><td>총 수익 / 총 손실</td></tr>\n";
    html += "            <tr><td>평균 거래 횟수</td><td>" + IntegerToString(analysis.averageTrades) + "</td><td>평균적인 거래 횟수</td></tr>\n";
    html += "        </table>\n";
    
    FileWriteString(htmlHandle, html);
    return true;
}

//+------------------------------------------------------------------+
//| HTML 심볼별 분석 섹션 작성                                       |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteHTMLSymbolAnalysis() {
    if(htmlHandle == INVALID_HANDLE) return false;
    
    string html = "        <h2>💱 심볼별 분석</h2>\n";
    html += "        <table>\n";
    html += "            <tr><th>심볼</th><th>평균 수익률</th><th>테스트 수</th><th>성과 등급</th></tr>\n";
    
    string symbols[10] = {"XAUUSD", "EURUSD", "GBPUSD", "USDJPY", "NASDAQ", "GBPJPY", "EURJPY", "AUDUSD", "USDCAD", "NZDUSD"};
    
    for(int i = 0; i < 10; i++) {
        if(analysis.symbolCounts[i] > 0) {
            string grade = "";
            if(analysis.symbolReturns[i] > 0.1) grade = "🟢 우수";
            else if(analysis.symbolReturns[i] > 0.05) grade = "🟡 양호";
            else if(analysis.symbolReturns[i] > 0.0) grade = "🟠 보통";
            else grade = "🔴 부진";
            
            html += "            <tr>\n";
            html += "                <td><strong>" + symbols[i] + "</strong></td>\n";
            html += "                <td>" + FormatPercentage(analysis.symbolReturns[i]) + "</td>\n";
            html += "                <td>" + IntegerToString(analysis.symbolCounts[i]) + "</td>\n";
            html += "                <td>" + grade + "</td>\n";
            html += "            </tr>\n";
        }
    }
    
    html += "        </table>\n";
    
    FileWriteString(htmlHandle, html);
    return true;
}

//+------------------------------------------------------------------+
//| HTML 파라미터별 분석 섹션 작성                                   |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteHTMLParameterAnalysis() {
    if(htmlHandle == INVALID_HANDLE) return false;
    
    string html = "        <h2>⚙️ 파라미터별 분석</h2>\n";
    
    // 키값별 분석
    html += "        <h3>키값별 성과</h3>\n";
    html += "        <table>\n";
    html += "            <tr><th>키값</th><th>평균 수익률</th><th>테스트 수</th><th>추천도</th></tr>\n";
    
    for(int i = 0; i < 50; i++) {
        if(analysis.keyValueCounts[i] > 0) {
            double keyValue = 0.5 + i * 0.1;
            string recommendation = "";
            if(analysis.keyValueReturns[i] > 0.1) recommendation = "⭐⭐⭐ 강력 추천";
            else if(analysis.keyValueReturns[i] > 0.05) recommendation = "⭐⭐ 추천";
            else if(analysis.keyValueReturns[i] > 0.0) recommendation = "⭐ 보통";
            else recommendation = "❌ 비추천";
            
            html += "            <tr>\n";
            html += "                <td>" + FormatNumber(keyValue, 1) + "</td>\n";
            html += "                <td>" + FormatPercentage(analysis.keyValueReturns[i]) + "</td>\n";
            html += "                <td>" + IntegerToString(analysis.keyValueCounts[i]) + "</td>\n";
            html += "                <td>" + recommendation + "</td>\n";
            html += "            </tr>\n";
        }
    }
    
    html += "        </table>\n";
    
    // ATR 기간별 분석
    html += "        <h3>ATR 기간별 성과</h3>\n";
    html += "        <table>\n";
    html += "            <tr><th>ATR 기간</th><th>평균 수익률</th><th>테스트 수</th><th>추천도</th></tr>\n";
    
    for(int i = 0; i < 20; i++) {
        if(analysis.atrPeriodCounts[i] > 0) {
            int atrPeriod = 10 + i * 5;
            string recommendation = "";
            if(analysis.atrPeriodReturns[i] > 0.1) recommendation = "⭐⭐⭐ 강력 추천";
            else if(analysis.atrPeriodReturns[i] > 0.05) recommendation = "⭐⭐ 추천";
            else if(analysis.atrPeriodReturns[i] > 0.0) recommendation = "⭐ 보통";
            else recommendation = "❌ 비추천";
            
            html += "            <tr>\n";
            html += "                <td>" + IntegerToString(atrPeriod) + "</td>\n";
            html += "                <td>" + FormatPercentage(analysis.atrPeriodReturns[i]) + "</td>\n";
            html += "                <td>" + IntegerToString(analysis.atrPeriodCounts[i]) + "</td>\n";
            html += "                <td>" + recommendation + "</td>\n";
            html += "            </tr>\n";
        }
    }
    
    html += "        </table>\n";
    
    // 지표 모드별 분석
    html += "        <h3>지표 모드별 성과</h3>\n";
    html += "        <table>\n";
    html += "            <tr><th>지표 모드</th><th>평균 수익률</th><th>테스트 수</th><th>추천도</th></tr>\n";
    
    string modeNames[5] = {"UT Bot Only", "UT Bot + ADX", "UT Bot + Volume", "UT Bot + RSI", "UT Bot + Enhanced"};
    
    for(int i = 0; i < 5; i++) {
        if(analysis.indicatorModeCounts[i] > 0) {
            string recommendation = "";
            if(analysis.indicatorModeReturns[i] > 0.1) recommendation = "⭐⭐⭐ 강력 추천";
            else if(analysis.indicatorModeReturns[i] > 0.05) recommendation = "⭐⭐ 추천";
            else if(analysis.indicatorModeReturns[i] > 0.0) recommendation = "⭐ 보통";
            else recommendation = "❌ 비추천";
            
            html += "            <tr>\n";
            html += "                <td>" + modeNames[i] + "</td>\n";
            html += "                <td>" + FormatPercentage(analysis.indicatorModeReturns[i]) + "</td>\n";
            html += "                <td>" + IntegerToString(analysis.indicatorModeCounts[i]) + "</td>\n";
            html += "                <td>" + recommendation + "</td>\n";
            html += "            </tr>\n";
        }
    }
    
    html += "        </table>\n";
    
    FileWriteString(htmlHandle, html);
    return true;
}

//+------------------------------------------------------------------+
//| HTML 상관관계 분석 섹션 작성                                     |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteHTMLCorrelationAnalysis() {
    if(htmlHandle == INVALID_HANDLE) return false;
    
    string html = "        <h2>🔗 상관관계 분석</h2>\n";
    html += "        <table>\n";
    html += "            <tr><th>상관관계</th><th>계수</th><th>해석</th></tr>\n";
    
    // 키값-ATR 상관관계
    string interpretation1 = "";
    if(MathAbs(analysis.keyValueATRCorrelation) > 0.7) interpretation1 = "강한 상관관계";
    else if(MathAbs(analysis.keyValueATRCorrelation) > 0.3) interpretation1 = "중간 상관관계";
    else interpretation1 = "약한 상관관계";
    
    html += "            <tr><td>키값 - ATR 기간</td><td>" + FormatNumber(analysis.keyValueATRCorrelation, 3) + "</td><td>" + interpretation1 + "</td></tr>\n";
    
    // 수익률-변동성 상관관계
    string interpretation2 = "";
    if(MathAbs(analysis.returnVolatilityCorrelation) > 0.7) interpretation2 = "강한 상관관계";
    else if(MathAbs(analysis.returnVolatilityCorrelation) > 0.3) interpretation2 = "중간 상관관계";
    else interpretation2 = "약한 상관관계";
    
    html += "            <tr><td>수익률 - 변동성</td><td>" + FormatNumber(analysis.returnVolatilityCorrelation, 3) + "</td><td>" + interpretation2 + "</td></tr>\n";
    
    // 샤프비율-승률 상관관계
    string interpretation3 = "";
    if(MathAbs(analysis.sharpeWinRateCorrelation) > 0.7) interpretation3 = "강한 상관관계";
    else if(MathAbs(analysis.sharpeWinRateCorrelation) > 0.3) interpretation3 = "중간 상관관계";
    else interpretation3 = "약한 상관관계";
    
    html += "            <tr><td>샤프 비율 - 승률</td><td>" + FormatNumber(analysis.sharpeWinRateCorrelation, 3) + "</td><td>" + interpretation3 + "</td></tr>\n";
    
    html += "        </table>\n";
    
    FileWriteString(htmlHandle, html);
    return true;
}

//+------------------------------------------------------------------+
//| HTML 푸터 작성                                                   |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteHTMLFooter() {
    if(htmlHandle == INVALID_HANDLE) return false;
    
    string html = "        <div class=\"footer\">\n";
    html += "            <p>📊 UT Bot 자동화 백테스트 시스템 | 생성 시간: " + GetCurrentDateTime() + "</p>\n";
    html += "            <p>💡 이 리포트는 자동화된 백테스트 결과를 바탕으로 생성되었습니다.</p>\n";
    html += "        </div>\n";
    html += "    </div>\n";
    html += "</body>\n";
    html += "</html>\n";
    
    FileWriteString(htmlHandle, html);
    return true;
}

//+------------------------------------------------------------------+
//| CSV 리포트 생성                                                   |
//+------------------------------------------------------------------+
bool CReportGenerator::GenerateCSVReport(string filename = "") {
    if(filename == "") {
        filename = "UT_Bot_Detailed_Results.csv";
    }
    
    Print("📊 CSV 리포트 생성 중: ", filename);
    
    if(!OpenCSVFile(filename)) {
        return false;
    }
    
    // CSV 헤더 작성
    WriteCSVHeader();
    
    // CSV 데이터 작성
    WriteCSVData();
    
    // CSV 요약 작성
    WriteCSVSummary();
    
    FileClose(csvHandle);
    csvHandle = INVALID_HANDLE;
    
    Print("✅ CSV 리포트 생성 완료");
    return true;
}

//+------------------------------------------------------------------+
//| CSV 헤더 작성                                                    |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteCSVHeader() {
    if(csvHandle == INVALID_HANDLE) return false;
    
    FileWrite(csvHandle, "Symbol", "KeyValue", "ATRPeriod", "IndicatorMode", "IndicatorModeName",
              "TotalReturn", "AnnualReturn", "MaxDrawdown", "SharpeRatio", "SortinoRatio", "CalmarRatio",
              "TotalTrades", "WinRate", "ProfitFactor", "Volatility", "VaR95", "ExpectedShortfall",
              "TotalProfit", "TotalLoss", "AverageWin", "AverageLoss", "WinningTrades", "LosingTrades",
              "MaxConsecutiveLosses", "TestDuration");
    
    return true;
}

//+------------------------------------------------------------------+
//| CSV 데이터 작성                                                   |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteCSVData() {
    if(csvHandle == INVALID_HANDLE) return false;
    
    for(int i = 0; i < resultCount; i++) {
        FileWrite(csvHandle, 
                  results[i].symbol,
                  results[i].keyValue,
                  results[i].atrPeriod,
                  results[i].indicatorMode,
                  GetIndicatorModeName(results[i].indicatorMode),
                  results[i].totalReturn,
                  results[i].annualReturn,
                  results[i].maxDrawdown,
                  results[i].sharpeRatio,
                  results[i].sortinoRatio,
                  results[i].calmarRatio,
                  results[i].totalTrades,
                  results[i].winRate,
                  results[i].profitFactor,
                  results[i].volatility,
                  results[i].var95,
                  results[i].expectedShortfall,
                  results[i].totalProfit,
                  results[i].totalLoss,
                  results[i].averageWin,
                  results[i].averageLoss,
                  results[i].winningTrades,
                  results[i].losingTrades,
                  results[i].maxConsecutiveLosses,
                  results[i].testDuration);
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| CSV 요약 작성                                                    |
//+------------------------------------------------------------------+
bool CReportGenerator::WriteCSVSummary() {
    if(csvHandle == INVALID_HANDLE) return false;
    
    // 빈 줄
    FileWrite(csvHandle, "");
    FileWrite(csvHandle, "=== 요약 통계 ===");
    
    // 기본 통계
    FileWrite(csvHandle, "항목", "값");
    FileWrite(csvHandle, "총 결과 수", analysis.totalResults);
    FileWrite(csvHandle, "평균 수익률", FormatPercentage(analysis.averageReturn));
    FileWrite(csvHandle, "중간값 수익률", FormatPercentage(analysis.medianReturn));
    FileWrite(csvHandle, "표준편차", FormatPercentage(analysis.stdDevReturn));
    FileWrite(csvHandle, "최소 수익률", FormatPercentage(analysis.minReturn));
    FileWrite(csvHandle, "최대 수익률", FormatPercentage(analysis.maxReturn));
    
    // 위험 지표
    FileWrite(csvHandle, "");
    FileWrite(csvHandle, "=== 위험 지표 ===");
    FileWrite(csvHandle, "항목", "값");
    FileWrite(csvHandle, "평균 최대손실", FormatPercentage(analysis.averageDrawdown));
    FileWrite(csvHandle, "전체 최대 손실", FormatPercentage(analysis.maxDrawdown));
    FileWrite(csvHandle, "평균 변동성", FormatPercentage(analysis.averageVolatility));
    FileWrite(csvHandle, "VaR 95%", FormatPercentage(analysis.var95));
    FileWrite(csvHandle, "기대 부족분", FormatPercentage(analysis.expectedShortfall));
    
    // 효율성 지표
    FileWrite(csvHandle, "");
    FileWrite(csvHandle, "=== 효율성 지표 ===");
    FileWrite(csvHandle, "항목", "값");
    FileWrite(csvHandle, "평균 샤프 비율", FormatNumber(analysis.averageSharpeRatio, 3));
    FileWrite(csvHandle, "중간값 샤프 비율", FormatNumber(analysis.medianSharpeRatio, 3));
    FileWrite(csvHandle, "최대 샤프 비율", FormatNumber(analysis.maxSharpeRatio, 3));
    FileWrite(csvHandle, "평균 소르티노 비율", FormatNumber(analysis.averageSortinoRatio, 3));
    FileWrite(csvHandle, "평균 칼마 비율", FormatNumber(analysis.averageCalmarRatio, 3));
    
    // 거래 지표
    FileWrite(csvHandle, "");
    FileWrite(csvHandle, "=== 거래 지표 ===");
    FileWrite(csvHandle, "항목", "값");
    FileWrite(csvHandle, "평균 승률", FormatPercentage(analysis.averageWinRate));
    FileWrite(csvHandle, "평균 수익 팩터", FormatNumber(analysis.averageProfitFactor, 2));
    FileWrite(csvHandle, "평균 거래 횟수", analysis.averageTrades);
    
    return true;
}

//+------------------------------------------------------------------+
//| 요약 리포트 생성                                                  |
//+------------------------------------------------------------------+
bool CReportGenerator::GenerateSummaryReport(string filename = "") {
    if(filename == "") {
        filename = "UT_Bot_Summary_Report.txt";
    }
    
    Print("📋 요약 리포트 생성 중: ", filename);
    
    if(!OpenSummaryFile(filename)) {
        return false;
    }
    
    FileWrite(summaryHandle, "=== UT Bot 자동화 백테스트 요약 리포트 ===");
    FileWrite(summaryHandle, "생성 시간: " + GetCurrentDateTime());
    FileWrite(summaryHandle, "");
    
    // 기본 정보
    FileWrite(summaryHandle, "📊 기본 정보:");
    FileWrite(summaryHandle, "  총 테스트 수: " + IntegerToString(analysis.totalResults));
    FileWrite(summaryHandle, "  최고 성과 심볼: " + analysis.bestSymbol);
    FileWrite(summaryHandle, "  최저 성과 심볼: " + analysis.worstSymbol);
    FileWrite(summaryHandle, "");
    
    // 주요 지표
    FileWrite(summaryHandle, "📈 주요 지표:");
    FileWrite(summaryHandle, "  평균 수익률: " + FormatPercentage(analysis.averageReturn));
    FileWrite(summaryHandle, "  평균 샤프 비율: " + FormatNumber(analysis.averageSharpeRatio, 3));
    FileWrite(summaryHandle, "  평균 승률: " + FormatPercentage(analysis.averageWinRate));
    FileWrite(summaryHandle, "  최대 손실: " + FormatPercentage(analysis.maxDrawdown));
    FileWrite(summaryHandle, "");
    
    // 최적 파라미터
    FileWrite(summaryHandle, "⚙️ 최적 파라미터:");
    FileWrite(summaryHandle, "  최적 키값: " + FormatNumber(analysis.bestKeyValue, 1));
    FileWrite(summaryHandle, "  최적 ATR 기간: " + IntegerToString(analysis.bestATRPeriod));
    FileWrite(summaryHandle, "  최적 지표 모드: " + GetIndicatorModeName(analysis.bestIndicatorMode));
    FileWrite(summaryHandle, "");
    
    // 상관관계
    FileWrite(summaryHandle, "🔗 상관관계:");
    FileWrite(summaryHandle, "  키값-ATR 기간: " + FormatNumber(analysis.keyValueATRCorrelation, 3));
    FileWrite(summaryHandle, "  수익률-변동성: " + FormatNumber(analysis.returnVolatilityCorrelation, 3));
    FileWrite(summaryHandle, "  샤프비율-승률: " + FormatNumber(analysis.sharpeWinRateCorrelation, 3));
    FileWrite(summaryHandle, "");
    
    // 권장사항
    FileWrite(summaryHandle, "💡 권장사항:");
    FileWrite(summaryHandle, "  1. " + analysis.bestSymbol + " 심볼에서 " + FormatNumber(analysis.bestKeyValue, 1) + " 키값 사용 권장");
    FileWrite(summaryHandle, "  2. ATR 기간 " + IntegerToString(analysis.bestATRPeriod) + " 사용 권장");
    FileWrite(summaryHandle, "  3. " + GetIndicatorModeName(analysis.bestIndicatorMode) + " 지표 모드 사용 권장");
    FileWrite(summaryHandle, "  4. 평균 수익률 " + FormatPercentage(analysis.averageReturn) + " 달성 가능");
    FileWrite(summaryHandle, "  5. 최대 손실 " + FormatPercentage(analysis.maxDrawdown) + " 이하로 관리 필요");
    
    FileClose(summaryHandle);
    summaryHandle = INVALID_HANDLE;
    
    Print("✅ 요약 리포트 생성 완료");
    return true;
}

//+------------------------------------------------------------------+
//| 파일 열기 함수들                                                 |
//+------------------------------------------------------------------+
bool CReportGenerator::OpenHTMLFile(string filename) {
    htmlHandle = FileOpen(filename, FILE_WRITE | FILE_TXT);
    if(htmlHandle == INVALID_HANDLE) {
        Print("❌ HTML 파일 열기 실패: ", filename);
        return false;
    }
    return true;
}

bool CReportGenerator::OpenCSVFile(string filename) {
    csvHandle = FileOpen(filename, FILE_WRITE | FILE_CSV);
    if(csvHandle == INVALID_HANDLE) {
        Print("❌ CSV 파일 열기 실패: ", filename);
        return false;
    }
    return true;
}

bool CReportGenerator::OpenSummaryFile(string filename) {
    summaryHandle = FileOpen(filename, FILE_WRITE | FILE_TXT);
    if(summaryHandle == INVALID_HANDLE) {
        Print("❌ 요약 파일 열기 실패: ", filename);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| 모든 파일 닫기                                                   |
//+------------------------------------------------------------------+
void CReportGenerator::CloseAllFiles() {
    if(htmlHandle != INVALID_HANDLE) {
        FileClose(htmlHandle);
        htmlHandle = INVALID_HANDLE;
    }
    if(csvHandle != INVALID_HANDLE) {
        FileClose(csvHandle);
        csvHandle = INVALID_HANDLE;
    }
    if(summaryHandle != INVALID_HANDLE) {
        FileClose(summaryHandle);
        summaryHandle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| 유틸리티 함수들                                                   |
//+------------------------------------------------------------------+
string CReportGenerator::FormatNumber(double value, int decimals = 2) {
    return DoubleToString(value, decimals);
}

string CReportGenerator::FormatPercentage(double value, int decimals = 2) {
    return DoubleToString(value * 100, decimals) + "%";
}

string CReportGenerator::GetIndicatorModeName(int mode) {
    switch(mode) {
        case 0: return "UT Bot Only";
        case 1: return "UT Bot + ADX";
        case 2: return "UT Bot + Volume";
        case 3: return "UT Bot + RSI";
        case 4: return "UT Bot + Enhanced";
        default: return "Unknown";
    }
}

string CReportGenerator::GetOptimizationTargetName(int target) {
    switch(target) {
        case 0: return "Sharpe Ratio";
        case 1: return "Total Return";
        case 2: return "Min Drawdown";
        default: return "Composite";
    }
}

string CReportGenerator::GetCurrentDateTime() {
    return TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("✅ UT Bot 리포트 생성기 시작");
    
    // 리포트 생성기 생성
    CReportGenerator generator;
    
    // 샘플 데이터 생성 (실제로는 분석기에서 가져옴)
    SBacktestResult sampleResults[100];
    SPerformanceAnalysis sampleAnalysis;
    
    // 샘플 데이터 설정
    for(int i = 0; i < 100; i++) {
        sampleResults[i].symbol = "XAUUSD";
        sampleResults[i].keyValue = 1.0 + i * 0.1;
        sampleResults[i].atrPeriod = 20;
        sampleResults[i].indicatorMode = 0;
        sampleResults[i].totalReturn = (MathRand() - 16383) / 16383.0 * 0.2; // -20% ~ +20%
        sampleResults[i].sharpeRatio = (MathRand() - 16383) / 16383.0 * 2.0; // -2 ~ +2
        sampleResults[i].winRate = 0.3 + (MathRand() / 32767.0) * 0.4; // 30% ~ 70%
        sampleResults[i].maxDrawdown = -0.1 - (MathRand() / 32767.0) * 0.2; // -10% ~ -30%
    }
    
    // 샘플 분석 설정
    sampleAnalysis.totalResults = 100;
    sampleAnalysis.averageReturn = 0.05;
    sampleAnalysis.bestSymbol = "XAUUSD";
    sampleAnalysis.worstSymbol = "EURUSD";
    sampleAnalysis.bestKeyValue = 2.0;
    sampleAnalysis.bestATRPeriod = 25;
    sampleAnalysis.bestIndicatorMode = 0;
    
    // 데이터 설정
    if(!generator.SetData(sampleResults, 100, sampleAnalysis)) {
        Print("❌ 데이터 설정 실패");
        return INIT_FAILED;
    }
    
    // 모든 리포트 생성
    if(!generator.GenerateAllReports()) {
        Print("❌ 리포트 생성 실패");
        return INIT_FAILED;
    }
    
    Print("✅ 모든 리포트 생성 완료");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("✅ UT Bot 리포트 생성기 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // 리포트 생성은 OnInit에서 실행됨
}
