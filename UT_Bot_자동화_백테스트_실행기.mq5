//+------------------------------------------------------------------+
//|                          UT_Bot_자동화_백테스트_실행기.mq5 |
//|                        Copyright 2024, MetaTrader Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaTrader Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "UT Bot 자동화 백테스트 통합 실행기 - 전체 시스템을 한 번에 실행"

#include "UT_Bot_Optimization_Controller.mq5"
#include "UT_Bot_Performance_Analyzer.mq5"
#include "UT_Bot_Report_Generator.mq5"

//+------------------------------------------------------------------+
//| 통합 실행기 클래스                                                |
//+------------------------------------------------------------------+
class CIntegratedBacktestRunner {
private:
    COptimizationManager optimizer;
    CPerformanceAnalyzer analyzer;
    CReportGenerator generator;
    
    // 실행 상태
    bool isRunning;
    datetime startTime;
    datetime endTime;
    
    // 결과 저장
    SBacktestResult results[10000];
    int resultCount;
    SPerformanceAnalysis analysis;
    
public:
    // 생성자
    CIntegratedBacktestRunner();
    
    // 소멸자
    ~CIntegratedBacktestRunner();
    
    // 전체 실행
    bool RunCompleteBacktest();
    bool RunQuickBacktest();  // 빠른 테스트 (제한된 조합)
    bool RunFullBacktest();   // 전체 테스트 (모든 조합)
    
    // 단계별 실행
    bool Step1_Optimization();
    bool Step2_Analysis();
    bool Step3_ReportGeneration();
    
    // 설정 관리
    bool LoadConfiguration();
    bool SaveConfiguration();
    
    // 상태 관리
    bool IsRunning();
    double GetProgress();
    string GetStatus();
    int GetEstimatedTime();
    
    // 결과 관리
    SBacktestResult GetBestResult();
    SPerformanceAnalysis GetAnalysis();
    bool ExportResults(string filename = "");
    
private:
    // 내부 함수들
    void InitializeSystem();
    void CleanupSystem();
    bool ValidateResults();
    void LogProgress();
    string GetExecutionTime();
};

//+------------------------------------------------------------------+
//| 생성자                                                           |
//+------------------------------------------------------------------+
CIntegratedBacktestRunner::CIntegratedBacktestRunner() {
    isRunning = false;
    startTime = 0;
    endTime = 0;
    resultCount = 0;
    ZeroMemory(analysis);
}

//+------------------------------------------------------------------+
//| 소멸자                                                           |
//+------------------------------------------------------------------+
CIntegratedBacktestRunner::~CIntegratedBacktestRunner() {
    CleanupSystem();
}

//+------------------------------------------------------------------+
//| 전체 백테스트 실행                                                |
//+------------------------------------------------------------------+
bool CIntegratedBacktestRunner::RunCompleteBacktest() {
    Print("🚀 UT Bot 자동화 백테스트 시스템 전체 실행 시작");
    Print("=" * 60);
    
    startTime = TimeCurrent();
    isRunning = true;
    
    // 시스템 초기화
    InitializeSystem();
    
    // 1단계: 최적화 실행
    Print("📊 1단계: 최적화 실행 중...");
    if(!Step1_Optimization()) {
        Print("❌ 1단계 실패: 최적화 실행 오류");
        isRunning = false;
        return false;
    }
    Print("✅ 1단계 완료: 최적화 실행 성공");
    
    // 2단계: 성능 분석
    Print("📈 2단계: 성능 분석 중...");
    if(!Step2_Analysis()) {
        Print("❌ 2단계 실패: 성능 분석 오류");
        isRunning = false;
        return false;
    }
    Print("✅ 2단계 완료: 성능 분석 성공");
    
    // 3단계: 리포트 생성
    Print("📄 3단계: 리포트 생성 중...");
    if(!Step3_ReportGeneration()) {
        Print("❌ 3단계 실패: 리포트 생성 오류");
        isRunning = false;
        return false;
    }
    Print("✅ 3단계 완료: 리포트 생성 성공");
    
    endTime = TimeCurrent();
    isRunning = false;
    
    // 최종 결과 출력
    PrintFinalResults();
    
    Print("=" * 60);
    Print("🎉 UT Bot 자동화 백테스트 시스템 전체 실행 완료!");
    Print("⏱️ 총 소요 시간: " + GetExecutionTime());
    
    return true;
}

//+------------------------------------------------------------------+
//| 빠른 백테스트 실행                                                |
//+------------------------------------------------------------------+
bool CIntegratedBacktestRunner::RunQuickBacktest() {
    Print("⚡ 빠른 백테스트 실행 (제한된 조합)");
    
    // 빠른 테스트를 위한 설정 조정
    // 실제로는 optimizer의 설정을 수정해야 함
    
    return RunCompleteBacktest();
}

//+------------------------------------------------------------------+
//| 전체 백테스트 실행                                                |
//+------------------------------------------------------------------+
bool CIntegratedBacktestRunner::RunFullBacktest() {
    Print("🔬 전체 백테스트 실행 (모든 조합)");
    
    // 전체 테스트를 위한 설정 조정
    // 실제로는 optimizer의 설정을 수정해야 함
    
    return RunCompleteBacktest();
}

//+------------------------------------------------------------------+
//| 1단계: 최적화 실행                                               |
//+------------------------------------------------------------------+
bool CIntegratedBacktestRunner::Step1_Optimization() {
    // 최적화 관리자 초기화
    if(!optimizer.LoadDefaultConfig()) {
        Print("❌ 최적화 설정 로드 실패");
        return false;
    }
    
    // 최적화 실행
    if(!optimizer.RunOptimization()) {
        Print("❌ 최적화 실행 실패");
        return false;
    }
    
    // 결과 수집
    resultCount = optimizer.GetTotalResults();
    if(resultCount == 0) {
        Print("❌ 최적화 결과가 없습니다");
        return false;
    }
    
    // 최적 결과 가져오기
    SBacktestResult bestResult = optimizer.GetBestResult();
    if(bestResult.symbol == "") {
        Print("❌ 최적 결과를 가져올 수 없습니다");
        return false;
    }
    
    Print("✅ 최적화 완료 - 총 ", resultCount, "개 결과");
    Print("🏆 최적 결과: ", bestResult.symbol, " 키값:", bestResult.keyValue, " ATR:", bestResult.atrPeriod);
    Print("   수익률: ", DoubleToString(bestResult.totalReturn * 100, 2), "%");
    Print("   샤프비율: ", DoubleToString(bestResult.sharpeRatio, 3));
    
    return true;
}

//+------------------------------------------------------------------+
//| 2단계: 성능 분석                                                 |
//+------------------------------------------------------------------+
bool CIntegratedBacktestRunner::Step2_Analysis() {
    // 성능 분석기 초기화
    if(!analyzer.LoadResultsFromCSV("UT_Bot_Optimization_Results.csv")) {
        Print("❌ 분석 데이터 로드 실패");
        return false;
    }
    
    // 분석 실행
    if(!analyzer.RunAnalysis()) {
        Print("❌ 성능 분석 실행 실패");
        return false;
    }
    
    // 분석 결과 가져오기
    analysis = analyzer.GetAnalysis();
    
    Print("✅ 성능 분석 완료");
    Print("📊 분석 결과:");
    Print("   평균 수익률: ", DoubleToString(analysis.averageReturn * 100, 2), "%");
    Print("   평균 샤프비율: ", DoubleToString(analysis.averageSharpeRatio, 3));
    Print("   평균 승률: ", DoubleToString(analysis.averageWinRate * 100, 2), "%");
    Print("   최대 손실: ", DoubleToString(analysis.maxDrawdown * 100, 2), "%");
    Print("   최고 성과 심볼: ", analysis.bestSymbol);
    Print("   최적 키값: ", DoubleToString(analysis.bestKeyValue, 1));
    Print("   최적 ATR 기간: ", analysis.bestATRPeriod);
    
    return true;
}

//+------------------------------------------------------------------+
//| 3단계: 리포트 생성                                                |
//+------------------------------------------------------------------+
bool CIntegratedBacktestRunner::Step3_ReportGeneration() {
    // 리포트 생성기 초기화
    if(!generator.SetData(results, resultCount, analysis)) {
        Print("❌ 리포트 데이터 설정 실패");
        return false;
    }
    
    // 모든 리포트 생성
    if(!generator.GenerateAllReports()) {
        Print("❌ 리포트 생성 실패");
        return false;
    }
    
    Print("✅ 리포트 생성 완료");
    Print("📄 생성된 파일:");
    Print("   - UT_Bot_Performance_Report.html (상세 HTML 리포트)");
    Print("   - UT_Bot_Detailed_Results.csv (상세 CSV 데이터)");
    Print("   - UT_Bot_Summary_Report.txt (요약 리포트)");
    
    return true;
}

//+------------------------------------------------------------------+
//| 시스템 초기화                                                    |
//+------------------------------------------------------------------+
void CIntegratedBacktestRunner::InitializeSystem() {
    Print("🔧 시스템 초기화 중...");
    
    // 결과 배열 초기화
    ArrayResize(results, 10000);
    resultCount = 0;
    
    // 분석 결과 초기화
    ZeroMemory(analysis);
    
    Print("✅ 시스템 초기화 완료");
}

//+------------------------------------------------------------------+
//| 시스템 정리                                                      |
//+------------------------------------------------------------------+
void CIntegratedBacktestRunner::CleanupSystem() {
    Print("🧹 시스템 정리 중...");
    
    // 동적 배열 정리
    ArrayFree(results);
    
    Print("✅ 시스템 정리 완료");
}

//+------------------------------------------------------------------+
//| 최종 결과 출력                                                   |
//+------------------------------------------------------------------+
void CIntegratedBacktestRunner::PrintFinalResults() {
    Print("=" * 60);
    Print("🏆 최종 결과 요약");
    Print("=" * 60);
    
    // 최적 결과
    SBacktestResult best = GetBestResult();
    if(best.symbol != "") {
        Print("🥇 최적 설정:");
        Print("   심볼: ", best.symbol);
        Print("   키값: ", best.keyValue);
        Print("   ATR 기간: ", best.atrPeriod);
        Print("   지표 모드: ", GetIndicatorModeName(best.indicatorMode));
        Print("   수익률: ", DoubleToString(best.totalReturn * 100, 2), "%");
        Print("   샤프비율: ", DoubleToString(best.sharpeRatio, 3));
        Print("   승률: ", DoubleToString(best.winRate * 100, 2), "%");
        Print("   최대손실: ", DoubleToString(best.maxDrawdown * 100, 2), "%");
    }
    
    Print("");
    Print("📊 전체 통계:");
    Print("   총 테스트 수: ", analysis.totalResults);
    Print("   평균 수익률: ", DoubleToString(analysis.averageReturn * 100, 2), "%");
    Print("   평균 샤프비율: ", DoubleToString(analysis.averageSharpeRatio, 3));
    Print("   평균 승률: ", DoubleToString(analysis.averageWinRate * 100, 2), "%");
    Print("   최대 손실: ", DoubleToString(analysis.maxDrawdown * 100, 2), "%");
    
    Print("");
    Print("💡 권장사항:");
    Print("   1. ", analysis.bestSymbol, " 심볼 사용 권장");
    Print("   2. 키값 ", DoubleToString(analysis.bestKeyValue, 1), " 사용 권장");
    Print("   3. ATR 기간 ", analysis.bestATRPeriod, " 사용 권장");
    Print("   4. ", GetIndicatorModeName(analysis.bestIndicatorMode), " 지표 모드 사용 권장");
    
    Print("");
    Print("📁 생성된 파일:");
    Print("   - UT_Bot_Performance_Report.html (웹 브라우저에서 열기)");
    Print("   - UT_Bot_Detailed_Results.csv (Excel에서 열기)");
    Print("   - UT_Bot_Summary_Report.txt (텍스트 에디터에서 열기)");
}

//+------------------------------------------------------------------+
//| 상태 관리 함수들                                                 |
//+------------------------------------------------------------------+
bool CIntegratedBacktestRunner::IsRunning() {
    return isRunning;
}

double CIntegratedBacktestRunner::GetProgress() {
    if(!isRunning) return 100.0;
    
    // 간단한 진행률 계산 (실제로는 더 정교하게 구현)
    datetime elapsed = TimeCurrent() - startTime;
    datetime estimated = 1800; // 30분 예상
    
    double progress = (double)elapsed / estimated * 100.0;
    if(progress > 100.0) progress = 100.0;
    
    return progress;
}

string CIntegratedBacktestRunner::GetStatus() {
    if(!isRunning) return "완료";
    
    double progress = GetProgress();
    return StringFormat("실행 중 (%.1f%%)", progress);
}

int CIntegratedBacktestRunner::GetEstimatedTime() {
    if(!isRunning) return 0;
    
    datetime elapsed = TimeCurrent() - startTime;
    double progress = GetProgress();
    
    if(progress <= 0) return 1800; // 30분 예상
    
    int remaining = (int)((100.0 - progress) / progress * elapsed);
    return remaining;
}

//+------------------------------------------------------------------+
//| 결과 관리 함수들                                                 |
//+------------------------------------------------------------------+
SBacktestResult CIntegratedBacktestRunner::GetBestResult() {
    return optimizer.GetBestResult();
}

SPerformanceAnalysis CIntegratedBacktestRunner::GetAnalysis() {
    return analysis;
}

bool CIntegratedBacktestRunner::ExportResults(string filename = "") {
    if(filename == "") {
        filename = "UT_Bot_Complete_Results.csv";
    }
    
    int handle = FileOpen(filename, FILE_WRITE | FILE_CSV);
    if(handle == INVALID_HANDLE) {
        Print("❌ 결과 내보내기 실패: ", filename);
        return false;
    }
    
    // 헤더 작성
    FileWrite(handle, "Symbol", "KeyValue", "ATRPeriod", "IndicatorMode", "TotalReturn", "SharpeRatio", "WinRate", "MaxDrawdown");
    
    // 데이터 작성
    for(int i = 0; i < resultCount; i++) {
        FileWrite(handle, results[i].symbol, results[i].keyValue, results[i].atrPeriod, 
                  results[i].indicatorMode, results[i].totalReturn, results[i].sharpeRatio, 
                  results[i].winRate, results[i].maxDrawdown);
    }
    
    FileClose(handle);
    Print("✅ 결과 내보내기 완료: ", filename);
    return true;
}

//+------------------------------------------------------------------+
//| 유틸리티 함수들                                                   |
//+------------------------------------------------------------------+
string CIntegratedBacktestRunner::GetExecutionTime() {
    if(startTime == 0) return "0초";
    
    datetime elapsed = endTime > startTime ? endTime - startTime : TimeCurrent() - startTime;
    int minutes = (int)(elapsed / 60);
    int seconds = (int)(elapsed % 60);
    
    return StringFormat("%d분 %d초", minutes, seconds);
}

string GetIndicatorModeName(int mode) {
    switch(mode) {
        case 0: return "UT Bot Only";
        case 1: return "UT Bot + ADX";
        case 2: return "UT Bot + Volume";
        case 3: return "UT Bot + RSI";
        case 4: return "UT Bot + Enhanced";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("🚀 UT Bot 자동화 백테스트 통합 실행기 시작");
    Print("=" * 60);
    
    // 통합 실행기 생성
    CIntegratedBacktestRunner runner;
    
    // 전체 백테스트 실행
    if(!runner.RunCompleteBacktest()) {
        Print("❌ 백테스트 실행 실패");
        return INIT_FAILED;
    }
    
    Print("✅ 백테스트 실행 완료");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("✅ UT Bot 자동화 백테스트 통합 실행기 종료");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // 백테스트는 OnInit에서 실행됨
}
