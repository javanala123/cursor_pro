#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🚀 Exness 백테스트 통합 실행 스크립트
MCP 서버를 활용하여 개발된 완전한 백테스트 시스템을 실행합니다.

작성자: AI Trading System
버전: 1.0
날짜: 2024-12-31
"""

import os
import sys
import subprocess
import json
import time
from datetime import datetime
import logging

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('exness_backtest.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class ExnessBacktestManager:
    """Exness 백테스트 관리자"""
    
    def __init__(self):
        """초기화"""
        self.data_dir = "historical_data"
        self.results_dir = "backtest_results"
        self.mt5_scripts_dir = "mt5_scripts"
        
        # 디렉토리 생성
        self._create_directories()
        
        logger.info("🎯 Exness 백테스트 관리자 초기화 완료")
    
    def _create_directories(self):
        """필요한 디렉토리 생성"""
        directories = [self.data_dir, self.results_dir, self.mt5_scripts_dir]
        
        for directory in directories:
            if not os.path.exists(directory):
                os.makedirs(directory)
                logger.info(f"📁 디렉토리 생성: {directory}")
    
    def check_requirements(self) -> bool:
        """필요한 패키지 확인"""
        logger.info("🔍 필요 패키지 확인 중...")
        
        required_packages = [
            'yfinance',
            'pandas',
            'numpy',
            'matplotlib',
            'seaborn'
        ]
        
        missing_packages = []
        
        for package in required_packages:
            try:
                __import__(package)
                logger.info(f"✅ {package} 설치됨")
            except ImportError:
                missing_packages.append(package)
                logger.warning(f"❌ {package} 누락")
        
        if missing_packages:
            logger.error(f"❌ 누락된 패키지: {', '.join(missing_packages)}")
            logger.info("다음 명령어로 설치하세요:")
            logger.info(f"pip install {' '.join(missing_packages)}")
            return False
        
        logger.info("✅ 모든 필요 패키지가 설치되어 있습니다.")
        return True
    
    def install_requirements(self):
        """필요한 패키지 설치"""
        logger.info("📦 필요 패키지 설치 중...")
        
        packages = [
            'yfinance>=0.2.18',
            'pandas>=1.5.0',
            'numpy>=1.21.0',
            'matplotlib>=3.5.0',
            'seaborn>=0.11.0'
        ]
        
        for package in packages:
            try:
                logger.info(f"설치 중: {package}")
                subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])
                logger.info(f"✅ {package} 설치 완료")
            except subprocess.CalledProcessError as e:
                logger.error(f"❌ {package} 설치 실패: {e}")
                return False
        
        logger.info("✅ 모든 패키지 설치 완료")
        return True
    
    def download_historical_data(self, symbols: list = None, period: str = "2y", interval: str = "1h"):
        """과거 데이터 다운로드"""
        logger.info("📥 과거 데이터 다운로드 시작...")
        
        if symbols is None:
            symbols = ["BTC-USD", "ETH-USD", "EURUSD=X", "GBPUSD=X"]
        
        try:
            # 데이터 다운로더 실행
            from historical_data_downloader import HistoricalDataDownloader
            
            downloader = HistoricalDataDownloader(self.data_dir)
            
            for symbol in symbols:
                logger.info(f"다운로드 중: {symbol}")
                data = downloader.download_symbol_data(symbol, period, interval)
                
                if data is not None:
                    downloader.save_backtest_data(symbol, data, format="mt5")
                    logger.info(f"✅ {symbol} 다운로드 완료")
                else:
                    logger.warning(f"⚠️ {symbol} 다운로드 실패")
                
                time.sleep(1)  # API 제한 방지
            
            logger.info("✅ 과거 데이터 다운로드 완료")
            return True
            
        except Exception as e:
            logger.error(f"❌ 데이터 다운로드 실패: {e}")
            return False
    
    def create_mt5_scripts(self):
        """MT5 스크립트 생성"""
        logger.info("📝 MT5 스크립트 생성 중...")
        
        # 커스텀 심볼 생성 스크립트 복사
        source_script = "Exness_Custom_Symbol_Creator.mq5"
        target_script = os.path.join(self.mt5_scripts_dir, "Exness_Custom_Symbol_Creator.mq5")
        
        if os.path.exists(source_script):
            with open(source_script, 'r', encoding='utf-8') as f:
                content = f.read()
            
            with open(target_script, 'w', encoding='utf-8') as f:
                f.write(content)
            
            logger.info(f"✅ MT5 스크립트 생성: {target_script}")
        else:
            logger.error(f"❌ 소스 스크립트를 찾을 수 없습니다: {source_script}")
            return False
        
        return True
    
    def run_backtest(self, symbol: str = "BTC-USD", strategy: str = "ma"):
        """백테스트 실행"""
        logger.info(f"🎯 백테스트 실행: {symbol} - {strategy} 전략")
        
        try:
            from accurate_backtest_engine import AccurateBacktestEngine, simple_ma_strategy, rsi_strategy
            
            # 데이터 로드
            data_file = os.path.join(self.data_dir, f"{symbol.replace('-', '_').replace('=', '_')}_2y_1h.csv")
            
            if not os.path.exists(data_file):
                logger.error(f"❌ 데이터 파일을 찾을 수 없습니다: {data_file}")
                return False
            
            data = pd.read_csv(data_file, index_col=0, parse_dates=True)
            logger.info(f"📊 데이터 로드: {len(data)}개 바")
            
            # 백테스트 엔진 초기화
            engine = AccurateBacktestEngine(
                initial_balance=1000.0,
                leverage=200,
                commission_per_lot=0.1,
                spread_points=0.5
            )
            
            # 전략 선택
            if strategy == "ma":
                strategy_func = simple_ma_strategy
                strategy_name = "MA20"
            elif strategy == "rsi":
                strategy_func = rsi_strategy
                strategy_name = "RSI"
            else:
                logger.error(f"❌ 알 수 없는 전략: {strategy}")
                return False
            
            # 백테스트 실행
            result = engine.run_backtest(data, symbol, strategy_func)
            
            # 결과 저장
            engine.save_results(result, f"{symbol}_{strategy_name}", self.results_dir)
            
            # 결과 출력
            self._print_results(result, symbol, strategy_name)
            
            logger.info("✅ 백테스트 완료")
            return True
            
        except Exception as e:
            logger.error(f"❌ 백테스트 실행 실패: {e}")
            return False
    
    def _print_results(self, result, symbol: str, strategy_name: str):
        """결과 출력"""
        print(f"\n📊 {symbol} - {strategy_name} 전략 백테스트 결과")
        print("=" * 60)
        print(f"총 거래: {result.total_trades}회")
        print(f"승률: {result.win_rate:.1f}%")
        print(f"총 수익: ${result.total_profit:.2f}")
        print(f"총 수수료: ${result.total_commission:.2f}")
        print(f"순수익: ${result.net_profit:.2f}")
        print(f"최대 낙폭: {result.max_drawdown_percentage:.1f}%")
        print(f"수익 팩터: {result.profit_factor:.2f}")
        print(f"샤프 비율: {result.sharpe_ratio:.2f}")
        print("=" * 60)
    
    def generate_report(self):
        """종합 리포트 생성"""
        logger.info("📋 종합 리포트 생성 중...")
        
        report = {
            "generated_at": datetime.now().isoformat(),
            "system_info": {
                "data_directory": self.data_dir,
                "results_directory": self.results_dir,
                "mt5_scripts_directory": self.mt5_scripts_dir
            },
            "available_data": [],
            "backtest_results": []
        }
        
        # 사용 가능한 데이터 파일 확인
        if os.path.exists(self.data_dir):
            for file in os.listdir(self.data_dir):
                if file.endswith('.csv') and not file.endswith('_report.json'):
                    report["available_data"].append(file)
        
        # 백테스트 결과 확인
        if os.path.exists(self.results_dir):
            for file in os.listdir(self.results_dir):
                if file.endswith('_summary.json'):
                    with open(os.path.join(self.results_dir, file), 'r', encoding='utf-8') as f:
                        summary = json.load(f)
                        report["backtest_results"].append(summary)
        
        # 리포트 저장
        report_file = os.path.join(self.results_dir, "comprehensive_report.json")
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        
        logger.info(f"✅ 종합 리포트 생성: {report_file}")
        return report
    
    def show_usage_guide(self):
        """사용법 가이드 표시"""
        print("\n📖 Exness 백테스트 시스템 사용법")
        print("=" * 60)
        print("1. 데이터 다운로드:")
        print("   python run_exness_backtest.py --download")
        print()
        print("2. 백테스트 실행:")
        print("   python run_exness_backtest.py --backtest BTC-USD ma")
        print()
        print("3. MT5에서 커스텀 심볼 생성:")
        print("   - MT5에서 Exness_Custom_Symbol_Creator.mq5 스크립트 실행")
        print("   - 생성된 커스텀 심볼로 백테스트 수행")
        print()
        print("4. 종합 리포트 생성:")
        print("   python run_exness_backtest.py --report")
        print()
        print("🎯 주요 특징:")
        print("   - 정확한 계약 크기 (1 랏 = 1 BTC)")
        print("   - 실매매와 동일한 조건")
        print("   - 신뢰할 수 있는 백테스트 결과")
        print("   - 다양한 전략 지원")
        print("=" * 60)

def main():
    """메인 실행 함수"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Exness 백테스트 시스템')
    parser.add_argument('--download', action='store_true', help='과거 데이터 다운로드')
    parser.add_argument('--backtest', nargs=2, metavar=('SYMBOL', 'STRATEGY'), 
                       help='백테스트 실행 (예: BTC-USD ma)')
    parser.add_argument('--report', action='store_true', help='종합 리포트 생성')
    parser.add_argument('--install', action='store_true', help='필요 패키지 설치')
    parser.add_argument('--guide', action='store_true', help='사용법 가이드 표시')
    
    args = parser.parse_args()
    
    # 백테스트 관리자 초기화
    manager = ExnessBacktestManager()
    
    if args.install:
        # 패키지 설치
        if not manager.install_requirements():
            sys.exit(1)
    
    if args.download:
        # 데이터 다운로드
        if not manager.download_historical_data():
            sys.exit(1)
    
    if args.backtest:
        # 백테스트 실행
        symbol, strategy = args.backtest
        if not manager.run_backtest(symbol, strategy):
            sys.exit(1)
    
    if args.report:
        # 리포트 생성
        manager.generate_report()
    
    if args.guide:
        # 사용법 가이드
        manager.show_usage_guide()
    
    # 인수 없이 실행된 경우
    if not any([args.download, args.backtest, args.report, args.install, args.guide]):
        print("🚀 Exness 백테스트 시스템")
        print("=" * 60)
        print("사용법을 보려면: python run_exness_backtest.py --guide")
        print("데이터 다운로드: python run_exness_backtest.py --download")
        print("백테스트 실행: python run_exness_backtest.py --backtest BTC-USD ma")
        print("=" * 60)

if __name__ == "__main__":
    main()
