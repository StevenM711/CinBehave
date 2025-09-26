@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================================
REM CinBehave - Instalador Windows limpio (SIN ANSI, robusto)
REM Por defecto NO instala SLEAP (puedes habilitarlo con WITH_SLEAP=1)
REM Requiere: Windows 10/11 x64
REM ============================================================================

REM --------- CONFIGURACION ----------
set "APP_NAME=CinBehave"
set "REPO_RAW=https://raw.githubusercontent.com/StevenM711/CinBehave/main"
REM Python 3.11.9 x64 oficial:
set "PY_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
REM Directorio de instalación (usuario actual):
set "INSTALL_DIR=%USERPROFILE%\%APP_NAME%"
set "VENV_DIR=%INSTALL_DIR%\venv"
set "LOG_DIR=%INSTALL_DIR%\logs"

REM Control SLEAP: 0=sin SLEAP (por defecto), 1=con SLEAP
if not defined WITH_SLEAP set "WITH_SLEAP=0"

REM --------- TITULO / HEADER ----------
title %APP_NAME% - Instalador
echo.
echo ===============================================================
echo                 %APP_NAME% - Instalador Windows
echo ===============================================================
echo Directorio de instalacion: %INSTALL_DIR%
echo SLEAP: %WITH_SLEAP%  (0 = sin SLEAP, 1 = con SLEAP)
echo.

REM --------- ELEVACION A ADMIN ----------
REM (necesario para instalar Python para el usuario y tocar PATH correctamente)
net session >nul 2>&1
if errorlevel 1 (
  echo [INFO] Elevando a administrador...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath 'cmd.exe' -ArgumentList '/c \"\"%~f0\" %*\"'"
  exit /b
)

REM --------- PREPARAR RUTAS / LOGS ----------
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%" >nul 2>&1
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

for /f "tokens=1-4 delims=/ " %%a in ("%date%") do set "TODAY=%%d%%b%%c"
for /f "tokens=1-3 delims=:." %%h in ("%time%") do set "NOW=%%h%%i%%j"
set "NOW=%NOW: =0%"
set "TS=%date:~6,4%%date:~3,2%%date:~0,2%_%NOW%"
set "LOG=%LOG_DIR%\install_%TS%.log"

call :log "=== %APP_NAME% Installer started %date% %time% ==="

REM --------- TEST INTERNET ----------
call :log "[STEP] Verificando conexion a Internet..."
ping -n 1 raw.githubusercontent.com >nul 2>&1
if errorlevel 1 (
  call :err "Sin conexion a Internet. Intenta de nuevo."
  goto :END
)
call :log "[OK] Internet verificado"

REM --------- COMPROBAR / INSTALAR PYTHON 3.11 ----------
call :log "[STEP] Verificando Python 3.11..."
set "PY_CMD="

REM 1) Intentar 'py -3.11'
py -3.11 -c "import sys;print(sys.version)" >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%P in ('where py') do set "PY_CMD=py -3.11"
)

REM 2) Intentar 'python' si no hay PY_CMD
if not defined PY_CMD (
  for /f "delims=" %%P in ('where python 2^>nul') do (
    python -c "import sys;import platform; v=platform.python_version_tuple(); print(int(v[0])==3 and int(v[1])==11)" 2>nul | find "True" >nul 2>&1
    if not errorlevel 1 set "PY_CMD=python"
  )
)

REM 3) Instalar si no hay Python 3.11
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

  REM re-intentar deteccion
  py -3.11 -c "import sys;print(sys.version)" >nul 2>&1 && set "PY_CMD=py -3.11"
  if not defined PY_CMD (
    for /f "delims=" %%P in ('where python 2^>nul') do (
      python -c "import sys;import platform; v=platform.python_version_tuple(); print(int(v[0])==3 and int(v[1])==11)" 2>nul | find "True" >nul 2>&1
      if not errorlevel 1 set "PY_CMD=python"
    )
  )
)

if not defined PY_CMD (
  call :err "No se pudo localizar Python 3.11 tras la instalacion. Verifica PATH e intenta de nuevo."
  goto :END
)
call :log "[OK] Python verificado: %PY_CMD%"

REM --------- CREAR / ACTUALIZAR VENV ----------
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

REM --------- DESCARGAR ARCHIVOS DEL PROYECTO ----------
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

REM --------- PREPARAR REQUIREMENTS (filtrar SLEAP si WITH_SLEAP=0) ----------
set "REQ=%INSTALL_DIR%\requirements.txt"
set "REQ_FINAL=%INSTALL_DIR%\requirements_final.txt"

if "%WITH_SLEAP%"=="1" (
  copy /y "%REQ%" "%REQ_FINAL%" >nul
  call :log "[INFO] Instalacion CON SLEAP"
) else (
  call :log "[INFO] Instalacion SIN SLEAP (filtrando sleap/tensorflow)"
  >"%REQ_FINAL%" type nul
  for /f "usebackq delims=" %%L in ("%REQ%") do (
    set "LINE=%%L"
    setlocal enabledelayedexpansion
    echo !LINE! | findstr /i /r "^\s*sleap" >nul && (endlocal & goto :SKIPLINE)
    echo !LINE! | findstr /i /r "^\s*tensorflow" >nul && (endlocal & goto :SKIPLINE)
    >>"%REQ_FINAL%" echo %%L
    endlocal
    :SKIPLINE
  )
)

REM --------- PIP INSTALL ----------
call :log "[STEP] Instalando dependencias (puede tardar)..."
"%PYV%" -m pip install --no-input --no-cache-dir -r "%REQ_FINAL%" >>"%LOG%" 2>&1
if errorlevel 1 (
  call :err "Fallo instalando dependencias. Revisa el log: %LOG%"
  goto :END
)

REM --------- CREAR LANZADOR ----------
call :log "[STEP] Creando lanzador..."
(
  echo @echo off
  echo "%VENV_DIR%\Scripts\python.exe" "%INSTALL_DIR%\cinbehave_guii.py"
) > "%INSTALL_DIR%\run_cinbehave.bat"

REM --------- FIN OK ----------
echo.
echo ===============================================================
echo  INSTALACION COMPLETADA
echo  Ejecuta: "%INSTALL_DIR%\run_cinbehave.bat"
echo  Log:     %LOG%
echo ===============================================================
call :log "=== OK ==="
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
