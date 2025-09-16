@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM ============================================================================
REM CinBehave - INSTALADOR MEJORADO CON PYTHON EN PATH
REM Version: 1.8 Enhanced (fix3 ultra-robust)
REM ============================================================================

echo.
echo ============================================================================
echo                    CinBehave SLEAP Analysis Suite
echo                 INSTALADOR MEJORADO v1.8 (fix3)
echo ============================================================================
echo [DEBUG] Ejecutando: %~f0
echo.

echo [INFO] Iniciando instalacion mejorada...
timeout /t 1 >nul

REM ==== PASO 1: ADMIN ====
echo [PASO 1] Verificando administrador...
net session >nul 2>&1
if errorlevel 1 goto ERR_ADMIN
echo [OK] Permisos de administrador verificados

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
    if /i not "%OVERWRITE%"=="s" goto ABORT_INSTALL
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
echo [PASO 4] Descargando e instalando Python 3.11.6...
echo [INFO] Descargando Python desde python.org (puede tomar varios minutos)...
powershell -NoProfile -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
  "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe' -OutFile 'python_installer.exe' -UseBasicParsing" 
if not exist "python_installer.exe" goto ERR_PY_DL

echo [INFO] Verificando servicio Windows Installer...
:CHECK_MSISERVER
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "(Get-Service -Name msiserver).Status"`) do set "MSI_STATUS=%%S"
if /i "%MSI_STATUS%"=="Running" goto MSI_OK

echo [ERROR] El servicio Windows Installer (msiserver) no esta activo. Estado: %MSI_STATUS%
echo [INFO] Para iniciarlo manualmente, ejecute: net start msiserver
set /p "RETRY=Reintentar verificacion tras iniciarlo? s/n: "
if /i "%RETRY%"=="s" goto CHECK_MSISERVER
goto ERR_MSI

:MSI_OK
echo [OK] Servicio Windows Installer activo

echo [INFO] Instalando Python 3.11.6 (esto puede tardar)...
echo [INFO] Python se instalara en: %INSTALL_DIR%\Python311
echo [INFO] Python se agregara al PATH del sistema
start /wait python_installer.exe /quiet ^
  TargetDir="%INSTALL_DIR%\Python311" ^
  InstallAllUsers=1 ^
  PrependPath=1 ^
  AssociateFiles=1 ^
  Shortcuts=1 ^
  Include_doc=0 ^
  Include_tcltk=1 ^
  Include_test=0 ^
  Include_launcher=1 ^
  InstallLauncherAllUsers=1

if errorlevel 1 goto ERR_PY_SETUP
if not exist "%INSTALL_DIR%\Python311\python.exe" goto ERR_PY_SETUP

del /q "python_installer.exe" >nul 2>&1
echo [OK] Python 3.11.6 instalado correctamente

REM ==== PASO 5: PATH ====
echo [PASO 5] Actualizando variables de entorno...
echo [INFO] Agregando Python al PATH del usuario (respaldo)...
setx PATH "%PATH%;%INSTALL_DIR%\Python311;%INSTALL_DIR%\Python311\Scripts" >nul 2>&1
echo [OK] PATH actualizado

REM ==== PASO 6: VENV ====
echo [PASO 6] Creando entorno virtual...
"%INSTALL_DIR%\Python311\python.exe" -m venv venv --upgrade-deps
if not exist "venv\Scripts\python.exe" goto ERR_VENV
echo [OK] Entorno virtual creado exitosamente

REM ==== PASO 7: APP ====
echo [PASO 7] Descargando aplicacion principal...
powershell -NoProfile -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
  "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py' -UseBasicParsing"
if not exist "cinbehave_gui.py" goto ERR_APP_DL
echo [OK] Aplicacion principal descargada

REM ==== PASO 8: DEPENDENCIAS ====
echo [PASO 8] Instalando dependencias...
call "venv\Scripts\activate.bat"
python -m pip install --upgrade pip
copy "%~dp0requirements.txt" "requirements.txt" >nul
python -m pip install -r requirements.txt
if errorlevel 1 goto ERR_DEPS
echo [OK] Dependencias instaladas

REM ==== PASO 9: SLEAP ====
echo [PASO 9] Verificando instalacion de SLEAP...
python -c "import sleap; print('[SUCCESS] SLEAP version:', sleap.__version__)" 1>nul 2>nul
if errorlevel 1 (
  echo [WARNING] SLEAP puede no haberse instalado correctamente
  echo [INFO] Se intentara instalar en el primer uso de la aplicacion
) else (
  echo [OK] SLEAP instalado correctamente
)

REM ==== PASO 10: LANZADORES ====
echo [PASO 10] Creando archivos de lanzamiento...
> "CinBehave.bat"  (
  echo @echo off
  echo REM Lanzador de CinBehave - Version 1.8
  echo title CinBehave - SLEAP Analysis Suite
  echo cd /d "%%~dp0"
  echo echo Iniciando CinBehave...
  echo call venv\Scripts\activate.bat
  echo python cinbehave_gui.py
  echo if errorlevel 1 ^
  echo ^( ^
  echo   echo. ^
  echo   echo [ERROR] Error ejecutando CinBehave ^
  echo   echo Presiona cualquier tecla para continuar... ^
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
  echo echo [TEST] Verificando dependencias...
  echo python -c "import requests, numpy, pandas, matplotlib; print('[OK] Dependencias basicas funcionan')"
  echo echo.
  echo echo [TEST] Verificando SLEAP...
  echo python -c "import sleap; print('[OK] SLEAP version:', sleap.__version__)"
  echo echo.
  echo echo [TEST] Verificando GPU...
  echo python -c "import tensorflow as tf; print('[INFO] GPUs detectadas:', len(tf.config.list_physical_devices('GPU')))"
  echo echo.
  echo echo ============================================
  echo echo Presiona cualquier tecla para continuar...
  echo pause ^>nul
)

> "Install_SLEAP.bat" (
  echo @echo off
  echo title Instalador de SLEAP para CinBehave
  echo cd /d "%%~dp0"
  echo echo Instalando dependencias...
  echo call venv\Scripts\activate.bat
  echo python -m pip install --upgrade pip
  echo copy "%%~dp0requirements.txt" requirements.txt ^>nul
  echo python -m pip install -r requirements.txt
  echo python -c "import sleap; print('SLEAP instalado:', sleap.__version__)"
  echo pause
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

REM ==== PASO 11: INFO DEL SISTEMA ====
echo [PASO 11] Creando archivo de informacion del sistema...
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

REM ==== PASO 12: VALIDACION ====
echo [PASO 12] Validacion final del sistema...
venv\Scripts\python.exe --version >nul 2>&1
if errorlevel 1 goto ERR_PY_RUN

venv\Scripts\python.exe -c "import requests, numpy, pandas" >nul 2>&1
if errorlevel 1 goto ERR_DEPS

venv\Scripts\python.exe -c "import sys; sys.path.append('.'); import cinbehave_gui" >nul 2>&1
if errorlevel 1 (
  echo [WARNING] La aplicacion puede tener problemas de importacion
  echo [INFO] Esto es normal si SLEAP no esta completamente instalado
)

echo [OK] Validacion del sistema completada

echo.
echo ============================================================================
echo                        INSTALACION COMPLETADA EXITOSAMENTE
echo ============================================================================
echo.
echo [SUCCESS] CinBehave ha sido instalado en: %INSTALL_DIR%
echo.
echo ARCHIVOS CREADOS:
echo    - CinBehave.bat (lanzador)
echo    - Test.bat (test del sistema)
echo    - Install_SLEAP.bat (instalar o reparar SLEAP)
echo    - Uninstall.bat (desinstalador)
echo    - system_info.txt (info del sistema)
echo.
echo PYTHON:
echo    - Version: 3.11.6
echo    - Ubicacion: %INSTALL_DIR%\Python311
echo    - PATH: agregado
echo    - Entorno virtual: configurado
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
:ERR_ADMIN
echo [ERROR] Ejecute como administrador
echo [INFO] Click derecho > Ejecutar como administrador
pause
exit /b 1

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
echo [INFO] Instalacion cancelada hasta que el servicio este activo.
pause
exit /b 1

:ERR_PY_SETUP
echo [ERROR] La instalacion de Python fallo o no se encontro python.exe
echo [INFO] Revise permisos de administrador o intente nuevamente
pause
exit /b 1

:ERR_VENV
echo [ERROR] Error creando entorno virtual
echo [INFO] Verifique la instalacion de Python
pause
exit /b 1

:ERR_APP_DL
echo [ERROR] Error descargando la aplicacion (cinbehave_gui.py)
echo [INFO] Verifique su conexion a internet
pause
exit /b 1

:ERR_DEPS
echo [ERROR] Fallo instalando dependencias basicas
echo [INFO] Revise requirements.txt y su conexion
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
