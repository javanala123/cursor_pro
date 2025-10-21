#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
전문가용 백테스트 대시보드 (Flask)
- 결과 폴더(parallel_results)의 집계/개별 결과를 API로 제공
- 템플릿(templates/pro_dashboard.html)에서 표/차트로 시각화
"""

from flask import Flask, jsonify, render_template, request, abort
from pathlib import Path
import json
import os
from datetime import datetime

app = Flask(__name__)

# 한글 주석: 결과 디렉토리 설정
RESULTS_DIR = Path('parallel_results')
AGG_DIR = RESULTS_DIR / 'aggregated'
IND_DIR = RESULTS_DIR / 'individual'

def _latest_aggregated_file():
    if not AGG_DIR.exists():
        return None
    files = sorted(AGG_DIR.glob('aggregated_*.json'), key=os.path.getmtime, reverse=True)
    return files[0] if files else None

def _list_individual(limit=200):
    if not IND_DIR.exists():
        return []
    files = sorted(IND_DIR.glob('result_*.json'), key=os.path.getmtime, reverse=True)
    items = []
    for f in files[:limit]:
        try:
            with open(f, 'r', encoding='utf-8') as fh:
                data = json.load(fh)
            items.append({
                'id': f.name,
                'symbol': data.get('config', {}).get('symbol'),
                'timeframe': data.get('config', {}).get('timeframe', ''),
                'strategy': data.get('config', {}).get('strategy_name'),
                'net_profit': data.get('net_profit'),
                'win_rate': data.get('win_rate'),
                'profit_factor': data.get('profit_factor'),
                'mdd': data.get('max_drawdown_percentage'),
                'status': data.get('status', ''),
            })
        except Exception:
            continue
    return items

@app.route('/')
def index():
    # 한글 주석: 템플릿 렌더링
    return render_template('pro_dashboard.html')

@app.route('/api/summary')
def api_summary():
    f = _latest_aggregated_file()
    if not f:
        return jsonify({'ok': True, 'data': {}})
    with open(f, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
    return jsonify({'ok': True, 'data': data.get('summary', {})})

@app.route('/api/top')
def api_top():
    f = _latest_aggregated_file()
    if not f:
        return jsonify({'ok': True, 'data': []})
    with open(f, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
    return jsonify({'ok': True, 'data': data.get('top_performers', [])})

@app.route('/api/strategies')
def api_strategies():
    f = _latest_aggregated_file()
    if not f:
        return jsonify({'ok': True, 'data': {}})
    with open(f, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
    return jsonify({'ok': True, 'data': data.get('strategy_analysis', {})})

@app.route('/api/symbols')
def api_symbols():
    f = _latest_aggregated_file()
    if not f:
        return jsonify({'ok': True, 'data': {}})
    with open(f, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
    return jsonify({'ok': True, 'data': data.get('symbol_analysis', {})})

@app.route('/api/list')
def api_list():
    limit = int(request.args.get('limit', 200))
    return jsonify({'ok': True, 'data': _list_individual(limit)})

@app.route('/api/detail')
def api_detail():
    fid = request.args.get('id')
    if not fid:
        abort(400)
    fpath = IND_DIR / fid
    if not fpath.exists():
        abort(404)
    with open(fpath, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
    return jsonify({'ok': True, 'data': data})

def main():
    print('🚀 전문가용 대시보드 시작: http://localhost:5002')
    app.run(host='0.0.0.0', port=5002)

if __name__ == '__main__':
    main()


