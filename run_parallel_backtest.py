#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🚀 병렬 백테스트 통합 실행기
수십 개의 전략을 동시에 실행하여 빠른 결과를 제공합니다.

작성자: AI Trading System
버전: 1.0
날짜: 2024-12-31
"""

import os
import sys
import json
import time
import argparse
from datetime import datetime, timedelta
from typing import List, Dict, Any
import logging

# 로컬 모듈 임포트
from parallel_backtest_runner import ParallelBacktestRunner
from realtime_dashboard import RealtimeDashboard
from strategy_loader import StrategyLoader

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('parallel_backtest.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def main():
    """메인 실행 함수"""
    parser = argparse.ArgumentParser(description="🚀 병렬 백테스트 시스템")
    parser.add_argument("--mode", choices=["quick", "comprehensive", "custom", "dashboard"], 
                       default="quick", help="실행 모드")
    parser.add_argument("--symbols", nargs="+", default=["BTC-USD"], 
                       help="테스트할 심볼들")
    parser.add_argument("--strategies", nargs="+", default=["ma_cross", "rsi"], 
                       help="테스트할 전략들")
    parser.add_argument("--days", type=int, default=30, 
                       help="테스트 기간 (일)")
    parser.add_argument("--timeframes", nargs="+", default=["5m", "15m", "30m", "1h", "4h"],
                       help="시간프레임 목록 (예: 5m 15m 30m 1h 4h)")
    parser.add_argument("--workers", type=int, default=8, 
                       help="워커 수")
    parser.add_argument("--dashboard", action="store_true", 
                       help="웹 대시보드 실행")
    parser.add_argument("--port", type=int, default=5000, 
                       help="대시보드 포트")
    
    args = parser.parse_args()
    
    print("🚀 병렬 백테스트 시스템 시작!")
    print("=" * 60)
    print(f"모드: {args.mode}")
    print(f"심볼: {args.symbols}")
    print(f"전략: {args.strategies}")
    print(f"기간: {args.days}일")
    print(f"워커: {args.workers}개")
    print("=" * 60)
    
    if args.dashboard:
        # 웹 대시보드 실행
        print("📊 웹 대시보드 실행 중...")
        dashboard = RealtimeDashboard(port=args.port)
        dashboard.run()
        return
    
    # 백테스트 실행기 초기화
    runner = ParallelBacktestRunner(max_workers=args.workers)
    
    start_time = time.time()
    
    try:
        if args.mode == "quick":
            # 빠른 테스트
            print("⚡ 빠른 테스트 실행 중...")
            results = runner.run_quick_test(
                symbols=args.symbols,
                strategies=args.strategies,
                timeframes=args.timeframes,
                days=args.days
            )
            
        elif args.mode == "comprehensive":
            # 종합 테스트
            print("🔬 종합 테스트 실행 중...")
            results = runner.run_comprehensive_test(
                symbols=args.symbols,
                strategies=args.strategies,
                timeframes=args.timeframes,
                days=args.days
            )
            
        elif args.mode == "custom":
            # 커스텀 테스트
            print("🎯 커스텀 테스트 실행 중...")
            results = runner.run_custom_test(
                symbols=args.symbols,
                strategies=args.strategies,
                days=args.days
            )
        
        # 실행 시간 계산
        total_time = time.time() - start_time
        
        # 결과 요약
        print("\n🎉 백테스트 완료!")
        print(f"총 실행 시간: {total_time:.2f}초")
        print(f"결과 파일: {runner.engine.results_dir} 폴더")
        
        # 상위 성과자 출력
        successful_results = [r for r in results if r.status == "completed"]
        if successful_results:
            top_performers = sorted(successful_results, key=lambda x: x.net_profit, reverse=True)[:5]
            
            print("\n🏆 상위 5개 성과자:")
            for i, result in enumerate(top_performers, 1):
                print(f"   {i}. {result.config.symbol} - {result.config.strategy_name}")
                print(f"      순수익: ${result.net_profit:.2f}, 승률: {result.win_rate:.1f}%, 수익팩터: {result.profit_factor:.2f}")
        
        # 웹 대시보드 제안
        print(f"\n💡 웹 대시보드로 상세 결과를 확인하려면:")
        print(f"   python {__file__} --dashboard --port {args.port}")
        
    except KeyboardInterrupt:
        print("\n🛑 사용자에 의해 중단됨")
    except Exception as e:
        logger.error(f"❌ 백테스트 실행 실패: {e}")
        print(f"❌ 오류 발생: {e}")

def run_custom_test(symbols: List[str], strategies: List[str], days: int, workers: int = 8):
    """커스텀 테스트 실행"""
    runner = ParallelBacktestRunner(max_workers=workers)
    
    # 전략 로더로 조합 생성
    strategy_loader = StrategyLoader()
    
    # 파라미터 범위 설정
    param_ranges = {
        "ma_cross": {
            "fast_period": [5, 10, 15],
            "slow_period": [20, 30, 40]
        },
        "rsi": {
            "period": [10, 14, 20],
            "overbought": [70, 75, 80],
            "oversold": [20, 25, 30]
        },
        "bollinger": {
            "period": [15, 20, 25],
            "deviation": [1.5, 2.0, 2.5]
        },
        "macd": {
            "fast_period": [8, 12, 16],
            "slow_period": [21, 26, 31],
            "signal_period": [7, 9, 11]
        }
    }
    
    # 전략 조합 생성
    combinations = strategy_loader.generate_strategy_combinations(
        symbols, strategies, param_ranges
    )
    
    print(f"📊 총 조합 수: {len(combinations)}개")
    
    # 설정 생성
    from parallel_backtest_engine import BacktestConfig
    
    configs = []
    end_date = datetime.now().strftime("%Y-%m-%d")
    start_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    
    for combo in combinations:
        config = BacktestConfig(
            symbol=combo['symbol'],
            strategy_name=combo['strategy'],
            strategy_params=combo['params'],
            start_date=start_date,
            end_date=end_date,
            initial_balance=1000.0,
            leverage=200,
            commission_per_lot=0.1,
            spread_points=0.5,
            lot_size=0.01
        )
        configs.append(config)
    
    # 백테스트 실행
    results = runner.run_custom_test(configs)
    
    return results

def show_available_strategies():
    """사용 가능한 전략 목록 표시"""
    print("📋 사용 가능한 전략 목록:")
    print("=" * 60)
    
    strategy_loader = StrategyLoader()
    strategies = strategy_loader.get_available_strategies()
    
    for strategy in strategies:
        try:
            info = strategy_loader.get_strategy_info(strategy)
            print(f"\n🔍 {strategy}:")
            print(f"   - 설명: {info['description']}")
            print(f"   - 파라미터: {list(info['parameters'].keys())}")
        except Exception as e:
            print(f"❌ {strategy} 정보 조회 실패: {e}")

def show_usage_examples():
    """사용 예시 표시"""
    print("📖 사용 예시:")
    print("=" * 60)
    
    examples = [
        {
            "title": "빠른 테스트 (1-2분)",
            "command": "python run_parallel_backtest.py --mode quick --symbols BTC-USD --strategies ma_cross rsi --days 30"
        },
        {
            "title": "종합 테스트 (5-10분)",
            "command": "python run_parallel_backtest.py --mode comprehensive --symbols BTC-USD ETH-USD --strategies ma_cross rsi bollinger --days 90"
        },
        {
            "title": "웹 대시보드 실행",
            "command": "python run_parallel_backtest.py --dashboard --port 5000"
        },
        {
            "title": "고성능 테스트 (16개 워커)",
            "command": "python run_parallel_backtest.py --mode comprehensive --workers 16 --symbols BTC-USD ETH-USD EURUSD --strategies ma_cross rsi bollinger macd --days 180"
        }
    ]
    
    for example in examples:
        print(f"\n🎯 {example['title']}:")
        print(f"   {example['command']}")

if __name__ == "__main__":
    if len(sys.argv) == 1:
        # 인수 없이 실행된 경우 도움말 표시
        print("🚀 병렬 백테스트 시스템")
        print("=" * 60)
        show_available_strategies()
        show_usage_examples()
        print("\n💡 자세한 도움말: python run_parallel_backtest.py --help")
    else:
        main()
