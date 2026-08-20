@echo off
setlocal

where dsh >nul 2>nul
if errorlevel 1 (
    start "" /wait cmd /c "echo [ERROR] dsh not found. Install it first: npm install -g @deepseek-ai/dsh & pause"
    exit /b 1
)

rem The bundle owns the app window and exits dsh when it closes. Its disposable
rem browser profile uses the OS temp directory and is removed on exit.
dsh web --app-mode 1
exit /b %errorlevel%
