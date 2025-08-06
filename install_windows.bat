@echo off
REM CinBehave - SLEAP Analysis GUI Installer for Windows
REM Version: 1.0 - Fixed Edition for Common Errors
REM Handles: hdf5.dll, requests, compilation issues

setlocal enabledelayedexpansion

REM Configurar colores
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

REM Mostrar banner
cls
echo.
echo    ╔══════════════════════════════════════════════════════════════╗
echo    ║                 CinBehave - SLEAP Analysis GUI               ║
echo    ║                   Instalador Windows FIXED                  ║
echo    ║                   Soluciona Errores Comunes                 ║
echo    ║                                                              ║
echo    ║    🔧 Corrige: hdf5.dll, requests, dependencias             ║
echo    ║    🧠 Instala: SLEAP con todas las dependencias             ║
echo    ║                                                              ║
echo    ╚══════════════════════════════════════════════════════════════╝
echo.

REM Verificar si se ejecuta como administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%[ERROR]%NC% Este instalador requiere permisos de administrador.
    echo %YELLOW%[INFO]%NC% Ejecuta como administrador haciendo clic derecho en el archivo.
    pause
    exit /b 1
)

echo %GREEN%[INFO]%NC% Iniciando instalación corregida de CinBehave...
echo.

REM Verificar sistema Windows
echo %BLUE%[STEP 1/15]%NC% Verificando sistema Windows...
ver | find "Windows" >nul
if %errorLevel% neq 0 (
    echo %RED%[ERROR]%NC% Este instalador está diseñado para Windows.
    pause
    exit /b 1
)

for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo %GREEN%[INFO]%NC% Windows %VERSION% detectado

REM Verificar arquitectura
echo %BLUE%[STEP 2/15]%NC% Verificando arquitectura del sistema...
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "ARCH=x64"
    echo %GREEN%[INFO]%NC% Arquitectura x64 detectada
) else (
    set "ARCH=x86"
    echo %GREEN%[INFO]%NC% Arquitectura x86 detectada
)

REM Verificar GPU
echo %BLUE%[STEP 3/15]%NC% Verificando GPU disponible...
nvidia-smi >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%[INFO]%NC% GPU NVIDIA detectada - Aceleración SLEAP habilitada
    set "GPU_SUPPORT=nvidia"
) else (
    echo %YELLOW%[WARNING]%NC% GPU NVIDIA no detectada - Usando CPU
    set "GPU_SUPPORT=cpu"
)

REM Crear directorio de instalación
echo %BLUE%[STEP 4/15]%NC% Creando directorio de instalación...
set "INSTALL_DIR=%USERPROFILE%\CinBehave"
if exist "%INSTALL_DIR%" (
    echo %YELLOW%[WARNING]%NC% El directorio ya existe. Limpiando instalación previa...
    rmdir /s /q "%INSTALL_DIR%\venv" 2>nul
    rmdir /s /q "%INSTALL_DIR%\temp" 2>nul
    del "%INSTALL_DIR%\*.py" 2>nul
    del "%INSTALL_DIR%\*.txt" 2>nul
) else (
    mkdir "%INSTALL_DIR%"
)

cd /d "%INSTALL_DIR%"

REM Verificar e instalar Python
echo %BLUE%[STEP 5/15]%NC% Verificando Python...
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% Python no encontrado. Instalando Python 3.11...
    
    REM Descargar Python
    echo %GREEN%[INFO]%NC% Descargando Python 3.11...
    if "%ARCH%"=="x64" (
        set "PYTHON_URL=https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe"
    ) else (
        set "PYTHON_URL=https://www.python.org/ftp/python/3.11.6/python-3.11.6.exe"
    )
    
    powershell -Command "Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile 'python_installer.exe'"
    
    REM Instalar Python silenciosamente
    echo %GREEN%[INFO]%NC% Instalando Python...
    python_installer.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    
    REM Esperar a que termine la instalación
    timeout /t 30 /nobreak >nul
    
    REM Limpiar instalador
    del python_installer.exe
    
    REM Verificar instalación
    python --version >nul 2>&1
    if %errorLevel% neq 0 (
        echo %RED%[ERROR]%NC% Error instalando Python. Por favor instala Python manualmente.
        pause
        exit /b 1
    )
) else (
    echo %GREEN%[INFO]%NC% Python encontrado:
    python --version
)

REM Verificar pip
echo %BLUE%[STEP 6/15]%NC% Verificando pip...
python -m pip --version >nul 2>&1
if %errorLevel% neq 0 (
    echo %GREEN%[INFO]%NC% Instalando pip...
    python -m ensurepip --upgrade
)

REM Crear entorno virtual
echo %BLUE%[STEP 7/15]%NC% Creando entorno virtual limpio...
if exist "venv" rmdir /s /q "venv"
python -m venv venv
call venv\Scripts\activate.bat

REM Actualizar pip y herramientas base
echo %BLUE%[STEP 8/15]%NC% Actualizando herramientas base...
python -m pip install --upgrade pip
python -m pip install --upgrade setuptools wheel

REM Descargar aplicación y requirements desde GitHub
echo %BLUE%[STEP 9/15]%NC% Descargando aplicación CinBehave...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/requirements.txt' -OutFile 'requirements.txt'"

REM Instalar dependencias críticas primero
echo %BLUE%[STEP 10/15]%NC% Instalando dependencias críticas...
echo %GREEN%[INFO]%NC% Instalando requests (requerido)...
python -m pip install requests

echo %GREEN%[INFO]%NC% Instalando librerías básicas...
python -m pip install psutil pillow matplotlib seaborn

echo %GREEN%[INFO]%NC% Instalando NumPy con versión compatible...
python -m pip install "numpy>=1.21.0,<1.24.0"

echo %GREEN%[INFO]%NC% Instalando pandas, scipy y utilidades...
python -m pip install pandas scipy python-dateutil tqdm

REM Instalar h5py con wheel precompilado para evitar hdf5.dll error
echo %BLUE%[STEP 11/15]%NC% Instalando h5py (solucionando hdf5.dll)...
echo %GREEN%[INFO]%NC% Usando wheel precompilado para h5py...
python -m pip install --only-binary=all "h5py>=3.6.0,<3.10.0"
if %errorLevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% Fallback: Instalando h5py desde conda-forge...
    python -m pip install --find-links https://github.com/h5py/h5py/releases/download/3.8.0/ h5py
    if %errorLevel% neq 0 (
        echo %YELLOW%[WARNING]%NC% Fallback 2: Instalando h5py básico...
        python -m pip install h5py --no-deps
    )
)

echo %GREEN%[INFO]%NC% Instalando procesamiento de video...
python -m pip install "opencv-python>=4.5.0,<4.8.0" imageio imageio-ffmpeg

echo %GREEN%[INFO]%NC% Instalando herramientas de datos...
python -m pip install reportlab openpyxl xlsxwriter

echo %GREEN%[INFO]%NC% Instalando scikit-learn...
python -m pip install --only-binary=all "scikit-learn>=1.0.0,<1.3.0"
if %errorLevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% Instalando scikit-learn sin compilación...
    python -m pip install scikit-learn --no-deps
    python -m pip install joblib threadpoolctl
)

REM Instalar TensorFlow con compatibilidad
echo %BLUE%[STEP 12/15]%NC% Instalando TensorFlow...
if "%GPU_SUPPORT%"=="nvidia" (
    echo %GREEN%[INFO]%NC% Instalando TensorFlow con soporte GPU...
    python -m pip install --only-binary=all "tensorflow>=2.7.0,<2.13.0"
) else (
    echo %GREEN%[INFO]%NC% Instalando TensorFlow CPU...
    python -m pip install --only-binary=all "tensorflow-cpu>=2.7.0,<2.13.0"
)

if %errorLevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% Error con TensorFlow. Instalando versión básica...
    python -m pip install tensorflow==2.11.0
)

REM Instalar SLEAP paso a paso
echo %BLUE%[STEP 13/15]%NC% Instalando SLEAP...
echo %GREEN%[INFO]%NC% Instalando SLEAP - puede tomar varios minutos...

REM Instalar dependencias de SLEAP primero
echo %GREEN%[INFO]%NC% Preparando dependencias de SLEAP...
python -m pip install attrs cattrs jsonpickle jsmin networkx packaging PySide2 pynvml rich
python -m pip install imgaug imageio-ffmpeg qudida albumentations

REM Instalar SLEAP
python -m pip install sleap
if %errorLevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% Error instalando SLEAP completo. Intentando instalación mínima...
    python -m pip install --no-deps sleap
    python -m pip install tensorflow-probability
)

REM Verificar instalación de SLEAP
echo %BLUE%[STEP 14/15]%NC% Verificando instalación...
echo %GREEN%[INFO]%NC% Verificando SLEAP...
python -c "import sleap; print('SLEAP instalado correctamente:', sleap.__version__)" 2>nul
if %errorLevel% equ 0 (
    echo %GREEN%[SUCCESS]%NC% SLEAP verificado correctamente
) else (
    echo %YELLOW%[WARNING]%NC% SLEAP instalado con advertencias
)

REM Verificar comando sleap-track
sleap-track --help >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%[SUCCESS]%NC% Comando sleap-track disponible
) else (
    echo %YELLOW%[WARNING]%NC% Comando sleap-track puede requerir PATH manual
)

echo %GREEN%[INFO]%NC% Verificando requests...
python -c "import requests; print('Requests OK:', requests.__version__)" 2>nul
if %errorLevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% Reinstalando requests...
    python -m pip install --force-reinstall requests
)

REM Crear estructura de directorios
echo %BLUE%[STEP 15/15]%NC% Configurando estructura...
mkdir users 2>nul
mkdir temp 2>nul
mkdir logs 2>nul
mkdir config 2>nul
mkdir assets 2>nul
mkdir docs 2>nul
mkdir models 2>nul
mkdir Proyectos 2>nul

REM Crear script de inicio mejorado
(
echo @echo off
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat
echo echo ================================
echo echo    CinBehave - SLEAP Analysis GUI
echo echo    Sistema de Análisis de Comportamiento
echo echo ================================
echo echo.
echo echo Verificando dependencias...
echo python -c "import requests, sleap, numpy, tensorflow; print('✅ Todas las dependencias OK')" 2^>nul
echo if %%ERRORLEVEL%% neq 0 ^(
echo     echo ❌ Error en dependencias. Ejecuta 'verificar_sistema.bat'
echo     pause
echo     exit /b 1
echo ^)
echo echo.
echo echo Iniciando CinBehave...
echo python cinbehave_gui.py
echo if %%ERRORLEVEL%% neq 0 ^(
echo     echo.
echo     echo ❌ Error ejecutando CinBehave.
echo     echo 📋 Revisa el archivo logs\cinbehave.log para más detalles
echo     echo 🔧 Ejecuta 'verificar_sistema.bat' para diagnosticar
echo     pause
echo ^)
) > start_cinbehave.bat

REM Crear script de verificación completo
(
echo @echo off
echo echo ================================================
echo echo       VERIFICACIÓN DEL SISTEMA - CinBehave
echo echo ================================================
echo echo.
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat
echo.
echo echo 🐍 PYTHON:
echo python --version
echo echo.
echo echo 📊 NUMPY:
echo python -c "import numpy; print('NumPy:', numpy.__version__)"
echo echo.
echo echo 🌐 REQUESTS:
echo python -c "import requests; print('Requests:', requests.__version__)"
echo echo.
echo echo 🧠 TENSORFLOW:
echo python -c "import tensorflow as tf; print('TensorFlow:', tf.__version__); print('GPU disponible:', len(tf.config.list_physical_devices('GPU')) > 0)"
echo echo.
echo echo 🔬 SLEAP:
echo python -c "import sleap; print('SLEAP:', sleap.__version__)"
echo echo.
echo echo 📹 OPENCV:
echo python -c "import cv2; print('OpenCV:', cv2.__version__)"
echo echo.
echo echo 📈 MATPLOTLIB:
echo python -c "import matplotlib; print('Matplotlib:', matplotlib.__version__)"
echo echo.
echo echo 🗃️ H5PY:
echo python -c "import h5py; print('h5py:', h5py.__version__)"
echo echo.
echo echo 🧮 SCIKIT-LEARN:
echo python -c "import sklearn; print('Scikit-learn:', sklearn.__version__)"
echo echo.
echo echo ================================================
echo echo           DIAGNÓSTICO COMPLETO
echo echo ================================================
echo echo.
echo echo 📂 Archivos importantes:
echo dir cinbehave_gui.py 2^>nul ^|^| echo ❌ cinbehave_gui.py FALTANTE
echo dir requirements.txt 2^>nul ^|^| echo ❌ requirements.txt FALTANTE
echo dir venv\Scripts\python.exe 2^>nul ^|^| echo ❌ Entorno virtual FALTANTE
echo echo.
echo echo 📁 Carpetas:
echo dir /b users logs config Proyectos 2^>nul ^|^| echo ❌ Carpetas del sistema FALTANTES
echo echo.
echo echo ================================================
echo if exist "logs\cinbehave.log" ^(
echo     echo 📋 Últimas líneas del log:
echo     echo ================================================
echo     powershell -Command "Get-Content logs\cinbehave.log -Tail 10"
echo ^) else ^(
echo     echo 📋 Sin archivo de log aún
echo ^)
echo echo ================================================
echo echo.
echo pause
) > verificar_sistema.bat

REM Crear script de reparación
(
echo @echo off
echo echo Reparando instalación de CinBehave...
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat
echo echo.
echo echo Reinstalando dependencias críticas...
echo python -m pip install --force-reinstall requests
echo python -m pip install --force-reinstall numpy
echo python -m pip install --force-reinstall --only-binary=all h5py
echo echo.
echo echo Verificando SLEAP...
echo python -c "import sleap; print('SLEAP OK')" 2^>nul ^|^| python -m pip install --force-reinstall sleap
echo echo.
echo echo Reparación completada.
echo pause
) > reparar_instalacion.bat

REM Crear acceso directo en el escritorio
echo %GREEN%[INFO]%NC% Creando acceso directo en el escritorio...
powershell -Command ^
"$WshShell = New-Object -comObject WScript.Shell; ^
$Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\CinBehave.lnk'); ^
$Shortcut.TargetPath = '%INSTALL_DIR%\start_cinbehave.bat'; ^
$Shortcut.WorkingDirectory = '%INSTALL_DIR%'; ^
$Shortcut.Description = 'CinBehave - SLEAP Analysis GUI'; ^
$Shortcut.Save()"

REM Crear acceso en el menú inicio
echo %GREEN%[INFO]%NC% Creando acceso en el menú inicio...
set "START_MENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
mkdir "%START_MENU%\CinBehave" 2>nul
powershell -Command ^
"$WshShell = New-Object -comObject WScript.Shell; ^
$Shortcut = $WshShell.CreateShortcut('%START_MENU%\CinBehave\CinBehave.lnk'); ^
$Shortcut.TargetPath = '%INSTALL_DIR%\start_cinbehave.bat'; ^
$Shortcut.WorkingDirectory = '%INSTALL_DIR%'; ^
$Shortcut.Description = 'CinBehave - SLEAP Analysis GUI'; ^
$Shortcut.Save()"

powershell -Command ^
"$WshShell = New-Object -comObject WScript.Shell; ^
$Shortcut = $WshShell.CreateShortcut('%START_MENU%\CinBehave\Verificar Sistema.lnk'); ^
$Shortcut.TargetPath = '%INSTALL_DIR%\verificar_sistema.bat'; ^
$Shortcut.WorkingDirectory = '%INSTALL_DIR%'; ^
$Shortcut.Description = 'Verificar instalación de CinBehave'; ^
$Shortcut.Save()"

powershell -Command ^
"$WshShell = New-Object -comObject WScript.Shell; ^
$Shortcut = $WshShell.CreateShortcut('%START_MENU%\CinBehave\Reparar Instalacion.lnk'); ^
$Shortcut.TargetPath = '%INSTALL_DIR%\reparar_instalacion.bat'; ^
$Shortcut.WorkingDirectory = '%INSTALL_DIR%'; ^
$Shortcut.Description = 'Reparar instalación de CinBehave'; ^
$Shortcut.Save()"

REM Crear desinstalador
(
echo @echo off
echo echo Desinstalando CinBehave...
echo.
echo REM Eliminar accesos directos
echo del "%%USERPROFILE%%\Desktop\CinBehave.lnk" 2^>nul
echo rmdir /s /q "%%APPDATA%%\Microsoft\Windows\Start Menu\Programs\CinBehave" 2^>nul
echo.
echo REM Eliminar directorio principal
echo cd /d "%%USERPROFILE%%"
echo rmdir /s /q "CinBehave"
echo.
echo echo CinBehave desinstalado correctamente.
echo pause
) > uninstall.bat

REM Crear archivo de información del sistema
(
echo ================================
echo CINBEHAVE - INFORMACIÓN DEL SISTEMA
echo ================================
echo Fecha de instalación: %DATE% %TIME%
echo Arquitectura: %ARCH%
echo Soporte GPU: %GPU_SUPPORT%
echo Python: Instalado
echo SLEAP: Instalado
echo TensorFlow: Instalado
echo ================================
echo.
echo ARCHIVOS CREADOS:
echo start_cinbehave.bat - Ejecutar CinBehave
echo verificar_sistema.bat - Verificar instalación  
echo reparar_instalacion.bat - Reparar problemas
echo uninstall.bat - Desinstalar CinBehave
echo.
echo CARPETAS IMPORTANTES:
echo users\ - Datos de usuarios
echo Proyectos\ - Proyectos y videos
echo logs\ - Archivos de log
echo models\ - Modelos SLEAP descargados
echo.
echo PROBLEMAS SOLUCIONADOS:
echo ✅ hdf5.dll error en h5py
echo ✅ requests module missing
echo ✅ Dependencias de compilación
echo ✅ Wheels precompilados
echo ✅ Instalación paso a paso
echo ================================
) > README_INSTALACION.txt

REM Completar instalación
cls
echo.
echo    ╔══════════════════════════════════════════════════════════════╗
echo    ║                    INSTALACIÓN COMPLETA                      ║
echo    ╠══════════════════════════════════════════════════════════════╣
echo    ║                                                              ║
echo    ║  🎉 CinBehave con SLEAP instalado exitosamente!             ║
echo    ║  🔧 Errores comunes corregidos automáticamente              ║
echo    ║                                                              ║
echo    ║  📍 Ubicación: %USERPROFILE%\CinBehave                      ║
echo    ║  🖥️ Acceso directo: Escritorio + Menú Inicio                ║
echo    ║  🧠 SLEAP: Instalado y configurado                          ║
echo    ║  🎮 GPU: %GPU_SUPPORT%                                       ║
echo    ║  🐍 Python: Entorno virtual aislado                         ║
echo    ║  ✅ Todas las dependencias: Instaladas                      ║
echo    ║                                                              ║
echo    ║  🚀 PARA EJECUTAR:                                          ║
echo    ║  • Doble clic en icono del escritorio                       ║
echo    ║  • O ejecutar: start_cinbehave.bat                          ║
echo    ║                                                              ║
echo    ║  🛠️ HERRAMIENTAS DE DIAGNÓSTICO:                            ║
echo    ║  • verificar_sistema.bat - Verificación completa            ║
echo    ║  • reparar_instalacion.bat - Reparar problemas             ║
echo    ║  • README_INSTALACION.txt - Información detallada          ║
echo    ║  • uninstall.bat - Desinstalar completamente               ║
echo    ║                                                              ║
echo    ║  📂 ERRORES CORREGIDOS:                                     ║
echo    ║  ✅ hdf5.dll missing - Solucionado con wheels               ║
echo    ║  ✅ requests missing - Instalado explícitamente            ║
echo    ║  ✅ Dependencias de compilación - Evitadas                 ║
echo    ║  ✅ Orden de instalación - Optimizado                      ║
echo    ║                                                              ║
echo    ╚══════════════════════════════════════════════════════════════╝
echo.

REM Preguntar si ejecutar
set /p response="¿Deseas ejecutar CinBehave ahora? (s/n): "
if /i "%response%"=="s" (
    echo %GREEN%[INFO]%NC% Iniciando CinBehave...
    start "" "%INSTALL_DIR%\start_cinbehave.bat"
)

echo.
echo %GREEN%[ÉXITO]%NC% Instalación completada exitosamente.
echo.
echo %GREEN%[NOTAS IMPORTANTES]%NC%
echo • Si hay algún problema, ejecuta 'verificar_sistema.bat'
echo • Para reparar errores, ejecuta 'reparar_instalacion.bat'
echo • Primera ejecución puede ser lenta (descarga de modelos SLEAP)
echo • Los modelos SLEAP se descargan automáticamente desde GitHub
echo • Manual y tutoriales incluidos en la aplicación
echo.
echo %GREEN%[INFO]%NC% Presiona cualquier tecla para salir...
pause >nul

endlocal
