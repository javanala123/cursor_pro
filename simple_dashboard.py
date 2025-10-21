#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
간단한 웹 대시보드 - 실시간 백테스트 모니터링
"""

from flask import Flask, render_template_string, jsonify
import json
import os
import time
from datetime import datetime
import threading

app = Flask(__name__)

# 전역 변수
latest_results = []
task_states = {}
total_tasks = 0
completed_tasks = 0

def load_latest_results():
    """최신 결과 로드"""
    global latest_results, task_states, total_tasks, completed_tasks
    
    results_dir = "parallel_results"
    if os.path.exists(results_dir):
        # 개별 결과 파일들 로드 (individual 폴더에서)
        individual_dir = os.path.join(results_dir, "individual")
        if os.path.exists(individual_dir):
            for filename in os.listdir(individual_dir):
                if filename.startswith("result_") and filename.endswith(".json"):
                    try:
                        with open(os.path.join(individual_dir, filename), 'r', encoding='utf-8') as f:
                            result = json.load(f)
                            # 결과를 대시보드 형식으로 변환
                            dashboard_result = {
                                'symbol': result.get('config', {}).get('symbol', 'N/A'),
                                'strategy_name': result.get('config', {}).get('strategy_name', 'N/A'),
                                'net_profit': result.get('net_profit', 0),
                                'win_rate': result.get('win_rate', 0) / 100 if result.get('win_rate', 0) > 1 else result.get('win_rate', 0),
                                'profit_factor': result.get('profit_factor', 0),
                                'max_drawdown': result.get('max_drawdown_percentage', 0),
                                'total_trades': result.get('total_trades', 0),
                                'sharpe_ratio': result.get('sharpe_ratio', 0)
                            }
                            latest_results.append(dashboard_result)
                    except Exception as e:
                        print(f"결과 파일 로드 오류: {filename} - {e}")
        
        # 집계 결과 로드 (aggregated 폴더에서)
        aggregated_dir = os.path.join(results_dir, "aggregated")
        if os.path.exists(aggregated_dir):
            # 가장 최근 집계 파일 찾기
            aggregated_files = [f for f in os.listdir(aggregated_dir) if f.startswith("aggregated_") and f.endswith(".json")]
            if aggregated_files:
                latest_aggregated = max(aggregated_files)
                try:
                    with open(os.path.join(aggregated_dir, latest_aggregated), 'r', encoding='utf-8') as f:
                        summary = json.load(f)
                        total_tasks = summary.get('summary', {}).get('total_configs', 0)
                        completed_tasks = summary.get('summary', {}).get('successful_configs', 0)
                except Exception as e:
                    print(f"집계 파일 로드 오류: {latest_aggregated} - {e}")
    
    # 결과를 수익률 순으로 정렬
    latest_results.sort(key=lambda x: x.get('net_profit', 0), reverse=True)

# HTML 템플릿
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🚀 백테스트 대시보드</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333; min-height: 100vh; padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; color: white; margin-bottom: 30px; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { 
            background: white; border-radius: 15px; padding: 25px; text-align: center; 
            box-shadow: 0 10px 30px rgba(0,0,0,0.1); transition: transform 0.3s ease;
        }
        .stat-card:hover { transform: translateY(-5px); }
        .stat-card h3 { font-size: 2.5em; color: #667eea; margin-bottom: 10px; }
        .stat-card p { color: #666; font-size: 1.1em; }
        .results-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .card { 
            background: white; border-radius: 15px; padding: 25px; 
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .card h2 { color: #4a5568; margin-bottom: 20px; border-bottom: 3px solid #667eea; padding-bottom: 10px; }
        .result-item { 
            background: #f8f9fa; border-radius: 8px; padding: 15px; margin-bottom: 10px; 
            border-left: 5px solid #48bb78; transition: all 0.3s ease;
        }
        .result-item:hover { background: #e9ecef; transform: translateX(5px); }
        .result-item.negative { border-left-color: #f56565; }
        .result-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
        .result-title { font-weight: bold; color: #2d3748; }
        .result-profit { font-weight: bold; font-size: 1.2em; }
        .profit-positive { color: #48bb78; }
        .profit-negative { color: #f56565; }
        .result-details { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; font-size: 0.9em; color: #718096; }
        .refresh-btn { 
            background: #667eea; color: white; border: none; padding: 12px 24px; 
            border-radius: 8px; cursor: pointer; font-size: 1em; margin: 20px 0;
            transition: background 0.3s ease;
        }
        .refresh-btn:hover { background: #5a67d8; }
        .loading { text-align: center; padding: 40px; color: #718096; }
        .spinner { 
            border: 4px solid #f3f3f3; border-top: 4px solid #667eea; border-radius: 50%; 
            width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 0 auto 20px;
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .no-data { text-align: center; padding: 40px; color: #718096; }
        @media (max-width: 768px) {
            .results-grid { grid-template-columns: 1fr; }
            .stats { grid-template-columns: repeat(2, 1fr); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 백테스트 대시보드</h1>
            <p>실시간 백테스트 결과 모니터링</p>
        </div>

        <div class="stats">
            <div class="stat-card">
                <h3 id="total-tasks">{{ total_tasks }}</h3>
                <p>총 작업</p>
            </div>
            <div class="stat-card">
                <h3 id="completed-tasks">{{ completed_tasks }}</h3>
                <p>완료</p>
            </div>
            <div class="stat-card">
                <h3 id="success-rate">{{ success_rate }}%</h3>
                <p>성공률</p>
            </div>
            <div class="stat-card">
                <h3 id="best-profit">${{ best_profit }}</h3>
                <p>최고 수익</p>
            </div>
        </div>

        <button class="refresh-btn" onclick="location.reload()">🔄 새로고침</button>

        <div class="results-grid">
            <div class="card">
                <h2>🏆 상위 성과 전략</h2>
                <div id="top-results">
                    {% if results %}
                        {% for result in results[:10] %}
                        <div class="result-item {% if result.net_profit < 0 %}negative{% endif %}">
                            <div class="result-header">
                                <span class="result-title">#{{ loop.index }} {{ result.symbol }} - {{ result.strategy_name }}</span>
                                <span class="result-profit {% if result.net_profit >= 0 %}profit-positive{% else %}profit-negative{% endif %}">
                                    ${{ "%.2f"|format(result.net_profit) }}
                                </span>
                            </div>
                            <div class="result-details">
                                <div><strong>승률:</strong> {{ "%.1f"|format(result.win_rate * 100) }}%</div>
                                <div><strong>수익팩터:</strong> {{ "%.2f"|format(result.profit_factor) }}</div>
                                <div><strong>최대손실:</strong> {{ "%.1f"|format(result.max_drawdown * 100) }}%</div>
                                <div><strong>거래수:</strong> {{ result.total_trades }}</div>
                            </div>
                        </div>
                        {% endfor %}
                    {% else %}
                        <div class="no-data">
                            <p>📊 백테스트 결과가 없습니다.</p>
                            <p>백테스트를 실행해보세요!</p>
                        </div>
                    {% endif %}
                </div>
            </div>

            <div class="card">
                <h2>📈 성과 통계</h2>
                <div id="statistics">
                    {% if results %}
                        <div class="result-item">
                            <div class="result-header">
                                <span class="result-title">평균 수익</span>
                                <span class="result-profit {% if avg_profit >= 0 %}profit-positive{% else %}profit-negative{% endif %}">
                                    ${{ "%.2f"|format(avg_profit) }}
                                </span>
                            </div>
                        </div>
                        <div class="result-item">
                            <div class="result-header">
                                <span class="result-title">평균 승률</span>
                                <span class="result-profit profit-positive">
                                    {{ "%.1f"|format(avg_win_rate * 100) }}%
                                </span>
                            </div>
                        </div>
                        <div class="result-item">
                            <div class="result-header">
                                <span class="result-title">평균 수익팩터</span>
                                <span class="result-profit profit-positive">
                                    {{ "%.2f"|format(avg_profit_factor) }}
                                </span>
                            </div>
                        </div>
                        <div class="result-item">
                            <div class="result-header">
                                <span class="result-title">총 거래수</span>
                                <span class="result-profit profit-positive">
                                    {{ total_trades }}
                                </span>
                            </div>
                        </div>
                    {% else %}
                        <div class="no-data">
                            <p>📊 통계 데이터가 없습니다.</p>
                        </div>
                    {% endif %}
                </div>
            </div>
        </div>

        <div style="text-align: center; margin-top: 30px; color: white; opacity: 0.8;">
            <p>마지막 업데이트: {{ last_update }}</p>
            <p>💡 새로고침 버튼을 눌러 최신 결과를 확인하세요!</p>
        </div>
    </div>

    <script>
        // 30초마다 자동 새로고침
        setTimeout(function() {
            location.reload();
        }, 30000);
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    """메인 대시보드"""
    load_latest_results()
    
    # 통계 계산
    if latest_results:
        avg_profit = sum(r.get('net_profit', 0) for r in latest_results) / len(latest_results)
        avg_win_rate = sum(r.get('win_rate', 0) for r in latest_results) / len(latest_results)
        avg_profit_factor = sum(r.get('profit_factor', 0) for r in latest_results) / len(latest_results)
        total_trades = sum(r.get('total_trades', 0) for r in latest_results)
        best_profit = max(r.get('net_profit', 0) for r in latest_results)
        success_rate = (completed_tasks / total_tasks * 100) if total_tasks > 0 else 0
    else:
        avg_profit = avg_win_rate = avg_profit_factor = total_trades = best_profit = 0
        success_rate = 0
    
    return render_template_string(HTML_TEMPLATE,
        results=latest_results,
        total_tasks=total_tasks,
        completed_tasks=completed_tasks,
        success_rate=round(success_rate, 1),
        best_profit=round(best_profit, 2),
        avg_profit=round(avg_profit, 2),
        avg_win_rate=round(avg_win_rate, 3),
        avg_profit_factor=round(avg_profit_factor, 2),
        total_trades=total_trades,
        last_update=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    )

@app.route('/api/results')
def api_results():
    """API 엔드포인트 - JSON 결과"""
    load_latest_results()
    return jsonify({
        'results': latest_results,
        'total_tasks': total_tasks,
        'completed_tasks': completed_tasks,
        'last_update': datetime.now().isoformat()
    })

if __name__ == '__main__':
    print("🚀 간단한 백테스트 대시보드 시작!")
    print("📊 주소: http://localhost:5001")
    print("🔄 30초마다 자동 새로고침됩니다.")
    app.run(host='0.0.0.0', port=5001, debug=False)
