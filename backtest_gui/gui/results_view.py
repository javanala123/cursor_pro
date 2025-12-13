#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
결과 뷰 - 백테스트 결과 표시
"""

from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                             QProgressBar, QTableWidget, QTableWidgetItem,
                             QPushButton, QHeaderView, QFileDialog, QMessageBox, QDialog, QTextEdit)
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QColor
import json
import csv
from datetime import datetime
from pathlib import Path


class ResultsView(QWidget):
    """결과 뷰 위젯"""
    
    def __init__(self):
        super().__init__()
        self.results = []
        self.init_ui()
    
    def init_ui(self):
        """UI 초기화"""
        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        
        # 제목
        title = QLabel('백테스트 결과')
        title.setStyleSheet('font-weight: bold; font-size: 12pt; padding: 5px;')
        layout.addWidget(title)
        
        # 진행률 바
        progress_layout = QHBoxLayout()
        progress_layout.addWidget(QLabel('진행률:'))
        self.progress_bar = QProgressBar()
        self.progress_bar.setMinimum(0)
        self.progress_bar.setMaximum(100)
        self.progress_bar.setValue(0)
        progress_layout.addWidget(self.progress_bar)
        self.status_label = QLabel('대기 중...')
        progress_layout.addWidget(self.status_label)
        layout.addLayout(progress_layout)
        
        # 결과 테이블
        self.results_table = QTableWidget()
        self.results_table.setColumnCount(7)
        self.results_table.setHorizontalHeaderLabels([
            '순위', '심볼', '시간프레임', '수익률 (%)', '승률 (%)', 
            '샤프 비율', '거래 수'
        ])
        self.results_table.horizontalHeader().setStretchLastSection(True)
        self.results_table.setAlternatingRowColors(True)
        self.results_table.setSortingEnabled(True)
        self.results_table.setSelectionBehavior(QTableWidget.SelectRows)
        self.results_table.itemDoubleClicked.connect(self.show_detail)
        layout.addWidget(self.results_table)
        
        # 버튼
        btn_layout = QHBoxLayout()
        
        self.chart_btn = QPushButton('차트 보기')
        self.chart_btn.clicked.connect(self.show_chart)
        btn_layout.addWidget(self.chart_btn)
        
        self.save_btn = QPushButton('결과 저장')
        self.save_btn.clicked.connect(self.save_results)
        btn_layout.addWidget(self.save_btn)
        
        self.report_btn = QPushButton('리포트 생성')
        self.report_btn.clicked.connect(self.generate_report)
        btn_layout.addWidget(self.report_btn)
        
        btn_layout.addStretch()
        layout.addLayout(btn_layout)
    
    def update_progress(self, value, status):
        """진행률 업데이트"""
        self.progress_bar.setValue(value)
        self.status_label.setText(status)
    
    def add_result(self, result_data):
        """결과 추가"""
        self.results.append(result_data)
        
        # 테이블에 추가
        row = self.results_table.rowCount()
        self.results_table.insertRow(row)
        
        # 순위
        rank_item = QTableWidgetItem(str(len(self.results)))
        rank_item.setData(Qt.UserRole, result_data)
        self.results_table.setItem(row, 0, rank_item)
        
        # 심볼
        symbol_item = QTableWidgetItem(result_data.get('symbol', ''))
        self.results_table.setItem(row, 1, symbol_item)
        
        # 시간프레임
        tf_item = QTableWidgetItem(result_data.get('timeframe', ''))
        self.results_table.setItem(row, 2, tf_item)
        
        # 수익률
        return_pct = result_data.get('metrics', {}).get('total_return', 0)
        return_item = QTableWidgetItem(f"{return_pct:.2f}")
        if return_pct > 0:
            return_item.setForeground(QColor(0, 150, 0))
        elif return_pct < 0:
            return_item.setForeground(QColor(200, 0, 0))
        self.results_table.setItem(row, 3, return_item)
        
        # 승률
        win_rate = result_data.get('metrics', {}).get('win_rate', 0)
        winrate_item = QTableWidgetItem(f"{win_rate:.2f}")
        self.results_table.setItem(row, 4, winrate_item)
        
        # 샤프 비율
        sharpe = result_data.get('metrics', {}).get('sharpe_ratio', 0)
        sharpe_item = QTableWidgetItem(f"{sharpe:.2f}")
        self.results_table.setItem(row, 5, sharpe_item)
        
        # 거래 수
        trades = result_data.get('metrics', {}).get('total_trades', 0)
        trades_item = QTableWidgetItem(str(trades))
        self.results_table.setItem(row, 6, trades_item)
        
        # 수익률 기준으로 정렬
        self.results_table.sortItems(3, Qt.DescendingOrder)
        
        # 순위 재계산
        for i in range(self.results_table.rowCount()):
            self.results_table.item(i, 0).setText(str(i + 1))
    
    def clear_results(self):
        """결과 초기화"""
        self.results = []
        self.results_table.setRowCount(0)
        self.progress_bar.setValue(0)
        self.status_label.setText('대기 중...')
    
    def get_all_results(self):
        """모든 결과 반환"""
        return self.results
    
    def show_detail(self, item):
        """상세 정보 표시"""
        result_data = item.data(Qt.UserRole)
        if not result_data:
            return
        
        from PyQt5.QtWidgets import QDialog, QVBoxLayout, QTextEdit
        
        dialog = QDialog(self)
        dialog.setWindowTitle('상세 결과')
        dialog.setGeometry(200, 200, 600, 400)
        
        layout = QVBoxLayout(dialog)
        
        text_edit = QTextEdit()
        text_edit.setReadOnly(True)
        
        # 결과 포맷팅
        text = "=== 백테스트 상세 결과 ===\n\n"
        text += f"심볼: {result_data.get('symbol', '')}\n"
        text += f"시간프레임: {result_data.get('timeframe', '')}\n\n"
        
        text += "파라미터:\n"
        params = result_data.get('parameters', {})
        for key, value in params.items():
            text += f"  {key}: {value}\n"
        
        text += "\n성과 지표:\n"
        metrics = result_data.get('metrics', {})
        for key, value in metrics.items():
            if isinstance(value, float):
                text += f"  {key}: {value:.2f}\n"
            else:
                text += f"  {key}: {value}\n"
        
        text_edit.setPlainText(text)
        layout.addWidget(text_edit)
        
        dialog.exec_()
    
    def show_chart(self):
        """차트 표시"""
        if not self.results:
            QMessageBox.warning(self, '경고', '표시할 결과가 없습니다.')
            return
        
        try:
            from gui.chart_view import ChartView
            chart_dialog = ChartView(self.results, self)
            chart_dialog.exec_()
        except Exception as e:
            QMessageBox.critical(self, '오류', f'차트 표시 실패:\n{str(e)}')
    
    def save_results(self):
        """결과 저장"""
        if not self.results:
            QMessageBox.warning(self, '경고', '저장할 결과가 없습니다.')
            return
        
        filename, _ = QFileDialog.getSaveFileName(
            self,
            '결과 저장',
            f"backtest_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json",
            'JSON 파일 (*.json);;CSV 파일 (*.csv);;모든 파일 (*.*)'
        )
        
        if filename:
            try:
                if filename.endswith('.csv'):
                    self._save_csv(filename)
                else:
                    self._save_json(filename)
                QMessageBox.information(self, '완료', '결과가 저장되었습니다.')
            except Exception as e:
                QMessageBox.critical(self, '오류', f'저장 실패:\n{str(e)}')
    
    def _save_json(self, filename):
        """JSON 형식으로 저장"""
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, indent=2, ensure_ascii=False)
    
    def _save_csv(self, filename):
        """CSV 형식으로 저장"""
        with open(filename, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow([
                '순위', '심볼', '시간프레임', '수익률 (%)', '승률 (%)',
                '샤프 비율', '거래 수', '파라미터'
            ])
            
            for i, result in enumerate(self.results, 1):
                metrics = result.get('metrics', {})
                params_str = str(result.get('parameters', {}))
                writer.writerow([
                    i,
                    result.get('symbol', ''),
                    result.get('timeframe', ''),
                    metrics.get('total_return', 0),
                    metrics.get('win_rate', 0),
                    metrics.get('sharpe_ratio', 0),
                    metrics.get('total_trades', 0),
                    params_str
                ])
    
    def generate_report(self):
        """리포트 생성"""
        if not self.results:
            QMessageBox.warning(self, '경고', '리포트를 생성할 결과가 없습니다.')
            return
        
        try:
            # 간단한 HTML 리포트 생성
            filename = self._generate_simple_report()
            QMessageBox.information(
                self,
                '완료',
                f'리포트가 생성되었습니다:\n{filename}'
            )
        except Exception as e:
            QMessageBox.critical(self, '오류', f'리포트 생성 실패:\n{str(e)}')
    
    def _generate_simple_report(self):
        """간단한 HTML 리포트 생성"""
        from datetime import datetime
        from pathlib import Path
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        report_dir = Path('results/reports')
        report_dir.mkdir(parents=True, exist_ok=True)
        filename = report_dir / f'report_{timestamp}.html'
        
        html = f"""
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>백테스트 리포트</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        table {{ border-collapse: collapse; width: 100%; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #4CAF50; color: white; }}
        tr:nth-child(even) {{ background-color: #f2f2f2; }}
    </style>
</head>
<body>
    <h1>백테스트 리포트</h1>
    <p>생성 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
    <h2>결과 요약</h2>
    <table>
        <tr>
            <th>순위</th>
            <th>심볼</th>
            <th>시간프레임</th>
            <th>수익률 (%)</th>
            <th>승률 (%)</th>
            <th>샤프 비율</th>
            <th>거래 수</th>
        </tr>
"""
        
        sorted_results = sorted(
            self.results,
            key=lambda x: x.get('metrics', {}).get('total_return', 0),
            reverse=True
        )[:20]
        
        for i, result in enumerate(sorted_results, 1):
            metrics = result.get('metrics', {})
            html += f"""
        <tr>
            <td>{i}</td>
            <td>{result.get('symbol', '')}</td>
            <td>{result.get('timeframe', '')}</td>
            <td>{metrics.get('total_return', 0):.2f}</td>
            <td>{metrics.get('win_rate', 0):.2f}</td>
            <td>{metrics.get('sharpe_ratio', 0):.2f}</td>
            <td>{metrics.get('total_trades', 0)}</td>
        </tr>
"""
        
        html += """
    </table>
</body>
</html>
"""
        
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(html)
        
        return str(filename)

