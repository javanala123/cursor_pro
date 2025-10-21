#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🚀 병렬 백테스트 실행기
수십 개의 전략을 동시에 실행하여 빠른 결과를 제공합니다.

작성자: AI Trading System
버전: 1.0
날짜: 2024-12-31
"""

import os
import sys
import json
import time
from datetime import datetime, timedelta
from typing import List, Dict, Any
import pandas as pd
import numpy as np
import logging

# 로컬 모듈 임포트
from parallel_backtest_engine import ParallelBacktestEngine, BacktestConfig
from strategy_loader import StrategyLoader

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('parallel_runner.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class ParallelBacktestRunner:
    """병렬 백테스트 실행기"""
    
    def __init__(self, 
                 max_workers: int = None,
                 data_dir: str = "historical_data",
                 results_dir: str = "parallel_results"):
        """
        초기화
        
        Args:
            max_workers: 최대 워커 수
            data_dir: 데이터 디렉토리
            results_dir: 결과 디렉토리
        """
        self.engine = ParallelBacktestEngine(max_workers, data_dir, results_dir)
        self.strategy_loader = StrategyLoader()
        
        # 전략 등록
        self._register_strategies()
        
        logger.info(f"🚀 병렬 백테스트 실행기 초기화 완료")
        logger.info(f"   - 워커 수: {self.engine.max_workers}")
        logger.info(f"   - 등록된 전략: {len(self.strategy_loader.get_available_strategies())}개")
    
    def _register_strategies(self):
        """전략 등록"""
        from strategy_functions import (
            create_ma_cross_strategy,
            create_rsi_strategy,
            create_bollinger_strategy,
            create_macd_strategy,
            create_stochastic_strategy,
            create_combined_strategy,
            create_ut_bot_strategy
        )
        
        # 전략 매핑
        strategy_functions = {
            'ma_cross': create_ma_cross_strategy,
            'rsi': create_rsi_strategy,
            'bollinger': create_bollinger_strategy,
            'macd': create_macd_strategy,
            'stochastic': create_stochastic_strategy,
            'combined': create_combined_strategy,
            'ut_bot': create_ut_bot_strategy
        }
        
        for strategy_name, strategy_func in strategy_functions.items():
            self.engine.register_strategy(strategy_name, strategy_func)
    
    def run_quick_test(self, 
                     symbols: List[str] = None,
                     strategies: List[str] = None,
                     timeframes: List[str] = None,
                     days: int = 30) -> List[Dict]:
        """
        빠른 테스트 실행
        
        Args:
            symbols: 심볼 리스트
            strategies: 전략 리스트
            days: 테스트 기간 (일)
            
        Returns:
            결과 리스트
        """
        if symbols is None:
            symbols = ["BTC-USD"]
        
        if strategies is None:
            strategies = ["ma_cross", "rsi"]
        if timeframes is None:
            timeframes = ["1h"]
        
        logger.info(f"⚡ 빠른 테스트 시작: {len(symbols)}개 심볼 × {len(strategies)}개 전략")
        
        # 설정 생성
        configs = []
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
        
        for symbol in symbols:
            for timeframe in timeframes:
                for strategy in strategies:
                    config = BacktestConfig(
                        symbol=symbol,
                        timeframe=timeframe,
                        strategy_name=strategy,
                        strategy_params={},
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
        results = self.engine.run_parallel_backtests(configs)
        
        # 결과 저장
        self.engine.save_results(results)
        
        # 요약 출력
        self._print_summary(results)
        
        return results
    
    def run_comprehensive_test(self,
                             symbols: List[str] = None,
                             strategies: List[str] = None,
                             param_ranges: Dict[str, Dict[str, List]] = None,
                             timeframes: List[str] = None,
                             days: int = 90) -> List[Dict]:
        """
        종합 테스트 실행
        
        Args:
            symbols: 심볼 리스트
            strategies: 전략 리스트
            param_ranges: 파라미터 범위
            days: 테스트 기간 (일)
            
        Returns:
            결과 리스트
        """
        if symbols is None:
            symbols = ["BTC-USD", "ETH-USD"]
        
        if strategies is None:
            strategies = ["ma_cross", "rsi", "bollinger", "macd"]
        
        if param_ranges is None:
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
                },
                "ut_bot": {
                    "atr_period": [7, 10, 14],
                    "factor": [0.8, 1.0, 1.2, 1.5, 2.0],
                    "ma_period": [0, 50, 100]
                }
            }
        if timeframes is None:
            timeframes = ["5m", "15m", "30m", "1h", "4h"]
        
        logger.info(f"🔬 종합 테스트 시작: {len(symbols)}개 심볼 × {len(strategies)}개 전략")
        
        # 전략 조합 생성
        base_combinations = self.strategy_loader.generate_strategy_combinations(
            symbols, strategies, param_ranges
        )
        # 시간프레임 확장
        combinations = []
        for combo in base_combinations:
            for tf in timeframes:
                combinations.append({**combo, 'timeframe': tf})
        
        logger.info(f"📊 총 조합 수: {len(combinations)}개")
        
        # 설정 생성
        configs = []
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
        
        for combo in combinations:
            config = BacktestConfig(
                symbol=combo['symbol'],
                timeframe=combo.get('timeframe', '1h'),
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
        results = self.engine.run_parallel_backtests(configs)
        
        # 결과 저장
        self.engine.save_results(results)
        
        # 상세 분석
        self._analyze_results(results)
        
        return results
    
    def run_custom_test(self, configs: List[BacktestConfig]) -> List[Dict]:
        """
        커스텀 테스트 실행
        
        Args:
            configs: 백테스트 설정 리스트
            
        Returns:
            결과 리스트
        """
        logger.info(f"🎯 커스텀 테스트 시작: {len(configs)}개 설정")
        
        # 백테스트 실행
        results = self.engine.run_parallel_backtests(configs)
        
        # 결과 저장
        self.engine.save_results(results)
        
        # 요약 출력
        self._print_summary(results)
        
        return results
    
    def _print_summary(self, results: List[Dict]):
        """결과 요약 출력"""
        if not results:
            print("❌ 결과가 없습니다.")
            return
        
        successful_results = [r for r in results if r.status == "completed"]
        failed_results = [r for r in results if r.status == "failed"]
        
        print("\n📊 백테스트 결과 요약")
        print("=" * 60)
        print(f"총 실행: {len(results)}개")
        print(f"성공: {len(successful_results)}개")
        print(f"실패: {len(failed_results)}개")
        print(f"성공률: {len(successful_results)/len(results)*100:.1f}%")
        
        if successful_results:
            # 성과 통계
            net_profits = [r.net_profit for r in successful_results]
            win_rates = [r.win_rate for r in successful_results]
            profit_factors = [r.profit_factor for r in successful_results]
            
            print(f"\n💰 수익 통계:")
            print(f"   - 평균 순수익: ${np.mean(net_profits):.2f}")
            print(f"   - 최고 순수익: ${np.max(net_profits):.2f}")
            print(f"   - 최저 순수익: ${np.min(net_profits):.2f}")
            print(f"   - 총 순수익: ${np.sum(net_profits):.2f}")
            
            print(f"\n🎯 승률 통계:")
            print(f"   - 평균 승률: {np.mean(win_rates):.1f}%")
            print(f"   - 최고 승률: {np.max(win_rates):.1f}%")
            print(f"   - 최저 승률: {np.min(win_rates):.1f}%")
            
            print(f"\n📈 수익 팩터 통계:")
            print(f"   - 평균 수익 팩터: {np.mean(profit_factors):.2f}")
            print(f"   - 최고 수익 팩터: {np.max(profit_factors):.2f}")
            
            # 상위 성과자
            top_performers = sorted(successful_results, key=lambda x: x.net_profit, reverse=True)[:5]
            
            print(f"\n🏆 상위 5개 성과자:")
            for i, result in enumerate(top_performers, 1):
                print(f"   {i}. {result.config.symbol} - {result.config.strategy_name}")
                print(f"      순수익: ${result.net_profit:.2f}, 승률: {result.win_rate:.1f}%, 수익팩터: {result.profit_factor:.2f}")
        
        if failed_results:
            print(f"\n❌ 실패한 테스트:")
            for result in failed_results[:5]:  # 처음 5개만 출력
                print(f"   - {result.config.symbol} - {result.config.strategy_name}: {result.error_message}")
    
    def _analyze_results(self, results: List[Dict]):
        """결과 상세 분석"""
        successful_results = [r for r in results if r.status == "completed"]
        
        if not successful_results:
            return
        
        print("\n🔍 상세 분석")
        print("=" * 60)
        
        # 전략별 분석
        strategy_stats = {}
        for result in successful_results:
            strategy = result.config.strategy_name
            if strategy not in strategy_stats:
                strategy_stats[strategy] = []
            strategy_stats[strategy].append(result)
        
        print("\n📊 전략별 성과:")
        for strategy, strategy_results in strategy_stats.items():
            net_profits = [r.net_profit for r in strategy_results]
            win_rates = [r.win_rate for r in strategy_results]
            
            print(f"\n🎯 {strategy}:")
            print(f"   - 테스트 수: {len(strategy_results)}개")
            print(f"   - 평균 순수익: ${np.mean(net_profits):.2f}")
            print(f"   - 평균 승률: {np.mean(win_rates):.1f}%")
            print(f"   - 최고 성과: ${np.max(net_profits):.2f}")
            print(f"   - 최저 성과: ${np.min(net_profits):.2f}")
        
        # 심볼별 분석
        symbol_stats = {}
        for result in successful_results:
            symbol = result.config.symbol
            if symbol not in symbol_stats:
                symbol_stats[symbol] = []
            symbol_stats[symbol].append(result)
        
        print("\n📈 심볼별 성과:")
        for symbol, symbol_results in symbol_stats.items():
            net_profits = [r.net_profit for r in symbol_results]
            win_rates = [r.win_rate for r in symbol_results]
            
            print(f"\n💰 {symbol}:")
            print(f"   - 테스트 수: {len(symbol_results)}개")
            print(f"   - 평균 순수익: ${np.mean(net_profits):.2f}")
            print(f"   - 평균 승률: {np.mean(win_rates):.1f}%")
            print(f"   - 최고 성과: ${np.max(net_profits):.2f}")
            print(f"   - 최저 성과: ${np.min(net_profits):.2f}")
    
    def generate_report(self, results: List[Dict], output_file: str = None):
        """상세 리포트 생성"""
        if output_file is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"{self.engine.results_dir}/detailed_report_{timestamp}.html"
        
        # HTML 리포트 생성
        html_content = self._generate_html_report(results)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        logger.info(f"📋 상세 리포트 생성: {output_file}")
    
    def _generate_html_report(self, results: List[Dict]) -> str:
        """HTML 리포트 생성"""
        successful_results = [r for r in results if r.status == "completed"]
        
        html = f"""
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>병렬 백테스트 결과 리포트</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .header {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; }}
        .summary {{ background-color: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0; }}
        .results {{ margin: 20px 0; }}
        table {{ width: 100%; border-collapse: collapse; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
        .positive {{ color: green; }}
        .negative {{ color: red; }}
        .top-performer {{ background-color: #fff3cd; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 병렬 백테스트 결과 리포트</h1>
        <p>생성 시간: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
        <p>총 테스트: {len(results)}개 | 성공: {len(successful_results)}개 | 실패: {len(results) - len(successful_results)}개</p>
    </div>
    
    <div class="summary">
        <h2>📊 요약 통계</h2>
        <p>성공률: {len(successful_results)/len(results)*100:.1f}%</p>
        <p>평균 순수익: ${np.mean([r.net_profit for r in successful_results]):.2f}</p>
        <p>평균 승률: {np.mean([r.win_rate for r in successful_results]):.1f}%</p>
    </div>
    
    <div class="results">
        <h2>📈 상세 결과</h2>
        <table>
            <tr>
                <th>순위</th>
                <th>심볼</th>
                <th>전략</th>
                <th>순수익</th>
                <th>승률</th>
                <th>수익팩터</th>
                <th>샤프비율</th>
                <th>최대낙폭</th>
            </tr>
"""
        
        # 상위 성과자 표시
        top_results = sorted(successful_results, key=lambda x: x.net_profit, reverse=True)[:20]
        
        for i, result in enumerate(top_results, 1):
            profit_class = "positive" if result.net_profit > 0 else "negative"
            row_class = "top-performer" if i <= 5 else ""
            
            html += f"""
            <tr class="{row_class}">
                <td>{i}</td>
                <td>{result.config.symbol}</td>
                <td>{result.config.strategy_name}</td>
                <td class="{profit_class}">${result.net_profit:.2f}</td>
                <td>{result.win_rate:.1f}%</td>
                <td>{result.profit_factor:.2f}</td>
                <td>{result.sharpe_ratio:.2f}</td>
                <td>{result.max_drawdown_percentage:.1f}%</td>
            </tr>
"""
        
        html += """
        </table>
    </div>
</body>
</html>
"""
        
        return html

def main():
    """메인 실행 함수"""
    print("🚀 병렬 백테스트 실행기 시작!")
    print("=" * 60)
    
    # 실행기 초기화
    runner = ParallelBacktestRunner(max_workers=8)
    
    # 사용자 선택
    print("\n📋 실행 모드를 선택하세요:")
    print("1. 빠른 테스트 (1-2분)")
    print("2. 종합 테스트 (5-10분)")
    print("3. 커스텀 테스트")
    print("4. 전략 정보 보기")
    
    choice = input("\n선택 (1-4): ").strip()
    
    if choice == "1":
        # 빠른 테스트
        print("\n⚡ 빠른 테스트 실행 중...")
        results = runner.run_quick_test(
            symbols=["BTC-USD"],
            strategies=["ma_cross", "rsi"],
            days=30
        )
        
    elif choice == "2":
        # 종합 테스트
        print("\n🔬 종합 테스트 실행 중...")
        results = runner.run_comprehensive_test(
            symbols=["BTC-USD", "ETH-USD"],
            strategies=["ma_cross", "rsi", "bollinger"],
            days=90
        )
        
    elif choice == "3":
        # 커스텀 테스트
        print("\n🎯 커스텀 테스트 설정")
        symbol = input("심볼 (예: BTC-USD): ").strip() or "BTC-USD"
        strategy = input("전략 (예: ma_cross): ").strip() or "ma_cross"
        days = int(input("테스트 기간 (일): ").strip() or "60")
        
        config = BacktestConfig(
            symbol=symbol,
            strategy_name=strategy,
            strategy_params={},
            start_date=(datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d"),
            end_date=datetime.now().strftime("%Y-%m-%d"),
            initial_balance=1000.0,
            leverage=200,
            commission_per_lot=0.1,
            spread_points=0.5,
            lot_size=0.01
        )
        
        results = runner.run_custom_test([config])
        
    elif choice == "4":
        # 전략 정보
        strategies = runner.strategy_loader.get_available_strategies()
        print(f"\n📋 사용 가능한 전략: {len(strategies)}개")
        for strategy in strategies:
            try:
                info = runner.strategy_loader.get_strategy_info(strategy)
                print(f"\n🔍 {strategy}:")
                print(f"   - 설명: {info['description']}")
                print(f"   - 파라미터: {list(info['parameters'].keys())}")
            except Exception as e:
                print(f"❌ {strategy} 정보 조회 실패: {e}")
        
        return
    
    else:
        print("❌ 잘못된 선택입니다.")
        return
    
    # 리포트 생성
    if 'results' in locals():
        runner.generate_report(results)
        print(f"\n🎉 백테스트 완료! 결과가 {runner.engine.results_dir} 폴더에 저장되었습니다.")

if __name__ == "__main__":
    main()
