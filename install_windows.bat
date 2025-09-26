@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ==========================
:: CinBehave Windows Installer
:: v1.0 (Stable, UTF-8 safe)
:: ==========================

:: Evitar mojibake en consola
chcp 65001 >nul

:: --- Configuración general ---
set "APP_NAME=CinBehave"
set "APP_DIR=%USERPROFILE%\CinBehave"
set "VENV_DIR=%APP_DIR%\venv"
set "LOG_DIR=%APP_DIR%\logs"
set "LOG_FILE=%LOG_DIR%\install_%DATE:~6,4%-%DATE:~3,2%-%DATE:~0,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%.log"
set "PYTHON_VERSION=3.11.9"
set "PYTHON_INSTALLER=python-%PYTHON_VERSION%-amd64.exe"
set "PYTHON_URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/%PYTHON_INSTALLER%"
set "REQS_URL=https://raw.githubusercontent.com/StevenM711/CinBehave/main/requirements.txt"
set "REQS_FILE=%APP_DIR%\requirements.txt"
set "REQS_NO_SLEAP_FILE=%APP_DIR%\requirements_nosleap.txt"

:: Variable opcional para saltar SLEAP / TensorFlow
:: Uso: SKIP_SLEAP=1 install_windows.bat
if not defined SKIP_SLEAP set "SKIP_SLEAP=0"

:: --- Función de log ---
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
call :log "[INFO] Iniciando instalación de %APP_NAME%..."

:: --- Verificar administrador; si no, auto-elevar ---
net session >nul 2>&1
if errorlevel 1 (
  echo [WARN] No hay privilegios de administrador. Reintentando elevado...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList 'relaunch' -WindowStyle Normal"
  exit /b
)

:: Si venimos del relanzamiento, continuar
if /i "%1"=="relaunch" shift

:: --- Info del sistema ---
ver | findstr /i "10." >nul && set "WINVER=Windows 10"
ver | findstr /i "11." >nul && set "WINVER=Windows 11"
if not defined WINVER set "WINVER=Windows (desconocido)"
call :log "[INFO] Sistema: %WINVER%"

:: Arquitectura
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
  set "ARCH=x64"
) else (
  set "ARCH=%PROCESSOR_ARCHITECTURE%"
)
call :log "[INFO] Arquitectura: %ARCH%"

:: --- Directorios base ---
if not exist "%APP_DIR%" (
  mkdir "%APP_DIR%" >nul 2>&1
  if errorlevel 1 (
    call :log "[ERROR] No se pudo crear %APP_DIR%"
    goto :fail
  )
) else (
  call :log "[WARN] El directorio %APP_DIR% ya existe. Se actualizará la instalación."
)

:: --- Descargar requirements.txt ---
call :log "[STEP] Descargando requirements.txt..."
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -Uri '%REQS_URL%' -OutFile '%REQS_FILE%'" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :log "[WARN] Falla Invoke-WebRequest; probando con curl..."
  curl -L -o "%REQS_FILE%" "%REQS_URL%" >> "%LOG_FILE%" 2>&1
  if errorlevel 1 (
    call :log "[ERROR] No se pudo descargar requirements.txt desde %REQS_URL%"
    goto :fail
  )
)

:: --- Python: detectar o instalar ---
call :log "[STEP] Verificando Python 3.11..."
where py >nul 2>&1
if not errorlevel 1 (
  for /f "usebackq tokens=2,* delims= " %%A in (`py -3.11 -V 2^>^&1`) do set "FOUND_PY=%%A %%B"
)

if defined FOUND_PY (
  call :log "[INFO] Detectado %FOUND_PY%"
) else (
  call :log "[WARN] Python 3.11 no encontrado. Instalando..."
  if exist "%TEMP%\%PYTHON_INSTALLER%" del /q "%TEMP%\%PYTHON_INSTALLER%" >nul 2>&1

  :: Descargar instalador
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%TEMP%\%PYTHON_INSTALLER%'" >> "%LOG_FILE%" 2>&1
  if errorlevel 1 (
    call :log "[WARN] Falla Invoke-WebRequest; probando con curl..."
    curl -L -o "%TEMP%\%PYTHON_INSTALLER%" "%PYTHON_URL%" >> "%LOG_FILE%" 2>&1
    if errorlevel 1 (
      call :log "[ERROR] No se pudo descargar Python desde %PYTHON_URL%"
      goto :fail
    )
  )

  :: Instalar silencioso
  call :log "[STEP] Instalando Python 3.11..."
  start /wait "" "%TEMP%\%PYTHON_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_pip=1 Include_launcher=1 SimpleInstall=1
  if errorlevel 1 (
    call :log "[ERROR] Falló la instalación de Python."
    goto :fail
  )

  :: Verificar de nuevo
  for /f "usebackq tokens=2,* delims= " %%A in (`py -3.11 -V 2^>^&1`) do set "FOUND_PY=%%A %%B"
  if not defined FOUND_PY (
    call :log "[ERROR] Python 3.11 no aparece en PATH tras instalar."
    goto :fail
  ) else (
    call :log "[INFO] Instalado %FOUND_PY%"
  )
)

:: --- Crear venv ---
call :log "[STEP] Creando entorno virtual..."
if not exist "%VENV_DIR%" (
  py -3.11 -m venv "%VENV_DIR%" >> "%LOG_FILE%" 2>&1
  if errorlevel 1 (
    call :log "[ERROR] No se pudo crear el venv."
    goto :fail
  )
) else (
  call :log "[INFO] venv ya existe, se reutiliza."
)

:: Activar venv en esta sesión
call "%VENV_DIR%\Scripts\activate.bat"
if errorlevel 1 (
  call :log "[ERROR] No se pudo activar el venv."
  goto :fail
)

:: --- Actualizar pip/setuptools/wheel ---
call :log "[STEP] Actualizando pip/setuptools/wheel..."
python -m pip install --upgrade pip setuptools wheel >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :log "[ERROR] No se pudo actualizar pip/setuptools/wheel."
  goto :fail
)

:: --- Construir requirements sin SLEAP si procede ---
if "%SKIP_SLEAP%"=="1" (
  call :log "[INFO] SKIP_SLEAP=1 -> se instalará requirements sin SLEAP/TensorFlow/OpenCV GPU."
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "(Get-Content '%REQS_FILE%') | Where-Object {$_ -notmatch '^\s*(sleap|tensorflow|opencv|h5py)\b'} | Set-Content -Encoding UTF8 '%REQS_NO_SLEAP_FILE%'" >> "%LOG_FILE%" 2>&1
  if errorlevel 1 (
    call :log "[ERROR] No se pudo generar requirements_nosleap.txt"
    goto :fail
  )
  set "REQS_TO_INSTALL=%REQS_NO_SLEAP_FILE%"
) else (
  set "REQS_TO_INSTALL=%REQS_FILE%"
)

:: --- Instalar dependencias ---
call :log "[STEP] Instalando dependencias desde %REQS_TO_INSTALL% ..."
python -m pip install -r "%REQS_TO_INSTALL%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :log "[ERROR] pip install falló. Revisa el log: %LOG_FILE%"
  goto :fail
)

:: --- Fin OK ---
call :log "[OK] Instalación completa."
echo.
echo ===============================================
echo   %APP_NAME% instalado correctamente.
echo   Log: %LOG_FILE%
echo   Para usar el entorno:
echo     1) "%VENV_DIR%\Scripts\activate.bat"
echo     2) python cinbehave_guii.py
echo ===============================================
echo.
goto :eof

:fail
echo.
echo =========[ ERROR ]=========
echo Ocurrió un error. Revisa el log:
echo %LOG_FILE%
echo ===========================
echo.
exit /b 1

:log
>> "%LOG_FILE%" echo %~1
echo %~1
goto :eof
