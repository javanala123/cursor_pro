#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MT5 백테스트 엔진
MetaTrader 5를 사용하여 백테스트 수행
"""

from typing import Dict, List, Any, Optional
import pandas as pd
import numpy as np

from .base_engine import BaseBacktestEngine, BacktestResult
from ..parsers.mt5_parser import MT5CodeParser

try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
except ImportError:
    MT5_AVAILABLE = False
    print("경고: MetaTrader5 라이브러리가 설치되지 않았습니다.")


class MT5Engine(BaseBacktestEngine):
    """MT5 백테스트 엔진"""
    
    def __init__(self, code: str):
        super().__init__(code)
        self.parser = MT5CodeParser()
        self.parsed_strategy = None
        self.mt5_connected = False
        
        if MT5_AVAILABLE:
            self._connect_mt5()
    
    def _connect_mt5(self):
        """MT5 연결"""
        if not MT5_AVAILABLE:
            return False
        
        try:
            if not mt5.initialize():
                print(f"MT5 초기화 실패: {mt5.last_error()}")
                return False
            
            self.mt5_connected = True
            return True
        except Exception as e:
            print(f"MT5 연결 오류: {e}")
            return False
    
    def __del__(self):
        """소멸자 - MT5 연결 해제"""
        if MT5_AVAILABLE and self.mt5_connected:
            mt5.shutdown()
    
    def parse_strategy(self) -> Dict[str, Any]:
        """전략 코드 파싱"""
        if not self.parsed_strategy:
            self.parsed_strategy = {
                'code': self.code,
                'parameters': self.extract_parameters()
            }
        return self.parsed_strategy
    
    def extract_parameters(self) -> List[Dict[str, Any]]:
        """파라미터 추출"""
        return self.parser.parse(self.code)
    
    def run_backtest(self, 
                    symbol: str, 
                    timeframe: str, 
                    parameters: Dict[str, Any],
                    start_date: Optional[str] = None,
                    end_date: Optional[str] = None) -> BacktestResult:
        """
        백테스트 실행
        
        주의: 실제 MT5 Strategy Tester API는 복잡하므로,
        여기서는 히스토리컬 데이터를 가져와서 시뮬레이션합니다.
        실제 구현 시 MT5 Strategy Tester API가 필요합니다.
        """
        # 데이터 가져오기
        data = self._get_historical_data(symbol, timeframe, start_date, end_date)
        
        if data.empty:
            raise ValueError(f"데이터를 가져올 수 없습니다: {symbol}")
        
        # 백테스트 시뮬레이션
        result = self._simulate_backtest(data, symbol, timeframe, parameters)
        
        return result
    
    def _get_historical_data(self, 
                            symbol: str, 
                            timeframe: str,
                            start_date: Optional[str] = None,
                            end_date: Optional[str] = None) -> pd.DataFrame:
        """히스토리컬 데이터 가져오기"""
        if not self.mt5_connected:
            # MT5가 연결되지 않은 경우 빈 DataFrame 반환
            print("MT5가 연결되지 않았습니다. 시뮬레이션 모드로 실행합니다.")
            return pd.DataFrame()
        
        try:
            # MT5 시간프레임 변환
            mt5_timeframe = self._convert_timeframe(timeframe)
            
            # 날짜 변환
            from datetime import datetime
            if start_date:
                date_from = datetime.strptime(start_date, '%Y-%m-%d')
            else:
                from datetime import timedelta
                date_from = datetime.now() - timedelta(days=365)
            
            if end_date:
                date_to = datetime.strptime(end_date, '%Y-%m-%d')
            else:
                date_to = datetime.now()
            
            # 데이터 가져오기
            rates = mt5.copy_rates_range(symbol, mt5_timeframe, date_from, date_to)
            
            if rates is None or len(rates) == 0:
                print(f"MT5 데이터 가져오기 실패: {mt5.last_error()}")
                return pd.DataFrame()
            
            # DataFrame으로 변환
            data = pd.DataFrame(rates)
            data['time'] = pd.to_datetime(data['time'], unit='s')
            data.set_index('time', inplace=True)
            data.columns = ['Open', 'High', 'Low', 'Close', 'Tick Volume', 'Spread', 'Real Volume']
            
            return data[['Open', 'High', 'Low', 'Close', 'Volume']]
            
        except Exception as e:
            print(f"MT5 데이터 가져오기 오류: {e}")
            return pd.DataFrame()
    
    def _convert_timeframe(self, timeframe: str):
        """시간프레임 변환"""
        if not MT5_AVAILABLE:
            return None
        
        tf_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'M30': mt5.TIMEFRAME_M30,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4,
            'D1': mt5.TIMEFRAME_D1,
            'W1': mt5.TIMEFRAME_W1,
        }
        return tf_map.get(timeframe, mt5.TIMEFRAME_H1)
    
    def _simulate_backtest(self, 
                          data: pd.DataFrame,
                          symbol: str,
                          timeframe: str,
                          parameters: Dict[str, Any]) -> BacktestResult:
        """
        백테스트 시뮬레이션
        
        실제 MT5 EA 실행 대신 간단한 시뮬레이션을 수행합니다.
        """
        # TradingView 엔진과 유사한 로직 사용
        # 실제 구현 시 MT5 Strategy Tester API 사용
        
        if data.empty:
            # 데이터가 없는 경우 시뮬레이션
            import random
            return BacktestResult(
                symbol=symbol,
                timeframe=timeframe,
                parameters=parameters,
                metrics={
                    'total_return': random.uniform(-10, 30),
                    'win_rate': random.uniform(40, 70),
                    'sharpe_ratio': random.uniform(0, 2),
                    'max_drawdown': random.uniform(5, 25),
                    'total_trades': random.randint(10, 100)
                }
            )
        
        # 간단한 이동평균 전략 시뮬레이션
        length = parameters.get('LongBBLength', parameters.get('length', 20))
        if length is None:
            length = 20
        
        if len(data) > length:
            data['MA'] = data['Close'].rolling(window=int(length)).mean()
            data['Signal'] = np.where(data['Close'] > data['MA'], 1, -1)
            data['Position'] = data['Signal'].diff()
            
            # 거래 시뮬레이션
            trades = []
            position = 0
            entry_price = 0
            equity = 10000
            equity_curve = [equity]
            
            for i in range(1, len(data)):
                if data['Position'].iloc[i] != 0:
                    if position != 0:
                        exit_price = data['Close'].iloc[i]
                        pnl = (exit_price - entry_price) * position
                        equity += pnl
                        trades.append({
                            'entry_price': entry_price,
                            'exit_price': exit_price,
                            'pnl': pnl
                        })
                    
                    position = data['Signal'].iloc[i]
                    entry_price = data['Close'].iloc[i]
                
                equity_curve.append(equity)
            
            # 성과 지표 계산
            total_return = ((equity - 10000) / 10000) * 100
            winning_trades = [t for t in trades if t['pnl'] > 0]
            win_rate = (len(winning_trades) / len(trades) * 100) if trades else 0
            
            returns = np.diff(equity_curve) / equity_curve[:-1] * 100
            sharpe_ratio = np.mean(returns) / (np.std(returns) + 1e-10) * np.sqrt(252) if len(returns) > 0 else 0
            
            peak = equity_curve[0]
            max_drawdown = 0
            for value in equity_curve:
                if value > peak:
                    peak = value
                drawdown = ((peak - value) / peak) * 100
                if drawdown > max_drawdown:
                    max_drawdown = drawdown
            
            metrics = {
                'total_return': total_return,
                'win_rate': win_rate,
                'sharpe_ratio': sharpe_ratio,
                'max_drawdown': max_drawdown,
                'total_trades': len(trades),
                'winning_trades': len(winning_trades),
                'losing_trades': len(trades) - len(winning_trades),
                'profit_factor': sum([t['pnl'] for t in winning_trades]) / 
                               (abs(sum([t['pnl'] for t in trades if t['pnl'] < 0])) + 1e-10)
            }
            
            return BacktestResult(
                symbol=symbol,
                timeframe=timeframe,
                parameters=parameters,
                metrics=metrics,
                trades=trades,
                equity_curve=equity_curve
            )
        else:
            return BacktestResult(
                symbol=symbol,
                timeframe=timeframe,
                parameters=parameters,
                metrics={
                    'total_return': 0,
                    'win_rate': 0,
                    'sharpe_ratio': 0,
                    'max_drawdown': 0,
                    'total_trades': 0
                }
            )

