#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
볼린저 밴드 전략 파라미터 최적화 메인 실행 스크립트

사용법:
    python run_optimization.py --symbol ES --timeframe H1 --method grid_search
    python run_optimization.py --category futures --method random_search --iterations 1000
"""

import argparse
import yaml
import json
import os
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional

# 로컬 모듈 import
sys.path.append(str(Path(__file__).parent))
from strategy_parser.pine_script_parser import parse_pine_script_file
from strategy_parser.mt5_code_parser import parse_mt5_file


class OptimizationRunner:
    """최적화 실행 클래스"""
    
    def __init__(self, config_path: str = "config/optimization_config.yaml"):
        """초기화"""
        self.config_path = config_path
        self.config = self._load_config()
        self.results_dir = Path("results")
        self.results_dir.mkdir(exist_ok=True)
        
    def _load_config(self) -> Dict:
        """설정 파일 로드"""
        with open(self.config_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    
    def run_optimization(self, 
                        symbol: str,
                        timeframe: str = "H1",
                        method: str = "grid_search",
                        iterations: int = 1000,
                        strategy_file: Optional[str] = None) -> Dict:
        """
        최적화 실행
        
        Args:
            symbol: 심볼명
            timeframe: 시간프레임
            method: 최적화 방법 (grid_search, random_search)
            iterations: 랜덤 서치 반복 횟수
            strategy_file: 전략 파일 경로 (Pine Script 또는 MT5)
            
        Returns:
            최적화 결과 딕셔너리
        """
        print("=" * 60)
        print("볼린저 밴드 전략 파라미터 최적화 시작")
        print("=" * 60)
        print(f"심볼: {symbol}")
        print(f"시간프레임: {timeframe}")
        print(f"방법: {method}")
        print(f"반복 횟수: {iterations}")
        print("=" * 60)
        
        # 전략 파일 파싱
        optimization_ranges = {}
        if strategy_file:
            print(f"\n전략 파일 파싱: {strategy_file}")
            if strategy_file.endswith('.pine'):
                parsed = parse_pine_script_file(strategy_file)
                optimization_ranges = parsed['optimization_ranges']
            elif strategy_file.endswith('.mq5'):
                parsed = parse_mt5_file(strategy_file)
                optimization_ranges = parsed['optimization_ranges']
            else:
                print("지원하지 않는 파일 형식입니다.")
                return {}
        else:
            # 기본 설정 사용
            optimization_ranges = self._get_default_ranges()
        
        print(f"\n최적화 파라미터: {len(optimization_ranges)}개")
        for param, range_info in optimization_ranges.items():
            print(f"  - {param}: {range_info}")
        
        # MT5 최적화 실행
        # 실제 구현 시 MT5 Strategy Tester API 호출
        print("\nMT5 Strategy Tester 실행 중...")
        print("(실제 구현 시 MT5 API를 통해 자동 실행)")
        
        # 결과 시뮬레이션 (실제 구현 시 제거)
        results = self._simulate_results(optimization_ranges, method, iterations)
        
        # 최적 파라미터 선정
        best_result = self._select_best_result(results)
        
        # 결과 저장
        self._save_results(symbol, timeframe, results, best_result)
        
        # 리포트 생성
        self._generate_report(symbol, timeframe, results, best_result)
        
        print("\n" + "=" * 60)
        print("최적화 완료!")
        print("=" * 60)
        print(f"\n최적 파라미터:")
        for key, value in best_result['parameters'].items():
            print(f"  {key}: {value}")
        print(f"\n성과 지표:")
        print(f"  총 수익률: {best_result['metrics']['total_return']:.2f}%")
        print(f"  승률: {best_result['metrics']['win_rate']:.2f}%")
        print(f"  샤프 비율: {best_result['metrics']['sharpe_ratio']:.2f}")
        print("=" * 60)
        
        return {
            'symbol': symbol,
            'timeframe': timeframe,
            'method': method,
            'best_result': best_result,
            'total_results': len(results)
        }
    
    def _get_default_ranges(self) -> Dict:
        """기본 최적화 범위 반환"""
        return self.config['optimization']['parameter_ranges']
    
    def _simulate_results(self, 
                         ranges: Dict, 
                         method: str, 
                         iterations: int) -> List[Dict]:
        """결과 시뮬레이션 (실제 구현 시 제거)"""
        import random
        results = []
        
        if method == "grid_search":
            # 그리드 서치 시뮬레이션
            total_combinations = 1
            for param, range_info in ranges.items():
                if 'min' in range_info and 'max' in range_info and 'step' in range_info:
                    count = int((range_info['max'] - range_info['min']) / range_info['step']) + 1
                    total_combinations *= count
            
            # 샘플링 (실제로는 모든 조합 테스트)
            sample_size = min(1000, total_combinations)
            for i in range(sample_size):
                params = {}
                for param, range_info in ranges.items():
                    if 'min' in range_info and 'max' in range_info:
                        value = random.uniform(range_info['min'], range_info['max'])
                        if 'step' in range_info:
                            value = round(value / range_info['step']) * range_info['step']
                        params[param] = value
                    else:
                        params[param] = range_info.get('default', 0)
                
                results.append({
                    'parameters': params,
                    'metrics': {
                        'total_return': random.uniform(-20, 50),
                        'win_rate': random.uniform(40, 70),
                        'sharpe_ratio': random.uniform(0, 3),
                        'profit_factor': random.uniform(0.5, 2.5),
                        'max_drawdown': random.uniform(5, 30),
                        'total_trades': random.randint(10, 200)
                    }
                })
        else:
            # 랜덤 서치
            for i in range(iterations):
                params = {}
                for param, range_info in ranges.items():
                    if 'min' in range_info and 'max' in range_info:
                        value = random.uniform(range_info['min'], range_info['max'])
                        if 'step' in range_info:
                            value = round(value / range_info['step']) * range_info['step']
                        params[param] = value
                    else:
                        params[param] = range_info.get('default', 0)
                
                results.append({
                    'parameters': params,
                    'metrics': {
                        'total_return': random.uniform(-20, 50),
                        'win_rate': random.uniform(40, 70),
                        'sharpe_ratio': random.uniform(0, 3),
                        'profit_factor': random.uniform(0.5, 2.5),
                        'max_drawdown': random.uniform(5, 30),
                        'total_trades': random.randint(10, 200)
                    }
                })
        
        return results
    
    def _select_best_result(self, results: List[Dict]) -> Dict:
        """최적 결과 선정 (수익률 기준)"""
        if not results:
            return {}
        
        best = results[0]
        for result in results:
            if result['metrics']['total_return'] > best['metrics']['total_return']:
                best = result
        
        return best
    
    def _save_results(self, 
                     symbol: str, 
                     timeframe: str, 
                     results: List[Dict], 
                     best_result: Dict):
        """결과 저장"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # JSON 형식으로 저장
        output_file = self.results_dir / f"{symbol}_{timeframe}_{timestamp}.json"
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump({
                'symbol': symbol,
                'timeframe': timeframe,
                'timestamp': timestamp,
                'best_result': best_result,
                'all_results': results[:100]  # 상위 100개만 저장
            }, f, indent=2, ensure_ascii=False)
        
        print(f"\n결과 저장: {output_file}")
    
    def _generate_report(self, 
                        symbol: str, 
                        timeframe: str, 
                        results: List[Dict], 
                        best_result: Dict):
        """리포트 생성"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = self.results_dir / f"report_{symbol}_{timeframe}_{timestamp}.txt"
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("=" * 60 + "\n")
            f.write("볼린저 밴드 전략 최적화 리포트\n")
            f.write("=" * 60 + "\n\n")
            f.write(f"심볼: {symbol}\n")
            f.write(f"시간프레임: {timeframe}\n")
            f.write(f"생성 시간: {timestamp}\n")
            f.write(f"총 결과 수: {len(results)}\n\n")
            
            f.write("=" * 60 + "\n")
            f.write("최적 파라미터\n")
            f.write("=" * 60 + "\n")
            for key, value in best_result['parameters'].items():
                f.write(f"{key}: {value}\n")
            
            f.write("\n" + "=" * 60 + "\n")
            f.write("성과 지표\n")
            f.write("=" * 60 + "\n")
            for key, value in best_result['metrics'].items():
                f.write(f"{key}: {value}\n")
        
        print(f"리포트 생성: {report_file}")


def main():
    """메인 함수"""
    parser = argparse.ArgumentParser(description='볼린저 밴드 전략 파라미터 최적화')
    
    parser.add_argument('--symbol', type=str, help='심볼명 (예: ES, EURUSD)')
    parser.add_argument('--category', type=str, choices=['futures', 'crypto', 'forex'],
                       help='심볼 카테고리')
    parser.add_argument('--timeframe', type=str, default='H1',
                       help='시간프레임 (기본값: H1)')
    parser.add_argument('--method', type=str, choices=['grid_search', 'random_search'],
                       default='grid_search', help='최적화 방법')
    parser.add_argument('--iterations', type=int, default=1000,
                       help='랜덤 서치 반복 횟수')
    parser.add_argument('--strategy-file', type=str,
                       help='전략 파일 경로 (Pine Script 또는 MT5)')
    parser.add_argument('--config', type=str, default='config/optimization_config.yaml',
                       help='설정 파일 경로')
    
    args = parser.parse_args()
    
    # 심볼 확인
    if not args.symbol and not args.category:
        print("오류: --symbol 또는 --category를 지정해야 합니다.")
        return
    
    runner = OptimizationRunner(args.config)
    
    if args.category:
        # 카테고리별 최적화
        with open('config/symbol_categories.yaml', 'r', encoding='utf-8') as f:
            categories = yaml.safe_load(f)
        
        category_symbols = categories.get(args.category, {})
        if isinstance(category_symbols, dict):
            # 카테고리 내 하위 카테고리 처리
            for subcat, symbols in category_symbols.items():
                if isinstance(symbols, list):
                    for symbol_info in symbols:
                        symbol = symbol_info.get('symbol', symbol_info.get('mt5_symbol', ''))
                        if symbol:
                            print(f"\n{'='*60}")
                            print(f"카테고리: {args.category} > {subcat}")
                            print(f"심볼: {symbol}")
                            print(f"{'='*60}")
                            runner.run_optimization(
                                symbol=symbol,
                                timeframe=args.timeframe,
                                method=args.method,
                                iterations=args.iterations,
                                strategy_file=args.strategy_file
                            )
        else:
            print(f"카테고리 '{args.category}'를 찾을 수 없습니다.")
    else:
        # 단일 심볼 최적화
        runner.run_optimization(
            symbol=args.symbol,
            timeframe=args.timeframe,
            method=args.method,
            iterations=args.iterations,
            strategy_file=args.strategy_file
        )


if __name__ == '__main__':
    main()

