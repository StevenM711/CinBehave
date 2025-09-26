@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM ============================================================================
REM CinBehave - Instalador Windows (v6)
REM - Aísla Python roto en %USERPROFILE%\CinBehave\Python311
REM - Ignora py.ini que secuestra el launcher
REM - Detecta Python 3.11 válido via Registro (Lib\encodings presente)
REM - Instala Python 3.11 si falta y usa su ruta directa
REM - Descarga con curl; GUI con doble intento y placeholder
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
cd /d "%INSTALL_DIR%"

REM --- Timestamp seguro ---
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd_HHmmss')"`) do set "TS=%%T"
set "LOG=%LOG_DIR%\install_%TS%.log"
call :log "=== %APP_NAME% Installer started %DATE% %TIME% ==="

REM --- Internet ---
call :log "[STEP] Verificando conexion a Internet..."
ping -n 1 raw.githubusercontent.com >nul 2>&1
if errorlevel 1 ( call :err "Sin conexion a Internet." & goto :END )
call :log "[OK] Internet verificado"

REM --- Aislar Python roto en CinBehave (si existe) ---
if exist "%INSTALL_DIR%\Python311\python.exe" (
  call :log "[WARN] Python311 dentro de %INSTALL_DIR% detectado -> se renombra para evitarlo"
  ren "%INSTALL_DIR%\Python311" "Python311.broken_%TS%" >nul 2>&1
)

REM --- Ignorar py.ini que manipule el launcher ---
for %%F in ("%LocalAppData%\py.ini" "%ProgramData%\py.ini" "%USERPROFILE%\py.ini") do (
  if exist "%%~F" (
    call :log "[WARN] Se detecto %%~F -> renombrando a backup"
    ren "%%~F" "py.ini.bak_%TS%" >nul 2>&1
  )
)

REM --- Buscar Python 3.11 valido en Registro (que tenga Lib\encodings)
set "PY_CMD="
call :find_py311_reg "HKCU\Software\Python\PythonCore\3.11\InstallPath"
if not defined PY_CMD call :find_py311_reg "HKLM\Software\Python\PythonCore\3.11\InstallPath"
if not defined PY_CMD call :find_py311_reg "HKLM\Software\Wow6432Node\Python\PythonCore\3.11\InstallPath"

REM --- Si no hay en Registro, intentar launcher y 'python' verificando version
if not defined PY_CMD (
  for /f "usebackq delims=" %%E in (`py -3.11 -c "import sys,os;print(sys.executable)" 2^>nul`) do (
    if exist "%%~dp0..\Lib\encodings" ( REM no fiable; mejor verificar directamente
    )
  )
)

if not defined PY_CMD (
  for /f "usebackq delims=" %%E in (`python -c "import sys,os;print(sys.executable if sys.version_info[:2]==(3,11) else '')" 2^>nul`) do (
    if exist "%%~dp0Lib\encodings" (
    )
  )
)

REM --- Si seguimos sin Python 3.11 valido, instalar uno limpio
if not defined PY_CMD (
  call :log "[INFO] Python 3.11 no encontrado. Instalando..."
  set "PY_EXE=%INSTALL_DIR%\python-3.11.9-amd64.exe"
  curl -fL -o "%PY_EXE%" "%PY_URL%" >>"%LOG%" 2>&1
  if errorlevel 1 ( call :err "Fallo al descargar Python desde %PY_URL%" & goto :END )
  call :log "[INFO] Ejecutando instalador de Python silencioso..."
  "%PY_EXE%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0 SimpleInstall=1 >>"%LOG%" 2>&1
  if errorlevel 1 ( call :err "Error instalando Python." & goto :END )
  del /q "%PY_EXE%" >nul 2>&1

  REM Re-detectar por Registro (preferido)
  call :find_py311_reg "HKCU\Software\Python\PythonCore\3.11\InstallPath"
  if not defined PY_CMD call :find_py311_reg "HKLM\Software\Python\PythonCore\3.11\InstallPath"
  if not defined PY_CMD call :find_py311_reg "HKLM\Software\Wow6432Node\Python\PythonCore\3.11\InstallPath"
)

if not defined PY_CMD (
  call :err "No se pudo localizar Python 3.11 valido. Revisa PATH/Registro e intenta de nuevo."
  goto :END
)
call :log "[OK] Python seleccionado: %PY_CMD%"

REM --- Crear venv con fallbacks ---
call :log "[STEP] Creando venv en %VENV_DIR% ..."
if exist "%VENV_DIR%\Scripts\python.exe" (
  call :log "[INFO] venv existente; se reutilizara."
) else (
  call :log "[TRY] -m venv"
  "%PY_CMD%" -m venv "%VENV_DIR%" >>"%LOG%" 2>&1
  if errorlevel 1 (
    call :log "[WARN] venv fallo; ensurepip y reintento"
    "%PY_CMD%" -m ensurepip --upgrade >>"%LOG%" 2>&1
    "%PY_CMD%" -m venv "%VENV_DIR%" >>"%LOG%" 2>&1
  )
  if not exist "%VENV_DIR%\Scripts\python.exe" (
    call :log "[WARN] venv aun no creado; virtualenv como fallback"
    "%PY_CMD%" -m pip install --upgrade pip setuptools wheel >>"%LOG%" 2>&1
    "%PY_CMD%" -m pip install --upgrade virtualenv >>"%LOG%" 2>&1
    "%PY_CMD%" -m virtualenv "%VENV_DIR%" >>"%LOG%" 2>&1
  )
  if not exist "%VENV_DIR%\Scripts\python.exe" (
    call :err "Error creando venv incluso con fallback (virtualenv)."
    goto :END
  )
)

set "PYV=%VENV_DIR%\Scripts\python.exe"
set "PIPV=%VENV_DIR%\Scripts\pip.exe"

REM --- Upgrades base en el venv ---
call :log "[STEP] Actualizando pip/setuptools/wheel en el venv..."
"%PYV%" -m pip install --upgrade pip setuptools wheel --no-input >>"%LOG%" 2>&1

REM --- Descargas del proyecto (con curl) ---
call :log "[STEP] Descargando requirements.txt..."
curl -fL -o "%INSTALL_DIR%\requirements.txt" "%REPO_RAW%/requirements.txt" >>"%LOG%" 2>&1
if errorlevel 1 ( call :err "No se pudo descargar requirements.txt" & goto :END )

call :log "[STEP] Descargando GUI (intento 1: cinbehave_guii.py)..."
curl -fL -o "%INSTALL_DIR%\cinbehave_guii.py" "%REPO_RAW%/cinbehave_guii.py" >>"%LOG%" 2>&1

if not exist "%INSTALL_DIR%\cinbehave_guii.py" (
  call :log "[INFO] Intento 2: cinbehave_gui.py"
  curl -fL -o "%INSTALL_DIR%\cinbehave_guii.py" "%REPO_RAW%/cinbehave_gui.py" >>"%LOG%" 2>&1
)

if not exist "%INSTALL_DIR%\cinbehave_guii.py" (
  call :log "[WARN] No se pudo descargar la GUI; creando placeholder para continuar."
  >"%INSTALL_DIR%\cinbehave_guii.py" (
    echo print("CinBehave GUI placeholder.")
    echo print("Coloca tu archivo GUI correcto en: %INSTALL_DIR%\cinbehave_guii.py")
  )
)

REM --- Filtrar requirements si SIN SLEAP ---
set "REQ=%INSTALL_DIR%\requirements.txt"
set "REQ_FINAL=%INSTALL_DIR%\requirements_final.txt"
if "%WITH_SLEAP%"=="1" (
  copy /y "%REQ%" "%REQ_FINAL%" >nul
  call :log "[INFO] Instalacion CON SLEAP"
) else (
  call :log "[INFO] Instalacion SIN SLEAP (filtrando sleap/tensorflow)"
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "(Get-Content '%REQ%') | Where-Object {$_ -notmatch '^\s*(sleap|tensorflow)'} | Set-Content -NoNewline '%REQ_FINAL%'"
)

REM --- Instalar dependencias ---
call :log "[STEP] Instalando dependencias..."
"%PYV%" -m pip install --no-input --no-cache-dir -r "%REQ_FINAL%" >>"%LOG%" 2>&1
if errorlevel 1 ( call :err "Fallo instalando dependencias. Revisa el log: %LOG%" & goto :END )

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

:find_py311_reg
REM Uso: call :find_py311_reg "HK...\...\3.11\InstallPath"
for /f "tokens=2,*" %%A in ('reg query %~1 /ve 2^>nul ^| find "REG_SZ"') do (
  set "CAND=%%B"
  if exist "%%B\python.exe" if exist "%%B\Lib\encodings" (
    set "PY_CMD=%%B\python.exe"
  )
)
goto :eof

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
