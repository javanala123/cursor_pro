#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
테스트 기록 관리 다이얼로그
"""

from PyQt5.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel, 
                             QPushButton, QTableWidget, QTableWidgetItem,
                             QHeaderView, QMessageBox, QLineEdit, QTextEdit,
                             QGroupBox, QDialogButtonBox, QAbstractItemView)
from PyQt5.QtCore import Qt, pyqtSignal
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))
from data.record_manager import RecordManager, TestRecord
from datetime import datetime


class RecordManagerDialog(QDialog):
    """테스트 기록 관리 다이얼로그"""
    
    record_selected = pyqtSignal(TestRecord)  # 기록 선택 시그널
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.record_manager = RecordManager()
        self.selected_record = None
        self.init_ui()
        self.load_records()
    
    def init_ui(self):
        """UI 초기화"""
        self.setWindowTitle('테스트 기록 관리')
        self.setMinimumSize(900, 600)
        
        layout = QVBoxLayout(self)
        
        # 검색 영역
        search_group = QGroupBox('검색')
        search_layout = QHBoxLayout()
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText('이름, 심볼, 메모로 검색...')
        self.search_input.textChanged.connect(self.on_search_changed)
        search_btn = QPushButton('검색')
        search_btn.clicked.connect(self.on_search)
        search_layout.addWidget(QLabel('검색:'))
        search_layout.addWidget(self.search_input)
        search_layout.addWidget(search_btn)
        search_group.setLayout(search_layout)
        layout.addWidget(search_group)
        
        # 기록 목록 테이블
        self.records_table = QTableWidget()
        self.records_table.setColumnCount(7)
        self.records_table.setHorizontalHeaderLabels([
            '날짜/시간', '이름', '환경', '심볼', '시간프레임', '최고 수익률', '메모'
        ])
        self.records_table.horizontalHeader().setStretchLastSection(True)
        self.records_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.records_table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.records_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.records_table.doubleClicked.connect(self.on_record_double_clicked)
        layout.addWidget(self.records_table)
        
        # 버튼 영역
        btn_layout = QHBoxLayout()
        
        self.view_btn = QPushButton('상세 보기')
        self.view_btn.clicked.connect(self.on_view_record)
        self.view_btn.setEnabled(False)
        
        self.load_btn = QPushButton('불러오기')
        self.load_btn.clicked.connect(self.on_load_record)
        self.load_btn.setEnabled(False)
        
        self.delete_btn = QPushButton('삭제')
        self.delete_btn.clicked.connect(self.on_delete_record)
        self.delete_btn.setEnabled(False)
        
        self.refresh_btn = QPushButton('새로고침')
        self.refresh_btn.clicked.connect(self.load_records)
        
        btn_layout.addWidget(self.view_btn)
        btn_layout.addWidget(self.load_btn)
        btn_layout.addWidget(self.delete_btn)
        btn_layout.addStretch()
        btn_layout.addWidget(self.refresh_btn)
        
        layout.addLayout(btn_layout)
        
        # 선택 변경 시그널
        self.records_table.selectionModel().selectionChanged.connect(self.on_selection_changed)
        
        # 닫기 버튼
        button_box = QDialogButtonBox(QDialogButtonBox.Close)
        button_box.rejected.connect(self.reject)
        layout.addWidget(button_box)
    
    def load_records(self):
        """기록 목록 로드"""
        records = self.record_manager.list_records(limit=100)
        self.update_table(records)
    
    def update_table(self, records: list):
        """테이블 업데이트"""
        self.records_table.setRowCount(len(records))
        
        for row, record in enumerate(records):
            # 날짜/시간
            try:
                dt = datetime.fromisoformat(record.timestamp)
                date_str = dt.strftime('%Y-%m-%d %H:%M')
            except:
                date_str = record.timestamp
            self.records_table.setItem(row, 0, QTableWidgetItem(date_str))
            
            # 이름
            self.records_table.setItem(row, 1, QTableWidgetItem(record.name))
            
            # 환경
            self.records_table.setItem(row, 2, QTableWidgetItem(record.environment))
            
            # 심볼
            self.records_table.setItem(row, 3, QTableWidgetItem(record.symbol))
            
            # 시간프레임
            tf_str = ', '.join(record.timeframes)
            self.records_table.setItem(row, 4, QTableWidgetItem(tf_str))
            
            # 최고 수익률
            if record.best_result:
                metrics = record.best_result.get('metrics', {})
                return_val = metrics.get('total_return', 0)
                return_str = f"{return_val:.2f}%"
            else:
                return_str = "N/A"
            self.records_table.setItem(row, 5, QTableWidgetItem(return_str))
            
            # 메모
            notes = record.notes[:50] if record.notes else ''
            self.records_table.setItem(row, 6, QTableWidgetItem(notes))
        
        self.records_table.resizeColumnsToContents()
    
    def on_search(self):
        """검색 실행"""
        keyword = self.search_input.text().strip()
        if not keyword:
            self.load_records()
            return
        
        records = self.record_manager.search_records(keyword)
        self.update_table(records)
    
    def on_search_changed(self):
        """검색어 변경 시 호출"""
        # 실시간 검색은 부하가 클 수 있으므로 여기서는 처리하지 않음
        pass
    
    def on_selection_changed(self):
        """선택 변경 시 호출"""
        has_selection = len(self.records_table.selectedItems()) > 0
        self.view_btn.setEnabled(has_selection)
        self.load_btn.setEnabled(has_selection)
        self.delete_btn.setEnabled(has_selection)
    
    def get_selected_record(self) -> TestRecord:
        """선택된 기록 가져오기"""
        selected_rows = self.records_table.selectionModel().selectedRows()
        if not selected_rows:
            return None
        
        row = selected_rows[0].row()
        # 테이블에서 ID를 직접 저장하지 않으므로, 이름과 타임스탬프로 찾기
        name_item = self.records_table.item(row, 1)
        date_item = self.records_table.item(row, 0)
        
        if not name_item or not date_item:
            return None
        
        # 이름과 날짜로 기록 찾기
        records = self.record_manager.list_records(limit=1000)
        for record in records:
            try:
                dt = datetime.fromisoformat(record.timestamp)
                record_date = dt.strftime('%Y-%m-%d %H:%M')
            except:
                record_date = record.timestamp
            
            if record.name == name_item.text() and record_date == date_item.text():
                return record
        
        return None
    
    def on_view_record(self):
        """기록 상세 보기"""
        record = self.get_selected_record()
        if not record:
            return
        
        dialog = RecordDetailDialog(record, self)
        dialog.exec_()
    
    def on_load_record(self):
        """기록 불러오기"""
        record = self.get_selected_record()
        if not record:
            return
        
        reply = QMessageBox.question(
            self,
            '확인',
            f'"{record.name}" 기록을 불러오시겠습니까?\n\n'
            '현재 코드와 설정이 덮어씌워집니다.',
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            self.record_selected.emit(record)
            self.accept()
    
    def on_delete_record(self):
        """기록 삭제"""
        record = self.get_selected_record()
        if not record:
            return
        
        reply = QMessageBox.question(
            self,
            '확인',
            f'"{record.name}" 기록을 삭제하시겠습니까?',
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            if self.record_manager.delete_record(record.id):
                QMessageBox.information(self, '완료', '기록이 삭제되었습니다.')
                self.load_records()
            else:
                QMessageBox.warning(self, '오류', '기록 삭제에 실패했습니다.')
    
    def on_record_double_clicked(self, index):
        """기록 더블클릭 시 상세 보기"""
        self.on_view_record()


class RecordDetailDialog(QDialog):
    """기록 상세 정보 다이얼로그"""
    
    def __init__(self, record: TestRecord, parent=None):
        super().__init__(parent)
        self.record = record
        self.init_ui()
    
    def init_ui(self):
        """UI 초기화"""
        self.setWindowTitle(f'기록 상세: {self.record.name}')
        self.setMinimumSize(700, 600)
        
        layout = QVBoxLayout(self)
        
        # 기본 정보
        info_group = QGroupBox('기본 정보')
        info_layout = QVBoxLayout()
        
        info_layout.addWidget(QLabel(f'이름: {self.record.name}'))
        info_layout.addWidget(QLabel(f'환경: {self.record.environment}'))
        info_layout.addWidget(QLabel(f'심볼: {self.record.symbol}'))
        info_layout.addWidget(QLabel(f'시간프레임: {", ".join(self.record.timeframes)}'))
        
        try:
            dt = datetime.fromisoformat(self.record.timestamp)
            date_str = dt.strftime('%Y-%m-%d %H:%M:%S')
        except:
            date_str = self.record.timestamp
        info_layout.addWidget(QLabel(f'날짜/시간: {date_str}'))
        
        info_group.setLayout(info_layout)
        layout.addWidget(info_group)
        
        # 최고 결과
        if self.record.best_result:
            best_group = QGroupBox('최고 결과')
            best_layout = QVBoxLayout()
            
            metrics = self.record.best_result.get('metrics', {})
            best_layout.addWidget(QLabel(f'수익률: {metrics.get("total_return", 0):.2f}%'))
            best_layout.addWidget(QLabel(f'승률: {metrics.get("win_rate", 0):.2f}%'))
            best_layout.addWidget(QLabel(f'샤프 비율: {metrics.get("sharpe_ratio", 0):.2f}'))
            best_layout.addWidget(QLabel(f'거래 수: {metrics.get("total_trades", 0)}'))
            
            best_group.setLayout(best_layout)
            layout.addWidget(best_group)
        
        # 코드
        code_group = QGroupBox('전략 코드')
        code_layout = QVBoxLayout()
        code_text = QTextEdit()
        code_text.setPlainText(self.record.code)
        code_text.setReadOnly(True)
        code_text.setFontFamily('Consolas')
        code_layout.addWidget(code_text)
        code_group.setLayout(code_layout)
        layout.addWidget(code_group)
        
        # 메모
        if self.record.notes:
            notes_group = QGroupBox('메모')
            notes_layout = QVBoxLayout()
            notes_text = QTextEdit()
            notes_text.setPlainText(self.record.notes)
            notes_text.setReadOnly(True)
            notes_layout.addWidget(notes_text)
            notes_group.setLayout(notes_layout)
            layout.addWidget(notes_group)
        
        # 닫기 버튼
        button_box = QDialogButtonBox(QDialogButtonBox.Close)
        button_box.rejected.connect(self.reject)
        layout.addWidget(button_box)


class RecordSaveDialog(QDialog):
    """기록 저장 다이얼로그"""
    
    def __init__(self, code, environment, symbol, timeframes, parameters, results, parent=None):
        super().__init__(parent)
        self.code = code
        self.environment = environment
        self.symbol = symbol
        self.timeframes = timeframes
        self.parameters = parameters
        self.results = results
        self.record = None
        self.init_ui()
    
    def init_ui(self):
        """UI 초기화"""
        self.setWindowTitle('테스트 기록 저장')
        self.setMinimumSize(500, 300)
        
        layout = QVBoxLayout(self)
        
        # 이름 입력
        name_layout = QHBoxLayout()
        name_layout.addWidget(QLabel('기록 이름:'))
        self.name_input = QLineEdit()
        # 기본 이름 생성
        from datetime import datetime
        default_name = f"{self.symbol}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.name_input.setText(default_name)
        name_layout.addWidget(self.name_input)
        layout.addLayout(name_layout)
        
        # 메모 입력
        notes_layout = QVBoxLayout()
        notes_layout.addWidget(QLabel('메모:'))
        self.notes_input = QTextEdit()
        self.notes_input.setMaximumHeight(100)
        notes_layout.addWidget(self.notes_input)
        layout.addLayout(notes_layout)
        
        # 정보 표시
        info_label = QLabel(
            f'환경: {self.environment}\n'
            f'심볼: {self.symbol}\n'
            f'시간프레임: {", ".join(self.timeframes)}\n'
            f'결과 수: {len(self.results)}개'
        )
        layout.addWidget(info_label)
        
        # 버튼
        button_box = QDialogButtonBox(QDialogButtonBox.Save | QDialogButtonBox.Cancel)
        button_box.accepted.connect(self.on_save)
        button_box.rejected.connect(self.reject)
        layout.addWidget(button_box)
    
    def on_save(self):
        """저장 버튼 클릭"""
        name = self.name_input.text().strip()
        if not name:
            QMessageBox.warning(self, '경고', '기록 이름을 입력해주세요.')
            return
        
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).parent.parent))
        from data.record_manager import RecordManager
        manager = RecordManager()
        
        self.record = manager.create_record(
            name=name,
            environment=self.environment,
            symbol=self.symbol,
            timeframes=self.timeframes,
            code=self.code,
            parameters=self.parameters,
            results=self.results,
            notes=self.notes_input.toPlainText()
        )
        
        self.accept()
    
    def get_record(self):
        """생성된 기록 반환"""
        return self.record
