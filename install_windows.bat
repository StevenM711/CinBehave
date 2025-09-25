@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM ============================================================================
REM CinBehave - INSTALADOR WINDOWS (SIN SLEAP)
REM Version: 1.9 (user-mode Python + venv, no PATH global, sin SLEAP)
REM ============================================================================

echo.
echo ============================================================================
echo                    CinBehave SLEAP Analysis Suite
echo                      INSTALADOR v1.9 (sin SLEAP)
echo ============================================================================
echo [DEBUG] Ejecutando: %~f0
echo.

echo [INFO] Iniciando instalacion...
timeout /t 1 >nul

REM ==== PASO 1: ADMIN (opcional, solo para MSI por usuario no es estrictamente necesario) ====
echo [PASO 1] Verificando administrador (opcional)...
net session >nul 2>&1
if errorlevel 1 (
  echo [NOTICE] No se ejecuta como admin. Continuando con instalacion por USUARIO...
) else (
  echo [OK] Permisos de administrador detectados (no requeridos).
)

REM ==== PASO 2: INTERNET ====
echo [PASO 2] Verificando conexion a internet...
ping -n 1 8.8.8.8 >nul 2>&1
if errorlevel 1 goto ERR_NET
echo [OK] Conexion a internet verificada

REM ==== PASO 3: DIRECTORIOS ====
echo [PASO 3] Preparando directorio de instalacion...
set "INSTALL_DIR=%USERPROFILE%\CinBehave"
echo [INFO] Directorio de instalacion: %INSTALL_DIR%

if exist "%INSTALL_DIR%" (
    echo [WARNING] Instalacion previa detectada
    set /p "OVERWRITE=Sobrescribir instalacion anterior? s/n: "
    if /i not "!OVERWRITE!"=="s" goto ABORT_INSTALL
    echo [INFO] Conservando carpetas de usuario y proyectos (backup)...
    if not exist "%USERPROFILE%\CinBehave_backup" mkdir "%USERPROFILE%\CinBehave_backup"
    for %%D in ("users" "Proyectos") do (
        if exist "%INSTALL_DIR%\%%~D" (
            echo [INFO] Copiando %%~D a backup...
            xcopy /e /i /y "%INSTALL_DIR%\%%~D" "%USERPROFILE%\CinBehave_backup\%%~D" >nul
        )
    )
    echo [INFO] Eliminando instalacion anterior...
    rmdir /s /q "%INSTALL_DIR%"
)

mkdir "%INSTALL_DIR%" 2>nul
mkdir "%INSTALL_DIR%\logs" 2>nul
mkdir "%INSTALL_DIR%\temp" 2>nul
mkdir "%INSTALL_DIR%\Proyectos" 2>nul
mkdir "%INSTALL_DIR%\users" 2>nul
mkdir "%INSTALL_DIR%\config" 2>nul
mkdir "%INSTALL_DIR%\assets" 2>nul
mkdir "%INSTALL_DIR%\docs" 2>nul
cd /d "%INSTALL_DIR%"
echo [OK] Estructura de carpetas creada

REM ==== PASO 4: PYTHON DOWNLOAD + MSI CHECK ====
echo [PASO 4] Descargando e instalando Python 3.11.6 (modo USUARIO)...
echo [INFO] Descargando Python desde python.org (puede tomar varios minutos)...
powershell -NoProfile -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
  "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe' -OutFile 'python_installer.exe' -UseBasicParsing"
if not exist "python_installer.exe" goto ERR_PY_DL

echo [INFO] Verificando servicio Windows Installer...
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "(Get-Service -Name msiserver).Status"`) do set "MSI_STATUS=%%S"
if /i not "%MSI_STATUS%"=="Running" (
  echo [NOTICE] msiserver no esta en Running. Intentando iniciar...
  net start msiserver >nul 2>&1
  for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "(Get-Service -Name msiserver).Status"`) do set "MSI_STATUS=%%S"
  if /i not "%MSI_STATUS%"=="Running" goto ERR_MSI
)
echo [OK] Servicio Windows Installer activo

echo [INFO] Instalando Python 3.11.6 para el USUARIO actual...
echo [INFO] Python se instalara en: %INSTALL_DIR%\Python311  (no se modificara el PATH global)
start /wait python_installer.exe /quiet ^
  TargetDir="%INSTALL_DIR%\Python311" ^
  InstallAllUsers=0 ^
  PrependPath=0 ^
  AssociateFiles=1 ^
  Shortcuts=1 ^
  Include_doc=0 ^
  Include_tcltk=1 ^
  Include_test=0 ^
  Include_launcher=1 ^
  InstallLauncherAllUsers=0

if errorlevel 1 goto ERR_PY_SETUP
if not exist "%INSTALL_DIR%\Python311\python.exe" goto ERR_PY_SETUP

del /q "python_installer.exe" >nul 2>&1
echo [OK] Python 3.11.6 instalado correctamente

REM ==== PASO 5: VENV ====
echo [PASO 5] Creando entorno virtual...
"%INSTALL_DIR%\Python311\python.exe" -m venv venv --upgrade-deps
if not exist "venv\Scripts\python.exe" goto ERR_VENV
echo [OK] Entorno virtual creado

REM ==== PASO 6: APP ====
echo [PASO 6] Obteniendo aplicacion principal...
REM Opcion A: Descargar desde GitHub (tag/commit fijo recomendado)
powershell -NoProfile -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
  "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py' -UseBasicParsing"
if not exist "cinbehave_gui.py" goto ERR_APP_DL
echo [OK] Aplicacion principal disponible

REM ==== PASO 7: DEPENDENCIAS (SIN SLEAP) ====
echo [PASO 7] Instalando dependencias (excluyendo SLEAP)...
call "venv\Scripts\activate.bat"
python -m pip install --upgrade pip

REM Si hay requirements.txt junto al instalador, copiarlo. Si no, crear basico.
if exist "%~dp0requirements.txt" (
  copy "%~dp0requirements.txt" "requirements.txt" >nul
) else (
  echo requests>requirements.txt
  echo numpy>>requirements.txt
  echo pandas>>requirements.txt
  echo matplotlib>>requirements.txt
  echo tqdm>>requirements.txt
)

REM Filtrar sleap si aparece en requirements.txt
echo [INFO] Generando requirements_sin_sleap.txt...
> requirements_sin_sleap.txt (
  for /f "usebackq delims=" %%L in ("requirements.txt") do (
    set "LINE=%%L"
    setlocal EnableDelayedExpansion
    set "LOW=!LINE:~0,5!"
    REM Excluir lineas que contengan 'sleap' (cualquier forma)
    echo !LINE! | find /I "sleap" >nul
    if errorlevel 1 (
      echo !LINE!
    )
    endlocal
  )
)

python -m pip install -r requirements_sin_sleap.txt
if errorlevel 1 goto ERR_DEPS
echo [OK] Dependencias instaladas

REM ==== PASO 8: LANZADORES ====
echo [PASO 8] Creando archivos de lanzamiento...
> "CinBehave.bat"  (
  echo @echo off
  echo REM Lanzador de CinBehave - v1.9 (sin SLEAP)
  echo title CinBehave - SLEAP Analysis Suite
  echo cd /d "%%~dp0"
  echo echo Iniciando CinBehave...
  echo call venv\Scripts\activate.bat
  echo python cinbehave_gui.py
  echo if errorlevel 1 ^
  echo ^( ^
  echo   echo. ^
  echo   echo [ERROR] Error ejecutando CinBehave ^
  echo   echo Revisa logs\ y dependencias ^
  echo   pause ^>nul ^
  echo ^)
)

> "Test.bat" (
  echo @echo off
  echo title CinBehave - Test del Sistema
  echo cd /d "%%~dp0"
  echo echo ============================================
  echo echo    Test de Componentes de CinBehave
  echo echo ============================================
  echo call venv\Scripts\activate.bat
  echo echo.
  echo echo [TEST] Verificando Python...
  echo python --version
  echo echo.
  echo echo [TEST] Verificando dependencias basicas...
  echo python -c "import requests, numpy, pandas, matplotlib; print('[OK] Dependencias basicas funcionan')"
  echo echo.
  echo echo [TEST] Verificando TensorFlow (opcional)...
  echo python -c "import importlib,sys; m=importlib.util.find_spec('tensorflow'); print('[INFO] TF instalado?' , bool(m))"
  echo echo.
  echo echo ============================================
  echo echo Presiona cualquier tecla para continuar...
  echo pause ^>nul
)

> "Uninstall.bat" (
  echo @echo off
  echo title Desinstalador de CinBehave
  echo echo.
  echo echo ============================================
  echo echo    Desinstalador de CinBehave
  echo echo ============================================
  echo echo.
  echo set /p CONFIRM=Desinstalar CinBehave? s/n: 
  echo if /i "%%CONFIRM%%"=="s" ^
  echo ^( 
  echo   echo Desinstalando...
  echo   cd /d "%%USERPROFILE%%"
  echo   rmdir /s /q "%%USERPROFILE%%\CinBehave"
  echo   echo CinBehave desinstalado.
  echo ^)
  echo pause
)

echo [OK] Archivos de lanzamiento creados

REM ==== PASO 9: INFO DEL SISTEMA ====
echo [PASO 9] Creando archivo de informacion del sistema...
> "system_info.txt" (
  echo ============================================
  echo    CinBehave System Information
  echo    Instalacion completada: %DATE% %TIME%
  echo ============================================
  echo.
  echo Directorio de instalacion: %INSTALL_DIR%
  echo Version de Python:
)
"%INSTALL_DIR%\Python311\python.exe" --version >> "system_info.txt" 2>&1
>> "system_info.txt" (
  echo.
  echo Sistema operativo:
)
systeminfo | findstr /C:"OS Name" /C:"OS Version" >> "system_info.txt"
>> "system_info.txt" (
  echo.
  echo Memoria del sistema:
)
systeminfo | findstr /C:"Total Physical Memory" >> "system_info.txt"
echo [OK] Informacion del sistema guardada

REM ==== PASO 10: VALIDACION FINAL ====
echo [PASO 10] Validacion final del sistema...
venv\Scripts\python.exe --version >nul 2>&1
if errorlevel 1 goto ERR_PY_RUN

venv\Scripts\python.exe -c "import requests, numpy, pandas" >nul 2>&1
if errorlevel 1 goto ERR_DEPS

venv\Scripts\python.exe -c "import sys; sys.path.append('.'); import cinbehave_gui" >nul 2>&1
if errorlevel 1 (
  echo [WARNING] La aplicacion pudo no importar correctamente (revisa dependencias).
) else (
  echo [OK] Validacion completada
)

echo.
echo ============================================================================
echo                        INSTALACION COMPLETADA
echo ============================================================================
echo.
echo [SUCCESS] CinBehave instalado en: %INSTALL_DIR%
echo.
echo ARCHIVOS CREADOS:
echo    - CinBehave.bat (lanzador)
echo    - Test.bat (test del sistema)
echo    - Uninstall.bat (desinstalador)
echo    - system_info.txt (info del sistema)
echo.
echo PYTHON:
echo    - Version: 3.11.6
echo    - Ubicacion: %INSTALL_DIR%\Python311
echo    - Entorno virtual: configurado (no se toco PATH global)
echo.
echo USO:
echo    1) Ir a: %INSTALL_DIR%
echo    2) Ejecutar: CinBehave.bat
echo.

set /p "RUN_NOW=Ejecutar CinBehave ahora? s/n: "
if /i "%RUN_NOW%"=="s" (
  echo [INFO] Iniciando CinBehave...
  start "" "%INSTALL_DIR%\CinBehave.bat"
  timeout /t 1 >nul
)

goto END_OK

REM ==== ERRORES ====
:ERR_NET
echo [ERROR] Sin conexion a internet
echo [INFO] Verifique su conexion y reintente
pause
exit /b 1

:ERR_PY_DL
echo [ERROR] Error descargando Python
echo [INFO] Verifique su conexion a internet
pause
exit /b 1

:ERR_MSI
echo [ERROR] El servicio Windows Installer no esta activo
echo [INFO] Inicielo con: net start msiserver y reintente
pause
exit /b 1

:ERR_PY_SETUP
echo [ERROR] La instalacion de Python fallo o no se encontro python.exe
echo [INFO] Revise permisos o intente nuevamente
pause
exit /b 1

:ERR_VENV
echo [ERROR] Error creando entorno virtual
echo [INFO] Verifique la instalacion de Python
pause
exit /b 1

:ERR_APP_DL
echo [ERROR] Error obteniendo la aplicacion (cinbehave_gui.py)
echo [INFO] Verifique su conexion a internet
pause
exit /b 1

:ERR_DEPS
echo [ERROR] Fallo instalando dependencias basicas
echo [INFO] Revise requirements.txt (sleap es excluido automaticamente)
pause
exit /b 1

:ERR_PY_RUN
echo [ERROR] Python del entorno virtual no responde correctamente
pause
exit /b 1

:ABORT_INSTALL
echo [INFO] Instalacion cancelada por el usuario
pause
exit /b 0

:END_OK
echo.
echo Gracias por instalar CinBehave.
echo Presiona cualquier tecla para salir...
pause >nul
endlocal
exit /b 0
