@echo off
cd /d "%~dp0"

docker info >nul 2>&1
if errorlevel 1 (
    echo(Docker Desktop is not running or Docker Engine is unavailable.
    echo Start Docker Desktop and run this file again.
    pause
    exit /b 1
)

docker compose up -d --build
if errorlevel 1 (
    echo(Failed to start the Docker container.
    pause
    exit /b 1
)

start "" http://localhost:5678/
echo(Slide Audio App started.
echo(The container will keep running after this window is closed.
pause
