#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
최신 집계 결과(JSON)를 읽어 CSV로 내보내기
- summary.csv: 요약 통계 키-값
- top_results.csv: 상위 성과 목록
"""

import json
import os
import csv
from pathlib import Path

RESULTS_DIR = Path('parallel_results')
AGG_DIR = RESULTS_DIR / 'aggregated'
EXPORT_DIR = RESULTS_DIR / 'exports'

def main() -> None:
    # 최신 집계 파일 탐색
    if not AGG_DIR.exists():
        print('집계 디렉토리가 없습니다:', AGG_DIR)
        return
    agg_files = sorted(AGG_DIR.glob('aggregated_*.json'), key=os.path.getmtime, reverse=True)
    if not agg_files:
        print('집계 파일이 없습니다:', AGG_DIR)
        return
    latest = agg_files[0]

    # JSON 로드
    with open(latest, 'r', encoding='utf-8') as f:
        data = json.load(f)

    EXPORT_DIR.mkdir(parents=True, exist_ok=True)

    # summary.csv
    summary = data.get('summary') or {}
    with open(EXPORT_DIR / 'summary.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['metric', 'value'])
        for k, v in summary.items():
            w.writerow([k, v])

    # top_results.csv (호환 필드명 보정)
    top = data.get('top_results') or data.get('top') or []
    if isinstance(top, dict):
        top = top.get('items') or top.get('results') or []
    # 컬럼 합집합
    cols = []
    seen = set()
    for r in top:
        for c in r.keys():
            if c not in seen:
                seen.add(c)
                cols.append(c)
    if not cols:
        cols = ['symbol','timeframe','strategy_name','net_profit','win_rate','profit_factor']
    with open(EXPORT_DIR / 'top_results.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in top:
            w.writerow({k: r.get(k) for k in cols})

    print('OK', latest.name, '->', EXPORT_DIR)

if __name__ == '__main__':
    main()


