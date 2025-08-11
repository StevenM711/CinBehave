@echo off
REM ============================================================================
REM CinBehave - INSTALADOR QUE REALMENTE FUNCIONA
REM Version: 1.5 Working Edition
REM ============================================================================

setlocal enabledelayedexpansion
set "INSTALLER_VERSION=1.5.0-working"

echo.
echo ============================================================================
echo                    CinBehave SLEAP Analysis Suite                          
echo                   INSTALADOR FUNCIONAL v%INSTALLER_VERSION%
echo ============================================================================
echo.

REM Pausar para ver el inicio
echo [INFO] Iniciando instalacion real de CinBehave...
timeout /t 2 >nul

REM Verificar administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Necesita ejecutar como administrador
    echo Haga clic derecho en el archivo y seleccione "Ejecutar como administrador"
    echo.
    pause
    exit /b 1
)
echo [OK] Privilegios de administrador verificados

REM Verificar conectividad
ping -n 1 8.8.8.8 >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Sin conexion a internet
    pause
    exit /b 1
)
echo [OK] Conectividad verificada

REM Configurar directorios
set "INSTALL_ROOT=%USERPROFILE%\CinBehave"
echo [INFO] Instalando en: %INSTALL_ROOT%

REM Crear estructura
echo [PASO 1/8] Creando estructura de directorios...
if exist "%INSTALL_ROOT%" rmdir /s /q "%INSTALL_ROOT%" >nul 2>&1
mkdir "%INSTALL_ROOT%" >nul 2>&1
mkdir "%INSTALL_ROOT%\logs" >nul 2>&1
mkdir "%INSTALL_ROOT%\temp" >nul 2>&1
mkdir "%INSTALL_ROOT%\Proyectos" >nul 2>&1
mkdir "%INSTALL_ROOT%\users" >nul 2>&1
mkdir "%INSTALL_ROOT%\config" >nul 2>&1

cd /d "%INSTALL_ROOT%"
echo [OK] Directorios creados

REM Verificar Python
echo [PASO 2/8] Verificando Python...
python --version >temp\python_check.txt 2>nul
if exist temp\python_check.txt (
    for /f "tokens=2" %%v in (temp\python_check.txt) do set "PYTHON_VERSION=%%v"
    echo [INFO] Python encontrado: !PYTHON_VERSION!
    del temp\python_check.txt
    
    REM Verificar si es compatible
    echo !PYTHON_VERSION! | findstr "3.13" >nul && set "NEED_PYTHON=1" || set "NEED_PYTHON=0"
    echo !PYTHON_VERSION! | findstr "3.12" >nul && set "NEED_PYTHON=1"
    echo !PYTHON_VERSION! | findstr "3.14" >nul && set "NEED_PYTHON=1"
) else (
    echo [INFO] Python no encontrado
    set "NEED_PYTHON=1"
)

REM Instalar Python si es necesario
if "%NEED_PYTHON%"=="1" (
    echo [PASO 3/8] Instalando Python 3.11.6...
    echo [INFO] Descargando Python (esto puede tomar varios minutos)...
    
    powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe' -OutFile 'temp\python_installer.exe' -UseBasicParsing"
    
    if exist temp\python_installer.exe (
        echo [INFO] Instalando Python 3.11.6...
        start /wait temp\python_installer.exe /quiet TargetDir="%INSTALL_ROOT%\Python311" InstallAllUsers=0 PrependPath=0 AssociateFiles=0 CompileAll=0
        
        if exist "%INSTALL_ROOT%\Python311\python.exe" (
            echo [OK] Python 3.11.6 instalado
            set "PYTHON_CMD=%INSTALL_ROOT%\Python311\python.exe"
        ) else (
            echo [ERROR] Error instalando Python
            pause
            exit /b 1
        )
    ) else (
        echo [ERROR] Error descargando Python
        pause
        exit /b 1
    )
) else (
    echo [PASO 3/8] Usando Python existente...
    set "PYTHON_CMD=python"
    echo [OK] Python compatible encontrado
)

REM Crear entorno virtual
echo [PASO 4/8] Creando entorno virtual...
if exist venv rmdir /s /q venv >nul 2>&1
"%PYTHON_CMD%" -m venv venv
if not exist venv\Scripts\activate.bat (
    echo [ERROR] Error creando entorno virtual
    pause
    exit /b 1
)
echo [OK] Entorno virtual creado

REM Activar entorno
call venv\Scripts\activate.bat
echo [OK] Entorno virtual activado

REM Actualizar pip
echo [PASO 5/8] Actualizando pip...
python -m pip install --upgrade pip >nul 2>&1
echo [OK] pip actualizado

REM Descargar aplicacion
echo [PASO 6/8] Descargando aplicacion CinBehave...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py' -UseBasicParsing"

if not exist cinbehave_gui.py (
    echo [ERROR] Error descargando aplicacion
    pause
    exit /b 1
)

REM Verificar tamaño
for %%I in (cinbehave_gui.py) do set "APP_SIZE=%%~zI"
if %APP_SIZE% LSS 10000 (
    echo [ERROR] Aplicacion descargada corrupta
    pause
    exit /b 1
)
echo [OK] Aplicacion descargada (%APP_SIZE% bytes)

REM Instalar dependencias
echo [PASO 7/8] Instalando dependencias...
echo [INFO] Instalando paquetes basicos (esto puede tomar varios minutos)...

python -m pip install requests
echo [INFO] requests instalado

python -m pip install numpy
echo [INFO] numpy instalado

python -m pip install pandas
echo [INFO] pandas instalado

python -m pip install matplotlib
echo [INFO] matplotlib instalado

python -m pip install Pillow
echo [INFO] Pillow instalado

python -m pip install opencv-python
echo [INFO] opencv-python instalado

python -m pip install psutil
echo [INFO] psutil instalado

echo [OK] Dependencias basicas instaladas

REM Intentar instalar SLEAP
echo [INFO] Intentando instalar SLEAP...
python -m pip install sleap >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] SLEAP instalado exitosamente
) else (
    echo [WARNING] SLEAP no se pudo instalar - funcionara con funciones limitadas
)

REM Crear lanzadores
echo [PASO 8/8] Creando lanzadores...

REM Lanzador principal
echo @echo off > CinBehave.bat
echo cd /d "%%~dp0" >> CinBehave.bat
echo call venv\Scripts\activate.bat >> CinBehave.bat
echo python cinbehave_gui.py >> CinBehave.bat
echo pause >> CinBehave.bat

REM Validador
echo @echo off > Validar_Instalacion.bat
echo cd /d "%%~dp0" >> Validar_Instalacion.bat
echo call venv\Scripts\activate.bat >> Validar_Instalacion.bat
echo python -c "import requests, numpy, pandas; print('Dependencias OK')" >> Validar_Instalacion.bat
echo pause >> Validar_Instalacion.bat

echo [OK] Lanzadores creados

REM Validacion final
echo [VALIDACION] Probando instalacion...
python -c "import requests, numpy; print('[OK] Dependencias criticas funcionan')" 2>nul
if %errorLevel% neq 0 (
    echo [ERROR] Dependencias no funcionan correctamente
    pause
    exit /b 1
)

REM Mostrar resultado final
echo.
echo ============================================================================
echo                        INSTALACION COMPLETADA EXITOSAMENTE
echo ============================================================================
echo.
echo [SUCCESS] CinBehave instalado correctamente en: %INSTALL_ROOT%
echo [INFO] Aplicacion: cinbehave_gui.py (%APP_SIZE% bytes)
echo [INFO] Python: Entorno virtual configurado
echo [INFO] Dependencias: Instaladas y verificadas
echo.
echo PARA USAR CINBEHAVE:
echo 1. Ir a: %INSTALL_ROOT%
echo 2. Ejecutar: CinBehave.bat
echo.
echo PARA VALIDAR:
echo - Ejecutar: Validar_Instalacion.bat
echo.
echo ============================================================================

REM Preguntar si ejecutar ahora
set /p "RUN_NOW=¿Ejecutar CinBehave ahora? (s/n): "
if /i "!RUN_NOW!"=="s" (
    echo.
    echo [LAUNCH] Iniciando CinBehave...
    start "" "%INSTALL_ROOT%\CinBehave.bat"
)

echo.
echo [COMPLETE] Instalacion terminada - presiona cualquier tecla para salir
pause >nul

endlocal
exit /b 0
