#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
메인 윈도우 - 백테스트 GUI 프로그램의 메인 인터페이스
"""

import sys
from PyQt5.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
                             QSplitter, QStatusBar, QMessageBox, QDialog)
from PyQt5.QtCore import Qt, pyqtSignal, QThread
from PyQt5.QtGui import QIcon

from gui.code_editor import CodeEditor
from gui.settings_panel import SettingsPanel
from gui.results_view import ResultsView


class BacktestThread(QThread):
    """백테스트 실행을 위한 별도 스레드"""
    progress_updated = pyqtSignal(int, str)  # 진행률, 현재 상태
    result_ready = pyqtSignal(object)  # 결과 데이터 (BacktestResult 객체)
    finished = pyqtSignal()
    
    def __init__(self, engine, symbol, timeframes, param_ranges):
        super().__init__()
        self.engine = engine
        self.symbol = symbol
        self.timeframes = timeframes
        self.param_ranges = param_ranges
        self.is_running = True
    
    def run(self):
        """백테스트 실행"""
        try:
            # 파라미터 조합 생성 (제한된 수로)
            import itertools
            max_combinations = 100  # 성능을 위해 제한
            
            # 조합 생성
            param_names = list(self.param_ranges.keys())
            param_values = []
            for param_name in param_names:
                range_info = self.param_ranges[param_name]
                min_val = range_info['min']
                max_val = range_info['max']
                step = range_info['step']
                values = []
                current = min_val
                while current <= max_val and len(values) < 10:  # 각 파라미터당 최대 10개
                    values.append(current)
                    current += step
                param_values.append(values)
            
            combinations = list(itertools.product(*param_values))[:max_combinations]
            total = len(combinations) * len(self.timeframes)
            current = 0
            
            for timeframe in self.timeframes:
                if not self.is_running:
                    break
                
                for params in combinations:
                    if not self.is_running:
                        break
                    
                    param_dict = dict(zip(param_names, params))
                    
                    try:
                        result = self.engine.run_backtest(
                            self.symbol,
                            timeframe,
                            param_dict
                        )
                        
                        self.result_ready.emit(result)
                        current += 1
                        
                        self.progress_updated.emit(
                            int((current / total) * 100) if total > 0 else 0,
                            f"{self.symbol} {timeframe}: {current}/{total}"
                        )
                    except Exception as e:
                        print(f"백테스트 오류: {e}")
                        continue
            
            self.finished.emit()
        except Exception as e:
            self.progress_updated.emit(0, f"오류: {str(e)}")
            self.finished.emit()
    
    def stop(self):
        """백테스트 중지"""
        self.is_running = False


class MainWindow(QMainWindow):
    """메인 윈도우 클래스"""
    
    def __init__(self):
        super().__init__()
        self.backtest_thread = None
        self.init_ui()
    
    def init_ui(self):
        """UI 초기화"""
        self.setWindowTitle('백테스트 프로그램 - 전략 파라미터 최적화')
        self.setGeometry(100, 100, 1400, 900)
        
        # 중앙 위젯
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # 메인 레이아웃
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(10, 10, 10, 10)
        main_layout.setSpacing(10)
        
        # 상단 분할기 (코드 에디터 + 설정 패널)
        top_splitter = QSplitter(Qt.Horizontal)
        
        # 코드 에디터
        self.code_editor = CodeEditor()
        top_splitter.addWidget(self.code_editor)
        
        # 설정 패널
        self.settings_panel = SettingsPanel()
        top_splitter.addWidget(self.settings_panel)
        
        # 분할기 비율 설정 (코드 에디터 60%, 설정 패널 40%)
        top_splitter.setSizes([600, 400])
        top_splitter.setStretchFactor(0, 1)
        top_splitter.setStretchFactor(1, 0)
        
        # 하단 분할기 (결과 뷰)
        bottom_splitter = QSplitter(Qt.Vertical)
        
        # 결과 뷰
        self.results_view = ResultsView()
        bottom_splitter.addWidget(self.results_view)
        
        # 메인 분할기 (상단 + 하단)
        main_splitter = QSplitter(Qt.Vertical)
        main_splitter.addWidget(top_splitter)
        main_splitter.addWidget(bottom_splitter)
        main_splitter.setSizes([500, 400])
        main_splitter.setStretchFactor(0, 1)
        main_splitter.setStretchFactor(1, 0)
        
        main_layout.addWidget(main_splitter)
        
        # 상태바
        self.statusBar = QStatusBar()
        self.setStatusBar(self.statusBar)
        self.statusBar.showMessage('준비됨')
        
        # 시그널 연결
        self.settings_panel.start_backtest.connect(self.start_backtest)
        self.settings_panel.stop_backtest.connect(self.stop_backtest)
        self.settings_panel.extract_parameters.connect(self.extract_parameters)
        self.settings_panel.reset_all.connect(self.reset_all_settings)
        self.code_editor.code_changed.connect(self.on_code_changed)
        
        # 환경 변경 시 코드 에디터 언어 변경
        self.settings_panel.env_group.buttonClicked.connect(self.on_environment_changed)
        
        # 메뉴바
        self.create_menu_bar()
    
    def create_menu_bar(self):
        """메뉴바 생성"""
        menubar = self.menuBar()
        
        # 파일 메뉴
        file_menu = menubar.addMenu('파일')
        
        open_action = file_menu.addAction('코드 열기')
        open_action.setShortcut('Ctrl+O')
        open_action.triggered.connect(self.open_code_file)
        
        save_action = file_menu.addAction('코드 저장')
        save_action.setShortcut('Ctrl+S')
        save_action.triggered.connect(self.save_code_file)
        
        file_menu.addSeparator()
        
        # 기록 관리
        records_action = file_menu.addAction('테스트 기록 관리')
        records_action.setShortcut('Ctrl+R')
        records_action.triggered.connect(self.show_record_manager)
        
        file_menu.addSeparator()
        
        exit_action = file_menu.addAction('종료')
        exit_action.setShortcut('Ctrl+Q')
        exit_action.triggered.connect(self.close)
        
        # 도움말 메뉴
        help_menu = menubar.addMenu('도움말')
        
        about_action = help_menu.addAction('정보')
        about_action.triggered.connect(self.show_about)
    
    def open_code_file(self):
        """코드 파일 열기"""
        from PyQt5.QtWidgets import QFileDialog
        filename, _ = QFileDialog.getOpenFileName(
            self,
            '코드 파일 열기',
            '',
            'Pine Script (*.pine);;MT5 (*.mq5);;모든 파일 (*.*)'
        )
        if filename:
            try:
                with open(filename, 'r', encoding='utf-8') as f:
                    code = f.read()
                self.code_editor.setPlainText(code)
                self.statusBar.showMessage(f'파일 로드: {filename}')
            except Exception as e:
                QMessageBox.critical(self, '오류', f'파일을 열 수 없습니다:\n{str(e)}')
    
    def save_code_file(self):
        """코드 파일 저장"""
        from PyQt5.QtWidgets import QFileDialog
        filename, _ = QFileDialog.getSaveFileName(
            self,
            '코드 파일 저장',
            '',
            'Pine Script (*.pine);;MT5 (*.mq5);;모든 파일 (*.*)'
        )
        if filename:
            try:
                with open(filename, 'w', encoding='utf-8') as f:
                    f.write(self.code_editor.toPlainText())
                self.statusBar.showMessage(f'파일 저장: {filename}')
            except Exception as e:
                QMessageBox.critical(self, '오류', f'파일을 저장할 수 없습니다:\n{str(e)}')
    
    def show_about(self):
        """정보 다이얼로그 표시"""
        QMessageBox.about(
            self,
            '백테스트 프로그램 정보',
            '백테스트 프로그램 v1.0\n\n'
            '전략 코드를 입력하고 파라미터를 최적화하여\n'
            '최적의 거래 전략을 찾는 도구입니다.\n\n'
            '지원 환경: TradingView, MT5'
        )
    
    def on_code_changed(self):
        """코드 변경 시 호출"""
        # 코드 검증은 code_editor에서 자동으로 수행
        pass
    
    def on_environment_changed(self):
        """환경 변경 시 호출"""
        environment = self.settings_panel.get_environment()
        language = 'pine' if environment == 'TradingView' else 'mt5'
        self.code_editor.set_language(language)
    
    def extract_parameters(self):
        """코드에서 파라미터 추출"""
        code = self.code_editor.toPlainText()
        if not code.strip():
            QMessageBox.warning(self, '경고', '코드를 입력해주세요.')
            return
        
        # 코드 에러 확인
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).parent.parent))
        from gui.code_validator import CodeValidator
        environment = self.settings_panel.get_environment()
        language = 'pine' if environment == 'TradingView' else 'mt5'
        validator = CodeValidator(language)
        errors = validator.validate(code)
        
        error_errors = [e for e in errors if e.severity == 'error']
        if error_errors:
            error_msg = '\n'.join([f"라인 {e.line}: {e.message}" for e in error_errors[:5]])
            reply = QMessageBox.question(
                self,
                '코드 에러 발견',
                f'코드에 에러가 있습니다:\n\n{error_msg}\n\n그래도 파라미터를 추출하시겠습니까?',
                QMessageBox.Yes | QMessageBox.No,
                QMessageBox.No
            )
            if reply == QMessageBox.No:
                return
        
        try:
            # 환경에 따라 파서 선택
            if environment == 'TradingView':
                from parsers.pine_parser import PineScriptParser
                parser = PineScriptParser()
                parameters = parser.parse(code)
            else:  # MT5
                from parsers.mt5_parser import MT5CodeParser
                parser = MT5CodeParser()
                parameters = parser.parse(code)
            
            # 파라미터 범위 설정 패널에 전달
            if parameters:
                self.settings_panel.set_parameters(parameters)
                self.statusBar.showMessage(f'{len(parameters)}개의 파라미터를 추출했습니다.')
            else:
                QMessageBox.warning(
                    self,
                    '파라미터 없음',
                    '코드에서 파라미터를 찾을 수 없습니다.\n\n'
                    'Pine Script: input.int() 또는 input.float() 구문이 필요합니다.\n'
                    'MT5: input int 또는 input double 구문이 필요합니다.'
                )
            
        except Exception as e:
            import traceback
            QMessageBox.critical(self, '오류', f'파라미터 추출 실패:\n{str(e)}\n\n{traceback.format_exc()}')
    
    def start_backtest(self):
        """백테스트 시작"""
        # 설정 확인
        code = self.code_editor.toPlainText()
        if not code.strip():
            QMessageBox.warning(self, '경고', '코드를 입력해주세요.')
            return
        
        environment = self.settings_panel.get_environment()
        symbol = self.settings_panel.get_symbol()
        timeframes = self.settings_panel.get_timeframes()
        param_ranges = self.settings_panel.get_parameter_ranges()
        
        if not symbol:
            QMessageBox.warning(self, '경고', '심볼을 선택해주세요.')
            return
        
        if not timeframes:
            QMessageBox.warning(self, '경고', '시간프레임을 선택해주세요.')
            return
        
        if not param_ranges:
            QMessageBox.warning(
                self, 
                '경고', 
                '파라미터 범위를 설정해주세요.\n\n'
                '"자동 추출" 버튼을 눌러 코드에서 파라미터를 추출하거나,\n'
                '파라미터 테이블에서 직접 값을 입력해주세요.'
            )
            return
        
        try:
            # 백테스트 엔진 선택
            if environment == 'TradingView':
                from backtest_engine.tradingview_engine import TradingViewEngine
                engine = TradingViewEngine(code)
            else:  # MT5
                from backtest_engine.mt5_engine import MT5Engine
                engine = MT5Engine(code)
            
            # 결과 뷰 초기화
            self.results_view.clear_results()
            
            # 백테스트 스레드 시작
            self.backtest_thread = BacktestThread(engine, symbol, timeframes, param_ranges)
            self.backtest_thread.progress_updated.connect(self.results_view.update_progress)
            self.backtest_thread.result_ready.connect(self.on_result_ready)
            self.backtest_thread.finished.connect(self.on_backtest_finished)
            self.backtest_thread.start()
            
            # UI 업데이트
            self.settings_panel.set_backtest_running(True)
            self.statusBar.showMessage('백테스트 실행 중...')
            
        except Exception as e:
            QMessageBox.critical(self, '오류', f'백테스트 시작 실패:\n{str(e)}')
    
    def stop_backtest(self):
        """백테스트 중지"""
        if self.backtest_thread and self.backtest_thread.isRunning():
            self.backtest_thread.stop()
            self.backtest_thread.wait()
            self.settings_panel.set_backtest_running(False)
            self.statusBar.showMessage('백테스트 중지됨')
    
    def on_result_ready(self, result):
        """결과 준비 완료 처리"""
        # BacktestResult를 딕셔너리로 변환
        if hasattr(result, 'symbol'):
            result_dict = {
                'symbol': result.symbol,
                'timeframe': result.timeframe,
                'parameters': result.parameters,
                'metrics': result.metrics
            }
        else:
            result_dict = result
        
        self.results_view.add_result(result_dict)
    
    def on_backtest_finished(self):
        """백테스트 완료 처리"""
        self.settings_panel.set_backtest_running(False)
        self.statusBar.showMessage('백테스트 완료')
        
        # 기록 저장 여부 확인
        reply = QMessageBox.question(
            self,
            '백테스트 완료',
            '백테스트가 완료되었습니다.\n\n결과를 기록으로 저장하시겠습니까?',
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.Yes
        )
        
        if reply == QMessageBox.Yes:
            self.save_test_record()
    
    def reset_all_settings(self):
        """모든 설정 초기화 (코드 에디터 포함)"""
        self.code_editor.clear()
        self.results_view.clear_results()
    
    def show_record_manager(self):
        """기록 관리 다이얼로그 표시"""
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).parent.parent))
        from gui.record_manager_dialog import RecordManagerDialog
        dialog = RecordManagerDialog(self)
        dialog.record_selected.connect(self.load_test_record)
        dialog.exec_()
    
    def save_test_record(self):
        """테스트 기록 저장"""
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).parent.parent))
        from gui.record_manager_dialog import RecordSaveDialog
        from data.record_manager import RecordManager
        
        # 현재 결과 가져오기
        results = self.results_view.get_all_results()
        if not results:
            QMessageBox.warning(self, '경고', '저장할 결과가 없습니다.')
            return
        
        code = self.code_editor.toPlainText()
        environment = self.settings_panel.get_environment()
        symbol = self.settings_panel.get_symbol()
        timeframes = self.settings_panel.get_timeframes()
        param_ranges = self.settings_panel.get_parameter_ranges()
        
        dialog = RecordSaveDialog(
            code=code,
            environment=environment,
            symbol=symbol,
            timeframes=timeframes,
            parameters=param_ranges,
            results=results,
            parent=self
        )
        
        if dialog.exec_() == QDialog.Accepted:
            record = dialog.get_record()
            if record:
                manager = RecordManager()
                manager.save_record(record)
                QMessageBox.information(self, '완료', f'기록이 저장되었습니다: {record.name}')
    
    def load_test_record(self, record):
        """테스트 기록 불러오기"""
        # 코드 로드
        self.code_editor.setPlainText(record.code)
        
        # 환경 설정
        if record.environment == 'TradingView':
            self.settings_panel.tv_radio.setChecked(True)
        else:
            self.settings_panel.mt5_radio.setChecked(True)
        
        # 심볼 설정 (카테고리 찾기)
        category_map = {
            'futures': '선물',
            'crypto': '암호화폐',
            'forex': '외환'
        }
        # 심볼로 카테고리 찾기 (간단한 방법)
        for cat_key, cat_name in category_map.items():
            symbols = self.settings_panel.symbols_data.get(cat_key, [])
            for sym_info in symbols:
                if isinstance(sym_info, dict) and sym_info.get('symbol') == record.symbol:
                    self.settings_panel.category_combo.setCurrentText(cat_name)
                    self.settings_panel.on_category_changed()
                    # 심볼 선택
                    for i in range(self.settings_panel.symbol_combo.count()):
                        if self.settings_panel.symbol_combo.itemData(i) == record.symbol:
                            self.settings_panel.symbol_combo.setCurrentIndex(i)
                            break
                    break
        
        # 시간프레임 설정
        for tf, checkbox in self.settings_panel.timeframes.items():
            checkbox.setChecked(tf in record.timeframes)
        
        # 파라미터 설정
        self.settings_panel.set_parameters(record.parameters)
        
        # 결과 로드
        self.results_view.clear_results()
        for result in record.results:
            self.results_view.add_result(result)
        
        QMessageBox.information(self, '완료', f'기록을 불러왔습니다: {record.name}')
    
    def closeEvent(self, event):
        """윈도우 닫기 이벤트"""
        if self.backtest_thread and self.backtest_thread.isRunning():
            reply = QMessageBox.question(
                self,
                '확인',
                '백테스트가 실행 중입니다. 종료하시겠습니까?',
                QMessageBox.Yes | QMessageBox.No,
                QMessageBox.No
            )
            
            if reply == QMessageBox.Yes:
                self.stop_backtest()
                event.accept()
            else:
                event.ignore()
        else:
            event.accept()

