@echo off
python "%~dp0run_tests.py" %*
exit /b %errorlevel%
