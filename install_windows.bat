@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM ============================================================================
REM CinBehave - Instalador Windows (v3)
REM - Sin ANSI
REM - Timestamp seguro
REM - Filtrado requirements via PowerShell
REM - Detección de Python 3.11 SIN heredoc (compatible con cmd.exe)
REM ============================================================================

set "APP_NAME=CinBehave"
set "REPO_RAW=https://raw.githubusercontent.com/StevenM711/CinBehave/main"
set "PY_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"

set "INSTALL_DIR=%USERPROFILE%\%APP_NAME%"
set "VENV_DIR=%INSTALL_DIR%\venv"
set "LOG_DIR=%INSTALL_DIR%\logs"

if not defined WITH_SLEAP set "WITH_SLEAP=0"

title %APP_NAME% - Instalador
echo.
echo ===============================================================
echo                 %APP_NAME% - Instalador Windows
echo ===============================================================
echo Directorio de instalacion: %INSTALL_DIR%
echo SLEAP: %WITH_SLEAP%  (0 = sin SLEAP, 1 = con SLEAP)
echo.

REM --- Elevacion a admin si hace falta ---
net session >nul 2>&1
if errorlevel 1 (
  echo [INFO] Elevando privilegios de administrador...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath 'cmd.exe' -ArgumentList '/k \"\"%~f0\" %*\"'"
  exit /b
)

REM --- Preparar carpetas ---
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%" >nul 2>&1
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

REM --- Timestamp seguro (para nombre del log) ---
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd_HHmmss')"`) do set "TS=%%T"
set "LOG=%LOG_DIR%\install_%TS%.log"

call :log "=== %APP_NAME% Installer started %DATE% %TIME% ==="

REM --- Internet ---
call :log "[STEP] Verificando conexion a Internet..."
ping -n 1 raw.githubusercontent.com >nul 2>&1
if errorlevel 1 (
  call :err "Sin conexion a Internet. Intenta de nuevo."
  goto :END
)
call :log "[OK] Internet verificado"

REM --- Python 3.11 (DETECCION CORREGIDA) ---
call :log "[STEP] Verificando Python 3.11..."
set "PY_CMD="

REM 1) Probar el launcher directamente
py -3.11 -V >nul 2>&1 && set "PY_CMD=py -3.11"

REM 2) Si no, probar 'python' y chequear major/minor
if not defined PY_CMD (
  python -c "import sys; print(1 if (sys.version_info[0]==3 and sys.version_info[1]==11) else 0)" 2>nul | find "1" >nul 2>&1 && set "PY_CMD=python"
)

REM 3) Instalar si sigue sin estar
if not defined PY_CMD (
  call :log "[INFO] Python 3.11 no encontrado. Instalando..."
  set "PY_EXE=%INSTALL_DIR%\python-3.11.9-amd64.exe"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%PY_URL%' -OutFile '%PY_EXE%' -UseBasicParsing" 2>>"%LOG%"
  if errorlevel 1 (
    call :err "Fallo al descargar Python desde %PY_URL%"
    goto :END
  )
  call :log "[INFO] Ejecutando instalador de Python..."
  "%PY_EXE%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0 SimpleInstall=1 >>"%LOG%" 2>&1
  if errorlevel 1 (
    call :err "Error instalando Python."
    goto :END
  )
  del /q "%PY_EXE%" >nul 2>&1

  REM Re-detectar
  py -3.11 -V >nul 2>&1 && set "PY_CMD=py -3.11"
  if not defined PY_CMD (
    python -c "import sys; print(1 if (sys.version_info[0]==3 and sys.version_info[1]==11) else 0)" 2>nul | find "1" >nul 2>&1 && set "PY_CMD=python"
  )
)

if not defined PY_CMD (
  call :err "No se pudo localizar Python 3.11 tras la instalacion. Verifica PATH e intenta de nuevo."
  goto :END
)
call :log "[OK] Python verificado: %PY_CMD%"

REM --- Crear venv ---
call :log "[STEP] Creando venv..."
if not exist "%VENV_DIR%" (
  %PY_CMD% -m venv "%VENV_DIR%" >>"%LOG%" 2>&1
  if errorlevel 1 (
    call :err "Error creando venv."
    goto :END
  )
) else (
  call :log "[INFO] venv existente, continuando..."
)

set "PYV=%VENV_DIR%\Scripts\python.exe"
set "PIPV=%VENV_DIR%\Scripts\pip.exe"
if not exist "%PYV%" (
  call :err "Python del venv no encontrado: %PYV%"
  goto :END
)

call :log "[STEP] Actualizando pip/setuptools/wheel..."
"%PYV%" -m pip install --upgrade pip setuptools wheel --no-input >>"%LOG%" 2>&1

REM --- Descargar archivos del proyecto ---
call :log "[STEP] Descargando archivos del proyecto..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%REPO_RAW%/requirements.txt' -OutFile '%INSTALL_DIR%\requirements.txt' -UseBasicParsing" 2>>"%LOG%"
if errorlevel 1 (
  call :err "No se pudo descargar requirements.txt"
  goto :END
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%REPO_RAW%/cinbehave_guii.py' -OutFile '%INSTALL_DIR%\cinbehave_guii.py' -UseBasicParsing" 2>>"%LOG%"
if errorlevel 1 (
  call :err "No se pudo descargar cinbehave_guii.py"
  goto :END
)

REM --- Filtrar requirements si SIN SLEAP ---
set "REQ=%INSTALL_DIR%\requirements.txt"
set "REQ_FINAL=%INSTALL_DIR%\requirements_final.txt"

if "%WITH_SLEAP%"=="1" (
  copy /y "%REQ%" "%REQ_FINAL%" >nul
  call :log "[INFO] Instalacion CON SLEAP"
) else (
  call :log "[INFO] Instalacion SIN SLEAP (filtrando sleap/tensorflow via PowerShell)"
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "(Get-Content '%REQ%') | Where-Object {$_ -notmatch '^\s*(sleap|tensorflow)'} | Set-Content -NoNewline '%REQ_FINAL%'"
)

REM --- Instalar dependencias ---
call :log "[STEP] Instalando dependencias..."
"%PYV%" -m pip install --no-input --no-cache-dir -r "%REQ_FINAL%" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :err "Fallo instalando dependencias. Revisa el log: %LOG%"
  goto :END
)

REM --- Lanzador ---
call :log "[STEP] Creando lanzador..."
(
  echo @echo off
  echo "%VENV_DIR%\Scripts\python.exe" "%INSTALL_DIR%\cinbehave_guii.py"
) > "%INSTALL_DIR%\run_cinbehave.bat"

echo.
echo ===============================================================
echo  INSTALACION COMPLETADA
echo  Ejecuta: "%INSTALL_DIR%\run_cinbehave.bat"
echo  Log:     %LOG%
echo ===============================================================
echo.
pause
goto :END

:log
echo %~1
>>"%LOG%" echo %~1
goto :eof

:err
echo [ERROR] %~1
>>"%LOG%" echo [ERROR] %~1
goto :eof

:END
endlocal
