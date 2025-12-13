#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🚀 고성능 병렬 백테스트 엔진
수십 개의 전략을 동시에 병렬로 실행하여 빠른 결과를 제공합니다.

작성자: AI Trading System
버전: 1.0
날짜: 2024-12-31
"""

import multiprocessing as mp
import pandas as pd
import numpy as np
import json
import os
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any, Callable
from dataclasses import dataclass, asdict
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor, as_completed
import queue
import threading
from pathlib import Path
import pickle
import warnings
warnings.filterwarnings('ignore')
try:
    from prometheus_client import Counter, Histogram, Gauge, start_http_server
    _PROM_AVAILABLE = True
except Exception:
    _PROM_AVAILABLE = False

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(processName)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('parallel_backtest.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class BacktestConfig:
    """백테스트 설정"""
    symbol: str
    timeframe: str
    strategy_name: str
    strategy_params: Dict[str, Any]
    start_date: str
    end_date: str
    initial_balance: float = 1000.0
    leverage: int = 200
    commission_per_lot: float = 0.1
    spread_points: float = 0.5
    lot_size: float = 0.01

@dataclass
class BacktestResult:
    """백테스트 결과"""
    config: BacktestConfig
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate: float
    total_profit: float
    total_commission: float
    net_profit: float
    max_drawdown: float
    max_drawdown_percentage: float
    profit_factor: float
    sharpe_ratio: float
    sortino_ratio: float
    calmar_ratio: float
    recovery_factor: float
    execution_time: float
    trades: List[Dict]
    equity_curve: List[Dict]
    status: str = "completed"
    error_message: str = ""

class ParallelBacktestEngine:
    """병렬 백테스트 엔진"""
    
    def __init__(self, 
                 max_workers: int = None,
                 data_dir: str = "historical_data",
                 results_dir: str = "parallel_results",
                 prometheus_port: Optional[int] = None):
        """
        초기화
        
        Args:
            max_workers: 최대 워커 수 (None이면 CPU 코어 수)
            data_dir: 데이터 디렉토리
            results_dir: 결과 디렉토리
        """
        self.max_workers = max_workers or mp.cpu_count()
        self.data_dir = data_dir
        self.results_dir = results_dir
        
        # 디렉토리 생성
        Path(self.results_dir).mkdir(exist_ok=True)
        Path(f"{self.results_dir}/individual").mkdir(exist_ok=True)
        Path(f"{self.results_dir}/aggregated").mkdir(exist_ok=True)
        
        # 전략 레지스트리
        self.strategy_registry = {}
        
        # 결과 큐
        self.result_queue = queue.Queue()

        # Prometheus 메트릭 초기화
        self._metrics = None
        if _PROM_AVAILABLE:
            try:
                port = prometheus_port or int(os.environ.get("PROMETHEUS_PORT", "8001"))
                start_http_server(port)
                self._metrics = {
                    'backtests_total': Counter('backtests_total', 'Total backtests run'),
                    'execution_time': Histogram('backtest_duration_seconds', 'Backtest execution time seconds'),
                    'active_workers': Gauge('active_workers', 'Number of active workers')
                }
                logger.info(f"📈 Prometheus 메트릭 서버 시작: port={port}")
            except Exception as _:
                logger.warning("Prometheus 초기화 실패 - 메트릭 비활성")
        
        logger.info(f"🚀 병렬 백테스트 엔진 초기화")
        logger.info(f"   - 최대 워커 수: {self.max_workers}")
        logger.info(f"   - 데이터 디렉토리: {self.data_dir}")
        logger.info(f"   - 결과 디렉토리: {self.results_dir}")
    
    def register_strategy(self, name: str, strategy_func: Callable):
        """
        전략 등록
        
        Args:
            name: 전략 이름
            strategy_func: 전략 함수
        """
        self.strategy_registry[name] = strategy_func
        logger.info(f"📝 전략 등록: {name}")
    
    def load_data(self, symbol: str, timeframe: str, start_date: str, end_date: str) -> pd.DataFrame:
        """데이터 로드"""
        # 심볼명 변환 (BTC-USD -> BTC_USD)
        file_symbol = symbol.replace('-', '_').replace('=', '_')
        tf_token = timeframe.replace(" ", "").lower()
        
        # 데이터 파일 찾기
        # 우선 시간프레임이 포함된 파일 우선
        data_files = list(Path(self.data_dir).glob(f"{file_symbol}_*{tf_token}*.csv"))
        if not data_files:
            # 시간프레임 표기가 다른 경우를 대비해 전체 검색 후 가장 최근 파일 사용
            data_files = list(Path(self.data_dir).glob(f"{file_symbol}_*.csv"))
        
        if not data_files:
            raise FileNotFoundError(f"데이터 파일을 찾을 수 없습니다: {symbol}")
        
        # 가장 최근 파일 사용
        data_file = max(data_files, key=os.path.getctime)
        
        # 데이터 로드
        data = pd.read_csv(data_file, index_col=0, parse_dates=True)
        # 한글 주석: 인덱스가 datetime 형이 아닐 경우 강제 변환
        if not isinstance(data.index, pd.DatetimeIndex):
            data.index = pd.to_datetime(data.index, errors='coerce')
        # 한글 주석: tz-aware 인덱스를 tz-naive로 정규화 (UTC 기준 제거)
        try:
            if getattr(data.index, 'tz', None) is not None:
                # UTC로 정규화 후 타임존 제거
                data.index = data.index.tz_convert('UTC').tz_localize(None)
        except Exception:
            try:
                data.index = data.index.tz_localize(None)
            except Exception:
                pass
        # 한글 주석: 수치형 컬럼 강제 변환
        for col in ['Open','High','Low','Close','Volume']:
            if col in data.columns:
                data[col] = pd.to_numeric(data[col], errors='coerce')
        # NaN 제거
        data = data.dropna(subset=['Open','High','Low','Close'])
        
        # 날짜 필터링 (문자열을 datetime으로 변환) - tz 정보 제거
        start_dt = pd.to_datetime(start_date).tz_localize(None) if hasattr(pd.to_datetime(start_date), 'tz') else pd.to_datetime(start_date)
        end_dt = pd.to_datetime(end_date).tz_localize(None) if hasattr(pd.to_datetime(end_date), 'tz') else pd.to_datetime(end_date)
        
        # 데이터가 있는 범위로 조정
        data_start = data.index.min()
        data_end = data.index.max()
        
        # 요청된 날짜가 데이터 범위를 벗어나면 데이터 범위로 조정
        if start_dt > data_end:
            # 요청된 시작일이 데이터 끝보다 늦으면 최근 데이터 사용
            days_diff = (start_dt - data_end).days
            actual_start = data_end - pd.Timedelta(days=min(days_diff, 365))  # 최대 1년 전
            actual_end = data_end
        elif end_dt < data_start:
            # 요청된 종료일이 데이터 시작보다 이르면 초기 데이터 사용
            days_diff = (data_start - end_dt).days
            actual_start = data_start
            actual_end = data_start + pd.Timedelta(days=min(days_diff, 365))  # 최대 1년 후
        else:
            # 정상 범위
            actual_start = max(start_dt, data_start)
            actual_end = min(end_dt, data_end)
        
        # 한글 주석: 비교를 위해 actual_start/end를 Timestamp로 통일
        actual_start = pd.to_datetime(actual_start)
        actual_end = pd.to_datetime(actual_end)
        data = data[(data.index >= actual_start) & (data.index <= actual_end)]
        
        if data.empty:
            raise ValueError(f"지정된 기간에 데이터가 없습니다: {start_date} ~ {end_date} (데이터 범위: {data_start.date()} ~ {data_end.date()})")
        
        logger.info(f"📊 데이터 로드: {symbol} ({len(data)}개 바)")
        return data
    
    def run_single_backtest(self, config: BacktestConfig) -> BacktestResult:
        """
        단일 백테스트 실행
        
        Args:
            config: 백테스트 설정
            
        Returns:
            백테스트 결과
        """
        start_time = time.time()
        
        try:
            # 데이터 로드
            data = self.load_data(config.symbol, config.timeframe, config.start_date, config.end_date)
            
            # 전략 함수 가져오기
            if config.strategy_name not in self.strategy_registry:
                raise ValueError(f"등록되지 않은 전략: {config.strategy_name}")
            
            strategy_func = self.strategy_registry[config.strategy_name]
            
            # 백테스트 실행
            timer_start = time.time()
            result = self._execute_backtest(data, config, strategy_func)
            exec_sec = time.time() - timer_start
            result.execution_time = exec_sec
            if self._metrics:
                self._metrics['backtests_total'].inc()
                self._metrics['execution_time'].observe(exec_sec)
            # 이미 위에서 기록됨
            
            logger.info(f"✅ 백테스트 완료: {config.symbol} - {config.strategy_name} ({result.execution_time:.2f}초)")
            
            return result
            
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(f"❌ 백테스트 실패: {config.symbol} - {config.strategy_name}: {str(e)}")
            
            return BacktestResult(
                config=config,
                total_trades=0,
                winning_trades=0,
                losing_trades=0,
                win_rate=0.0,
                total_profit=0.0,
                total_commission=0.0,
                net_profit=0.0,
                max_drawdown=0.0,
                max_drawdown_percentage=0.0,
                profit_factor=0.0,
                sharpe_ratio=0.0,
                sortino_ratio=0.0,
                calmar_ratio=0.0,
                recovery_factor=0.0,
                execution_time=execution_time,
                trades=[],
                equity_curve=[],
                status="failed",
                error_message=str(e)
            )
    
    def _execute_backtest(self, 
                         data: pd.DataFrame, 
                         config: BacktestConfig, 
                         strategy_func: Callable) -> BacktestResult:
        """백테스트 실행"""
        # 초기화
        balance = config.initial_balance
        trades = []
        equity_curve = []
        open_positions = {}
        
        # 전략 파라미터로 전략 함수 생성
        strategy = strategy_func(**config.strategy_params)
        
        # 백테스트 실행
        for i, (timestamp, row) in enumerate(data.iterrows()):
            # 자본 곡선 업데이트
            unrealized_pnl = sum(
                self._calculate_unrealized_pnl(pos, row['Close'], config)
                for pos in open_positions.values()
            )
            total_equity = balance + unrealized_pnl
            equity_curve.append({
                'timestamp': timestamp.isoformat(),
                'balance': balance,
                'unrealized_pnl': unrealized_pnl,
                'total_equity': total_equity
            })
            
            # 전략 신호 생성
            signal = strategy.generate_signal(data.iloc[:i+1], row, open_positions)
            
            if signal:
                # 거래 실행
                trade_result = self._execute_trade(
                    signal, row['Close'], timestamp, config, open_positions
                )
                
                if trade_result:
                    trades.append(trade_result)
                    balance += trade_result['profit'] - trade_result['commission']
        
        # 마지막에 모든 포지션 청산
        for symbol in list(open_positions.keys()):
            last_price = data['Close'].iloc[-1]
            trade_result = self._close_position(
                symbol, last_price, data.index[-1], config, open_positions
            )
            if trade_result:
                trades.append(trade_result)
                balance += trade_result['profit'] - trade_result['commission']
        
        # 결과 계산
        return self._calculate_results(config, trades, equity_curve, balance)
    
    def _calculate_unrealized_pnl(self, position: Dict, current_price: float, config: BacktestConfig) -> float:
        """미실현 손익 계산"""
        if position['type'] == 'BUY':
            return (current_price - position['entry_price']) * position['volume'] * config.lot_size
        else:
            return (position['entry_price'] - current_price) * position['volume'] * config.lot_size
    
    def _execute_trade(self, signal: Dict, price: float, timestamp: datetime, 
                      config: BacktestConfig, open_positions: Dict) -> Optional[Dict]:
        """거래 실행"""
        action = signal.get('action')
        volume = signal.get('volume', config.lot_size)
        symbol = config.symbol
        
        if action == 'BUY':
            if symbol not in open_positions:
                # 매수 진입
                open_positions[symbol] = {
                    'type': 'BUY',
                    'volume': volume,
                    'entry_price': price,
                    'entry_time': timestamp
                }
                return None
            elif open_positions[symbol]['type'] == 'SELL':
                # 매도 포지션 청산 후 매수 진입
                trade_result = self._close_position(symbol, price, timestamp, config, open_positions)
                open_positions[symbol] = {
                    'type': 'BUY',
                    'volume': volume,
                    'entry_price': price,
                    'entry_time': timestamp
                }
                return trade_result
        
        elif action == 'SELL':
            if symbol not in open_positions:
                # 매도 진입
                open_positions[symbol] = {
                    'type': 'SELL',
                    'volume': volume,
                    'entry_price': price,
                    'entry_time': timestamp
                }
                return None
            elif open_positions[symbol]['type'] == 'BUY':
                # 매수 포지션 청산 후 매도 진입
                trade_result = self._close_position(symbol, price, timestamp, config, open_positions)
                open_positions[symbol] = {
                    'type': 'SELL',
                    'volume': volume,
                    'entry_price': price,
                    'entry_time': timestamp
                }
                return trade_result
        
        elif action == 'CLOSE':
            if symbol in open_positions:
                return self._close_position(symbol, price, timestamp, config, open_positions)
        
        return None
    
    def _close_position(self, symbol: str, price: float, timestamp: datetime,
                       config: BacktestConfig, open_positions: Dict) -> Dict:
        """포지션 청산"""
        position = open_positions[symbol]
        
        # 수익 계산
        if position['type'] == 'BUY':
            profit = (price - position['entry_price']) * position['volume'] * config.lot_size
        else:
            profit = (position['entry_price'] - price) * position['volume'] * config.lot_size
        
        # 수수료 계산
        commission = position['volume'] * config.commission_per_lot
        
        # 거래 결과
        trade_result = {
            'symbol': symbol,
            'type': position['type'],
            'volume': position['volume'],
            'entry_price': position['entry_price'],
            'exit_price': price,
            'entry_time': position['entry_time'].isoformat(),
            'exit_time': timestamp.isoformat(),
            'profit': profit,
            'commission': commission,
            'net_profit': profit - commission
        }
        
        # 포지션 제거
        del open_positions[symbol]
        
        return trade_result
    
    def _calculate_results(self, config: BacktestConfig, trades: List[Dict], 
                          equity_curve: List[Dict], final_balance: float) -> BacktestResult:
        """결과 계산"""
        if not trades:
            return BacktestResult(
                config=config,
                total_trades=0,
                winning_trades=0,
                losing_trades=0,
                win_rate=0.0,
                total_profit=0.0,
                total_commission=sum(t['commission'] for t in trades),
                net_profit=0.0,
                max_drawdown=0.0,
                max_drawdown_percentage=0.0,
                profit_factor=0.0,
                sharpe_ratio=0.0,
                sortino_ratio=0.0,
                calmar_ratio=0.0,
                recovery_factor=0.0,
                execution_time=0.0,
                trades=trades,
                equity_curve=equity_curve
            )
        
        # 기본 통계
        total_trades = len(trades)
        winning_trades = len([t for t in trades if t['profit'] > 0])
        losing_trades = total_trades - winning_trades
        win_rate = (winning_trades / total_trades) * 100 if total_trades > 0 else 0
        
        # 수익 통계
        total_profit = sum(t['profit'] for t in trades)
        total_commission = sum(t['commission'] for t in trades)
        net_profit = total_profit - total_commission
        
        # 최대 낙폭 계산
        if equity_curve:
            equity_df = pd.DataFrame(equity_curve)
            equity_df['peak'] = equity_df['total_equity'].expanding().max()
            equity_df['drawdown'] = (equity_df['total_equity'] - equity_df['peak']) / equity_df['peak'] * 100
            max_drawdown_percentage = equity_df['drawdown'].min()
            max_drawdown = config.initial_balance * (max_drawdown_percentage / 100)
        else:
            max_drawdown = 0.0
            max_drawdown_percentage = 0.0
        
        # 수익 팩터
        gross_profit = sum(t['profit'] for t in trades if t['profit'] > 0)
        gross_loss = abs(sum(t['profit'] for t in trades if t['profit'] < 0))
        profit_factor = gross_profit / gross_loss if gross_loss > 0 else 0
        
        # 샤프/소르티노/칼마/리커버리 비율
        if len(trades) > 1:
            returns = [t['profit'] for t in trades]
            sharpe_ratio = np.mean(returns) / np.std(returns) if np.std(returns) > 0 else 0
        else:
            sharpe_ratio = 0.0
        # 일별 수익률 근사 (트레이드 기반 간략화)
        returns_series = pd.Series([t['profit'] for t in trades])
        downside = returns_series[returns_series < 0]
        sortino_ratio = (returns_series.mean() / downside.std()) if downside.std() and downside.std() > 0 else 0.0
        calmar_ratio = ((net_profit / config.initial_balance) / abs(max_drawdown_percentage)) if max_drawdown_percentage != 0 else 0.0
        recovery_factor = (net_profit / abs(max_drawdown)) if max_drawdown != 0 else 0.0
        
        return BacktestResult(
            config=config,
            total_trades=total_trades,
            winning_trades=winning_trades,
            losing_trades=losing_trades,
            win_rate=win_rate,
            total_profit=total_profit,
            total_commission=total_commission,
            net_profit=net_profit,
            max_drawdown=max_drawdown,
            max_drawdown_percentage=max_drawdown_percentage,
            profit_factor=profit_factor,
            sharpe_ratio=sharpe_ratio,
            sortino_ratio=sortino_ratio,
            calmar_ratio=calmar_ratio,
            recovery_factor=recovery_factor,
            execution_time=0.0,
            trades=trades,
            equity_curve=equity_curve
        )
    
    def run_parallel_backtests(self, configs: List[BacktestConfig]) -> List[BacktestResult]:
        """
        병렬 백테스트 실행
        
        Args:
            configs: 백테스트 설정 리스트
            
        Returns:
            백테스트 결과 리스트
        """
        logger.info(f"🚀 병렬 백테스트 시작: {len(configs)}개 작업")
        logger.info(f"   - 워커 수: {self.max_workers}")
        
        start_time = time.time()
        results = []
        
        # 멀티프로세싱 대신 스레딩 사용 (pickle 문제 해결)
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            # 작업 제출
            future_to_config = {
                executor.submit(self.run_single_backtest, config): config 
                for config in configs
            }
            
            # 결과 수집
            completed = 0
            for future in as_completed(future_to_config):
                config = future_to_config[future]
                try:
                    result = future.result()
                    results.append(result)
                    completed += 1
                    
                    logger.info(f"📊 진행률: {completed}/{len(configs)} "
                              f"({completed/len(configs)*100:.1f}%) - "
                              f"{config.symbol} - {config.strategy_name}")
                    
                except Exception as e:
                    logger.error(f"❌ 백테스트 실패: {config.symbol} - {config.strategy_name}: {e}")
        
        total_time = time.time() - start_time
        logger.info(f"✅ 병렬 백테스트 완료: {total_time:.2f}초")
        logger.info(f"   - 평균 실행 시간: {total_time/len(configs):.2f}초/작업")
        
        return results
    
    def save_results(self, results: List[BacktestResult]):
        """결과 저장"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 개별 결과 저장
        for i, result in enumerate(results):
            filename = f"{self.results_dir}/individual/result_{i:03d}_{timestamp}.json"
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(asdict(result), f, ensure_ascii=False, indent=2, default=str)
        
        # 집계 결과 생성
        aggregated = self._aggregate_results(results)
        
        # 집계 결과 저장
        aggregated_file = f"{self.results_dir}/aggregated/aggregated_{timestamp}.json"
        with open(aggregated_file, 'w', encoding='utf-8') as f:
            json.dump(aggregated, f, ensure_ascii=False, indent=2, default=str)
        
        logger.info(f"💾 결과 저장 완료: {len(results)}개 개별 결과 + 1개 집계 결과")
    
    def _aggregate_results(self, results: List[BacktestResult]) -> Dict:
        """결과 집계"""
        if not results:
            return {}
        
        # 기본 통계
        total_configs = len(results)
        successful_configs = len([r for r in results if r.status == "completed"])
        failed_configs = total_configs - successful_configs
        
        # 성공한 결과만 분석
        successful_results = [r for r in results if r.status == "completed"]
        
        if not successful_results:
            return {
                "summary": {
                    "total_configs": total_configs,
                    "successful_configs": successful_configs,
                    "failed_configs": failed_configs,
                    "success_rate": 0.0
                }
            }
        
        # 성과 통계
        win_rates = [r.win_rate for r in successful_results]
        net_profits = [r.net_profit for r in successful_results]
        profit_factors = [r.profit_factor for r in successful_results]
        sharpe_ratios = [r.sharpe_ratio for r in successful_results]
        max_drawdowns = [r.max_drawdown_percentage for r in successful_results]
        
        # 상위 성과자
        top_performers = sorted(successful_results, key=lambda x: x.net_profit, reverse=True)[:10]
        
        return {
            "summary": {
                "total_configs": total_configs,
                "successful_configs": successful_configs,
                "failed_configs": failed_configs,
                "success_rate": successful_configs / total_configs * 100,
                "total_execution_time": sum(r.execution_time for r in results),
                "average_execution_time": np.mean([r.execution_time for r in results])
            },
            "performance_stats": {
                "win_rate": {
                    "mean": np.mean(win_rates),
                    "std": np.std(win_rates),
                    "min": np.min(win_rates),
                    "max": np.max(win_rates)
                },
                "net_profit": {
                    "mean": np.mean(net_profits),
                    "std": np.std(net_profits),
                    "min": np.min(net_profits),
                    "max": np.max(net_profits),
                    "total": sum(net_profits)
                },
                "profit_factor": {
                    "mean": np.mean(profit_factors),
                    "std": np.std(profit_factors),
                    "min": np.min(profit_factors),
                    "max": np.max(profit_factors)
                },
                "sharpe_ratio": {
                    "mean": np.mean(sharpe_ratios),
                    "std": np.std(sharpe_ratios),
                    "min": np.min(sharpe_ratios),
                    "max": np.max(sharpe_ratios)
                },
                "max_drawdown": {
                    "mean": np.mean(max_drawdowns),
                    "std": np.std(max_drawdowns),
                    "min": np.min(max_drawdowns),
                    "max": np.max(max_drawdowns)
                }
            },
            "top_performers": [
                {
                    "rank": i + 1,
                    "symbol": r.config.symbol,
                    "strategy": r.config.strategy_name,
                    "net_profit": r.net_profit,
                    "win_rate": r.win_rate,
                    "profit_factor": r.profit_factor,
                    "sharpe_ratio": r.sharpe_ratio,
                    "max_drawdown": r.max_drawdown_percentage
                }
                for i, r in enumerate(top_performers)
            ],
            "strategy_analysis": self._analyze_strategies(successful_results),
            "symbol_analysis": self._analyze_symbols(successful_results)
        }
    
    def _analyze_strategies(self, results: List[BacktestResult]) -> Dict:
        """전략별 분석"""
        strategy_stats = {}
        
        for result in results:
            strategy_name = result.config.strategy_name
            if strategy_name not in strategy_stats:
                strategy_stats[strategy_name] = []
            strategy_stats[strategy_name].append(result)
        
        analysis = {}
        for strategy_name, strategy_results in strategy_stats.items():
            win_rates = [r.win_rate for r in strategy_results]
            net_profits = [r.net_profit for r in strategy_results]
            
            analysis[strategy_name] = {
                "count": len(strategy_results),
                "avg_win_rate": np.mean(win_rates),
                "avg_net_profit": np.mean(net_profits),
                "total_net_profit": sum(net_profits),
                "best_performance": max(net_profits),
                "worst_performance": min(net_profits)
            }
        
        return analysis
    
    def _analyze_symbols(self, results: List[BacktestResult]) -> Dict:
        """심볼별 분석"""
        symbol_stats = {}
        
        for result in results:
            symbol = result.config.symbol
            if symbol not in symbol_stats:
                symbol_stats[symbol] = []
            symbol_stats[symbol].append(result)
        
        analysis = {}
        for symbol, symbol_results in symbol_stats.items():
            win_rates = [r.win_rate for r in symbol_results]
            net_profits = [r.net_profit for r in symbol_results]
            
            analysis[symbol] = {
                "count": len(symbol_results),
                "avg_win_rate": np.mean(win_rates),
                "avg_net_profit": np.mean(net_profits),
                "total_net_profit": sum(net_profits),
                "best_performance": max(net_profits),
                "worst_performance": min(net_profits)
            }
        
        return analysis

def main():
    """메인 실행 함수"""
    print("🚀 고성능 병렬 백테스트 엔진 시작!")
    print("=" * 60)
    
    # 엔진 초기화
    engine = ParallelBacktestEngine(max_workers=8)
    
    # 전략 등록 (예시)
    # engine.register_strategy("ma_cross", ma_cross_strategy)
    # engine.register_strategy("rsi", rsi_strategy)
    
    print("✅ 병렬 백테스트 엔진 준비 완료")
    print(f"   - 최대 워커 수: {engine.max_workers}")
    print(f"   - 등록된 전략: {len(engine.strategy_registry)}개")

if __name__ == "__main__":
    main()
