#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
설정 패널 - 환경, 심볼, 시간프레임, 파라미터 설정
"""

from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                             QRadioButton, QButtonGroup, QComboBox, 
                             QCheckBox, QPushButton, QGroupBox, QTableWidget,
                             QTableWidgetItem, QHeaderView, QDoubleSpinBox,
                             QSpinBox, QMessageBox)
from PyQt5.QtCore import pyqtSignal, Qt
import yaml
from pathlib import Path


class SettingsPanel(QWidget):
    """설정 패널 위젯"""
    
    start_backtest = pyqtSignal()
    stop_backtest = pyqtSignal()
    extract_parameters = pyqtSignal()
    reset_all = pyqtSignal()  # 리셋 시그널
    
    def __init__(self):
        super().__init__()
        self.parameters = {}
        # symbols_data를 먼저 초기화해야 on_category_changed()에서 사용 가능
        self.load_symbols()
        self.init_ui()
    
    def init_ui(self):
        """UI 초기화"""
        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        
        # 제목
        title = QLabel('백테스트 설정')
        title.setStyleSheet('font-weight: bold; font-size: 12pt; padding: 5px;')
        layout.addWidget(title)
        
        # 환경 선택
        env_group = QGroupBox('테스트 환경')
        env_layout = QVBoxLayout()
        self.env_group = QButtonGroup()
        
        self.tv_radio = QRadioButton('TradingView')
        self.tv_radio.setChecked(True)
        self.mt5_radio = QRadioButton('MT5')
        
        self.env_group.addButton(self.tv_radio, 0)
        self.env_group.addButton(self.mt5_radio, 1)
        
        env_layout.addWidget(self.tv_radio)
        env_layout.addWidget(self.mt5_radio)
        env_group.setLayout(env_layout)
        layout.addWidget(env_group)
        
        # 심볼 선택 (카테고리별)
        symbol_group = QGroupBox('심볼 선택')
        symbol_layout = QVBoxLayout()
        
        # 카테고리 선택
        category_label = QLabel('카테고리:')
        symbol_layout.addWidget(category_label)
        self.category_combo = QComboBox()
        self.category_combo.addItems(['선물', '암호화폐', '외환'])
        self.category_combo.currentIndexChanged.connect(self.on_category_changed)
        symbol_layout.addWidget(self.category_combo)
        
        # 심볼 선택
        symbol_label = QLabel('심볼:')
        symbol_layout.addWidget(symbol_label)
        self.symbol_combo = QComboBox()
        self.symbol_combo.setEditable(False)
        symbol_layout.addWidget(self.symbol_combo)
        symbol_group.setLayout(symbol_layout)
        layout.addWidget(symbol_group)
        
        # 초기 카테고리 로드
        self.on_category_changed()
        
        # 시간프레임 선택
        tf_group = QGroupBox('시간프레임 선택')
        tf_layout = QVBoxLayout()
        
        self.timeframes = {}
        tf_list = ['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1']
        for tf in tf_list:
            checkbox = QCheckBox(tf)
            if tf in ['M15', 'H1', 'H4']:  # 기본 선택
                checkbox.setChecked(True)
            self.timeframes[tf] = checkbox
            tf_layout.addWidget(checkbox)
        
        tf_group.setLayout(tf_layout)
        layout.addWidget(tf_group)
        
        # 파라미터 범위 설정
        param_group = QGroupBox('파라미터 범위')
        param_layout = QVBoxLayout()
        
        # 버튼
        btn_layout = QHBoxLayout()
        self.extract_btn = QPushButton('자동 추출')
        self.extract_btn.clicked.connect(self.extract_parameters.emit)
        self.manual_btn = QPushButton('수동 설정')
        self.manual_btn.clicked.connect(self.show_manual_dialog)
        btn_layout.addWidget(self.extract_btn)
        btn_layout.addWidget(self.manual_btn)
        param_layout.addLayout(btn_layout)
        
        # 파라미터 테이블
        self.param_table = QTableWidget()
        self.param_table.setColumnCount(5)
        self.param_table.setHorizontalHeaderLabels(['파라미터', '최소값', '최대값', '단계', '기본값'])
        self.param_table.horizontalHeader().setStretchLastSection(True)
        self.param_table.setAlternatingRowColors(True)
        param_layout.addWidget(self.param_table)
        
        param_group.setLayout(param_layout)
        layout.addWidget(param_group)
        
        # 실행 버튼
        self.start_btn = QPushButton('백테스트 시작')
        self.start_btn.setStyleSheet('background-color: #4CAF50; color: white; font-weight: bold; padding: 10px;')
        self.start_btn.clicked.connect(self.start_backtest.emit)
        layout.addWidget(self.start_btn)
        
        self.stop_btn = QPushButton('백테스트 중지')
        self.stop_btn.setStyleSheet('background-color: #f44336; color: white; font-weight: bold; padding: 10px;')
        self.stop_btn.clicked.connect(self.stop_backtest.emit)
        self.stop_btn.setEnabled(False)
        layout.addWidget(self.stop_btn)
        
        # 리셋 버튼
        self.reset_btn = QPushButton('리셋')
        self.reset_btn.setStyleSheet('background-color: #ff9800; color: white; font-weight: bold; padding: 8px;')
        self.reset_btn.clicked.connect(self.on_reset_clicked)
        layout.addWidget(self.reset_btn)
        
        layout.addStretch()
    
    def load_symbols(self):
        """심볼 목록 로드 (카테고리별)"""
        try:
            config_path = Path(__file__).parent.parent / 'config' / 'symbols.yaml'
            if config_path.exists():
                with open(config_path, 'r', encoding='utf-8') as f:
                    self.symbols_data = yaml.safe_load(f)
            else:
                # 기본 심볼 데이터
                self.symbols_data = {
                    'futures': [
                        {'symbol': 'ES1!', 'name': 'E-mini S&P 500'},
                        {'symbol': 'NQ1!', 'name': 'E-mini NASDAQ'},
                        {'symbol': 'GC1!', 'name': 'Gold'},
                        {'symbol': 'CL1!', 'name': 'Crude Oil'}
                    ],
                    'crypto': [
                        {'symbol': 'BTCUSD', 'name': 'Bitcoin'},
                        {'symbol': 'ETHUSD', 'name': 'Ethereum'},
                        {'symbol': 'ADAUSD', 'name': 'Cardano'}
                    ],
                    'forex': [
                        {'symbol': 'EURUSD', 'name': 'Euro/US Dollar'},
                        {'symbol': 'GBPUSD', 'name': 'British Pound/US Dollar'},
                        {'symbol': 'USDJPY', 'name': 'US Dollar/Japanese Yen'}
                    ]
                }
        except Exception as e:
            print(f"심볼 로드 오류: {e}")
            self.symbols_data = {}
    
    def on_category_changed(self):
        """카테고리 변경 시 심볼 목록 업데이트"""
        self.symbol_combo.clear()
        
        # symbols_data가 아직 초기화되지 않았을 수 있음
        if not hasattr(self, 'symbols_data') or not self.symbols_data:
            return
        
        category = self.category_combo.currentText()
        category_map = {
            '선물': 'futures',
            '암호화폐': 'crypto',
            '외환': 'forex'
        }
        
        category_key = category_map.get(category, 'futures')
        symbols = self.symbols_data.get(category_key, [])
        
        if isinstance(symbols, list):
            for symbol_info in symbols:
                if isinstance(symbol_info, dict):
                    symbol = symbol_info.get('symbol', '')
                    name = symbol_info.get('name', symbol)
                    display_text = f"{name} ({symbol})"
                    self.symbol_combo.addItem(display_text, symbol)
                elif isinstance(symbol_info, str):
                    self.symbol_combo.addItem(symbol_info, symbol_info)
    
    def get_environment(self):
        """선택된 환경 반환"""
        return 'TradingView' if self.tv_radio.isChecked() else 'MT5'
    
    def get_symbol(self):
        """선택된 심볼 반환"""
        current_data = self.symbol_combo.currentData()
        if current_data:
            return current_data
        # 데이터가 없으면 텍스트에서 추출
        text = self.symbol_combo.currentText()
        if '(' in text and ')' in text:
            return text.split('(')[1].split(')')[0]
        return text
    
    def get_timeframes(self):
        """선택된 시간프레임 리스트 반환"""
        selected = []
        for tf, checkbox in self.timeframes.items():
            if checkbox.isChecked():
                selected.append(tf)
        return selected
    
    def set_parameters(self, parameters):
        """파라미터 설정"""
        if not parameters:
            QMessageBox.warning(self, '경고', '추출된 파라미터가 없습니다.\n코드에 input.int 또는 input.float 구문이 있는지 확인해주세요.')
            return
        
        self.parameters = parameters
        self.update_parameter_table()
        
        if len(parameters) > 0:
            QMessageBox.information(self, '완료', f'{len(parameters)}개의 파라미터를 추출했습니다.')
    
    def update_parameter_table(self):
        """파라미터 테이블 업데이트"""
        # 최적화 가능한 파라미터만 필터링 (int, float만)
        optimizable_params = {
            k: v for k, v in self.parameters.items() 
            if v.get('type') in ['int', 'float']
        }
        
        self.param_table.setRowCount(len(optimizable_params))
        
        for row, (param_name, param_info) in enumerate(optimizable_params.items()):
            # 파라미터 이름
            name_item = QTableWidgetItem(param_name)
            name_item.setFlags(name_item.flags() & ~Qt.ItemIsEditable)
            self.param_table.setItem(row, 0, name_item)
            
            # 최소값
            min_spin = self._create_spinbox(param_info, 'min')
            if min_spin:
                self.param_table.setCellWidget(row, 1, min_spin)
            else:
                self.param_table.setItem(row, 1, QTableWidgetItem('N/A'))
            
            # 최대값
            max_spin = self._create_spinbox(param_info, 'max')
            if max_spin:
                self.param_table.setCellWidget(row, 2, max_spin)
            else:
                self.param_table.setItem(row, 2, QTableWidgetItem('N/A'))
            
            # 단계
            step_spin = self._create_spinbox(param_info, 'step', is_step=True)
            if step_spin:
                self.param_table.setCellWidget(row, 3, step_spin)
            else:
                self.param_table.setItem(row, 3, QTableWidgetItem('N/A'))
            
            # 기본값
            default_value = param_info.get('default', '')
            if param_info.get('type') == 'bool':
                default_value = 'true' if default_value else 'false'
            default_item = QTableWidgetItem(str(default_value))
            default_item.setFlags(default_item.flags() & ~Qt.ItemIsEditable)
            self.param_table.setItem(row, 4, default_item)
        
        self.param_table.resizeColumnsToContents()
        
        # 최적화 불가능한 파라미터 정보 표시
        non_optimizable = {
            k: v for k, v in self.parameters.items() 
            if v.get('type') not in ['int', 'float']
        }
        if non_optimizable:
            info_text = f"참고: {len(non_optimizable)}개의 파라미터는 최적화 대상이 아닙니다 (string, bool, color 타입)"
            # 상태바나 메시지로 표시할 수 있음
    
    def _create_spinbox(self, param_info, key, is_step=False):
        """스핀박스 생성"""
        param_type = param_info.get('type', 'float')
        default_value = param_info.get(key, param_info.get('default', 0))
        
        if param_type == 'int':
            spin = QSpinBox()
            spin.setRange(-1000000, 1000000)
            spin.setValue(int(default_value) if default_value else 0)
        elif param_type == 'float':
            spin = QDoubleSpinBox()
            spin.setRange(-1000000.0, 1000000.0)
            spin.setDecimals(4)
            spin.setValue(float(default_value) if default_value else 0.0)
        else:
            # string, bool, color 타입은 스핀박스 대신 None 반환
            return None
        
        if is_step:
            spin.setSingleStep(0.1 if param_type == 'float' else 1)
        else:
            spin.setSingleStep(1 if param_type == 'int' else 0.1)
        
        return spin
    
    def get_parameter_ranges(self):
        """파라미터 범위 가져오기"""
        ranges = {}
        
        if self.param_table.rowCount() == 0:
            return ranges
        
        for row in range(self.param_table.rowCount()):
            name_item = self.param_table.item(row, 0)
            if not name_item:
                continue
            
            param_name = name_item.text()
            
            min_widget = self.param_table.cellWidget(row, 1)
            max_widget = self.param_table.cellWidget(row, 2)
            step_widget = self.param_table.cellWidget(row, 3)
            
            if min_widget and max_widget and step_widget:
                min_val = min_widget.value()
                max_val = max_widget.value()
                step_val = step_widget.value()
                
                if min_val < max_val and step_val > 0:
                    ranges[param_name] = {
                        'min': min_val,
                        'max': max_val,
                        'step': step_val,
                        'type': 'int' if isinstance(min_widget, QSpinBox) else 'float'
                    }
        
        return ranges
    
    def show_manual_dialog(self):
        """수동 설정 다이얼로그 표시"""
        QMessageBox.information(
            self,
            '수동 설정',
            '파라미터 테이블에서 직접 값을 수정할 수 있습니다.\n'
            '또는 "자동 추출" 버튼을 눌러 코드에서 파라미터를 추출하세요.'
        )
    
    def set_backtest_running(self, running):
        """백테스트 실행 상태 설정"""
        self.start_btn.setEnabled(not running)
        self.stop_btn.setEnabled(running)
        self.reset_btn.setEnabled(not running)
    
    def on_reset_clicked(self):
        """리셋 버튼 클릭 시 호출"""
        from PyQt5.QtWidgets import QMessageBox
        reply = QMessageBox.question(
            self,
            '확인',
            '모든 설정을 초기화하시겠습니까?',
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            # 파라미터 테이블 초기화
            self.param_table.setRowCount(0)
            self.parameters = {}
            
            # 시간프레임 초기화
            for checkbox in self.timeframes.values():
                checkbox.setChecked(False)
            # 기본 시간프레임만 선택
            for tf in ['M15', 'H1', 'H4']:
                if tf in self.timeframes:
                    self.timeframes[tf].setChecked(True)
            
            # 심볼 초기화
            self.category_combo.setCurrentIndex(0)
            self.on_category_changed()
            
            # 환경 초기화
            self.tv_radio.setChecked(True)
            
            # 시그널 발생 (메인 윈도우에서 코드 에디터도 초기화)
            self.reset_all.emit()
            
            QMessageBox.information(self, '완료', '모든 설정이 초기화되었습니다.')

