#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
전략 함수들 - 멀티프로세싱 직렬화를 위한 전역 함수들
"""

def create_ma_cross_strategy(**params):
    """이동평균 교차 전략 생성"""
    from strategy_loader import MovingAverageCrossStrategy
    return MovingAverageCrossStrategy(**params)

def create_rsi_strategy(**params):
    """RSI 전략 생성"""
    from strategy_loader import RSIStrategy
    return RSIStrategy(**params)

def create_bollinger_strategy(**params):
    """볼린저 밴드 전략 생성"""
    from strategy_loader import BollingerBandsStrategy
    return BollingerBandsStrategy(**params)

def create_macd_strategy(**params):
    """MACD 전략 생성"""
    from strategy_loader import MACDStrategy
    return MACDStrategy(**params)

def create_stochastic_strategy(**params):
    """스토캐스틱 전략 생성"""
    from strategy_loader import StochasticStrategy
    return StochasticStrategy(**params)

def create_combined_strategy(**params):
    """복합 전략 생성"""
    from strategy_loader import CombinedStrategy
    return CombinedStrategy(**params)

def create_ut_bot_strategy(**params):
    """UT Bot 전략 생성"""
    from strategy_loader import UTBotStrategy
    return UTBotStrategy(**params)
