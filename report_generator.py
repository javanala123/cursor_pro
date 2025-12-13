#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
리포트 생성 시스템
심볼별, 카테고리별 최적화 결과 리포트를 생성합니다.
"""

import json
import yaml
import pandas as pd
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams['font.family'] = 'Malgun Gothic'  # 한글 폰트 설정
matplotlib.rcParams['axes.unicode_minus'] = False


class ReportGenerator:
    """리포트 생성기"""
    
    def __init__(self, results_dir: str = "results"):
        """초기화"""
        self.results_dir = Path(results_dir)
        self.reports_dir = self.results_dir / "reports"
        self.reports_dir.mkdir(exist_ok=True)
    
    def generate_symbol_report(self, symbol: str, timeframe: str) -> str:
        """
        심볼별 리포트 생성
        
        Args:
            symbol: 심볼명
            timeframe: 시간프레임
            
        Returns:
            리포트 파일 경로
        """
        # 결과 파일 찾기
        result_files = list(self.results_dir.glob(f"{symbol}_{timeframe}_*.json"))
        if not result_files:
            print(f"결과 파일을 찾을 수 없습니다: {symbol}_{timeframe}")
            return ""
        
        # 가장 최근 파일 사용
        latest_file = max(result_files, key=lambda p: p.stat().st_mtime)
        
        with open(latest_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # 리포트 생성
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = self.reports_dir / f"report_{symbol}_{timeframe}_{timestamp}.html"
        
        html_content = self._generate_html_report(symbol, timeframe, data)
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"리포트 생성: {report_file}")
        return str(report_file)
    
    def generate_category_report(self, category: str) -> str:
        """
        카테고리별 리포트 생성
        
        Args:
            category: 카테고리명 (futures, crypto, forex)
            
        Returns:
            리포트 파일 경로
        """
        # 카테고리별 결과 파일 찾기
        result_files = list(self.results_dir.glob(f"*_*.json"))
        
        category_results = []
        for file in result_files:
            with open(file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                # 심볼 카테고리 확인 (간단한 방법)
                symbol = data.get('symbol', '')
                if self._is_category_symbol(symbol, category):
                    category_results.append(data)
        
        if not category_results:
            print(f"카테고리 '{category}'에 대한 결과를 찾을 수 없습니다.")
            return ""
        
        # 리포트 생성
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = self.reports_dir / f"report_{category}_{timestamp}.html"
        
        html_content = self._generate_category_html_report(category, category_results)
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"카테고리 리포트 생성: {report_file}")
        return str(report_file)
    
    def _is_category_symbol(self, symbol: str, category: str) -> bool:
        """심볼이 특정 카테고리에 속하는지 확인"""
        with open('config/symbol_categories.yaml', 'r', encoding='utf-8') as f:
            categories = yaml.safe_load(f)
        
        if category == 'futures':
            futures_symbols = []
            for subcat in ['indices', 'metals', 'energy']:
                if subcat in categories.get('futures', {}):
                    for item in categories['futures'][subcat]:
                        futures_symbols.append(item.get('symbol', ''))
                        futures_symbols.append(item.get('mt5_symbol', ''))
            return symbol in futures_symbols
        
        elif category == 'crypto':
            crypto_symbols = []
            for subcat in ['major', 'altcoins']:
                if subcat in categories.get('crypto', {}):
                    for item in categories['crypto'][subcat]:
                        crypto_symbols.append(item.get('symbol', ''))
                        crypto_symbols.append(item.get('mt5_symbol', ''))
            return symbol in crypto_symbols
        
        elif category == 'forex':
            forex_symbols = []
            if 'major_pairs' in categories.get('forex', {}):
                for item in categories['forex']['major_pairs']:
                    forex_symbols.append(item.get('symbol', ''))
                    forex_symbols.append(item.get('mt5_symbol', ''))
            return symbol in forex_symbols
        
        return False
    
    def _generate_html_report(self, symbol: str, timeframe: str, data: Dict) -> str:
        """HTML 리포트 생성"""
        best_result = data.get('best_result', {})
        all_results = data.get('all_results', [])
        
        html = f"""
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>볼린저 밴드 전략 최적화 리포트 - {symbol} {timeframe}</title>
    <style>
        body {{
            font-family: 'Malgun Gothic', Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        h1 {{
            color: #333;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }}
        h2 {{
            color: #555;
            margin-top: 30px;
        }}
        .section {{
            margin: 20px 0;
            padding: 20px;
            background-color: #f9f9f9;
            border-radius: 5px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }}
        th, td {{
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }}
        th {{
            background-color: #4CAF50;
            color: white;
        }}
        tr:hover {{
            background-color: #f5f5f5;
        }}
        .metric {{
            display: inline-block;
            margin: 10px 20px;
            padding: 15px;
            background-color: #e8f5e9;
            border-radius: 5px;
            min-width: 150px;
        }}
        .metric-label {{
            font-weight: bold;
            color: #666;
        }}
        .metric-value {{
            font-size: 24px;
            color: #4CAF50;
            font-weight: bold;
        }}
        .parameter {{
            display: inline-block;
            margin: 5px 10px;
            padding: 8px 15px;
            background-color: #fff3e0;
            border-radius: 3px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>볼린저 밴드 전략 최적화 리포트</h1>
        
        <div class="section">
            <h2>기본 정보</h2>
            <p><strong>심볼:</strong> {symbol}</p>
            <p><strong>시간프레임:</strong> {timeframe}</p>
            <p><strong>생성 시간:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            <p><strong>총 결과 수:</strong> {len(all_results)}</p>
        </div>
        
        <div class="section">
            <h2>최적 파라미터</h2>
"""
        
        params = best_result.get('parameters', {})
        for key, value in params.items():
            html += f'            <span class="parameter"><strong>{key}:</strong> {value}</span>\n'
        
        html += """
        </div>
        
        <div class="section">
            <h2>성과 지표</h2>
"""
        
        metrics = best_result.get('metrics', {})
        for key, value in metrics.items():
            if isinstance(value, float):
                value = f"{value:.2f}"
            html += f"""
            <div class="metric">
                <div class="metric-label">{key}</div>
                <div class="metric-value">{value}</div>
            </div>
"""
        
        html += """
        </div>
        
        <div class="section">
            <h2>상위 10개 결과</h2>
            <table>
                <thead>
                    <tr>
                        <th>순위</th>
                        <th>수익률 (%)</th>
                        <th>승률 (%)</th>
                        <th>샤프 비율</th>
                        <th>거래 횟수</th>
                    </tr>
                </thead>
                <tbody>
"""
        
        # 결과 정렬 (수익률 기준)
        sorted_results = sorted(all_results, 
                              key=lambda x: x.get('metrics', {}).get('total_return', 0), 
                              reverse=True)
        
        for i, result in enumerate(sorted_results[:10], 1):
            metrics = result.get('metrics', {})
            html += f"""
                    <tr>
                        <td>{i}</td>
                        <td>{metrics.get('total_return', 0):.2f}</td>
                        <td>{metrics.get('win_rate', 0):.2f}</td>
                        <td>{metrics.get('sharpe_ratio', 0):.2f}</td>
                        <td>{metrics.get('total_trades', 0)}</td>
                    </tr>
"""
        
        html += """
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
"""
        
        return html
    
    def _generate_category_html_report(self, category: str, results: List[Dict]) -> str:
        """카테고리별 HTML 리포트 생성"""
        html = f"""
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>볼린저 밴드 전략 최적화 리포트 - {category}</title>
    <style>
        body {{
            font-family: 'Malgun Gothic', Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        h1 {{
            color: #333;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }}
        th, td {{
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }}
        th {{
            background-color: #4CAF50;
            color: white;
        }}
        tr:hover {{
            background-color: #f5f5f5;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>볼린저 밴드 전략 최적화 리포트 - {category.upper()}</h1>
        
        <table>
            <thead>
                <tr>
                    <th>심볼</th>
                    <th>시간프레임</th>
                    <th>최적 수익률 (%)</th>
                    <th>승률 (%)</th>
                    <th>샤프 비율</th>
                    <th>거래 횟수</th>
                </tr>
            </thead>
            <tbody>
"""
        
        for result_data in results:
            symbol = result_data.get('symbol', '')
            timeframe = result_data.get('timeframe', '')
            best_result = result_data.get('best_result', {})
            metrics = best_result.get('metrics', {})
            
            html += f"""
                <tr>
                    <td>{symbol}</td>
                    <td>{timeframe}</td>
                    <td>{metrics.get('total_return', 0):.2f}</td>
                    <td>{metrics.get('win_rate', 0):.2f}</td>
                    <td>{metrics.get('sharpe_ratio', 0):.2f}</td>
                    <td>{metrics.get('total_trades', 0)}</td>
                </tr>
"""
        
        html += """
            </tbody>
        </table>
    </div>
</body>
</html>
"""
        
        return html


def main():
    """메인 함수"""
    import argparse
    
    parser = argparse.ArgumentParser(description='최적화 결과 리포트 생성')
    parser.add_argument('--symbol', type=str, help='심볼명')
    parser.add_argument('--timeframe', type=str, default='H1', help='시간프레임')
    parser.add_argument('--category', type=str, choices=['futures', 'crypto', 'forex'],
                       help='카테고리')
    
    args = parser.parse_args()
    
    generator = ReportGenerator()
    
    if args.category:
        generator.generate_category_report(args.category)
    elif args.symbol:
        generator.generate_symbol_report(args.symbol, args.timeframe)
    else:
        print("--symbol 또는 --category를 지정해야 합니다.")


if __name__ == '__main__':
    main()

