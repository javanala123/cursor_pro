#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
코드 에디터 - 전략 코드 입력 및 편집
"""

from PyQt5.QtWidgets import QPlainTextEdit, QWidget, QVBoxLayout, QLabel, QHBoxLayout
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QFont, QTextCharFormat, QColor, QSyntaxHighlighter
import re


class SyntaxHighlighter(QSyntaxHighlighter):
    """구문 강조 (Pine Script 및 MT5)"""
    
    def __init__(self, parent=None, language='pine'):
        super().__init__(parent)
        self.language = language
        self.highlighting_rules = []
        self.setup_rules()
    
    def setup_rules(self):
        """구문 강조 규칙 설정"""
        if self.language == 'pine':
            self.setup_pine_rules()
        else:  # MT5
            self.setup_mt5_rules()
    
    def setup_pine_rules(self):
        """Pine Script 구문 강조 규칙"""
        # 키워드
        keyword_format = QTextCharFormat()
        keyword_format.setForeground(QColor(86, 156, 214))
        keyword_format.setFontWeight(700)
        
        keywords = [
            'strategy', 'study', 'indicator', 'input', 'var', 'if', 'else',
            'for', 'while', 'switch', 'case', 'true', 'false', 'na', 'and', 'or',
            'not', 'ta.', 'math.', 'str.', 'array.', 'plot', 'fill', 'bgcolor'
        ]
        
        for keyword in keywords:
            pattern = r'\b' + keyword + r'\b'
            self.highlighting_rules.append((re.compile(pattern), keyword_format))
        
        # 문자열
        string_format = QTextCharFormat()
        string_format.setForeground(QColor(206, 145, 120))
        self.highlighting_rules.append((re.compile(r'"[^"]*"'), string_format))
        self.highlighting_rules.append((re.compile(r"'[^']*'"), string_format))
        
        # 숫자
        number_format = QTextCharFormat()
        number_format.setForeground(QColor(181, 206, 168))
        self.highlighting_rules.append((re.compile(r'\b\d+\.?\d*\b'), number_format))
        
        # 주석
        comment_format = QTextCharFormat()
        comment_format.setForeground(QColor(106, 153, 85))
        comment_format.setFontItalic(True)
        self.highlighting_rules.append((re.compile(r'//.*'), comment_format))
    
    def setup_mt5_rules(self):
        """MT5 구문 강조 규칙"""
        # 키워드
        keyword_format = QTextCharFormat()
        keyword_format.setForeground(QColor(86, 156, 214))
        keyword_format.setFontWeight(700)
        
        keywords = [
            'input', 'int', 'double', 'bool', 'string', 'datetime', 'color',
            'if', 'else', 'for', 'while', 'switch', 'case', 'break', 'return',
            'void', 'bool', 'int', 'double', 'string', 'class', 'struct',
            'public', 'private', 'protected', 'static', 'const', 'true', 'false'
        ]
        
        for keyword in keywords:
            pattern = r'\b' + keyword + r'\b'
            self.highlighting_rules.append((re.compile(pattern), keyword_format))
        
        # 문자열
        string_format = QTextCharFormat()
        string_format.setForeground(QColor(206, 145, 120))
        self.highlighting_rules.append((re.compile(r'"[^"]*"'), string_format))
        
        # 숫자
        number_format = QTextCharFormat()
        number_format.setForeground(QColor(181, 206, 168))
        self.highlighting_rules.append((re.compile(r'\b\d+\.?\d*\b'), number_format))
        
        # 주석
        comment_format = QTextCharFormat()
        comment_format.setForeground(QColor(106, 153, 85))
        comment_format.setFontItalic(True)
        self.highlighting_rules.append((re.compile(r'//.*'), comment_format))
        self.highlighting_rules.append((re.compile(r'/\*.*?\*/', re.DOTALL), comment_format))
    
    def highlightBlock(self, text):
        """텍스트 블록 강조"""
        for pattern, format in self.highlighting_rules:
            for match in pattern.finditer(text):
                start, end = match.span()
                self.setFormat(start, end - start, format)


class CodeEditor(QWidget):
    """코드 에디터 위젯"""
    
    code_changed = pyqtSignal()  # 코드 변경 시그널
    
    def __init__(self):
        super().__init__()
        self.current_language = 'pine'
        self.init_ui()
    
    def init_ui(self):
        """UI 초기화"""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        
        # 제목
        title = QLabel('전략 코드 입력')
        title.setStyleSheet('font-weight: bold; font-size: 12pt; padding: 5px;')
        layout.addWidget(title)
        
        # 에러 표시 레이블
        error_layout = QHBoxLayout()
        self.error_label = QLabel('')
        self.error_label.setStyleSheet('color: red; font-size: 9pt; padding: 3px;')
        self.error_label.setWordWrap(True)
        error_layout.addWidget(self.error_label)
        layout.addLayout(error_layout)
        
        # 텍스트 에디터
        self.text_edit = QPlainTextEdit()
        self.text_edit.setFont(QFont('Consolas', 10))
        self.text_edit.setPlaceholderText(
            'Pine Script 또는 MT5 코드를 입력하세요...\n\n'
            '예시 (Pine Script):\n'
            '//@version=5\n'
            'strategy("My Strategy")\n'
            'length = input.int(20, "Length")\n'
            'ma = ta.sma(close, length)\n'
            'plot(ma)'
        )
        self.text_edit.textChanged.connect(self.on_text_changed)
        
        # 구문 강조 (기본값: Pine Script)
        self.highlighter = SyntaxHighlighter(self.text_edit.document(), 'pine')
        
        layout.addWidget(self.text_edit)
    
    def setPlainText(self, text):
        """텍스트 설정"""
        self.text_edit.setPlainText(text)
    
    def toPlainText(self):
        """텍스트 가져오기"""
        return self.text_edit.toPlainText()
    
    def set_language(self, language):
        """언어 설정 (pine 또는 mt5)"""
        self.current_language = language
        self.highlighter = SyntaxHighlighter(self.text_edit.document(), language)
        self.highlighter.rehighlight()
        self.validate_code()  # 언어 변경 시 재검증
    
    def on_text_changed(self):
        """텍스트 변경 시 호출"""
        self.code_changed.emit()
        # 실시간 검증 (디바운싱)
        from PyQt5.QtCore import QTimer
        if not hasattr(self, 'validate_timer'):
            self.validate_timer = QTimer()
            self.validate_timer.setSingleShot(True)
            self.validate_timer.timeout.connect(self.validate_code)
        self.validate_timer.stop()
        self.validate_timer.start(500)  # 0.5초 후 검증
    
    def validate_code(self):
        """코드 검증"""
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).parent.parent))
        from gui.code_validator import CodeValidator
        
        code = self.text_edit.toPlainText()
        if not code.strip():
            self.error_label.setText('')
            return
        
        validator = CodeValidator(self.current_language)
        errors = validator.validate(code)
        
        if errors:
            error_texts = []
            for error in errors[:5]:  # 최대 5개만 표시
                error_texts.append(f"라인 {error.line}: {error.message}")
            self.error_label.setText(' | '.join(error_texts))
            self.error_label.setStyleSheet('color: red; font-size: 9pt; padding: 3px; background-color: #ffebee;')
        else:
            self.error_label.setText('✓ 코드 검증 완료')
            self.error_label.setStyleSheet('color: green; font-size: 9pt; padding: 3px;')
    
    def get_code(self):
        """코드 가져오기"""
        return self.text_edit.toPlainText()
    
    def clear(self):
        """에디터 비우기"""
        self.text_edit.clear()
        self.error_label.setText('')

