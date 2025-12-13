#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
기본 백테스트 엔진 인터페이스
"""

from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional
from dataclasses import dataclass


@dataclass
class BacktestResult:
    """백테스트 결과"""
    symbol: str
    timeframe: str
    parameters: Dict[str, Any]
    metrics: Dict[str, float]
    trades: Optional[List[Dict]] = None
    equity_curve: Optional[List[float]] = None


class BaseBacktestEngine(ABC):
    """기본 백테스트 엔진 인터페이스"""
    
    def __init__(self, code: str):
        """
        초기화
        
        Args:
            code: 전략 코드 (Pine Script 또는 MT5)
        """
        self.code = code
        self.parsed_strategy = None
    
    @abstractmethod
    def parse_strategy(self) -> Dict[str, Any]:
        """
        전략 코드 파싱
        
        Returns:
            파싱된 전략 정보
        """
        pass
    
    @abstractmethod
    def extract_parameters(self) -> List[Dict[str, Any]]:
        """
        파라미터 추출
        
        Returns:
            파라미터 정보 리스트
        """
        pass
    
    @abstractmethod
    def run_backtest(self, 
                    symbol: str, 
                    timeframe: str, 
                    parameters: Dict[str, Any],
                    start_date: Optional[str] = None,
                    end_date: Optional[str] = None) -> BacktestResult:
        """
        백테스트 실행
        
        Args:
            symbol: 심볼명
            timeframe: 시간프레임
            parameters: 파라미터 딕셔너리
            start_date: 시작 날짜 (YYYY-MM-DD)
            end_date: 종료 날짜 (YYYY-MM-DD)
            
        Returns:
            백테스트 결과
        """
        pass
    
    def optimize_parameters(self,
                           symbol: str,
                           timeframe: str,
                           param_ranges: Dict[str, Dict[str, float]],
                           method: str = 'grid_search',
                           max_combinations: int = 1000) -> List[BacktestResult]:
        """
        파라미터 최적화
        
        Args:
            symbol: 심볼명
            timeframe: 시간프레임
            param_ranges: 파라미터 범위 딕셔너리
            method: 최적화 방법 ('grid_search' 또는 'random_search')
            max_combinations: 최대 조합 수 (random_search용)
            
        Returns:
            백테스트 결과 리스트 (수익률 기준 정렬)
        """
        # 파라미터 조합 생성
        if method == 'grid_search':
            combinations = self._generate_grid_combinations(param_ranges)
        else:
            combinations = self._generate_random_combinations(param_ranges, max_combinations)
        
        # 각 조합에 대해 백테스트 실행
        results = []
        for i, params in enumerate(combinations):
            try:
                result = self.run_backtest(symbol, timeframe, params)
                results.append(result)
            except Exception as e:
                print(f"백테스트 실패 (조합 {i+1}/{len(combinations)}): {e}")
                continue
        
        # 수익률 기준으로 정렬
        results.sort(key=lambda x: x.metrics.get('total_return', 0), reverse=True)
        
        return results
    
    def _generate_grid_combinations(self, param_ranges: Dict[str, Dict[str, float]]) -> List[Dict[str, Any]]:
        """그리드 서치 조합 생성"""
        import itertools
        
        param_names = list(param_ranges.keys())
        param_values = []
        
        for param_name in param_names:
            range_info = param_ranges[param_name]
            min_val = range_info['min']
            max_val = range_info['max']
            step = range_info['step']
            
            # 값 리스트 생성
            values = []
            current = min_val
            while current <= max_val:
                values.append(current)
                current += step
            
            param_values.append(values)
        
        # 모든 조합 생성
        combinations = []
        for combo in itertools.product(*param_values):
            params = dict(zip(param_names, combo))
            combinations.append(params)
        
        return combinations
    
    def _generate_random_combinations(self, 
                                     param_ranges: Dict[str, Dict[str, float]], 
                                     max_count: int) -> List[Dict[str, Any]]:
        """랜덤 서치 조합 생성"""
        import random
        
        combinations = []
        
        for _ in range(max_count):
            params = {}
            for param_name, range_info in param_ranges.items():
                min_val = range_info['min']
                max_val = range_info['max']
                step = range_info['step']
                
                # 랜덤 값 생성
                if range_info.get('type') == 'int':
                    value = random.randint(int(min_val), int(max_val))
                    value = (value // int(step)) * int(step)  # step에 맞춤
                else:
                    value = random.uniform(min_val, max_val)
                    value = round(value / step) * step  # step에 맞춤
                
                params[param_name] = value
            
            combinations.append(params)
        
        return combinations

