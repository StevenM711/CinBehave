@echo off
setlocal EnableDelayedExpansion
REM ============================================================================
REM CinBehave - INSTALADOR MEJORADO CON PYTHON EN PATH
REM Version: 1.8 Enhanced - Python PATH Integration
REM ============================================================================

echo.
echo ============================================================================
echo                    CinBehave SLEAP Analysis Suite
echo                      INSTALADOR MEJORADO v1.8
echo ============================================================================
echo.

echo [INFO] Iniciando instalacion mejorada...
timeout /t 3 >nul

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
set INSTALL_DIR=%USERPROFILE%\CinBehave
echo [INFO] Directorio de instalacion: %INSTALL_DIR%

if exist "%INSTALL_DIR%" (
    echo [WARNING] Instalacion previa detectada
    set /p "OVERWRITE=Sobrescribir instalacion anterior? (s/n): "
    if /i not "!OVERWRITE!"=="s" (
        echo [INFO] Instalacion cancelada
        pause
        exit /b 0
    )
    echo [INFO] Eliminando instalacion anterior...
    rmdir /s /q "%INSTALL_DIR%"
)

mkdir "%INSTALL_DIR%"
mkdir "%INSTALL_DIR%\logs"
mkdir "%INSTALL_DIR%\temp"
mkdir "%INSTALL_DIR%\Proyectos"
mkdir "%INSTALL_DIR%\users"
mkdir "%INSTALL_DIR%\config"
mkdir "%INSTALL_DIR%\assets"
mkdir "%INSTALL_DIR%\docs"
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
for /f "tokens=4" %%s in ('sc query msiserver ^| find "STATE"') do set "MSI_STATUS=%%s"
if /i "!MSI_STATUS!"=="RUNNING" (
    echo [OK] Servicio Windows Installer activo
) else (
    echo [ERROR] El servicio Windows Installer (msiserver) no esta activo.
    echo [INFO] Para iniciarlo manualmente, ejecute: net start msiserver
    set /p "RETRY=¿Reintentar verificacion tras iniciarlo? (s/n): "
    if /i "!RETRY!"=="s" goto check_msiserver
    echo [INFO] Instalacion cancelada hasta que el servicio este activo.
    pause
    exit /b 1
)

echo [INFO] Instalando Python 3.11.6 (esto puede tomar unos minutos)...
echo [INFO] Python se instalara en: %INSTALL_DIR%\Python311
echo [INFO] Python se agregara al PATH del sistema

REM Instalacion de Python con opciones mejoradas:
REM PrependPath=1 - Agregar Python al PATH del sistema
REM AssociateFiles=1 - Asociar archivos .py con Python
REM Shortcuts=1 - Crear accesos directos
REM Include_doc=0 - No incluir documentacion (ahorra espacio)
REM Include_tcltk=1 - Incluir tkinter (necesario para GUI)
REM Include_test=0 - No incluir tests (ahorra espacio)
REM Include_launcher=1 - Incluir Python Launcher
REM InstallLauncherAllUsers=0 - Launcher solo para usuario actual

start /wait python_installer.exe /quiet /log "%INSTALL_DIR%\logs\python_install.log" ^
    TargetDir="%INSTALL_DIR%\Python311" ^
    InstallAllUsers=0 ^
    PrependPath=1 ^
    AssociateFiles=1 ^
    Shortcuts=1 ^
    Include_doc=0 ^
    Include_tcltk=1 ^
    Include_test=0 ^
    Include_launcher=1 ^
    InstallLauncherAllUsers=0
if errorlevel 1 (
    echo [ERROR] La instalacion de Python fallo. Revise el log: %INSTALL_DIR%\logs\python_install.log
)

if not exist "%INSTALL_DIR%\Python311\python.exe" (
    echo [ERROR] Error en la instalacion de Python
    echo [INFO] Verifique que tiene permisos de administrador
    pause
    exit /b 1
)

REM Limpiar instalador
del python_installer.exe >nul 2>&1

echo [OK] Python 3.11.6 instalado correctamente

echo [PASO 5] Actualizando variables de entorno...
echo [INFO] Agregando Python al PATH del usuario...
REM Agregar Python al PATH del usuario actual (respaldo por si la instalacion no lo hizo)
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

echo [PASO 8] Instalando dependencias basicas...
echo [INFO] Activando entorno virtual...
call venv\Scripts\activate.bat

echo [INFO] Actualizando pip a la ultima version...
python -m pip install --upgrade pip

echo [INFO] Instalando dependencias principales (puede tomar varios minutos)...
python -m pip install requests
python -m pip install numpy
python -m pip install pandas
python -m pip install matplotlib
python -m pip install Pillow
python -m pip install opencv-python
python -m pip install psutil
python -m pip install seaborn

echo [OK] Dependencias basicas instaladas

echo [PASO 9] Instalando TensorFlow y SLEAP...
echo [INFO] Instalando TensorFlow (requerido por SLEAP)...
python -m pip install tensorflow

echo [INFO] Instalando SLEAP (puede tomar varios minutos)...
python -m pip install sleap

echo [INFO] Verificando instalacion de SLEAP...
python -c "import sleap; print('[SUCCESS] SLEAP version:', sleap.__version__)" 2>nul
if errorlevel 1 (
    echo [WARNING] SLEAP puede no haberse instalado correctamente
    echo [INFO] Se intentara instalar en el primer uso de la aplicacion
) else (
    echo [OK] SLEAP instalado correctamente
)

echo [PASO 10] Creando archivos de lanzamiento...
echo [INFO] Creando lanzadores optimizados...

REM Crear lanzador principal mejorado
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

REM Crear script de test mejorado
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

REM Crear instalador de SLEAP independiente
echo @echo off > Install_SLEAP.bat
echo title Instalador de SLEAP para CinBehave >> Install_SLEAP.bat
echo cd /d "%%~dp0" >> Install_SLEAP.bat
echo echo Instalando SLEAP... >> Install_SLEAP.bat
echo call venv\Scripts\activate.bat >> Install_SLEAP.bat
echo python -m pip install --upgrade pip >> Install_SLEAP.bat
echo python -m pip install tensorflow >> Install_SLEAP.bat
echo python -m pip install sleap >> Install_SLEAP.bat
echo python -c "import sleap; print('SLEAP instalado:', sleap.__version__)" >> Install_SLEAP.bat
echo pause >> Install_SLEAP.bat

REM Crear desinstalador
echo @echo off > Uninstall.bat
echo title Desinstalador de CinBehave >> Uninstall.bat
echo echo. >> Uninstall.bat
echo echo ============================================ >> Uninstall.bat
echo echo    Desinstalador de CinBehave >> Uninstall.bat
echo echo ============================================ >> Uninstall.bat
echo echo. >> Uninstall.bat
echo set /p CONFIRM=Desinstalar CinBehave? (s/n): >> Uninstall.bat
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

REM Crear archivo de info del sistema
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

REM Test de Python
venv\Scripts\python.exe --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python no funciona correctamente
    pause
    exit /b 1
)

REM Test de dependencias basicas
venv\Scripts\python.exe -c "import requests, numpy, pandas" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Dependencias basicas fallan
    pause
    exit /b 1
)

REM Test de importacion de la aplicacion
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
echo 📁 ARCHIVOS CREADOS:
echo    • CinBehave.bat - Lanzador principal
echo    • Test.bat - Verificar instalacion
echo    • Install_SLEAP.bat - Instalar/reparar SLEAP
echo    • Uninstall.bat - Desinstalar CinBehave
echo    • system_info.txt - Informacion del sistema
echo.
echo 🐍 PYTHON:
echo    • Version: 3.11.6
echo    • Ubicacion: %INSTALL_DIR%\Python311
echo    • PATH: Agregado al sistema
echo    • Entorno virtual: Configurado
echo.
echo 🚀 PARA USAR CINBEHAVE:
echo    1. Ir a: %INSTALL_DIR%
echo    2. Ejecutar: CinBehave.bat
echo.
echo 🧪 PARA PROBAR LA INSTALACION:
echo    • Ejecutar: Test.bat
echo.
echo 🔧 PARA PROBLEMAS CON SLEAP:
echo    • Ejecutar: Install_SLEAP.bat
echo.
echo ============================================================================
echo.

REM Preguntar si ejecutar ahora
set /p "RUN_NOW=¿Ejecutar CinBehave ahora? (s/n): "
if /i "%RUN_NOW%"=="s" (
    echo.
    echo [INFO] Iniciando CinBehave...
    start "" "%INSTALL_DIR%\CinBehave.bat"
    timeout /t 3 >nul
)

echo.
echo ¡Gracias por instalar CinBehave!
echo Presiona cualquier tecla para salir...
pause >nul
endlocal
exit /b 0
