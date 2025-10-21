#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
프로페셔널 백테스트 시스템
- 다중 심볼, 다중 시간프레임, 다중 전략 파라미터 최적화
- 정확한 수수료, 스프레드, 슬리피지 계산
- 리스크 관리 및 포지션 사이징
- 상세한 성과 분석 및 리포팅
"""

import pandas as pd
import numpy as np
import yfinance as yf
import json
import os
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass, asdict
from concurrent.futures import ProcessPoolExecutor, as_completed
import multiprocessing as mp
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('professional_backtest.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class TradingConfig:
    """거래 설정"""
    symbol: str
    timeframe: str  # '1m', '5m', '15m', '30m', '1h', '4h', '1d'
    strategy_name: str
    strategy_params: Dict[str, Any]
    start_date: str
    end_date: str
    initial_balance: float = 10000.0
    leverage: int = 200
    commission_per_lot: float = 0.1
    spread_points: float = 0.5
    lot_size: float = 0.01
    max_risk_per_trade: float = 0.02  # 2% 리스크
    max_daily_trades: int = 10
    max_concurrent_positions: int = 3

@dataclass
class Trade:
    """개별 거래 정보"""
    symbol: str
    type: str  # 'BUY' or 'SELL'
    volume: float
    entry_price: float
    exit_price: float
    entry_time: str
    exit_time: str
    profit: float
    commission: float
    spread_cost: float
    net_profit: float
    risk_amount: float
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None

@dataclass
class BacktestResult:
    """백테스트 결과"""
    config: TradingConfig
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate: float
    total_profit: float
    total_commission: float
    total_spread_cost: float
    net_profit: float
    max_drawdown: float
    max_drawdown_percentage: float
    profit_factor: float
    sharpe_ratio: float
    sortino_ratio: float
    calmar_ratio: float
    recovery_factor: float
    average_win: float
    average_loss: float
    largest_win: float
    largest_loss: float
    consecutive_wins: int
    consecutive_losses: int
    execution_time: float
    trades: List[Trade]
    equity_curve: List[float]
    drawdown_curve: List[float]
    monthly_returns: Dict[str, float]
    daily_returns: List[float]

class ProfessionalBacktestEngine:
    """프로페셔널 백테스트 엔진"""
    
    def __init__(self, data_dir: str = "professional_data"):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(exist_ok=True)
        
        # 심볼별 데이터 캐시
        self.data_cache = {}
        
        # 거래 시간 설정 (UTC 기준)
        self.trading_hours = {
            'forex': {'start': '00:00', 'end': '23:59'},  # 24시간
            'crypto': {'start': '00:00', 'end': '23:59'},  # 24시간
            'stocks': {'start': '09:30', 'end': '16:00'}   # 미국 주식시장
        }
    
    def download_data(self, symbols: List[str], timeframes: List[str], 
                     start_date: str, end_date: str) -> None:
        """다중 심볼, 다중 시간프레임 데이터 다운로드"""
        logger.info(f"📊 데이터 다운로드 시작: {len(symbols)}개 심볼 × {len(timeframes)}개 시간프레임")
        
        for symbol in symbols:
            for timeframe in timeframes:
                try:
                    # yfinance 심볼 변환
                    yf_symbol = self._convert_symbol(symbol)
                    
                    # 데이터 다운로드
                    ticker = yf.Ticker(yf_symbol)
                    data = ticker.history(
                        start=start_date,
                        end=end_date,
                        interval=self._convert_timeframe(timeframe)
                    )
                    
                    if data.empty:
                        logger.warning(f"⚠️ 데이터 없음: {symbol} {timeframe}")
                        continue
                    
                    # 데이터 정리
                    data = self._clean_data(data)

                    # 인덱스 타임존 제거 (tz-aware → tz-naive)
                    try:
                        if getattr(data.index, 'tz', None) is not None:
                            # UTC로 정규화 후 타임존 제거
                            data.index = data.index.tz_convert('UTC').tz_localize(None)
                    except Exception:
                        # tz_convert 불가한 경우 바로 tz 정보 제거 시도
                        try:
                            data.index = data.index.tz_localize(None)
                        except Exception:
                            pass
                    
                    # 파일 저장
                    filename = f"{symbol.replace('-', '_')}_{timeframe}_{start_date}_{end_date}.csv"
                    filepath = self.data_dir / filename
                    data.to_csv(filepath)
                    
                    logger.info(f"✅ {symbol} {timeframe}: {len(data)}개 바 저장")
                    
                except Exception as e:
                    logger.error(f"❌ 데이터 다운로드 실패: {symbol} {timeframe} - {e}")
    
    def _convert_symbol(self, symbol: str) -> str:
        """심볼 변환"""
        symbol_map = {
            'BTC-USD': 'BTC-USD',
            'ETH-USD': 'ETH-USD',
            'EURUSD': 'EURUSD=X',
            'GBPUSD': 'GBPUSD=X',
            'USDJPY': 'USDJPY=X',
            'AUDUSD': 'AUDUSD=X',
            'USDCAD': 'USDCAD=X',
            'NZDUSD': 'NZDUSD=X',
            'USDCHF': 'USDCHF=X',
            'XAUUSD': 'GC=F',  # 금
            'XAGUSD': 'SI=F',  # 은
            'SPX500': '^GSPC',  # S&P 500
            'NAS100': '^IXIC',  # NASDAQ
            'UK100': '^FTSE',   # FTSE 100
            'GER30': '^GDAXI',  # DAX
        }
        return symbol_map.get(symbol, symbol)
    
    def _convert_timeframe(self, timeframe: str) -> str:
        """시간프레임 변환"""
        timeframe_map = {
            '1m': '1m',
            '5m': '5m',
            '15m': '15m',
            '30m': '30m',
            '1h': '1h',
            '4h': '4h',
            '1d': '1d'
        }
        return timeframe_map.get(timeframe, '1d')
    
    def _clean_data(self, data: pd.DataFrame) -> pd.DataFrame:
        """데이터 정리"""
        # 컬럼명 정규화
        data.columns = [col.lower().replace(' ', '_') for col in data.columns]
        
        # 필수 컬럼 확인
        required_columns = ['open', 'high', 'low', 'close', 'volume']
        for col in required_columns:
            if col not in data.columns:
                logger.error(f"필수 컬럼 누락: {col}")
                return pd.DataFrame()
        
        # 결측값 제거
        data = data.dropna()
        
        # 가격 데이터 정리
        for col in ['open', 'high', 'low', 'close']:
            data[col] = pd.to_numeric(data[col], errors='coerce')
        
        # 볼륨 데이터 정리
        data['volume'] = pd.to_numeric(data['volume'], errors='coerce').fillna(0)
        
        # 이상값 제거 (가격이 0이거나 음수인 경우)
        for col in ['open', 'high', 'low', 'close']:
            data = data[data[col] > 0]
        
        # High >= Low 확인
        data = data[data['high'] >= data['low']]
        
        return data
    
    def load_data(self, symbol: str, timeframe: str, 
                 start_date: str, end_date: str) -> pd.DataFrame:
        """데이터 로드"""
        # 캐시 확인
        cache_key = f"{symbol}_{timeframe}_{start_date}_{end_date}"
        if cache_key in self.data_cache:
            return self.data_cache[cache_key]
        
        # 파일 찾기
        pattern = f"{symbol.replace('-', '_')}_{timeframe}_*.csv"
        files = list(self.data_dir.glob(pattern))
        
        if not files:
            raise FileNotFoundError(f"데이터 파일 없음: {symbol} {timeframe}")
        
        # 가장 최근 파일 사용
        latest_file = max(files, key=os.path.getctime)
        
        # 데이터 로드
        data = pd.read_csv(latest_file, index_col=0, parse_dates=True)

        # 인덱스 타임존 제거 (tz-aware → tz-naive) - 비교 시 오류 방지
        try:
            if getattr(data.index, 'tz', None) is not None:
                data.index = data.index.tz_localize(None)
        except Exception:
            pass
        
        # 날짜 필터링
        start_dt = pd.to_datetime(start_date)
        end_dt = pd.to_datetime(end_date)
        data = data[(data.index >= start_dt) & (data.index <= end_dt)]
        
        if data.empty:
            raise ValueError(f"지정 기간 데이터 없음: {start_date} ~ {end_date}")
        
        # 캐시 저장
        self.data_cache[cache_key] = data
        
        logger.info(f"📊 데이터 로드: {symbol} {timeframe} ({len(data)}개 바)")
        return data
    
    def run_backtest(self, config: TradingConfig) -> BacktestResult:
        """백테스트 실행"""
        start_time = time.time()
        
        try:
            # 데이터 로드
            data = self.load_data(
                config.symbol, config.timeframe,
                config.start_date, config.end_date
            )
            
            # 전략 실행
            trades, equity_curve = self._execute_strategy(data, config)
            
            # 결과 계산
            result = self._calculate_results(trades, equity_curve, config, start_time)
            
            logger.info(f"✅ 백테스트 완료: {config.symbol} {config.timeframe} {config.strategy_name}")
            return result
            
        except Exception as e:
            logger.error(f"❌ 백테스트 실패: {config.symbol} {config.timeframe} {config.strategy_name} - {e}")
            raise
    
    def _execute_strategy(self, data: pd.DataFrame, config: TradingConfig) -> Tuple[List[Trade], List[float]]:
        """전략 실행"""
        trades = []
        equity_curve = [config.initial_balance]
        current_balance = config.initial_balance
        open_positions = []
        
        # 전략별 신호 생성
        signals = self._generate_signals(data, config)
        
        for i, (timestamp, row) in enumerate(data.iterrows()):
            # 기존 포지션 체크
            self._check_existing_positions(
                open_positions, row, trades, config, timestamp
            )
            
            # 새 신호 체크
            if i < len(signals) and signals.iloc[i] != 0:
                signal = signals.iloc[i]
                
                # 포지션 제한 체크
                if len(open_positions) >= config.max_concurrent_positions:
                    continue
                
                # 일일 거래 제한 체크
                today_trades = [t for t in trades if t.entry_time.startswith(timestamp.strftime('%Y-%m-%d'))]
                if len(today_trades) >= config.max_daily_trades:
                    continue
                
                # 새 포지션 진입
                if signal > 0:  # 매수
                    self._enter_position(
                        'BUY', row, open_positions, config, timestamp, current_balance
                    )
                elif signal < 0:  # 매도
                    self._enter_position(
                        'SELL', row, open_positions, config, timestamp, current_balance
                    )
            
            # 잔고 업데이트
            current_balance = self._calculate_current_balance(open_positions, row, config.initial_balance)
            equity_curve.append(current_balance)
        
        # 남은 포지션 청산
        for position in open_positions:
            self._close_position(position, data.iloc[-1], trades, config, data.index[-1])
        
        return trades, equity_curve
    
    def _generate_signals(self, data: pd.DataFrame, config: TradingConfig) -> pd.Series:
        """전략별 신호 생성"""
        strategy_name = config.strategy_name
        params = config.strategy_params
        
        if strategy_name == 'ma_cross':
            return self._ma_cross_signals(data, params)
        elif strategy_name == 'rsi':
            return self._rsi_signals(data, params)
        elif strategy_name == 'bollinger':
            return self._bollinger_signals(data, params)
        elif strategy_name == 'macd':
            return self._macd_signals(data, params)
        elif strategy_name == 'stochastic':
            return self._stochastic_signals(data, params)
        elif strategy_name == 'combined':
            return self._combined_signals(data, params)
        else:
            raise ValueError(f"알 수 없는 전략: {strategy_name}")
    
    def _ma_cross_signals(self, data: pd.DataFrame, params: Dict) -> pd.Series:
        """이동평균 교차 전략"""
        fast_period = params.get('fast_period', 10)
        slow_period = params.get('slow_period', 20)
        
        fast_ma = data['close'].rolling(window=fast_period).mean()
        slow_ma = data['close'].rolling(window=slow_period).mean()
        
        signals = pd.Series(0, index=data.index)
        signals[fast_ma > slow_ma] = 1   # 매수
        signals[fast_ma < slow_ma] = -1  # 매도
        
        # 교차점에서만 신호 발생
        cross_up = (fast_ma > slow_ma) & (fast_ma.shift(1) <= slow_ma.shift(1))
        cross_down = (fast_ma < slow_ma) & (fast_ma.shift(1) >= slow_ma.shift(1))
        
        signals = pd.Series(0, index=data.index)
        signals[cross_up] = 1
        signals[cross_down] = -1
        
        return signals
    
    def _rsi_signals(self, data: pd.DataFrame, params: Dict) -> pd.Series:
        """RSI 전략"""
        period = params.get('period', 14)
        oversold = params.get('oversold', 30)
        overbought = params.get('overbought', 70)
        
        delta = data['close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        
        signals = pd.Series(0, index=data.index)
        signals[rsi < oversold] = 1   # 매수
        signals[rsi > overbought] = -1  # 매도
        
        return signals
    
    def _bollinger_signals(self, data: pd.DataFrame, params: Dict) -> pd.Series:
        """볼린저 밴드 전략"""
        period = params.get('period', 20)
        std_dev = params.get('std_dev', 2)
        
        sma = data['close'].rolling(window=period).mean()
        std = data['close'].rolling(window=period).std()
        upper_band = sma + (std * std_dev)
        lower_band = sma - (std * std_dev)
        
        signals = pd.Series(0, index=data.index)
        signals[data['close'] < lower_band] = 1   # 매수
        signals[data['close'] > upper_band] = -1  # 매도
        
        return signals
    
    def _macd_signals(self, data: pd.DataFrame, params: Dict) -> pd.Series:
        """MACD 전략"""
        fast_period = params.get('fast_period', 12)
        slow_period = params.get('slow_period', 26)
        signal_period = params.get('signal_period', 9)
        
        ema_fast = data['close'].ewm(span=fast_period).mean()
        ema_slow = data['close'].ewm(span=slow_period).mean()
        macd = ema_fast - ema_slow
        signal_line = macd.ewm(span=signal_period).mean()
        
        signals = pd.Series(0, index=data.index)
        signals[macd > signal_line] = 1   # 매수
        signals[macd < signal_line] = -1  # 매도
        
        return signals
    
    def _stochastic_signals(self, data: pd.DataFrame, params: Dict) -> pd.Series:
        """스토캐스틱 전략"""
        k_period = params.get('k_period', 14)
        d_period = params.get('d_period', 3)
        oversold = params.get('oversold', 20)
        overbought = params.get('overbought', 80)
        
        low_min = data['low'].rolling(window=k_period).min()
        high_max = data['high'].rolling(window=k_period).max()
        k_percent = 100 * ((data['close'] - low_min) / (high_max - low_min))
        d_percent = k_percent.rolling(window=d_period).mean()
        
        signals = pd.Series(0, index=data.index)
        signals[(k_percent < oversold) & (d_percent < oversold)] = 1   # 매수
        signals[(k_percent > overbought) & (d_percent > overbought)] = -1  # 매도
        
        return signals
    
    def _combined_signals(self, data: pd.DataFrame, params: Dict) -> pd.Series:
        """복합 전략"""
        # 여러 지표의 신호를 조합
        ma_signals = self._ma_cross_signals(data, params.get('ma_params', {}))
        rsi_signals = self._rsi_signals(data, params.get('rsi_params', {}))
        bb_signals = self._bollinger_signals(data, params.get('bb_params', {}))
        
        # 신호 조합 (모든 신호가 일치할 때만 거래)
        combined = pd.Series(0, index=data.index)
        combined[(ma_signals == 1) & (rsi_signals == 1) & (bb_signals == 1)] = 1
        combined[(ma_signals == -1) & (rsi_signals == -1) & (bb_signals == -1)] = -1
        
        return combined
    
    def _enter_position(self, position_type: str, row: pd.Series, 
                       open_positions: List, config: TradingConfig, 
                       timestamp: pd.Timestamp, current_balance: float) -> None:
        """포지션 진입"""
        # 포지션 크기 계산 (리스크 기반)
        risk_amount = current_balance * config.max_risk_per_trade
        
        # 진입 가격 (스프레드 고려)
        if position_type == 'BUY':
            entry_price = row['close'] + (config.spread_points / 2)
        else:
            entry_price = row['close'] - (config.spread_points / 2)
        
        # 포지션 크기 계산
        volume = risk_amount / (entry_price * config.lot_size)
        volume = min(volume, config.lot_size * 10)  # 최대 10랏 제한
        
        # 포지션 생성
        position = {
            'type': position_type,
            'volume': volume,
            'entry_price': entry_price,
            'entry_time': timestamp,
            'risk_amount': risk_amount,
            'stop_loss': self._calculate_stop_loss(position_type, entry_price, config),
            'take_profit': self._calculate_take_profit(position_type, entry_price, config)
        }
        
        open_positions.append(position)
    
    def _check_existing_positions(self, open_positions: List, row: pd.Series,
                                trades: List[Trade], config: TradingConfig,
                                timestamp: pd.Timestamp) -> None:
        """기존 포지션 체크"""
        positions_to_close = []
        
        for position in open_positions:
            should_close = False
            exit_price = 0
            
            # 손절/익절 체크
            if position['type'] == 'BUY':
                if position['stop_loss'] and row['low'] <= position['stop_loss']:
                    should_close = True
                    exit_price = position['stop_loss']
                elif position['take_profit'] and row['high'] >= position['take_profit']:
                    should_close = True
                    exit_price = position['take_profit']
            else:  # SELL
                if position['stop_loss'] and row['high'] >= position['stop_loss']:
                    should_close = True
                    exit_price = position['stop_loss']
                elif position['take_profit'] and row['low'] <= position['take_profit']:
                    should_close = True
                    exit_price = position['take_profit']
            
            if should_close:
                self._close_position(position, row, trades, config, timestamp, exit_price)
                positions_to_close.append(position)
        
        # 포지션 제거
        for position in positions_to_close:
            open_positions.remove(position)
    
    def _close_position(self, position: Dict, row: pd.Series, trades: List[Trade],
                       config: TradingConfig, timestamp: pd.Timestamp,
                       exit_price: Optional[float] = None) -> None:
        """포지션 청산"""
        if exit_price is None:
            # 시장가 청산
            if position['type'] == 'BUY':
                exit_price = row['close'] - (config.spread_points / 2)
            else:
                exit_price = row['close'] + (config.spread_points / 2)
        
        # 수익 계산
        if position['type'] == 'BUY':
            profit = (exit_price - position['entry_price']) * position['volume']
        else:
            profit = (position['entry_price'] - exit_price) * position['volume']
        
        # 수수료 계산
        commission = position['volume'] * config.commission_per_lot
        
        # 스프레드 비용
        spread_cost = position['volume'] * config.spread_points
        
        # 순수익
        net_profit = profit - commission - spread_cost
        
        # 거래 생성
        trade = Trade(
            symbol=config.symbol,
            type=position['type'],
            volume=position['volume'],
            entry_price=position['entry_price'],
            exit_price=exit_price,
            entry_time=position['entry_time'].strftime('%Y-%m-%d %H:%M:%S'),
            exit_time=timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            profit=profit,
            commission=commission,
            spread_cost=spread_cost,
            net_profit=net_profit,
            risk_amount=position['risk_amount'],
            stop_loss=position.get('stop_loss'),
            take_profit=position.get('take_profit')
        )
        
        trades.append(trade)
    
    def _calculate_stop_loss(self, position_type: str, entry_price: float, 
                           config: TradingConfig) -> float:
        """손절가 계산"""
        atr_period = config.strategy_params.get('atr_period', 14)
        stop_multiplier = config.strategy_params.get('stop_multiplier', 2.0)
        
        # 간단한 ATR 기반 손절 (실제로는 데이터에서 계산해야 함)
        stop_distance = entry_price * 0.01 * stop_multiplier  # 1% * 배수
        
        if position_type == 'BUY':
            return entry_price - stop_distance
        else:
            return entry_price + stop_distance
    
    def _calculate_take_profit(self, position_type: str, entry_price: float,
                             config: TradingConfig) -> float:
        """익절가 계산"""
        risk_reward_ratio = config.strategy_params.get('risk_reward_ratio', 2.0)
        
        # 손절 거리 계산
        stop_distance = entry_price * 0.01 * config.strategy_params.get('stop_multiplier', 2.0)
        profit_distance = stop_distance * risk_reward_ratio
        
        if position_type == 'BUY':
            return entry_price + profit_distance
        else:
            return entry_price - profit_distance
    
    def _calculate_current_balance(self, open_positions: List, row: pd.Series,
                                 initial_balance: float) -> float:
        """현재 잔고 계산"""
        unrealized_pnl = 0
        
        for position in open_positions:
            if position['type'] == 'BUY':
                unrealized_pnl += (row['close'] - position['entry_price']) * position['volume']
            else:
                unrealized_pnl += (position['entry_price'] - row['close']) * position['volume']
        
        return initial_balance + unrealized_pnl
    
    def _calculate_results(self, trades: List[Trade], equity_curve: List[float],
                          config: TradingConfig, start_time: float) -> BacktestResult:
        """결과 계산"""
        if not trades:
            return self._create_empty_result(config, start_time)
        
        # 기본 통계
        total_trades = len(trades)
        winning_trades = len([t for t in trades if t.net_profit > 0])
        losing_trades = len([t for t in trades if t.net_profit < 0])
        win_rate = winning_trades / total_trades if total_trades > 0 else 0
        
        # 수익 통계
        total_profit = sum(t.profit for t in trades)
        total_commission = sum(t.commission for t in trades)
        total_spread_cost = sum(t.spread_cost for t in trades)
        net_profit = sum(t.net_profit for t in trades)
        
        # 드로우다운 계산
        equity_series = pd.Series(equity_curve)
        rolling_max = equity_series.expanding().max()
        drawdown = equity_series - rolling_max
        max_drawdown = drawdown.min()
        max_drawdown_percentage = max_drawdown / config.initial_balance
        
        # 수익 팩터
        gross_profit = sum(t.net_profit for t in trades if t.net_profit > 0)
        gross_loss = abs(sum(t.net_profit for t in trades if t.net_profit < 0))
        profit_factor = gross_profit / gross_loss if gross_loss > 0 else float('inf')
        
        # 샤프 비율
        daily_returns = pd.Series(equity_curve).pct_change().dropna()
        sharpe_ratio = daily_returns.mean() / daily_returns.std() * np.sqrt(252) if daily_returns.std() > 0 else 0
        
        # 소르티노 비율
        negative_returns = daily_returns[daily_returns < 0]
        downside_std = negative_returns.std() if len(negative_returns) > 0 else 0
        sortino_ratio = daily_returns.mean() / downside_std * np.sqrt(252) if downside_std > 0 else 0
        
        # 칼마 비율
        calmar_ratio = (net_profit / config.initial_balance) / abs(max_drawdown_percentage) if max_drawdown_percentage != 0 else 0
        
        # 복구 팩터
        recovery_factor = net_profit / abs(max_drawdown) if max_drawdown != 0 else 0
        
        # 거래 통계
        winning_trades_list = [t for t in trades if t.net_profit > 0]
        losing_trades_list = [t for t in trades if t.net_profit < 0]
        
        average_win = np.mean([t.net_profit for t in winning_trades_list]) if winning_trades_list else 0
        average_loss = np.mean([t.net_profit for t in losing_trades_list]) if losing_trades_list else 0
        largest_win = max([t.net_profit for t in trades]) if trades else 0
        largest_loss = min([t.net_profit for t in trades]) if trades else 0
        
        # 연속 승/패
        consecutive_wins, consecutive_losses = self._calculate_consecutive_trades(trades)
        
        # 월별 수익률
        monthly_returns = self._calculate_monthly_returns(equity_curve)
        
        return BacktestResult(
            config=config,
            total_trades=total_trades,
            winning_trades=winning_trades,
            losing_trades=losing_trades,
            win_rate=win_rate,
            total_profit=total_profit,
            total_commission=total_commission,
            total_spread_cost=total_spread_cost,
            net_profit=net_profit,
            max_drawdown=max_drawdown,
            max_drawdown_percentage=max_drawdown_percentage,
            profit_factor=profit_factor,
            sharpe_ratio=sharpe_ratio,
            sortino_ratio=sortino_ratio,
            calmar_ratio=calmar_ratio,
            recovery_factor=recovery_factor,
            average_win=average_win,
            average_loss=average_loss,
            largest_win=largest_win,
            largest_loss=largest_loss,
            consecutive_wins=consecutive_wins,
            consecutive_losses=consecutive_losses,
            execution_time=time.time() - start_time,
            trades=trades,
            equity_curve=equity_curve,
            drawdown_curve=drawdown.tolist(),
            monthly_returns=monthly_returns,
            daily_returns=daily_returns.tolist()
        )
    
    def _create_empty_result(self, config: TradingConfig, start_time: float) -> BacktestResult:
        """빈 결과 생성"""
        return BacktestResult(
            config=config,
            total_trades=0,
            winning_trades=0,
            losing_trades=0,
            win_rate=0,
            total_profit=0,
            total_commission=0,
            total_spread_cost=0,
            net_profit=0,
            max_drawdown=0,
            max_drawdown_percentage=0,
            profit_factor=0,
            sharpe_ratio=0,
            sortino_ratio=0,
            calmar_ratio=0,
            recovery_factor=0,
            average_win=0,
            average_loss=0,
            largest_win=0,
            largest_loss=0,
            consecutive_wins=0,
            consecutive_losses=0,
            execution_time=time.time() - start_time,
            trades=[],
            equity_curve=[config.initial_balance],
            drawdown_curve=[0],
            monthly_returns={},
            daily_returns=[]
        )
    
    def _calculate_consecutive_trades(self, trades: List[Trade]) -> Tuple[int, int]:
        """연속 승/패 계산"""
        if not trades:
            return 0, 0
        
        max_consecutive_wins = 0
        max_consecutive_losses = 0
        current_wins = 0
        current_losses = 0
        
        for trade in trades:
            if trade.net_profit > 0:
                current_wins += 1
                current_losses = 0
                max_consecutive_wins = max(max_consecutive_wins, current_wins)
            else:
                current_losses += 1
                current_wins = 0
                max_consecutive_losses = max(max_consecutive_losses, current_losses)
        
        return max_consecutive_wins, max_consecutive_losses
    
    def _calculate_monthly_returns(self, equity_curve: List[float]) -> Dict[str, float]:
        """월별 수익률 계산"""
        # 간단한 구현 (실제로는 날짜 정보가 필요)
        monthly_returns = {}
        
        if len(equity_curve) >= 30:  # 최소 30일 데이터
            monthly_returns['month_1'] = (equity_curve[-1] - equity_curve[0]) / equity_curve[0]
        
        return monthly_returns

class ParameterOptimizer:
    """파라미터 최적화기"""
    
    def __init__(self, engine: ProfessionalBacktestEngine):
        self.engine = engine
    
    def optimize_strategy(self, base_config: TradingConfig, 
                         param_ranges: Dict[str, List]) -> List[BacktestResult]:
        """전략 파라미터 최적화"""
        logger.info(f"🔧 파라미터 최적화 시작: {base_config.strategy_name}")
        
        # 파라미터 조합 생성
        param_combinations = self._generate_param_combinations(param_ranges)
        logger.info(f"📊 총 {len(param_combinations)}개 조합 생성")
        
        # 백테스트 실행
        results = []
        for i, params in enumerate(param_combinations):
            try:
                config = TradingConfig(
                    symbol=base_config.symbol,
                    timeframe=base_config.timeframe,
                    strategy_name=base_config.strategy_name,
                    strategy_params=params,
                    start_date=base_config.start_date,
                    end_date=base_config.end_date,
                    initial_balance=base_config.initial_balance,
                    leverage=base_config.leverage,
                    commission_per_lot=base_config.commission_per_lot,
                    spread_points=base_config.spread_points,
                    lot_size=base_config.lot_size,
                    max_risk_per_trade=base_config.max_risk_per_trade,
                    max_daily_trades=base_config.max_daily_trades,
                    max_concurrent_positions=base_config.max_concurrent_positions
                )
                
                result = self.engine.run_backtest(config)
                results.append(result)
                
                if (i + 1) % 10 == 0:
                    logger.info(f"📈 진행률: {i + 1}/{len(param_combinations)}")
                    
            except Exception as e:
                logger.error(f"❌ 최적화 실패: {params} - {e}")
        
        # 결과 정렬 (샤프 비율 기준)
        results.sort(key=lambda x: x.sharpe_ratio, reverse=True)
        
        logger.info(f"✅ 최적화 완료: {len(results)}개 결과")
        return results
    
    def _generate_param_combinations(self, param_ranges: Dict[str, List]) -> List[Dict]:
        """파라미터 조합 생성"""
        import itertools
        
        keys = list(param_ranges.keys())
        values = list(param_ranges.values())
        
        combinations = []
        for combo in itertools.product(*values):
            combinations.append(dict(zip(keys, combo)))
        
        return combinations

class ProfessionalBacktestRunner:
    """프로페셔널 백테스트 실행기"""
    
    def __init__(self):
        self.engine = ProfessionalBacktestEngine()
        self.optimizer = ParameterOptimizer(self.engine)
        self.results_dir = Path("professional_results")
        self.results_dir.mkdir(exist_ok=True)
    
    def run_comprehensive_backtest(self) -> None:
        """종합 백테스트 실행"""
        logger.info("🚀 프로페셔널 백테스트 시스템 시작!")
        
        # 1. 데이터 다운로드
        self._download_all_data()
        
        # 2. 전략별 최적화 실행
        self._run_strategy_optimization()
        
        # 3. 결과 분석 및 리포팅
        self._generate_final_report()
        
        logger.info("🎉 프로페셔널 백테스트 완료!")
    
    def _download_all_data(self) -> None:
        """모든 데이터 다운로드"""
        symbols = ['BTC-USD', 'ETH-USD', 'EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD']
        timeframes = ['1h', '4h', '1d']
        
        start_date = '2020-01-01'
        end_date = '2024-12-31'
        
        logger.info("📊 데이터 다운로드 시작...")
        self.engine.download_data(symbols, timeframes, start_date, end_date)
        logger.info("✅ 데이터 다운로드 완료!")
    
    def _run_strategy_optimization(self) -> None:
        """전략별 최적화 실행"""
        strategies = {
            'ma_cross': {
                'fast_period': [5, 10, 15, 20],
                'slow_period': [20, 30, 40, 50],
                'atr_period': [14, 20],
                'stop_multiplier': [1.5, 2.0, 2.5],
                'risk_reward_ratio': [1.5, 2.0, 2.5]
            },
            'rsi': {
                'period': [10, 14, 20],
                'oversold': [20, 30],
                'overbought': [70, 80],
                'atr_period': [14, 20],
                'stop_multiplier': [1.5, 2.0, 2.5],
                'risk_reward_ratio': [1.5, 2.0, 2.5]
            },
            'bollinger': {
                'period': [15, 20, 25],
                'std_dev': [1.5, 2.0, 2.5],
                'atr_period': [14, 20],
                'stop_multiplier': [1.5, 2.0, 2.5],
                'risk_reward_ratio': [1.5, 2.0, 2.5]
            },
            'macd': {
                'fast_period': [8, 12, 16],
                'slow_period': [21, 26, 31],
                'signal_period': [7, 9, 11],
                'atr_period': [14, 20],
                'stop_multiplier': [1.5, 2.0, 2.5],
                'risk_reward_ratio': [1.5, 2.0, 2.5]
            },
            'stochastic': {
                'k_period': [10, 14, 18],
                'd_period': [3, 5],
                'oversold': [15, 20, 25],
                'overbought': [75, 80, 85],
                'atr_period': [14, 20],
                'stop_multiplier': [1.5, 2.0, 2.5],
                'risk_reward_ratio': [1.5, 2.0, 2.5]
            }
        }
        
        symbols = ['BTC-USD', 'ETH-USD', 'EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD']
        timeframes = ['1h', '4h', '1d']
        
        all_results = []
        
        for symbol in symbols:
            for timeframe in timeframes:
                for strategy_name, param_ranges in strategies.items():
                    try:
                        logger.info(f"🔧 최적화: {symbol} {timeframe} {strategy_name}")
                        
                        base_config = TradingConfig(
                            symbol=symbol,
                            timeframe=timeframe,
                            strategy_name=strategy_name,
                            strategy_params={},
                            start_date='2023-01-01',
                            end_date='2024-12-31',
                            initial_balance=10000.0,
                            leverage=200,
                            commission_per_lot=0.1,
                            spread_points=0.5,
                            lot_size=0.01,
                            max_risk_per_trade=0.02,
                            max_daily_trades=10,
                            max_concurrent_positions=3
                        )
                        
                        results = self.optimizer.optimize_strategy(base_config, param_ranges)
                        
                        # 상위 10개 결과 저장
                        top_results = results[:10]
                        self._save_optimization_results(symbol, timeframe, strategy_name, top_results)
                        
                        all_results.extend(top_results)
                        
                    except Exception as e:
                        logger.error(f"❌ 최적화 실패: {symbol} {timeframe} {strategy_name} - {e}")
        
        # 전체 결과 저장
        self._save_all_results(all_results)
    
    def _save_optimization_results(self, symbol: str, timeframe: str, 
                                 strategy_name: str, results: List[BacktestResult]) -> None:
        """최적화 결과 저장"""
        filename = f"{symbol}_{timeframe}_{strategy_name}_optimization.json"
        filepath = self.results_dir / filename
        
        # 결과를 JSON 직렬화 가능한 형태로 변환
        serializable_results = []
        for result in results:
            result_dict = asdict(result)
            # Trade 객체들을 딕셔너리로 변환
            result_dict['trades'] = [asdict(trade) for trade in result.trades]
            serializable_results.append(result_dict)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(serializable_results, f, indent=2, ensure_ascii=False)
        
        logger.info(f"💾 결과 저장: {filename}")
    
    def _save_all_results(self, results: List[BacktestResult]) -> None:
        """전체 결과 저장"""
        # 결과를 수익률 순으로 정렬
        results.sort(key=lambda x: x.sharpe_ratio, reverse=True)
        
        # 상위 100개 결과만 저장
        top_results = results[:100]
        
        filename = "top_100_results.json"
        filepath = self.results_dir / filename
        
        serializable_results = []
        for result in top_results:
            result_dict = asdict(result)
            result_dict['trades'] = [asdict(trade) for trade in result.trades]
            serializable_results.append(result_dict)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(serializable_results, f, indent=2, ensure_ascii=False)
        
        logger.info(f"💾 전체 결과 저장: {filename}")
    
    def _generate_final_report(self) -> None:
        """최종 리포트 생성"""
        logger.info("📊 최종 리포트 생성 중...")
        
        # 결과 파일 로드
        results_file = self.results_dir / "top_100_results.json"
        if not results_file.exists():
            logger.error("❌ 결과 파일 없음")
            return
        
        with open(results_file, 'r', encoding='utf-8') as f:
            results = json.load(f)
        
        # 리포트 생성
        report = self._create_analysis_report(results)
        
        # 리포트 저장
        report_file = self.results_dir / "final_analysis_report.json"
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        logger.info(f"📋 최종 리포트 저장: {report_file}")
    
    def _create_analysis_report(self, results: List[Dict]) -> Dict:
        """분석 리포트 생성"""
        if not results:
            return {}
        
        # 기본 통계
        total_results = len(results)
        avg_sharpe = np.mean([r['sharpe_ratio'] for r in results])
        avg_profit_factor = np.mean([r['profit_factor'] for r in results])
        avg_win_rate = np.mean([r['win_rate'] for r in results])
        avg_max_drawdown = np.mean([r['max_drawdown_percentage'] for r in results])
        
        # 심볼별 분석
        symbol_analysis = {}
        for result in results:
            symbol = result['config']['symbol']
            if symbol not in symbol_analysis:
                symbol_analysis[symbol] = []
            symbol_analysis[symbol].append(result)
        
        # 전략별 분석
        strategy_analysis = {}
        for result in results:
            strategy = result['config']['strategy_name']
            if strategy not in strategy_analysis:
                strategy_analysis[strategy] = []
            strategy_analysis[strategy].append(result)
        
        # 시간프레임별 분석
        timeframe_analysis = {}
        for result in results:
            timeframe = result['config']['timeframe']
            if timeframe not in timeframe_analysis:
                timeframe_analysis[timeframe] = []
            timeframe_analysis[timeframe].append(result)
        
        # 상위 성과자
        top_performers = results[:20]
        
        report = {
            'summary': {
                'total_results': total_results,
                'average_sharpe_ratio': avg_sharpe,
                'average_profit_factor': avg_profit_factor,
                'average_win_rate': avg_win_rate,
                'average_max_drawdown': avg_max_drawdown,
                'generated_at': datetime.now().isoformat()
            },
            'top_performers': top_performers,
            'symbol_analysis': {
                symbol: {
                    'count': len(symbol_results),
                    'avg_sharpe': np.mean([r['sharpe_ratio'] for r in symbol_results]),
                    'avg_profit_factor': np.mean([r['profit_factor'] for r in symbol_results]),
                    'avg_win_rate': np.mean([r['win_rate'] for r in symbol_results]),
                    'best_result': max(symbol_results, key=lambda x: x['sharpe_ratio'])
                }
                for symbol, symbol_results in symbol_analysis.items()
            },
            'strategy_analysis': {
                strategy: {
                    'count': len(strategy_results),
                    'avg_sharpe': np.mean([r['sharpe_ratio'] for r in strategy_results]),
                    'avg_profit_factor': np.mean([r['profit_factor'] for r in strategy_results]),
                    'avg_win_rate': np.mean([r['win_rate'] for r in strategy_results]),
                    'best_result': max(strategy_results, key=lambda x: x['sharpe_ratio'])
                }
                for strategy, strategy_results in strategy_analysis.items()
            },
            'timeframe_analysis': {
                timeframe: {
                    'count': len(timeframe_results),
                    'avg_sharpe': np.mean([r['sharpe_ratio'] for r in timeframe_results]),
                    'avg_profit_factor': np.mean([r['profit_factor'] for r in timeframe_results]),
                    'avg_win_rate': np.mean([r['win_rate'] for r in timeframe_results]),
                    'best_result': max(timeframe_results, key=lambda x: x['sharpe_ratio'])
                }
                for timeframe, timeframe_results in timeframe_analysis.items()
            }
        }
        
        return report

if __name__ == "__main__":
    runner = ProfessionalBacktestRunner()
    runner.run_comprehensive_backtest()
