@echo off
chcp 65001 >nul
echo 바탕화면 바로가기 생성 중...

cd /d "%~dp0"

python create_desktop_shortcut.py

if %ERRORLEVEL% EQU 0 (
    echo.
    echo 바로가기가 성공적으로 생성되었습니다!
    echo 바탕화면에서 "백테스트 프로그램" 바로가기를 확인하세요.
) else (
    echo.
    echo 바로가기 생성에 실패했습니다.
    echo 수동으로 바로가기를 생성하세요.
)

pause

