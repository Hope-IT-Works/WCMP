@echo off
cd /d "%~dp0"

echo  _      __  _____  __  ___  ___
echo | | /| / / / ___/ /  ^|/  / / _ \
echo | ^|/ ^|/ / / /__  / /^|_/ / / ___/
echo ^|__/^|__/  \___/ /_/  /_/ /_/
echo ====================================
echo Starting WCMP...
echo.

if not exist "%~dp0caddy\caddy.exe" (
    echo [ERRO]: caddy\caddy.exe not found. Is Caddy installed?
    goto :error
)

echo [INFO]: Starting Caddy...
start "WCMP Caddy" /D "%~dp0caddy" "%~dp0caddy\caddy.exe" run --watch

if exist "%~dp0php\php-cgi.exe" (
    echo [INFO]: Starting PHP...
    start "WCMP PHP" /D "%~dp0php" "%~dp0php\php-cgi.exe" -b 127.0.0.1:##PHPPORT##
) else (
    echo [WARN]: php\php-cgi.exe not found. Skipping PHP.
)

if exist "%~dp0mariadb\bin\mariadbd.exe" (
    echo [INFO]: Starting MariaDB...
    start "WCMP MariaDB" /D "%~dp0mariadb\bin" "%~dp0mariadb\bin\mariadbd.exe" --port=##MARIADBPORT##
) else (
    echo [WARN]: mariadb\bin\mariadbd.exe not found. Skipping MariaDB.
)

echo.
echo [INFO]: WCMP started.
goto :eof

:error
echo.
pause
