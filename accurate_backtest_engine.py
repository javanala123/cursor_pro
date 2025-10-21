#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🎯 정확한 백테스트 엔진
Exness 브로커의 실제 계약 크기와 동일한 조건으로 백테스트를 수행합니다.

작성자: AI Trading System
버전: 1.0
날짜: 2024-12-31
"""

import pandas as pd
import numpy as np
import json
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
import logging
from dataclasses import dataclass
from enum import Enum
import warnings
warnings.filterwarnings('ignore')

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('backtest_engine.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class OrderType(Enum):
    """주문 타입"""
    BUY = "BUY"
    SELL = "SELL"

class OrderStatus(Enum):
    """주문 상태"""
    PENDING = "PENDING"
    FILLED = "FILLED"
    CANCELLED = "CANCELLED"

@dataclass
class Trade:
    """거래 정보"""
    symbol: str
    order_type: OrderType
    volume: float  # 랏 수
    entry_price: float
    exit_price: float
    entry_time: datetime
    exit_time: datetime
    profit: float
    commission: float
    swap: float
    contract_size: float
    leverage: int
    
    @property
    def actual_volume_btc(self) -> float:
        """실제 거래된 BTC 양"""
        return self.volume * self.contract_size
    
    @property
    def profit_percentage(self) -> float:
        """수익률 (%)"""
        if self.order_type == OrderType.BUY:
            return ((self.exit_price - self.entry_price) / self.entry_price) * 100
        else:
            return ((self.entry_price - self.exit_price) / self.entry_price) * 100

@dataclass
class BacktestResult:
    """백테스트 결과"""
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate: float
    total_profit: float
    total_commission: float
    total_swap: float
    net_profit: float
    max_drawdown: float
    max_drawdown_percentage: float
    profit_factor: float
    sharpe_ratio: float
    trades: List[Trade]
    equity_curve: pd.DataFrame

class AccurateBacktestEngine:
    """정확한 백테스트 엔진"""
    
    def __init__(self, 
                 initial_balance: float = 1000.0,
                 leverage: int = 200,
                 commission_per_lot: float = 0.1,
                 spread_points: float = 0.5):
        """
        초기화
        
        Args:
            initial_balance: 초기 자본
            leverage: 레버리지
            commission_per_lot: 랏당 수수료 (USD)
            spread_points: 스프레드 (포인트)
        """
        self.initial_balance = initial_balance
        self.current_balance = initial_balance
        self.leverage = leverage
        self.commission_per_lot = commission_per_lot
        self.spread_points = spread_points
        
        # 거래 기록
        self.trades: List[Trade] = []
        self.equity_curve: List[Dict] = []
        self.open_positions: Dict[str, Trade] = {}
        
        # 통계
        self.total_commission = 0.0
        self.total_swap = 0.0
        
        logger.info(f"🎯 백테스트 엔진 초기화 완료")
        logger.info(f"   - 초기 자본: ${initial_balance:,.2f}")
        logger.info(f"   - 레버리지: 1:{leverage}")
        logger.info(f"   - 수수료: ${commission_per_lot}/랏")
        logger.info(f"   - 스프레드: {spread_points}포인트")
    
    def load_symbol_config(self, symbol: str) -> Dict:
        """심볼 설정 로드"""
        config_path = "historical_data/symbols_config.json"
        
        if not os.path.exists(config_path):
            logger.error(f"❌ 설정 파일을 찾을 수 없습니다: {config_path}")
            return {}
        
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        # 심볼 찾기
        for category, symbols in config.items():
            if symbol in symbols:
                symbol_config = symbols[symbol].copy()
                symbol_config['category'] = category
                return symbol_config
        
        logger.warning(f"⚠️ {symbol} 설정을 찾을 수 없습니다. 기본값 사용")
        return {
            'contract_size': 1.0,
            'min_lot': 0.01,
            'max_lot': 100.0,
            'leverage': self.leverage,
            'spread': self.spread_points,
            'commission': self.commission_per_lot
        }
    
    def calculate_margin_required(self, symbol: str, volume: float, price: float) -> float:
        """필요 증거금 계산"""
        config = self.load_symbol_config(symbol)
        contract_size = config.get('contract_size', 1.0)
        
        # 실제 거래 금액
        actual_volume = volume * contract_size
        trade_value = actual_volume * price
        
        # 필요 증거금 (레버리지 적용)
        margin_required = trade_value / self.leverage
        
        return margin_required
    
    def check_margin_requirement(self, symbol: str, volume: float, price: float) -> bool:
        """증거금 요구사항 확인"""
        margin_required = self.calculate_margin_required(symbol, volume, price)
        
        if margin_required > self.current_balance:
            logger.warning(f"⚠️ 증거금 부족: 필요 ${margin_required:.2f}, 보유 ${self.current_balance:.2f}")
            return False
        
        return True
    
    def open_position(self, 
                     symbol: str, 
                     order_type: OrderType, 
                     volume: float, 
                     price: float, 
                     timestamp: datetime) -> bool:
        """
        포지션 오픈
        
        Args:
            symbol: 심볼
            order_type: 주문 타입
            volume: 거래량 (랏)
            price: 가격
            timestamp: 시간
            
        Returns:
            성공 여부
        """
        # 증거금 확인
        if not self.check_margin_requirement(symbol, volume, price):
            return False
        
        # 스프레드 적용
        if order_type == OrderType.BUY:
            entry_price = price + (self.spread_points * 0.0001)  # 스프레드 추가
        else:
            entry_price = price - (self.spread_points * 0.0001)  # 스프레드 차감
        
        # 수수료 계산
        config = self.load_symbol_config(symbol)
        contract_size = config.get('contract_size', 1.0)
        actual_volume = volume * contract_size
        commission = volume * self.commission_per_lot
        
        # 거래 생성
        trade = Trade(
            symbol=symbol,
            order_type=order_type,
            volume=volume,
            entry_price=entry_price,
            exit_price=0.0,  # 나중에 설정
            entry_time=timestamp,
            exit_time=timestamp,  # 임시
            profit=0.0,  # 나중에 계산
            commission=commission,
            swap=0.0,  # 나중에 계산
            contract_size=contract_size,
            leverage=self.leverage
        )
        
        # 포지션 저장
        self.open_positions[symbol] = trade
        
        # 수수료 차감
        self.current_balance -= commission
        self.total_commission += commission
        
        logger.info(f"📈 포지션 오픈: {symbol} {order_type.value} {volume}랏 @ ${entry_price:.2f}")
        logger.info(f"   - 실제 거래량: {actual_volume} BTC")
        logger.info(f"   - 필요 증거금: ${self.calculate_margin_required(symbol, volume, price):.2f}")
        logger.info(f"   - 수수료: ${commission:.2f}")
        
        return True
    
    def close_position(self, symbol: str, price: float, timestamp: datetime) -> Optional[Trade]:
        """
        포지션 클로즈
        
        Args:
            symbol: 심볼
            price: 가격
            timestamp: 시간
            
        Returns:
            완료된 거래 또는 None
        """
        if symbol not in self.open_positions:
            logger.warning(f"⚠️ {symbol}에 대한 오픈 포지션이 없습니다.")
            return None
        
        trade = self.open_positions[symbol]
        
        # 스프레드 적용
        if trade.order_type == OrderType.BUY:
            exit_price = price - (self.spread_points * 0.0001)  # 스프레드 차감
        else:
            exit_price = price + (self.spread_points * 0.0001)  # 스프레드 추가
        
        # 수익 계산
        if trade.order_type == OrderType.BUY:
            price_diff = exit_price - trade.entry_price
        else:
            price_diff = trade.entry_price - exit_price
        
        # 실제 수익 (계약 크기 적용)
        actual_volume = trade.volume * trade.contract_size
        profit = price_diff * actual_volume
        
        # 수수료 차감
        commission = trade.volume * self.commission_per_lot
        
        # 거래 완료
        trade.exit_price = exit_price
        trade.exit_time = timestamp
        trade.profit = profit
        trade.commission = commission
        
        # 잔고 업데이트
        self.current_balance += profit - commission
        self.total_commission += commission
        
        # 거래 기록에 추가
        self.trades.append(trade)
        
        # 오픈 포지션에서 제거
        del self.open_positions[symbol]
        
        logger.info(f"📉 포지션 클로즈: {symbol} @ ${exit_price:.2f}")
        logger.info(f"   - 수익: ${profit:.2f}")
        logger.info(f"   - 수수료: ${commission:.2f}")
        logger.info(f"   - 순수익: ${profit - commission:.2f}")
        logger.info(f"   - 현재 잔고: ${self.current_balance:.2f}")
        
        return trade
    
    def update_equity_curve(self, timestamp: datetime):
        """자본 곡선 업데이트"""
        # 오픈 포지션의 미실현 손익 계산
        unrealized_pnl = 0.0
        for symbol, trade in self.open_positions.items():
            # 현재 가격은 마지막 가격으로 가정 (실제로는 실시간 가격 필요)
            current_price = trade.entry_price  # 임시
            if trade.order_type == OrderType.BUY:
                price_diff = current_price - trade.entry_price
            else:
                price_diff = trade.entry_price - current_price
            
            actual_volume = trade.volume * trade.contract_size
            unrealized_pnl += price_diff * actual_volume
        
        # 총 자본 계산
        total_equity = self.current_balance + unrealized_pnl
        
        # 자본 곡선에 추가
        self.equity_curve.append({
            'timestamp': timestamp,
            'balance': self.current_balance,
            'unrealized_pnl': unrealized_pnl,
            'total_equity': total_equity
        })
    
    def run_backtest(self, 
                    data: pd.DataFrame, 
                    symbol: str,
                    strategy_function: callable) -> BacktestResult:
        """
        백테스트 실행
        
        Args:
            data: 가격 데이터
            symbol: 심볼
            strategy_function: 전략 함수
            
        Returns:
            백테스트 결과
        """
        logger.info(f"🚀 백테스트 시작: {symbol}")
        logger.info(f"   - 데이터 기간: {data.index[0]} ~ {data.index[-1]}")
        logger.info(f"   - 총 바 수: {len(data)}")
        
        # 초기화
        self.current_balance = self.initial_balance
        self.trades = []
        self.equity_curve = []
        self.open_positions = {}
        self.total_commission = 0.0
        self.total_swap = 0.0
        
        # 심볼 설정 로드
        config = self.load_symbol_config(symbol)
        logger.info(f"📋 심볼 설정: {config}")
        
        # 전략 실행
        for i, (timestamp, row) in enumerate(data.iterrows()):
            # 자본 곡선 업데이트
            self.update_equity_curve(timestamp)
            
            # 전략 함수 호출
            signal = strategy_function(data.iloc[:i+1], row, self.open_positions)
            
            if signal:
                action = signal.get('action')
                volume = signal.get('volume', 0.01)
                
                if action == 'BUY':
                    if symbol not in self.open_positions:
                        self.open_position(symbol, OrderType.BUY, volume, row['Close'], timestamp)
                elif action == 'SELL':
                    if symbol not in self.open_positions:
                        self.open_position(symbol, OrderType.SELL, volume, row['Close'], timestamp)
                elif action == 'CLOSE':
                    if symbol in self.open_positions:
                        self.close_position(symbol, row['Close'], timestamp)
        
        # 마지막에 모든 포지션 클로즈
        for symbol in list(self.open_positions.keys()):
            last_price = data['Close'].iloc[-1]
            self.close_position(symbol, last_price, data.index[-1])
        
        # 결과 생성
        result = self._generate_result()
        
        logger.info(f"✅ 백테스트 완료!")
        logger.info(f"   - 총 거래: {result.total_trades}회")
        logger.info(f"   - 승률: {result.win_rate:.1f}%")
        logger.info(f"   - 순수익: ${result.net_profit:.2f}")
        logger.info(f"   - 최대 낙폭: {result.max_drawdown_percentage:.1f}%")
        
        return result
    
    def _generate_result(self) -> BacktestResult:
        """백테스트 결과 생성"""
        if not self.trades:
            return BacktestResult(
                total_trades=0,
                winning_trades=0,
                losing_trades=0,
                win_rate=0.0,
                total_profit=0.0,
                total_commission=self.total_commission,
                total_swap=self.total_swap,
                net_profit=0.0,
                max_drawdown=0.0,
                max_drawdown_percentage=0.0,
                profit_factor=0.0,
                sharpe_ratio=0.0,
                trades=[],
                equity_curve=pd.DataFrame()
            )
        
        # 기본 통계
        total_trades = len(self.trades)
        winning_trades = len([t for t in self.trades if t.profit > 0])
        losing_trades = total_trades - winning_trades
        win_rate = (winning_trades / total_trades) * 100 if total_trades > 0 else 0
        
        # 수익 통계
        total_profit = sum(t.profit for t in self.trades)
        net_profit = total_profit - self.total_commission
        
        # 최대 낙폭 계산
        equity_df = pd.DataFrame(self.equity_curve)
        if not equity_df.empty:
            equity_df['peak'] = equity_df['total_equity'].expanding().max()
            equity_df['drawdown'] = (equity_df['total_equity'] - equity_df['peak']) / equity_df['peak'] * 100
            max_drawdown_percentage = equity_df['drawdown'].min()
            max_drawdown = self.initial_balance * (max_drawdown_percentage / 100)
        else:
            max_drawdown = 0.0
            max_drawdown_percentage = 0.0
        
        # 수익 팩터
        gross_profit = sum(t.profit for t in self.trades if t.profit > 0)
        gross_loss = abs(sum(t.profit for t in self.trades if t.profit < 0))
        profit_factor = gross_profit / gross_loss if gross_loss > 0 else 0
        
        # 샤프 비율 (간단한 계산)
        if len(self.trades) > 1:
            returns = [t.profit for t in self.trades]
            sharpe_ratio = np.mean(returns) / np.std(returns) if np.std(returns) > 0 else 0
        else:
            sharpe_ratio = 0.0
        
        return BacktestResult(
            total_trades=total_trades,
            winning_trades=winning_trades,
            losing_trades=losing_trades,
            win_rate=win_rate,
            total_profit=total_profit,
            total_commission=self.total_commission,
            total_swap=self.total_swap,
            net_profit=net_profit,
            max_drawdown=max_drawdown,
            max_drawdown_percentage=max_drawdown_percentage,
            profit_factor=profit_factor,
            sharpe_ratio=sharpe_ratio,
            trades=self.trades,
            equity_curve=pd.DataFrame(self.equity_curve)
        )
    
    def save_results(self, result: BacktestResult, symbol: str, output_dir: str = "backtest_results"):
        """결과 저장"""
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 거래 내역 저장
        trades_data = []
        for trade in result.trades:
            trades_data.append({
                'symbol': trade.symbol,
                'order_type': trade.order_type.value,
                'volume': trade.volume,
                'actual_volume_btc': trade.actual_volume_btc,
                'entry_price': trade.entry_price,
                'exit_price': trade.exit_price,
                'entry_time': trade.entry_time.isoformat(),
                'exit_time': trade.exit_time.isoformat(),
                'profit': trade.profit,
                'commission': trade.commission,
                'profit_percentage': trade.profit_percentage
            })
        
        trades_df = pd.DataFrame(trades_data)
        trades_file = os.path.join(output_dir, f"{symbol}_trades_{timestamp}.csv")
        trades_df.to_csv(trades_file, index=False, encoding='utf-8')
        
        # 자본 곡선 저장
        if not result.equity_curve.empty:
            equity_file = os.path.join(output_dir, f"{symbol}_equity_{timestamp}.csv")
            result.equity_curve.to_csv(equity_file, index=False, encoding='utf-8')
        
        # 요약 리포트 저장
        summary = {
            'symbol': symbol,
            'backtest_date': datetime.now().isoformat(),
            'initial_balance': self.initial_balance,
            'final_balance': self.initial_balance + result.net_profit,
            'total_trades': result.total_trades,
            'winning_trades': result.winning_trades,
            'losing_trades': result.losing_trades,
            'win_rate': result.win_rate,
            'total_profit': result.total_profit,
            'total_commission': result.total_commission,
            'net_profit': result.net_profit,
            'max_drawdown': result.max_drawdown,
            'max_drawdown_percentage': result.max_drawdown_percentage,
            'profit_factor': result.profit_factor,
            'sharpe_ratio': result.sharpe_ratio
        }
        
        summary_file = os.path.join(output_dir, f"{symbol}_summary_{timestamp}.json")
        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump(summary, f, ensure_ascii=False, indent=2)
        
        logger.info(f"💾 결과 저장 완료:")
        logger.info(f"   - 거래 내역: {trades_file}")
        logger.info(f"   - 자본 곡선: {equity_file}")
        logger.info(f"   - 요약 리포트: {summary_file}")

# 예제 전략 함수들
def simple_ma_strategy(data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
    """간단한 이동평균 전략"""
    if len(data) < 20:
        return None
    
    # 20일 이동평균 계산
    ma20 = data['Close'].rolling(window=20).mean().iloc[-1]
    current_price = current_row['Close']
    
    # 매수 신호: 가격이 이동평균 위로 돌파
    if current_price > ma20 and 'BTC-USD' not in open_positions:
        return {'action': 'BUY', 'volume': 0.01}
    
    # 매도 신호: 가격이 이동평균 아래로 하락
    elif current_price < ma20 and 'BTC-USD' in open_positions:
        return {'action': 'CLOSE'}
    
    return None

def rsi_strategy(data: pd.DataFrame, current_row: pd.Series, open_positions: Dict) -> Optional[Dict]:
    """RSI 전략"""
    if len(data) < 14:
        return None
    
    # RSI 계산
    delta = data['Close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    current_rsi = rsi.iloc[-1]
    
    # 매수 신호: RSI < 30 (과매도)
    if current_rsi < 30 and 'BTC-USD' not in open_positions:
        return {'action': 'BUY', 'volume': 0.01}
    
    # 매도 신호: RSI > 70 (과매수)
    elif current_rsi > 70 and 'BTC-USD' in open_positions:
        return {'action': 'CLOSE'}
    
    return None

def main():
    """메인 실행 함수"""
    print("🎯 정확한 백테스트 엔진 시작!")
    print("=" * 60)
    
    # 데이터 로드
    data_file = "historical_data/BTC_USD_2y_1h.csv"
    if not os.path.exists(data_file):
        print(f"❌ 데이터 파일을 찾을 수 없습니다: {data_file}")
        print("먼저 historical_data_downloader.py를 실행하세요.")
        return
    
    # 데이터 로드
    data = pd.read_csv(data_file, index_col=0, parse_dates=True)
    print(f"📊 데이터 로드 완료: {len(data)}개 바")
    
    # 백테스트 엔진 초기화
    engine = AccurateBacktestEngine(
        initial_balance=1000.0,
        leverage=200,
        commission_per_lot=0.1,
        spread_points=0.5
    )
    
    # 전략 선택
    print("\n📋 전략을 선택하세요:")
    print("1. 간단한 이동평균 전략")
    print("2. RSI 전략")
    
    choice = input("선택 (1-2): ").strip()
    
    if choice == "1":
        strategy = simple_ma_strategy
        strategy_name = "MA20"
    elif choice == "2":
        strategy = rsi_strategy
        strategy_name = "RSI"
    else:
        print("❌ 잘못된 선택입니다.")
        return
    
    # 백테스트 실행
    print(f"\n🚀 {strategy_name} 전략 백테스트 실행 중...")
    result = engine.run_backtest(data, "BTC-USD", strategy)
    
    # 결과 출력
    print("\n📊 백테스트 결과:")
    print(f"   - 총 거래: {result.total_trades}회")
    print(f"   - 승률: {result.win_rate:.1f}%")
    print(f"   - 총 수익: ${result.total_profit:.2f}")
    print(f"   - 총 수수료: ${result.total_commission:.2f}")
    print(f"   - 순수익: ${result.net_profit:.2f}")
    print(f"   - 최대 낙폭: {result.max_drawdown_percentage:.1f}%")
    print(f"   - 수익 팩터: {result.profit_factor:.2f}")
    print(f"   - 샤프 비율: {result.sharpe_ratio:.2f}")
    
    # 결과 저장
    engine.save_results(result, f"BTC-USD_{strategy_name}")
    
    print(f"\n🎉 백테스트 완료! 결과가 backtest_results 폴더에 저장되었습니다.")

if __name__ == "__main__":
    main()
