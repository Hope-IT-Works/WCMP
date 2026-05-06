@echo off
echo Stopping WCMP...
echo.

taskkill /F /IM caddy.exe /T >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO]: Caddy stopped.
) else (
    echo [WARN]: Caddy was not running.
)

taskkill /F /IM php-cgi.exe /T >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO]: PHP stopped.
) else (
    echo [WARN]: PHP was not running.
)

taskkill /F /IM mariadbd.exe /T >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO]: MariaDB stopped.
) else (
    echo [WARN]: MariaDB was not running.
)

echo.
echo [INFO]: WCMP stopped.
