@echo off
REM CinBehave - SLEAP Analysis GUI Installer for Windows
REM Version: 1.0 - Fixed
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
echo    ║                       Instalador Windows                     ║
echo    ║                                                              ║
echo    ║    Sistema de Análisis de Videos con SLEAP                   ║
echo    ║    Versión: 1.0                                              ║
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

echo %GREEN%[INFO]%NC% Iniciando instalación de CinBehave...
echo.

REM Verificar sistema Windows
echo %BLUE%[STEP 1/10]%NC% Verificando sistema Windows...
ver | find "Windows" >nul
if %errorLevel% neq 0 (
    echo %RED%[ERROR]%NC% Este instalador está diseñado para Windows.
    pause
    exit /b 1
)

for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo %GREEN%[INFO]%NC% Windows %VERSION% detectado

REM Verificar arquitectura
echo %BLUE%[STEP 2/10]%NC% Verificando arquitectura del sistema...
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "ARCH=x64"
    echo %GREEN%[INFO]%NC% Arquitectura x64 detectada
) else (
    set "ARCH=x86"
    echo %GREEN%[INFO]%NC% Arquitectura x86 detectada
)

REM Crear directorio de instalación
echo %BLUE%[STEP 3/10]%NC% Creando directorio de instalación...
set "INSTALL_DIR=%USERPROFILE%\CinBehave"
if exist "%INSTALL_DIR%" (
    echo %YELLOW%[WARNING]%NC% El directorio ya existe. Actualizando instalación...
    rmdir /s /q "%INSTALL_DIR%\temp" 2>nul
) else (
    mkdir "%INSTALL_DIR%"
)

cd /d "%INSTALL_DIR%"

REM Verificar e instalar Python
echo %BLUE%[STEP 4/10]%NC% Verificando Python...
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
echo %BLUE%[STEP 5/10]%NC% Verificando pip...
python -m pip --version >nul 2>&1
if %errorLevel% neq 0 (
    echo %GREEN%[INFO]%NC% Instalando pip...
    python -m ensurepip --upgrade
)

REM Crear entorno virtual
echo %BLUE%[STEP 6/10]%NC% Creando entorno virtual...
python -m venv venv
call venv\Scripts\activate.bat

REM Actualizar pip
echo %BLUE%[STEP 7/10]%NC% Actualizando pip...
python -m pip install --upgrade pip setuptools wheel

REM Instalar dependencias esenciales
echo %BLUE%[STEP 8/10]%NC% Instalando dependencias...
python -m pip install psutil

REM Descargar aplicación desde GitHub
echo %BLUE%[STEP 9/10]%NC% Descargando aplicación CinBehave...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/requirements.txt' -OutFile 'requirements.txt'"

REM Instalar dependencias específicas
echo %GREEN%[INFO]%NC% Instalando dependencias de requirements.txt...
python -m pip install -r requirements.txt

REM Crear estructura de directorios
mkdir users 2>nul
mkdir temp 2>nul
mkdir logs 2>nul
mkdir config 2>nul
mkdir assets 2>nul
mkdir docs 2>nul

REM Crear script de inicio
(
echo @echo off
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat
echo python cinbehave_gui.py
echo pause
) > start_cinbehave.bat

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

echo %BLUE%[STEP 10/10]%NC% Finalizando instalación...

REM Completar instalación
cls
echo.
echo    ╔══════════════════════════════════════════════════════════════╗
echo    ║                    INSTALACIÓN COMPLETA                      ║
echo    ╠══════════════════════════════════════════════════════════════╣
echo    ║                                                              ║
echo    ║  ✅ CinBehave instalado en: %USERPROFILE%\CinBehave         ║
echo    ║  ✅ Acceso directo creado en escritorio                      ║
echo    ║  ✅ Acceso creado en menú inicio                             ║
echo    ║  ✅ Python y dependencias instaladas                        ║
echo    ║  ✅ Entorno virtual configurado                              ║
echo    ║  ✅ Aplicación lista para usar                               ║
echo    ║                                                              ║
echo    ║  Para ejecutar:                                              ║
echo    ║  • Doble clic en el icono del escritorio                    ║
echo    ║  • O ejecutar: start_cinbehave.bat                          ║
echo    ║                                                              ║
echo    ║  Documentación: docs\                                       ║
echo    ║  Logs: logs\cinbehave.log                                   ║
echo    ║  Desinstalar: uninstall.bat                                 ║
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
echo %GREEN%[INFO]%NC% Presiona cualquier tecla para salir...
pause >nul

endlocal
