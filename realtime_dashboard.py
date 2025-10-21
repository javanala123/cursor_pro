#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
📊 실시간 모니터링 대시보드
병렬 백테스트 진행 상황을 실시간으로 모니터링합니다.

작성자: AI Trading System
버전: 1.0
날짜: 2024-12-31
"""

import os
import sys
import json
import time
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Any
import pandas as pd
import numpy as np
from flask import Flask, render_template, jsonify, request
import logging

# 로컬 모듈 임포트
from parallel_backtest_engine import ParallelBacktestEngine, BacktestConfig, BacktestResult
from strategy_loader import StrategyLoader

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class RealtimeDashboard:
    """실시간 모니터링 대시보드"""
    
    def __init__(self, 
                 host: str = "0.0.0.0",
                 port: int = 5000,
                 results_dir: str = "parallel_results"):
        """
        초기화
        
        Args:
            host: 호스트 주소
            port: 포트 번호
            results_dir: 결과 디렉토리
        """
        self.host = host
        self.port = port
        self.results_dir = results_dir
        
        # Flask 앱 초기화
        self.app = Flask(__name__)
        self.app.config['SECRET_KEY'] = 'parallel_backtest_dashboard'
        
        # 라우트 설정
        self._setup_routes()
        
        # 상태 변수
        self.is_running = False
        self.current_results = []
        self.progress_info = {
            'total': 0,
            'completed': 0,
            'failed': 0,
            'start_time': None,
            'estimated_completion': None
        }
        
        logger.info(f"📊 실시간 대시보드 초기화 완료")
        logger.info(f"   - 주소: http://{host}:{port}")
        logger.info(f"   - 결과 디렉토리: {results_dir}")
    
    def _setup_routes(self):
        """라우트 설정"""
        
        @self.app.route('/')
        def index():
            """메인 페이지"""
            return render_template('dashboard.html')
        
        @self.app.route('/api/status')
        def get_status():
            """상태 정보 API"""
            return jsonify({
                'is_running': self.is_running,
                'progress': self.progress_info,
                'timestamp': datetime.now().isoformat()
            })
        
        @self.app.route('/api/results')
        def get_results():
            """결과 정보 API"""
            return jsonify({
                'results': [self._result_to_dict(r) for r in self.current_results],
                'summary': self._calculate_summary(),
                'timestamp': datetime.now().isoformat()
            })
        
        @self.app.route('/api/start_backtest', methods=['POST'])
        def start_backtest():
            """백테스트 시작 API"""
            try:
                data = request.get_json()
                
                # 백테스트 설정 생성
                configs = self._create_configs_from_request(data)
                
                # 백테스트 시작 (별도 스레드에서)
                thread = threading.Thread(
                    target=self._run_backtest_thread,
                    args=(configs,)
                )
                thread.daemon = True
                thread.start()
                
                return jsonify({
                    'status': 'success',
                    'message': f'{len(configs)}개 백테스트 시작됨',
                    'configs_count': len(configs)
                })
                
            except Exception as e:
                logger.error(f"백테스트 시작 실패: {e}")
                return jsonify({
                    'status': 'error',
                    'message': str(e)
                }), 500
        
        @self.app.route('/api/stop_backtest', methods=['POST'])
        def stop_backtest():
            """백테스트 중지 API"""
            self.is_running = False
            return jsonify({
                'status': 'success',
                'message': '백테스트 중지 요청됨'
            })
        
        @self.app.route('/api/export_results', methods=['POST'])
        def export_results():
            """결과 내보내기 API"""
            try:
                data = request.get_json()
                format_type = data.get('format', 'json')
                
                if format_type == 'json':
                    return self._export_json()
                elif format_type == 'csv':
                    return self._export_csv()
                elif format_type == 'excel':
                    return self._export_excel()
                else:
                    return jsonify({
                        'status': 'error',
                        'message': '지원하지 않는 형식'
                    }), 400
                    
            except Exception as e:
                logger.error(f"결과 내보내기 실패: {e}")
                return jsonify({
                    'status': 'error',
                    'message': str(e)
                }), 500
    
    def _create_configs_from_request(self, data: Dict) -> List[BacktestConfig]:
        """요청 데이터로부터 설정 생성"""
        symbols = data.get('symbols', ['BTC-USD'])
        strategies = data.get('strategies', ['ma_cross'])
        days = data.get('days', 30)
        
        # 날짜 설정
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
        
        configs = []
        for symbol in symbols:
            for strategy in strategies:
                config = BacktestConfig(
                    symbol=symbol,
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
        
        return configs
    
    def _run_backtest_thread(self, configs: List[BacktestConfig]):
        """백테스트 실행 스레드"""
        try:
            self.is_running = True
            self.current_results = []
            self.progress_info = {
                'total': len(configs),
                'completed': 0,
                'failed': 0,
                'start_time': datetime.now(),
                'estimated_completion': None
            }
            
            # 백테스트 엔진 초기화
            engine = ParallelBacktestEngine(max_workers=8)
            strategy_loader = StrategyLoader()
            
            # 전략 등록
            available_strategies = strategy_loader.get_available_strategies()
            for strategy_name in available_strategies:
                def create_strategy_func(name):
                    def strategy_func(**params):
                        return strategy_loader.create_strategy(name, **params)
                    return strategy_func
                
                engine.register_strategy(strategy_name, create_strategy_func(strategy_name))
            
            # 백테스트 실행
            results = engine.run_parallel_backtests(configs)
            
            # 결과 저장
            self.current_results = results
            self.progress_info['completed'] = len([r for r in results if r.status == "completed"])
            self.progress_info['failed'] = len([r for r in results if r.status == "failed"])
            
            # 결과 저장
            engine.save_results(results)
            
            logger.info(f"✅ 백테스트 완료: {len(results)}개 결과")
            
        except Exception as e:
            logger.error(f"❌ 백테스트 실행 실패: {e}")
        finally:
            self.is_running = False
    
    def _result_to_dict(self, result: BacktestResult) -> Dict:
        """결과를 딕셔너리로 변환"""
        return {
            'symbol': result.config.symbol,
            'strategy': result.config.strategy_name,
            'total_trades': result.total_trades,
            'winning_trades': result.winning_trades,
            'losing_trades': result.losing_trades,
            'win_rate': result.win_rate,
            'total_profit': result.total_profit,
            'net_profit': result.net_profit,
            'max_drawdown': result.max_drawdown,
            'max_drawdown_percentage': result.max_drawdown_percentage,
            'profit_factor': result.profit_factor,
            'sharpe_ratio': result.sharpe_ratio,
            'execution_time': result.execution_time,
            'status': result.status,
            'error_message': result.error_message
        }
    
    def _calculate_summary(self) -> Dict:
        """요약 통계 계산"""
        if not self.current_results:
            return {}
        
        successful_results = [r for r in self.current_results if r.status == "completed"]
        
        if not successful_results:
            return {
                'total': len(self.current_results),
                'successful': 0,
                'failed': len(self.current_results),
                'success_rate': 0.0
            }
        
        net_profits = [r.net_profit for r in successful_results]
        win_rates = [r.win_rate for r in successful_results]
        profit_factors = [r.profit_factor for r in successful_results]
        
        return {
            'total': len(self.current_results),
            'successful': len(successful_results),
            'failed': len(self.current_results) - len(successful_results),
            'success_rate': len(successful_results) / len(self.current_results) * 100,
            'avg_net_profit': np.mean(net_profits),
            'max_net_profit': np.max(net_profits),
            'min_net_profit': np.min(net_profits),
            'total_net_profit': np.sum(net_profits),
            'avg_win_rate': np.mean(win_rates),
            'avg_profit_factor': np.mean(profit_factors),
            'top_performers': [
                {
                    'symbol': r.config.symbol,
                    'strategy': r.config.strategy_name,
                    'net_profit': r.net_profit,
                    'win_rate': r.win_rate
                }
                for r in sorted(successful_results, key=lambda x: x.net_profit, reverse=True)[:5]
            ]
        }
    
    def _export_json(self):
        """JSON 형식으로 내보내기"""
        data = {
            'results': [self._result_to_dict(r) for r in self.current_results],
            'summary': self._calculate_summary(),
            'export_time': datetime.now().isoformat()
        }
        
        filename = f"backtest_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        filepath = os.path.join(self.results_dir, filename)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2, default=str)
        
        return jsonify({
            'status': 'success',
            'message': f'결과가 {filename}으로 저장되었습니다.',
            'filepath': filepath
        })
    
    def _export_csv(self):
        """CSV 형식으로 내보내기"""
        if not self.current_results:
            return jsonify({
                'status': 'error',
                'message': '내보낼 결과가 없습니다.'
            }), 400
        
        # 데이터프레임 생성
        data = []
        for result in self.current_results:
            data.append({
                'symbol': result.config.symbol,
                'strategy': result.config.strategy_name,
                'total_trades': result.total_trades,
                'winning_trades': result.winning_trades,
                'losing_trades': result.losing_trades,
                'win_rate': result.win_rate,
                'total_profit': result.total_profit,
                'net_profit': result.net_profit,
                'max_drawdown': result.max_drawdown,
                'max_drawdown_percentage': result.max_drawdown_percentage,
                'profit_factor': result.profit_factor,
                'sharpe_ratio': result.sharpe_ratio,
                'execution_time': result.execution_time,
                'status': result.status
            })
        
        df = pd.DataFrame(data)
        
        filename = f"backtest_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        filepath = os.path.join(self.results_dir, filename)
        
        df.to_csv(filepath, index=False, encoding='utf-8-sig')
        
        return jsonify({
            'status': 'success',
            'message': f'결과가 {filename}으로 저장되었습니다.',
            'filepath': filepath
        })
    
    def _export_excel(self):
        """Excel 형식으로 내보내기"""
        if not self.current_results:
            return jsonify({
                'status': 'error',
                'message': '내보낼 결과가 없습니다.'
            }), 400
        
        # 데이터프레임 생성
        data = []
        for result in self.current_results:
            data.append({
                'symbol': result.config.symbol,
                'strategy': result.config.strategy_name,
                'total_trades': result.total_trades,
                'winning_trades': result.winning_trades,
                'losing_trades': result.losing_trades,
                'win_rate': result.win_rate,
                'total_profit': result.total_profit,
                'net_profit': result.net_profit,
                'max_drawdown': result.max_drawdown,
                'max_drawdown_percentage': result.max_drawdown_percentage,
                'profit_factor': result.profit_factor,
                'sharpe_ratio': result.sharpe_ratio,
                'execution_time': result.execution_time,
                'status': result.status
            })
        
        df = pd.DataFrame(data)
        
        filename = f"backtest_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
        filepath = os.path.join(self.results_dir, filename)
        
        with pd.ExcelWriter(filepath, engine='openpyxl') as writer:
            df.to_excel(writer, sheet_name='Results', index=False)
            
            # 요약 시트 추가
            summary = self._calculate_summary()
            summary_df = pd.DataFrame([summary])
            summary_df.to_excel(writer, sheet_name='Summary', index=False)
        
        return jsonify({
            'status': 'success',
            'message': f'결과가 {filename}으로 저장되었습니다.',
            'filepath': filepath
        })
    
    def run(self, debug: bool = False):
        """대시보드 실행"""
        logger.info(f"🚀 실시간 대시보드 시작")
        logger.info(f"   - 주소: http://{self.host}:{self.port}")
        logger.info(f"   - 디버그 모드: {debug}")
        
        try:
            self.app.run(
                host=self.host,
                port=self.port,
                debug=debug,
                threaded=True
            )
        except KeyboardInterrupt:
            logger.info("🛑 대시보드 종료")
        except Exception as e:
            logger.error(f"❌ 대시보드 실행 실패: {e}")

def create_dashboard_template():
    """대시보드 HTML 템플릿 생성"""
    template_dir = "templates"
    os.makedirs(template_dir, exist_ok=True)
    
    html_content = """
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🚀 병렬 백테스트 대시보드</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .dashboard {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .card h3 {
            margin-top: 0;
            color: #333;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .status {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 20px;
        }
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background-color: #28a745;
        }
        .status-indicator.running {
            background-color: #ffc107;
            animation: pulse 1s infinite;
        }
        .status-indicator.stopped {
            background-color: #dc3545;
        }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        .progress-bar {
            width: 100%;
            height: 20px;
            background-color: #e9ecef;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #28a745, #20c997);
            transition: width 0.3s ease;
        }
        .controls {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-weight: bold;
            transition: all 0.3s ease;
        }
        .btn-primary {
            background-color: #007bff;
            color: white;
        }
        .btn-primary:hover {
            background-color: #0056b3;
        }
        .btn-danger {
            background-color: #dc3545;
            color: white;
        }
        .btn-danger:hover {
            background-color: #c82333;
        }
        .btn-success {
            background-color: #28a745;
            color: white;
        }
        .btn-success:hover {
            background-color: #218838;
        }
        .results-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        .results-table th,
        .results-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        .results-table th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        .positive {
            color: #28a745;
            font-weight: bold;
        }
        .negative {
            color: #dc3545;
            font-weight: bold;
        }
        .top-performer {
            background-color: #fff3cd;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            color: #666;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 병렬 백테스트 대시보드</h1>
            <p>실시간 모니터링 및 결과 분석</p>
        </div>
        
        <div class="dashboard">
            <div class="card">
                <h3>📊 실행 상태</h3>
                <div class="status">
                    <div class="status-indicator" id="statusIndicator"></div>
                    <span id="statusText">대기 중</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="progressFill" style="width: 0%"></div>
                </div>
                <div id="progressText">0 / 0 (0%)</div>
                <div id="timeInfo"></div>
                
                <div class="controls">
                    <button class="btn btn-primary" onclick="startQuickTest()">빠른 테스트</button>
                    <button class="btn btn-primary" onclick="startComprehensiveTest()">종합 테스트</button>
                    <button class="btn btn-danger" onclick="stopBacktest()">중지</button>
                </div>
            </div>
            
            <div class="card">
                <h3>📈 요약 통계</h3>
                <div class="stats-grid" id="summaryStats">
                    <div class="stat-card">
                        <div class="stat-value" id="totalTests">0</div>
                        <div class="stat-label">총 테스트</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value" id="successRate">0%</div>
                        <div class="stat-label">성공률</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value" id="avgProfit">$0</div>
                        <div class="stat-label">평균 수익</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value" id="totalProfit">$0</div>
                        <div class="stat-label">총 수익</div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h3>🏆 상위 성과자</h3>
            <div class="controls">
                <button class="btn btn-success" onclick="exportResults('json')">JSON 내보내기</button>
                <button class="btn btn-success" onclick="exportResults('csv')">CSV 내보내기</button>
                <button class="btn btn-success" onclick="exportResults('excel')">Excel 내보내기</button>
            </div>
            <table class="results-table" id="resultsTable">
                <thead>
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
                </thead>
                <tbody id="resultsBody">
                </tbody>
            </table>
        </div>
    </div>
    
    <script>
        let updateInterval;
        
        // 페이지 로드 시 초기화
        document.addEventListener('DOMContentLoaded', function() {
            startUpdates();
        });
        
        // 주기적 업데이트 시작
        function startUpdates() {
            updateInterval = setInterval(updateDashboard, 2000);
            updateDashboard();
        }
        
        // 대시보드 업데이트
        async function updateDashboard() {
            try {
                const [statusResponse, resultsResponse] = await Promise.all([
                    fetch('/api/status'),
                    fetch('/api/results')
                ]);
                
                const status = await statusResponse.json();
                const results = await resultsResponse.json();
                
                updateStatus(status);
                updateResults(results);
                
            } catch (error) {
                console.error('업데이트 실패:', error);
            }
        }
        
        // 상태 업데이트
        function updateStatus(status) {
            const indicator = document.getElementById('statusIndicator');
            const statusText = document.getElementById('statusText');
            const progressFill = document.getElementById('progressFill');
            const progressText = document.getElementById('progressText');
            const timeInfo = document.getElementById('timeInfo');
            
            if (status.is_running) {
                indicator.className = 'status-indicator running';
                statusText.textContent = '실행 중';
            } else {
                indicator.className = 'status-indicator stopped';
                statusText.textContent = '중지됨';
            }
            
            const progress = status.progress;
            const percentage = progress.total > 0 ? (progress.completed / progress.total) * 100 : 0;
            
            progressFill.style.width = percentage + '%';
            progressText.textContent = `${progress.completed} / ${progress.total} (${percentage.toFixed(1)}%)`;
            
            if (progress.start_time) {
                const startTime = new Date(progress.start_time);
                const elapsed = Math.floor((Date.now() - startTime.getTime()) / 1000);
                timeInfo.textContent = `경과 시간: ${elapsed}초`;
            }
        }
        
        // 결과 업데이트
        function updateResults(results) {
            const summary = results.summary;
            
            // 요약 통계 업데이트
            document.getElementById('totalTests').textContent = summary.total || 0;
            document.getElementById('successRate').textContent = (summary.success_rate || 0).toFixed(1) + '%';
            document.getElementById('avgProfit').textContent = '$' + (summary.avg_net_profit || 0).toFixed(2);
            document.getElementById('totalProfit').textContent = '$' + (summary.total_net_profit || 0).toFixed(2);
            
            // 결과 테이블 업데이트
            const tbody = document.getElementById('resultsBody');
            tbody.innerHTML = '';
            
            if (results.results && results.results.length > 0) {
                const sortedResults = results.results
                    .filter(r => r.status === 'completed')
                    .sort((a, b) => b.net_profit - a.net_profit)
                    .slice(0, 20);
                
                sortedResults.forEach((result, index) => {
                    const row = document.createElement('tr');
                    if (index < 5) row.className = 'top-performer';
                    
                    row.innerHTML = `
                        <td>${index + 1}</td>
                        <td>${result.symbol}</td>
                        <td>${result.strategy}</td>
                        <td class="${result.net_profit >= 0 ? 'positive' : 'negative'}">$${result.net_profit.toFixed(2)}</td>
                        <td>${result.win_rate.toFixed(1)}%</td>
                        <td>${result.profit_factor.toFixed(2)}</td>
                        <td>${result.sharpe_ratio.toFixed(2)}</td>
                        <td>${result.max_drawdown_percentage.toFixed(1)}%</td>
                    `;
                    
                    tbody.appendChild(row);
                });
            }
        }
        
        // 빠른 테스트 시작
        async function startQuickTest() {
            try {
                const response = await fetch('/api/start_backtest', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        symbols: ['BTC-USD'],
                        strategies: ['ma_cross', 'rsi'],
                        days: 30
                    })
                });
                
                const result = await response.json();
                if (result.status === 'success') {
                    alert('빠른 테스트가 시작되었습니다!');
                } else {
                    alert('테스트 시작 실패: ' + result.message);
                }
            } catch (error) {
                alert('오류 발생: ' + error.message);
            }
        }
        
        // 종합 테스트 시작
        async function startComprehensiveTest() {
            try {
                const response = await fetch('/api/start_backtest', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        symbols: ['BTC-USD', 'ETH-USD'],
                        strategies: ['ma_cross', 'rsi', 'bollinger', 'macd'],
                        days: 90
                    })
                });
                
                const result = await response.json();
                if (result.status === 'success') {
                    alert('종합 테스트가 시작되었습니다!');
                } else {
                    alert('테스트 시작 실패: ' + result.message);
                }
            } catch (error) {
                alert('오류 발생: ' + error.message);
            }
        }
        
        // 백테스트 중지
        async function stopBacktest() {
            try {
                const response = await fetch('/api/stop_backtest', {
                    method: 'POST'
                });
                
                const result = await response.json();
                if (result.status === 'success') {
                    alert('백테스트 중지 요청이 전송되었습니다.');
                }
            } catch (error) {
                alert('오류 발생: ' + error.message);
            }
        }
        
        // 결과 내보내기
        async function exportResults(format) {
            try {
                const response = await fetch('/api/export_results', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        format: format
                    })
                });
                
                const result = await response.json();
                if (result.status === 'success') {
                    alert(result.message);
                } else {
                    alert('내보내기 실패: ' + result.message);
                }
            } catch (error) {
                alert('오류 발생: ' + error.message);
            }
        }
    </script>
</body>
</html>
"""
    
    with open(os.path.join(template_dir, "dashboard.html"), 'w', encoding='utf-8') as f:
        f.write(html_content)

def main():
    """메인 실행 함수"""
    print("📊 실시간 모니터링 대시보드 시작!")
    print("=" * 60)
    
    # 템플릿 생성
    create_dashboard_template()
    
    # 대시보드 초기화
    dashboard = RealtimeDashboard(host="0.0.0.0", port=5000)
    
    print("🚀 대시보드 실행 중...")
    print("   - 주소: http://localhost:5000")
    print("   - 브라우저에서 접속하여 사용하세요")
    print("   - Ctrl+C로 종료")
    
    # 대시보드 실행
    dashboard.run(debug=False)

if __name__ == "__main__":
    main()
