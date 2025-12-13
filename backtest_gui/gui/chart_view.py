#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
차트 뷰 - 백테스트 결과 시각화
"""

from PyQt5.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QPushButton, QComboBox, QLabel
from PyQt5.QtCore import Qt
try:
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
    from matplotlib.figure import Figure
    import numpy as np
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False


class ChartView(QDialog):
    """차트 뷰 다이얼로그"""
    
    def __init__(self, results, parent=None):
        super().__init__(parent)
        self.results = results
        self.init_ui()
        self.plot_chart()
    
    def init_ui(self):
        """UI 초기화"""
        self.setWindowTitle('백테스트 결과 차트')
        self.setGeometry(100, 100, 1000, 700)
        
        layout = QVBoxLayout(self)
        
        if not MATPLOTLIB_AVAILABLE:
            error_label = QLabel('matplotlib가 설치되지 않았습니다.\npip install matplotlib로 설치해주세요.')
            error_label.setStyleSheet('color: red; font-size: 14pt; padding: 20px;')
            layout.addWidget(error_label)
            close_btn = QPushButton('닫기')
            close_btn.clicked.connect(self.close)
            layout.addWidget(close_btn)
            return
        
        # 차트 타입 선택
        chart_layout = QHBoxLayout()
        chart_layout.addWidget(QLabel('차트 타입:'))
        self.chart_combo = QComboBox()
        self.chart_combo.addItems(['수익률 비교', '승률 비교', '샤프 비율 비교', '종합 성과'])
        self.chart_combo.currentIndexChanged.connect(self.plot_chart)
        chart_layout.addWidget(self.chart_combo)
        chart_layout.addStretch()
        layout.addLayout(chart_layout)
        
        # Matplotlib 캔버스
        self.figure = Figure(figsize=(10, 6))
        self.canvas = FigureCanvas(self.figure)
        layout.addWidget(self.canvas)
        
        # 닫기 버튼
        close_btn = QPushButton('닫기')
        close_btn.clicked.connect(self.close)
        layout.addWidget(close_btn)
    
    def plot_chart(self):
        """차트 그리기"""
        if not MATPLOTLIB_AVAILABLE:
            return
        
        self.figure.clear()
        ax = self.figure.add_subplot(111)
        
        chart_type = self.chart_combo.currentText()
        
        if not self.results:
            ax.text(0.5, 0.5, '표시할 데이터가 없습니다.', 
                   ha='center', va='center', transform=ax.transAxes)
            self.canvas.draw()
            return
        
        # 상위 10개만 표시
        sorted_results = sorted(
            self.results,
            key=lambda x: x.get('metrics', {}).get('total_return', 0),
            reverse=True
        )[:10]
        
        if chart_type == '수익률 비교':
            self.plot_return_comparison(ax, sorted_results)
        elif chart_type == '승률 비교':
            self.plot_winrate_comparison(ax, sorted_results)
        elif chart_type == '샤프 비율 비교':
            self.plot_sharpe_comparison(ax, sorted_results)
        else:  # 종합 성과
            self.plot_comprehensive(ax, sorted_results)
        
        self.figure.tight_layout()
        self.canvas.draw()
    
    def plot_return_comparison(self, ax, results):
        """수익률 비교 차트"""
        labels = [f"#{i+1}" for i in range(len(results))]
        values = [r.get('metrics', {}).get('total_return', 0) for r in results]
        
        colors = ['green' if v > 0 else 'red' for v in values]
        ax.barh(labels, values, color=colors)
        ax.set_xlabel('수익률 (%)')
        ax.set_title('상위 10개 결과 - 수익률 비교')
        ax.axvline(x=0, color='black', linestyle='--', linewidth=0.5)
        ax.grid(axis='x', alpha=0.3)
    
    def plot_winrate_comparison(self, ax, results):
        """승률 비교 차트"""
        labels = [f"#{i+1}" for i in range(len(results))]
        values = [r.get('metrics', {}).get('win_rate', 0) for r in results]
        
        ax.bar(labels, values, color='blue', alpha=0.7)
        ax.set_ylabel('승률 (%)')
        ax.set_title('상위 10개 결과 - 승률 비교')
        ax.set_ylim(0, 100)
        ax.grid(axis='y', alpha=0.3)
    
    def plot_sharpe_comparison(self, ax, results):
        """샤프 비율 비교 차트"""
        labels = [f"#{i+1}" for i in range(len(results))]
        values = [r.get('metrics', {}).get('sharpe_ratio', 0) for r in results]
        
        colors = ['green' if v > 1 else 'orange' if v > 0 else 'red' for v in values]
        ax.bar(labels, values, color=colors, alpha=0.7)
        ax.set_ylabel('샤프 비율')
        ax.set_title('상위 10개 결과 - 샤프 비율 비교')
        ax.axhline(y=1, color='red', linestyle='--', linewidth=1, label='기준선 (1.0)')
        ax.legend()
        ax.grid(axis='y', alpha=0.3)
    
    def plot_comprehensive(self, ax, results):
        """종합 성과 차트"""
        x = np.arange(len(results))
        width = 0.25
        
        returns = [r.get('metrics', {}).get('total_return', 0) for r in results]
        winrates = [r.get('metrics', {}).get('win_rate', 0) for r in results]
        sharpes = [r.get('metrics', {}).get('sharpe_ratio', 0) * 10 for r in results]  # 스케일 조정
        
        ax.bar(x - width, returns, width, label='수익률 (%)', color='green', alpha=0.7)
        ax.bar(x, winrates, width, label='승률 (%)', color='blue', alpha=0.7)
        ax.bar(x + width, sharpes, width, label='샤프 비율 (×10)', color='orange', alpha=0.7)
        
        ax.set_xlabel('결과 순위')
        ax.set_ylabel('값')
        ax.set_title('상위 10개 결과 - 종합 성과 비교')
        ax.set_xticks(x)
        ax.set_xticklabels([f"#{i+1}" for i in range(len(results))])
        ax.legend()
        ax.grid(axis='y', alpha=0.3)

