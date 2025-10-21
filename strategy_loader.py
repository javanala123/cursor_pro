#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🎯 전략 동적 로딩 시스템
다양한 전략을 동적으로 로드하고 관리합니다.

작성자: AI Trading System
버전: 1.0
날짜: 2024-12-31
"""

import os
import sys
import importlib
import inspect
import json
from typing import Dict, List, Any, Callable, Type, Optional
from dataclasses import dataclass
from abc import ABC, abstractmethod
import pandas as pd
import numpy as np
import logging

logger = logging.getLogger(__name__)

class BaseStrategy(ABC):
    """전략 기본 클래스"""
    
    def __init__(self, **params):
        """초기화"""
        self.params = params
        self.name = self.__class__.__name__
    
    @abstractmethod
    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        """
        신호 생성
        
        Args:
            data: 과거 데이터
            current_row: 현재 행
            open_positions: 오픈 포지션
            
        Returns:
            신호 딕셔너리 또는 None
        """
        pass
    
    def get_info(self) -> Dict:
        """전략 정보 반환"""
        return {
            "name": self.name,
            "params": self.params,
            "description": self.__doc__ or "No description available"
        }

# =============================================================================
# 기본 전략들
# =============================================================================

class MovingAverageCrossStrategy(BaseStrategy):
    """이동평균 교차 전략"""
    
    def __init__(self, fast_period: int = 10, slow_period: int = 20, **kwargs):
        super().__init__(fast_period=fast_period, slow_period=slow_period, **kwargs)
        self.fast_period = fast_period
        self.slow_period = slow_period
    
    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        """이동평균 교차 신호 생성"""
        if len(data) < self.slow_period:
            return None
        
        # 이동평균 계산
        ma_fast = data['Close'].rolling(window=self.fast_period).mean()
        ma_slow = data['Close'].rolling(window=self.slow_period).mean()
        
        if len(ma_fast) < 2 or len(ma_slow) < 2:
            return None
        
        # 골든 크로스 (상승 신호)
        if (ma_fast.iloc[-1] > ma_slow.iloc[-1] and 
            ma_fast.iloc[-2] <= ma_slow.iloc[-2]):
            return {'action': 'BUY', 'volume': 0.01}
        
        # 데드 크로스 (하락 신호)
        if (ma_fast.iloc[-1] < ma_slow.iloc[-1] and 
            ma_fast.iloc[-2] >= ma_slow.iloc[-2]):
            return {'action': 'SELL', 'volume': 0.01}
        
        return None

class RSIStrategy(BaseStrategy):
    """RSI 전략"""
    
    def __init__(self, period: int = 14, overbought: float = 70.0, oversold: float = 30.0, **kwargs):
        super().__init__(period=period, overbought=overbought, oversold=oversold, **kwargs)
        self.period = period
        self.overbought = overbought
        self.oversold = oversold
    
    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        """RSI 신호 생성"""
        if len(data) < self.period + 1:
            return None
        
        # RSI 계산
        delta = data['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=self.period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=self.period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        
        if len(rsi) < 1 or pd.isna(rsi.iloc[-1]):
            return None
        
        current_rsi = rsi.iloc[-1]
        
        # 과매도에서 반등 (매수 신호)
        if current_rsi < self.oversold:
            return {'action': 'BUY', 'volume': 0.01}
        
        # 과매수에서 하락 (매도 신호)
        if current_rsi > self.overbought:
            return {'action': 'SELL', 'volume': 0.01}
        
        return None

class BollingerBandsStrategy(BaseStrategy):
    """볼린저 밴드 전략"""
    
    def __init__(self, period: int = 20, deviation: float = 2.0, **kwargs):
        super().__init__(period=period, deviation=deviation, **kwargs)
        self.period = period
        self.deviation = deviation
    
    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        """볼린저 밴드 신호 생성"""
        if len(data) < self.period:
            return None
        
        # 볼린저 밴드 계산
        sma = data['Close'].rolling(window=self.period).mean()
        std = data['Close'].rolling(window=self.period).std()
        upper_band = sma + (std * self.deviation)
        lower_band = sma - (std * self.deviation)
        
        if len(upper_band) < 1 or len(lower_band) < 1:
            return None
        
        current_price = current_row['Close']
        current_upper = upper_band.iloc[-1]
        current_lower = lower_band.iloc[-1]
        
        # 하단 터치 후 반등 (매수 신호)
        if current_price <= current_lower:
            return {'action': 'BUY', 'volume': 0.01}
        
        # 상단 터치 후 하락 (매도 신호)
        if current_price >= current_upper:
            return {'action': 'SELL', 'volume': 0.01}
        
        return None

class MACDStrategy(BaseStrategy):
    """MACD 전략"""
    
    def __init__(self, fast_period: int = 12, slow_period: int = 26, signal_period: int = 9, **kwargs):
        super().__init__(fast_period=fast_period, slow_period=slow_period, signal_period=signal_period, **kwargs)
        self.fast_period = fast_period
        self.slow_period = slow_period
        self.signal_period = signal_period
    
    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        """MACD 신호 생성"""
        if len(data) < self.slow_period + self.signal_period:
            return None
        
        # MACD 계산
        ema_fast = data['Close'].ewm(span=self.fast_period).mean()
        ema_slow = data['Close'].ewm(span=self.slow_period).mean()
        macd_line = ema_fast - ema_slow
        signal_line = macd_line.ewm(span=self.signal_period).mean()
        histogram = macd_line - signal_line
        
        if len(histogram) < 2:
            return None
        
        # MACD 히스토그램이 0선을 상향 돌파 (매수 신호)
        if (histogram.iloc[-1] > 0 and histogram.iloc[-2] <= 0):
            return {'action': 'BUY', 'volume': 0.01}
        
        # MACD 히스토그램이 0선을 하향 돌파 (매도 신호)
        if (histogram.iloc[-1] < 0 and histogram.iloc[-2] >= 0):
            return {'action': 'SELL', 'volume': 0.01}
        
        return None

class StochasticStrategy(BaseStrategy):
    """스토캐스틱 전략"""
    
    def __init__(self, k_period: int = 14, d_period: int = 3, overbought: float = 80.0, oversold: float = 20.0, **kwargs):
        super().__init__(k_period=k_period, d_period=d_period, overbought=overbought, oversold=oversold, **kwargs)
        self.k_period = k_period
        self.d_period = d_period
        self.overbought = overbought
        self.oversold = oversold
    
    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        """스토캐스틱 신호 생성"""
        if len(data) < self.k_period:
            return None
        
        # 스토캐스틱 계산
        low_min = data['Low'].rolling(window=self.k_period).min()
        high_max = data['High'].rolling(window=self.k_period).max()
        k_percent = 100 * ((data['Close'] - low_min) / (high_max - low_min))
        d_percent = k_percent.rolling(window=self.d_period).mean()
        
        if len(k_percent) < 1 or len(d_percent) < 1:
            return None
        
        current_k = k_percent.iloc[-1]
        current_d = d_percent.iloc[-1]
        
        # 과매도에서 반등 (매수 신호)
        if current_k < self.oversold and current_d < self.oversold:
            return {'action': 'BUY', 'volume': 0.01}
        
        # 과매수에서 하락 (매도 신호)
        if current_k > self.overbought and current_d > self.overbought:
            return {'action': 'SELL', 'volume': 0.01}
        
        return None

class CombinedStrategy(BaseStrategy):
    """복합 전략 (여러 지표 조합)"""
    
    def __init__(self, ma_fast: int = 10, ma_slow: int = 20, rsi_period: int = 14, 
                 rsi_overbought: float = 70.0, rsi_oversold: float = 30.0, **kwargs):
        super().__init__(ma_fast=ma_fast, ma_slow=ma_slow, rsi_period=rsi_period, 
                        rsi_overbought=rsi_overbought, rsi_oversold=rsi_oversold, **kwargs)
        self.ma_fast = ma_fast
        self.ma_slow = ma_slow
        self.rsi_period = rsi_period
        self.rsi_overbought = rsi_overbought
        self.rsi_oversold = rsi_oversold
    
    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        """복합 신호 생성"""
        if len(data) < max(self.ma_slow, self.rsi_period):
            return None
        
        # 이동평균 신호
        ma_fast = data['Close'].rolling(window=self.ma_fast).mean()
        ma_slow = data['Close'].rolling(window=self.ma_slow).mean()
        
        # RSI 신호
        delta = data['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=self.rsi_period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=self.rsi_period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        
        if len(ma_fast) < 2 or len(ma_slow) < 2 or len(rsi) < 1:
            return None
        
        # 이동평균 교차 확인
        ma_bullish = ma_fast.iloc[-1] > ma_slow.iloc[-1] and ma_fast.iloc[-2] <= ma_slow.iloc[-2]
        ma_bearish = ma_fast.iloc[-1] < ma_slow.iloc[-1] and ma_fast.iloc[-2] >= ma_slow.iloc[-2]
        
        # RSI 확인
        rsi_oversold = rsi.iloc[-1] < self.rsi_oversold
        rsi_overbought = rsi.iloc[-1] > self.rsi_overbought
        
        # 복합 매수 신호: MA 골든크로스 + RSI 과매도
        if ma_bullish and rsi_oversold:
            return {'action': 'BUY', 'volume': 0.01}
        
        # 복합 매도 신호: MA 데드크로스 + RSI 과매수
        if ma_bearish and rsi_overbought:
            return {'action': 'SELL', 'volume': 0.01}
        
        return None

class UTBotStrategy(BaseStrategy):
    """UT Bot 간소화 전략 (ATR 기반 트레일링 스탑)
    - params:
      atr_period: ATR 기간
      factor: 키값(배수)
      ma_period: 필터용 이동평균 기간(선택)
    """
    def __init__(self, atr_period: int = 10, factor: float = 1.0, ma_period: int = 0, **kwargs):
        super().__init__(atr_period=atr_period, factor=factor, ma_period=ma_period, **kwargs)
        self.atr_period = atr_period
        self.factor = factor
        self.ma_period = ma_period
        self._last_trend = None  # 'long' or 'short'
        self._trail = None

    def _atr(self, data: pd.DataFrame, period: int) -> pd.Series:
        high = data['High']
        low = data['Low']
        close = data['Close']
        prev_close = close.shift(1)
        tr = pd.concat([
            (high - low),
            (high - prev_close).abs(),
            (low - prev_close).abs()
        ], axis=1).max(axis=1)
        return tr.rolling(window=period).mean()

    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        if len(data) < max(3, self.atr_period + 1):
            return None

        atr = self._atr(data, self.atr_period)
        if pd.isna(atr.iloc[-1]):
            return None

        price = current_row['Close']
        trail_long = price - self.factor * atr.iloc[-1]
        trail_short = price + self.factor * atr.iloc[-1]

        # 선택적 추세 필터
        if self.ma_period and self.ma_period > 0 and len(data) >= self.ma_period:
            ma = data['Close'].rolling(self.ma_period).mean().iloc[-1]
        else:
            ma = None

        signal = None

        if self._last_trend is None:
            # 초기 추세 설정
            self._last_trend = 'long' if (ma is None or price >= ma) else 'short'
            self._trail = trail_long if self._last_trend == 'long' else trail_short
            return None

        if self._last_trend == 'long':
            # 롱 트레일 갱신
            self._trail = max(self._trail, trail_long) if self._trail is not None else trail_long
            # 롱 유지, 트레일 하향 이탈 시 숏 전환
            if price < self._trail:
                self._last_trend = 'short'
                self._trail = trail_short
                signal = {'action': 'SELL', 'volume': 0.01}
        else:
            # 숏 트레일 갱신
            self._trail = min(self._trail, trail_short) if self._trail is not None else trail_short
            # 숏 유지, 트레일 상향 돌파 시 롱 전환
            if price > self._trail:
                self._last_trend = 'long'
                self._trail = trail_long
                signal = {'action': 'BUY', 'volume': 0.01}

        return signal

class StrategyLoader:
    """전략 로더"""
    
    def __init__(self, strategies_dir: str = "strategies"):
        """
        초기화
        
        Args:
            strategies_dir: 전략 디렉토리
        """
        self.strategies_dir = strategies_dir
        self.strategies = {}
        self.strategy_classes = {}
        
        # 기본 전략 등록
        self._register_builtin_strategies()
        
        # 외부 전략 로드
        self._load_external_strategies()
    
    def _register_builtin_strategies(self):
        """내장 전략 등록"""
        builtin_strategies = {
            'ma_cross': MovingAverageCrossStrategy,
            'rsi': RSIStrategy,
            'bollinger': BollingerBandsStrategy,
            'macd': MACDStrategy,
            'stochastic': StochasticStrategy,
            'combined': CombinedStrategy,
            'ut_bot': UTBotStrategy
        }
        
        for name, strategy_class in builtin_strategies.items():
            self.strategy_classes[name] = strategy_class
            logger.info(f"📝 내장 전략 등록: {name}")
    
    def _load_external_strategies(self):
        """외부 전략 로드"""
        if not os.path.exists(self.strategies_dir):
            os.makedirs(self.strategies_dir)
            logger.info(f"📁 전략 디렉토리 생성: {self.strategies_dir}")
            return
        
        # 전략 파일 스캔
        for filename in os.listdir(self.strategies_dir):
            if filename.endswith('.py') and not filename.startswith('__'):
                try:
                    self._load_strategy_file(filename)
                except Exception as e:
                    logger.error(f"❌ 전략 로드 실패: {filename} - {e}")
    
    def _load_strategy_file(self, filename: str):
        """전략 파일 로드"""
        module_name = filename[:-3]  # .py 제거
        module_path = os.path.join(self.strategies_dir, filename)
        
        # 모듈 로드
        spec = importlib.util.spec_from_file_location(module_name, module_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        
        # 전략 클래스 찾기
        for name, obj in inspect.getmembers(module, inspect.isclass):
            if (issubclass(obj, BaseStrategy) and 
                obj != BaseStrategy and 
                not inspect.isabstract(obj)):
                
                self.strategy_classes[module_name] = obj
                logger.info(f"📝 외부 전략 로드: {module_name}")
    
    def create_strategy(self, name: str, **params) -> BaseStrategy:
        """
        전략 인스턴스 생성
        
        Args:
            name: 전략 이름
            **params: 전략 파라미터
            
        Returns:
            전략 인스턴스
        """
        if name not in self.strategy_classes:
            raise ValueError(f"등록되지 않은 전략: {name}")
        
        strategy_class = self.strategy_classes[name]
        return strategy_class(**params)
    
    def get_available_strategies(self) -> List[str]:
        """사용 가능한 전략 목록 반환"""
        return list(self.strategy_classes.keys())
    
    def get_strategy_info(self, name: str) -> Dict:
        """전략 정보 반환"""
        if name not in self.strategy_classes:
            raise ValueError(f"등록되지 않은 전략: {name}")
        
        strategy_class = self.strategy_classes[name]
        
        # 파라미터 정보 추출
        sig = inspect.signature(strategy_class.__init__)
        params = {}
        for param_name, param in sig.parameters.items():
            if param_name != 'self' and param_name != 'kwargs':
                params[param_name] = {
                    'type': param.annotation if param.annotation != inspect.Parameter.empty else 'Any',
                    'default': param.default if param.default != inspect.Parameter.empty else None,
                    'required': param.default == inspect.Parameter.empty
                }
        
        return {
            'name': name,
            'class': strategy_class.__name__,
            'description': strategy_class.__doc__ or "No description available",
            'parameters': params
        }
    
    def generate_strategy_combinations(self, 
                                     symbols: List[str],
                                     strategies: List[str],
                                     param_ranges: Dict[str, Dict[str, List]]) -> List[Dict]:
        """
        전략 조합 생성
        
        Args:
            symbols: 심볼 리스트
            strategies: 전략 리스트
            param_ranges: 파라미터 범위
            
        Returns:
            전략 조합 리스트
        """
        combinations = []
        
        for symbol in symbols:
            for strategy_name in strategies:
                if strategy_name not in self.strategy_classes:
                    continue
                
                # 파라미터 조합 생성
                param_combinations = self._generate_param_combinations(strategy_name, param_ranges.get(strategy_name, {}))
                
                for params in param_combinations:
                    combinations.append({
                        'symbol': symbol,
                        'strategy': strategy_name,
                        'params': params
                    })
        
        logger.info(f"🎯 전략 조합 생성: {len(combinations)}개")
        return combinations
    
    def _generate_param_combinations(self, strategy_name: str, param_ranges: Dict[str, List]) -> List[Dict]:
        """파라미터 조합 생성"""
        if not param_ranges:
            return [{}]
        
        import itertools
        
        # 파라미터 이름과 값 리스트
        param_names = list(param_ranges.keys())
        param_values = list(param_ranges.values())
        
        # 모든 조합 생성
        combinations = []
        for combination in itertools.product(*param_values):
            params = dict(zip(param_names, combination))
            combinations.append(params)
        
        return combinations
    
    def save_strategy_template(self, strategy_name: str, filename: str = None):
        """전략 템플릿 저장"""
        if filename is None:
            filename = f"{strategy_name}_template.py"
        
        template = f'''#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
{strategy_name.upper()} 전략 템플릿
사용자 정의 전략을 구현하세요.
"""

import pandas as pd
import numpy as np
from strategy_loader import BaseStrategy
from typing import Dict, Optional

class {strategy_name.title()}Strategy(BaseStrategy):
    """사용자 정의 {strategy_name} 전략"""
    
    def __init__(self, param1: float = 10.0, param2: float = 20.0, **kwargs):
        super().__init__(param1=param1, param2=param2, **kwargs)
        self.param1 = param1
        self.param2 = param2
    
    def generate_signal(self, data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
        """
        신호 생성 로직을 구현하세요
        
        Args:
            data: 과거 데이터
            current_row: 현재 행
            open_positions: 오픈 포지션
            
        Returns:
            신호 딕셔너리 또는 None
            예: {{'action': 'BUY', 'volume': 0.01}}
        """
        # 여기에 전략 로직을 구현하세요
        
        # 예시: 간단한 가격 기반 전략
        if len(data) < 2:
            return None
        
        current_price = current_row['Close']
        previous_price = data['Close'].iloc[-2]
        
        # 가격 상승 시 매수
        if current_price > previous_price * 1.01:  # 1% 상승
            return {{'action': 'BUY', 'volume': 0.01}}
        
        # 가격 하락 시 매도
        if current_price < previous_price * 0.99:  # 1% 하락
            return {{'action': 'SELL', 'volume': 0.01}}
        
        return None
'''
        
        filepath = os.path.join(self.strategies_dir, filename)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(template)
        
        logger.info(f"📝 전략 템플릿 저장: {filepath}")

def main():
    """메인 실행 함수"""
    print("🎯 전략 로더 시스템 시작!")
    print("=" * 60)
    
    # 전략 로더 초기화
    loader = StrategyLoader()
    
    # 사용 가능한 전략 목록
    strategies = loader.get_available_strategies()
    print(f"📋 사용 가능한 전략: {len(strategies)}개")
    for strategy in strategies:
        print(f"   - {strategy}")
    
    # 전략 정보 출력
    print("\n📊 전략 상세 정보:")
    for strategy_name in strategies[:3]:  # 처음 3개만 출력
        try:
            info = loader.get_strategy_info(strategy_name)
            print(f"\n🔍 {strategy_name}:")
            print(f"   - 설명: {info['description']}")
            print(f"   - 파라미터: {list(info['parameters'].keys())}")
        except Exception as e:
            print(f"❌ {strategy_name} 정보 조회 실패: {e}")
    
    print("\n✅ 전략 로더 시스템 준비 완료!")

if __name__ == "__main__":
    main()
