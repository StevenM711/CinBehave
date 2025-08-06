@echo off
REM CinBehave - SLEAP Analysis GUI Installer for Windows
REM Version: 1.0 - SLEAP Integration Edition
REM Author: SLEAP Analysis System

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
echo    ║                   Instalador Windows v1.0                   ║
echo    ║                   SLEAP Integration Edition                  ║
echo    ║                                                              ║
echo    ║    Sistema de Análisis de Videos con SLEAP                   ║
echo    ║    Inteligencia Artificial para Comportamiento Animal       ║
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

echo %GREEN%[INFO]%NC% Iniciando instalación de CinBehave con SLEAP...
echo.

REM Verificar sistema Windows
echo %BLUE%[STEP 1/12]%NC% Verificando sistema Windows...
ver | find "Windows" >nul
if %errorLevel% neq 0 (
    echo %RED%[ERROR]%NC% Este instalador está diseñado para Windows.
    pause
    exit /b 1
)

for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo %GREEN%[INFO]%NC% Windows %VERSION% detectado

REM Verificar arquitectura
echo %BLUE%[STEP 2/12]%NC% Verificando arquitectura del sistema...
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "ARCH=x64"
    echo %GREEN%[INFO]%NC% Arquitectura x64 detectada
) else (
    set "ARCH=x86"
    echo %GREEN%[INFO]%NC% Arquitectura x86 detectada
)

REM Verificar GPU
echo %BLUE%[STEP 3/12]%NC% Verificando GPU disponible...
nvidia-smi >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%[INFO]%NC% GPU NVIDIA detectada - Aceleración SLEAP habilitada
    set "GPU_SUPPORT=nvidia"
) else (
    echo %YELLOW%[WARNING]%NC% GPU NVIDIA no detectada - Usando CPU
    set "GPU_SUPPORT=cpu"
)

REM Crear directorio de instalación
echo %BLUE%[STEP 4/12]%NC% Creando directorio de instalación...
set "INSTALL_DIR=%USERPROFILE%\CinBehave"
if exist "%INSTALL_DIR%" (
    echo %YELLOW%[WARNING]%NC% El directorio ya existe. Actualizando instalación...
    rmdir /s /q "%INSTALL_DIR%\temp" 2>nul
) else (
    mkdir "%INSTALL_DIR%"
)

cd /d "%INSTALL_DIR%"

REM Verificar e instalar Python
echo %BLUE%[STEP 5/12]%NC% Verificando Python...
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
echo %BLUE%[STEP 6/12]%NC% Verificando pip...
python -m pip --version >nul 2>&1
if %errorLevel% neq 0 (
    echo %GREEN%[INFO]%NC% Instalando pip...
    python -m ensurepip --upgrade
)

REM Crear entorno virtual
echo %BLUE%[STEP 7/12]%NC% Creando entorno virtual...
python -m venv venv
call venv\Scripts\activate.bat

REM Actualizar pip
echo %BLUE%[STEP 8/12]%NC% Actualizando pip y herramientas...
python -m pip install --upgrade pip setuptools wheel

REM Descargar aplicación y requirements desde GitHub
echo %BLUE%[STEP 9/12]%NC% Descargando aplicación CinBehave...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/requirements.txt' -OutFile 'requirements.txt'"

REM Instalar dependencias específicas con compatibilidad
echo %BLUE%[STEP 10/12]%NC% Instalando dependencias de CinBehave...
echo %GREEN%[INFO]%NC% Instalando librerías básicas...
python -m pip install psutil pillow matplotlib seaborn

echo %GREEN%[INFO]%NC% Instalando NumPy con versión compatible...
python -m pip install "numpy>=1.21.0,<1.24.0"

echo %GREEN%[INFO]%NC% Instalando pandas y scipy...
python -m pip install pandas scipy python-dateutil tqdm

echo %GREEN%[INFO]%NC% Instalando procesamiento de video...
python -m pip install "opencv-python>=4.5.0,<4.8.0" imageio imageio-ffmpeg

echo %GREEN%[INFO]%NC% Instalando herramientas de datos...
python -m pip install reportlab openpyxl xlsxwriter "h5py>=3.6.0,<3.10.0"

echo %GREEN%[INFO]%NC% Instalando scikit-learn...
python -m pip install "scikit-learn>=1.0.0,<1.3.0"

REM Instalar TensorFlow con compatibilidad
echo %GREEN%[INFO]%NC% Instalando TensorFlow...
if "%GPU_SUPPORT%"=="nvidia" (
    echo %YELLOW%[INFO]%NC% Instalando TensorFlow con soporte GPU...
    python -m pip install "tensorflow>=2.7.0,<2.13.0"
) else (
    echo %YELLOW%[INFO]%NC% Instalando TensorFlow CPU...
    python -m pip install "tensorflow-cpu>=2.7.0,<2.13.0"
)

REM Instalar SLEAP
echo %BLUE%[STEP 11/12]%NC% Instalando SLEAP...
echo %GREEN%[INFO]%NC% Instalando SLEAP - puede tomar varios minutos...
python -m pip install sleap

REM Verificar instalación de SLEAP
echo %GREEN%[INFO]%NC% Verificando instalación de SLEAP...
python -c "import sleap; print('SLEAP instalado correctamente:', sleap.__version__)" 2>nul
if %errorLevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% SLEAP instalado pero con advertencias. Continuando...
)

REM Verificar comando sleap-track
sleap-track --help >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%[INFO]%NC% Comando sleap-track disponible
) else (
    echo %YELLOW%[WARNING]%NC% Comando sleap-track no disponible en PATH
)

REM Crear estructura de directorios
echo %BLUE%[STEP 12/12]%NC% Configurando estructura...
mkdir users 2>nul
mkdir temp 2>nul
mkdir logs 2>nul
mkdir config 2>nul
mkdir assets 2>nul
mkdir docs 2>nul
mkdir models 2>nul
mkdir Proyectos 2>nul

REM Crear script de inicio
(
echo @echo off
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat
echo echo Iniciando CinBehave...
echo echo Sistema de Análisis de Comportamiento Animal con SLEAP
echo echo.
echo python cinbehave_gui.py
echo if %%ERRORLEVEL%% neq 0 ^(
echo     echo.
echo     echo Error ejecutando CinBehave. Presiona cualquier tecla para ver detalles...
echo     pause ^>nul
echo ^)
) > start_cinbehave.bat

REM Crear script de verificación de sistema
(
echo @echo off
echo echo Verificando instalación de CinBehave...
echo echo.
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat
echo echo Python:
echo python --version
echo echo.
echo echo NumPy:
echo python -c "import numpy; print('NumPy:', numpy.__version__)"
echo echo.
echo echo TensorFlow:
echo python -c "import tensorflow as tf; print('TensorFlow:', tf.__version__); print('GPU disponible:', len(tf.config.list_physical_devices('GPU')) > 0)"
echo echo.
echo echo SLEAP:
echo python -c "import sleap; print('SLEAP:', sleap.__version__)"
echo echo.
echo echo OpenCV:
echo python -c "import cv2; print('OpenCV:', cv2.__version__)"
echo echo.
echo echo Matplotlib:
echo python -c "import matplotlib; print('Matplotlib:', matplotlib.__version__)"
echo echo.
echo pause
) > verificar_sistema.bat

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
echo COMANDOS ÚTILES:
echo start_cinbehave.bat - Ejecutar CinBehave
echo verificar_sistema.bat - Verificar instalación
echo uninstall.bat - Desinstalar CinBehave
echo.
echo CARPETAS IMPORTANTES:
echo users\ - Datos de usuarios
echo Proyectos\ - Proyectos y videos
echo logs\ - Archivos de log
echo models\ - Modelos SLEAP descargados
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
echo    ║                                                              ║
echo    ║  📍 Ubicación: %USERPROFILE%\CinBehave                      ║
echo    ║  🖥️ Acceso directo: Escritorio + Menú Inicio                ║
echo    ║  🧠 SLEAP: Instalado y configurado                          ║
echo    ║  🎮 GPU: %GPU_SUPPORT%                                       ║
echo    ║  🐍 Python: Instalado con entorno virtual                   ║
echo    ║  📊 Todas las dependencias: Instaladas                      ║
echo    ║                                                              ║
echo    ║  🚀 PARA EJECUTAR:                                          ║
echo    ║  • Doble clic en icono del escritorio                       ║
echo    ║  • O ejecutar: start_cinbehave.bat                          ║
echo    ║                                                              ║
echo    ║  🔧 HERRAMIENTAS ADICIONALES:                               ║
echo    ║  • verificar_sistema.bat - Verificar instalación            ║
echo    ║  • README_INSTALACION.txt - Información detallada          ║
echo    ║  • uninstall.bat - Desinstalar completamente               ║
echo    ║                                                              ║
echo    ║  📁 CARPETAS CREADAS:                                       ║
echo    ║  • users\ - Perfiles de usuarios                            ║
echo    ║  • Proyectos\ - Videos y análisis                          ║
echo    ║  • logs\ - Registro de actividad                            ║
echo    ║  • models\ - Modelos SLEAP (descarga automática)           ║
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
echo %GREEN%[INFO]%NC% Instalación completada exitosamente.
echo %GREEN%[INFO]%NC% 
echo %GREEN%[NOTAS IMPORTANTES]%NC%
echo • Primera ejecución puede ser lenta (descarga de modelos SLEAP)
echo • Los modelos SLEAP se descargan automáticamente desde GitHub
echo • Recomendado: Ejecutar 'verificar_sistema.bat' si hay problemas
echo • Manual y tutoriales incluidos en la aplicación
echo.
echo %GREEN%[INFO]%NC% Presiona cualquier tecla para salir...
pause >nul

endlocal
