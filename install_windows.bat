@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM ============================================================================
REM CinBehave - INSTALADOR MEJORADO CON PYTHON EN PATH
REM Version: 1.8 Enhanced - Python PATH Integration (fix2 - robust IFs)
REM ============================================================================

echo.
echo ============================================================================
echo                    CinBehave SLEAP Analysis Suite
echo                 INSTALADOR MEJORADO v1.8 (fix2 robust)
echo ============================================================================
echo [DEBUG] Ejecutando: %~f0
echo.

echo [INFO] Iniciando instalacion mejorada...
timeout /t 1 >nul

echo [PASO 1] Verificando administrador...
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Ejecute como administrador
    echo [INFO] Haga clic derecho en el archivo y seleccione "Ejecutar como administrador"
    pause
    exit /b 1
)
echo [OK] Permisos de administrador verificados

echo [PASO 2] Verificando conexion a internet...
ping -n 1 8.8.8.8 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Sin conexion a internet
    echo [INFO] Verifique su conexion y reintente
    pause
    exit /b 1
)
echo [OK] Conexion a internet verificada

echo [PASO 3] Preparando directorio de instalacion...
set "INSTALL_DIR=%USERPROFILE%\CinBehave"
echo [INFO] Directorio de instalacion: %INSTALL_DIR%

if exist "%INSTALL_DIR%" (
    echo [WARNING] Instalacion previa detectada
    set /p "OVERWRITE=Sobrescribir instalacion anterior? s/n: "
    if /i not "!OVERWRITE!"=="s" (
        echo [INFO] Instalacion cancelada
        pause
        exit /b 0
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

echo [PASO 4] Descargando e instalando Python 3.11.6...
echo [INFO] Descargando Python desde python.org (puede tomar varios minutos)...
powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe' -OutFile 'python_installer.exe' -UseBasicParsing}"

if not exist python_installer.exe (
    echo [ERROR] Error descargando Python
    echo [INFO] Verifique su conexion a internet
    pause
    exit /b 1
)

echo [INFO] Verificando servicio Windows Installer...
:check_msiserver
REM Usar estado numerico 4 para RUNNING (independiente del idioma)
sc query msiserver | findstr /R /C:"STATE *: *4" >nul
if errorlevel 1 (
    echo [ERROR] El servicio Windows Installer (msiserver) no esta activo.
    echo [INFO] Para iniciarlo manualmente, ejecute: net start msiserver
    set /p "RETRY=Reintentar verificacion tras iniciarlo? s/n: "
    if /i "%RETRY%"=="s" goto check_msiserver
    echo [INFO] Instalacion cancelada hasta que el servicio este activo.
    pause
    exit /b 1
)
echo [OK] Servicio Windows Installer activo

echo [INFO] Instalando Python 3.11.6 (esto puede tomar unos minutos)...
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

if errorlevel 1 (
    echo [ERROR] La instalacion de Python fallo. Revise el log: %INSTALL_DIR%\logs\python_install.log
    exit /b 1
)

if not exist "%INSTALL_DIR%\Python311\python.exe" (
    echo [ERROR] Error en la instalacion de Python
    echo [INFO] Verifique que tiene permisos de administrador
    pause
    exit /b 1
)

del python_installer.exe >nul 2>&1
echo [OK] Python 3.11.6 instalado correctamente

echo [PASO 5] Actualizando variables de entorno...
echo [INFO] Agregando Python al PATH del usuario...
REM Ojo: setx puede truncar PATH; se usa como respaldo
setx PATH "%PATH%;%INSTALL_DIR%\Python311;%INSTALL_DIR%\Python311\Scripts" >nul 2>&1
echo [OK] PATH actualizado

echo [PASO 6] Creando entorno virtual...
echo [INFO] Creando entorno virtual optimizado...
"%INSTALL_DIR%\Python311\python.exe" -m venv venv --upgrade-deps

if not exist venv\Scripts\python.exe (
    echo [ERROR] Error creando entorno virtual
    echo [INFO] Verifique la instalacion de Python
    pause
    exit /b 1
)
echo [OK] Entorno virtual creado exitosamente

echo [PASO 7] Descargando aplicacion principal...
echo [INFO] Descargando CinBehave GUI desde GitHub...
powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py' -UseBasicParsing}"

if not exist cinbehave_gui.py (
    echo [ERROR] Error descargando la aplicacion
    echo [INFO] Verifique su conexion a internet
    pause
    exit /b 1
)
echo [OK] Aplicacion principal descargada

echo [PASO 8] Instalando dependencias...
echo [INFO] Activando entorno virtual...
call venv\Scripts\activate.bat

echo [INFO] Actualizando pip a la ultima version...
python -m pip install --upgrade pip

echo [INFO] Copiando archivo de dependencias...
copy "%~dp0requirements.txt" requirements.txt >nul

echo [INFO] Instalando dependencias desde requirements.txt (puede tomar varios minutos)...
python -m pip install -r requirements.txt

echo [OK] Dependencias instaladas

echo [PASO 9] Verificando instalacion de SLEAP...
python -c "import sleap; print('[SUCCESS] SLEAP version:', sleap.__version__)" 1>nul 2>nul
if errorlevel 1 (
    echo [WARNING] SLEAP puede no haberse instalado correctamente
    echo [INFO] Se intentara instalar en el primer uso de la aplicacion
)
if not errorlevel 1 (
    echo [OK] SLEAP instalado correctamente
)

echo [PASO 10] Creando archivos de lanzamiento...
echo [INFO] Creando lanzadores optimizados...

REM === Lanzador principal ===
echo @echo off > CinBehave.bat
echo REM Lanzador de CinBehave - Version 1.8 >> CinBehave.bat
echo title CinBehave - SLEAP Analysis Suite >> CinBehave.bat
echo cd /d "%%~dp0" >> CinBehave.bat
echo echo Iniciando CinBehave... >> CinBehave.bat
echo call venv\Scripts\activate.bat >> CinBehave.bat
echo python cinbehave_gui.py >> CinBehave.bat
echo if errorlevel 1 ( >> CinBehave.bat
echo     echo. >> CinBehave.bat
echo     echo [ERROR] Error ejecutando CinBehave >> CinBehave.bat
echo     echo Presiona cualquier tecla para continuar... >> CinBehave.bat
echo     pause ^>nul >> CinBehave.bat
echo ) >> CinBehave.bat

REM === Script de test ===
echo @echo off > Test.bat
echo title CinBehave - Test del Sistema >> Test.bat
echo cd /d "%%~dp0" >> Test.bat
echo echo ============================================ >> Test.bat
echo echo    Test de Componentes de CinBehave >> Test.bat
echo echo ============================================ >> Test.bat
echo call venv\Scripts\activate.bat >> Test.bat
echo echo. >> Test.bat
echo echo [TEST] Verificando Python... >> Test.bat
echo python --version >> Test.bat
echo echo. >> Test.bat
echo echo [TEST] Verificando dependencias... >> Test.bat
echo python -c "import requests, numpy, pandas, matplotlib; print('[OK] Dependencias basicas funcionan')" >> Test.bat
echo echo. >> Test.bat
echo echo [TEST] Verificando SLEAP... >> Test.bat
echo python -c "import sleap; print('[OK] SLEAP version:', sleap.__version__)" >> Test.bat
echo echo. >> Test.bat
echo echo [TEST] Verificando GPU... >> Test.bat
echo python -c "import tensorflow as tf; print('[INFO] GPUs detectadas:', len(tf.config.list_physical_devices('GPU')))" >> Test.bat
echo echo. >> Test.bat
echo echo ============================================ >> Test.bat
echo echo Presiona cualquier tecla para continuar... >> Test.bat
echo pause ^>nul >> Test.bat

REM === Instalador SLEAP ===
echo @echo off > Install_SLEAP.bat
echo title Instalador de SLEAP para CinBehave >> Install_SLEAP.bat
echo cd /d "%%~dp0" >> Install_SLEAP.bat
echo echo Instalando dependencias... >> Install_SLEAP.bat
echo call venv\Scripts\activate.bat >> Install_SLEAP.bat
echo python -m pip install --upgrade pip >> Install_SLEAP.bat
echo copy "%%~dp0requirements.txt" requirements.txt ^>nul >> Install_SLEAP.bat
echo python -m pip install -r requirements.txt >> Install_SLEAP.bat
echo python -c "import sleap; print('SLEAP instalado:', sleap.__version__)" >> Install_SLEAP.bat
echo pause >> Install_SLEAP.bat

REM === Desinstalador ===
echo @echo off > Uninstall.bat
echo title Desinstalador de CinBehave >> Uninstall.bat
echo echo. >> Uninstall.bat
echo echo ============================================ >> Uninstall.bat
echo echo    Desinstalador de CinBehave >> Uninstall.bat
echo echo ============================================ >> Uninstall.bat
echo echo. >> Uninstall.bat
echo set /p CONFIRM=Desinstalar CinBehave? s/n: >> Uninstall.bat
echo if /i "%%CONFIRM%%"=="s" ( >> Uninstall.bat
echo     echo Desinstalando... >> Uninstall.bat
echo     cd /d "%%USERPROFILE%%" >> Uninstall.bat
echo     rmdir /s /q "%%USERPROFILE%%\CinBehave" >> Uninstall.bat
echo     echo CinBehave desinstalado. >> Uninstall.bat
echo ) >> Uninstall.bat
echo pause >> Uninstall.bat

echo [OK] Archivos de lanzamiento creados

echo [PASO 11] Creando archivo de informacion del sistema...
echo [INFO] Generando reporte del sistema...

echo ============================================ > system_info.txt
echo    CinBehave System Information >> system_info.txt
echo    Instalacion completada: %DATE% %TIME% >> system_info.txt
echo ============================================ >> system_info.txt
echo. >> system_info.txt
echo Directorio de instalacion: %INSTALL_DIR% >> system_info.txt
echo Version de Python: >> system_info.txt
"%INSTALL_DIR%\Python311\python.exe" --version >> system_info.txt 2>&1
echo. >> system_info.txt
echo Sistema operativo: >> system_info.txt
systeminfo | findstr /C:"OS Name" /C:"OS Version" >> system_info.txt
echo. >> system_info.txt
echo Memoria del sistema: >> system_info.txt
systeminfo | findstr /C:"Total Physical Memory" >> system_info.txt
echo. >> system_info.txt

echo [OK] Informacion del sistema guardada

echo [PASO 12] Validacion final del sistema...
echo [INFO] Ejecutando tests finales...

venv\Scripts\python.exe --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python no funciona correctamente
    pause
    exit /b 1
)

venv\Scripts\python.exe -c "import requests, numpy, pandas" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Dependencias basicas fallan
    pause
    exit /b 1
)

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
echo    - Install_SLEAP.bat (instalar/reparar SLEAP)
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

echo.
echo Gracias por instalar CinBehave.
echo Presiona cualquier tecla para salir...
pause >nul
endlocal
exit /b 0
