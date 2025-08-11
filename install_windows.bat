@echo off
REM ============================================================================
REM CinBehave - INSTALADOR CON DETECCIÓN DE PYTHON ARREGLADA
REM Version: 1.6 Python Detection Fixed
REM ============================================================================

setlocal enabledelayedexpansion
set "INSTALLER_VERSION=1.6.0-python-fixed"

echo.
echo ============================================================================
echo                    CinBehave SLEAP Analysis Suite                          
echo                   INSTALADOR ARREGLADO v%INSTALLER_VERSION%
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

REM DETECCIÓN DE PYTHON ARREGLADA
echo [PASO 2/8] Verificando Python...
set "PYTHON_FOUND=0"
set "NEED_PYTHON=1"

REM Método 1: Probar python
echo [INFO] Probando comando 'python'...
python --version >nul 2>&1
if %errorLevel% equ 0 (
    echo [INFO] Comando python funciona
    python --version
    set "PYTHON_FOUND=1"
    set "PYTHON_CMD=python"
) else (
    echo [INFO] Comando python no disponible
)

REM Método 2: Probar py (Python Launcher)
if "%PYTHON_FOUND%"=="0" (
    echo [INFO] Probando comando 'py'...
    py --version >nul 2>&1
    if !errorLevel! equ 0 (
        echo [INFO] Comando py funciona
        py --version
        set "PYTHON_FOUND=1"
        set "PYTHON_CMD=py"
    ) else (
        echo [INFO] Comando py no disponible
    )
)

REM Método 3: Buscar Python instalado
if "%PYTHON_FOUND%"=="0" (
    echo [INFO] Buscando Python instalado...
    if exist "C:\Python311\python.exe" (
        echo [INFO] Python 3.11 encontrado en C:\Python311\
        set "PYTHON_FOUND=1"
        set "PYTHON_CMD=C:\Python311\python.exe"
    )
    if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
        echo [INFO] Python 3.11 encontrado en Programs
        set "PYTHON_FOUND=1"
        set "PYTHON_CMD=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    )
)

REM Decidir si instalar Python
if "%PYTHON_FOUND%"=="1" (
    echo [OK] Python encontrado: %PYTHON_CMD%
    REM Verificar version muy simplemente
    echo [INFO] Verificando version de Python...
    %PYTHON_CMD% --version 2>nul | findstr "3.13" >nul
    if !errorLevel! equ 0 (
        echo [WARNING] Python 3.13 detectado - instalando Python 3.11.6 para compatibilidad
        set "NEED_PYTHON=1"
    ) else (
        echo [OK] Version de Python compatible
        set "NEED_PYTHON=0"
    )
) else (
    echo [INFO] Python no encontrado - se instalara Python 3.11.6
    set "NEED_PYTHON=1"
)

REM Instalar Python si es necesario
if "%NEED_PYTHON%"=="1" (
    echo [PASO 3/8] Instalando Python 3.11.6...
    echo [INFO] Descargando Python (esto puede tomar varios minutos)...
    
    powershell -Command "try { Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe' -OutFile 'temp\python_installer.exe' -UseBasicParsing; Write-Host '[OK] Python descargado' } catch { Write-Host '[ERROR] Error descargando Python'; exit 1 }"
    
    if exist temp\python_installer.exe (
        echo [INFO] Instalando Python 3.11.6 (esto puede tomar varios minutos)...
        start /wait temp\python_installer.exe /quiet TargetDir="%INSTALL_ROOT%\Python311" InstallAllUsers=0 PrependPath=0 AssociateFiles=0 CompileAll=0
        
        if exist "%INSTALL_ROOT%\Python311\python.exe" (
            echo [OK] Python 3.11.6 instalado exitosamente
            set "PYTHON_CMD=%INSTALL_ROOT%\Python311\python.exe"
        ) else (
            echo [ERROR] Error instalando Python - archivo no encontrado
            echo [DEBUG] Verificando directorio Python311:
            dir "%INSTALL_ROOT%\Python311\" 2>nul || echo [DEBUG] Directorio vacio
            pause
            exit /b 1
        )
    ) else (
        echo [ERROR] Error descargando Python - archivo no encontrado
        pause
        exit /b 1
    )
) else (
    echo [PASO 3/8] Usando Python existente...
    echo [OK] Python compatible: %PYTHON_CMD%
)

REM Verificar que Python funciona
echo [INFO] Verificando que Python funciona correctamente...
"%PYTHON_CMD%" --version
if %errorLevel% neq 0 (
    echo [ERROR] Python no responde correctamente
    pause
    exit /b 1
)
echo [OK] Python verificado y funcional

REM Crear entorno virtual
echo [PASO 4/8] Creando entorno virtual...
if exist venv rmdir /s /q venv >nul 2>&1
echo [INFO] Creando entorno virtual con: %PYTHON_CMD%
"%PYTHON_CMD%" -m venv venv
if not exist venv\Scripts\activate.bat (
    echo [ERROR] Error creando entorno virtual - activate.bat no encontrado
    echo [DEBUG] Verificando directorio venv:
    dir venv 2>nul || echo [DEBUG] Directorio venv no existe
    dir venv\Scripts 2>nul || echo [DEBUG] Directorio Scripts no existe
    pause
    exit /b 1
)
echo [OK] Entorno virtual creado exitosamente

REM Activar entorno
echo [INFO] Activando entorno virtual...
call venv\Scripts\activate.bat
if %errorLevel% neq 0 (
    echo [ERROR] Error activando entorno virtual
    pause
    exit /b 1
)
echo [OK] Entorno virtual activado

REM Verificar Python en entorno virtual
echo [INFO] Verificando Python en entorno virtual...
venv\Scripts\python.exe --version
if %errorLevel% neq 0 (
    echo [ERROR] Python no funciona en entorno virtual
    pause
    exit /b 1
)
echo [OK] Python en entorno virtual verificado

REM Actualizar pip
echo [PASO 5/8] Actualizando pip...
venv\Scripts\python.exe -m pip install --upgrade pip >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] pip actualizado exitosamente
) else (
    echo [WARNING] Error actualizando pip - continuando
)

REM Descargar aplicacion
echo [PASO 6/8] Descargando aplicacion CinBehave...
powershell -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py' -UseBasicParsing; Write-Host '[OK] Aplicacion descargada' } catch { Write-Host '[ERROR] Error descargando aplicacion'; exit 1 }"

if not exist cinbehave_gui.py (
    echo [ERROR] Error descargando aplicacion - archivo no encontrado
    pause
    exit /b 1
)

REM Verificar tamaño
for %%I in (cinbehave_gui.py) do set "APP_SIZE=%%~zI"
if %APP_SIZE% LSS 10000 (
    echo [ERROR] Aplicacion descargada muy pequeña (%APP_SIZE% bytes) - posiblemente corrupta
    echo [DEBUG] Contenido del archivo:
    type cinbehave_gui.py | more
    pause
    exit /b 1
)
echo [OK] Aplicacion descargada y verificada (%APP_SIZE% bytes)

REM Instalar dependencias
echo [PASO 7/8] Instalando dependencias...
echo [INFO] Instalando paquetes basicos (esto puede tomar varios minutos)...

set "PACKAGES=requests numpy pandas matplotlib Pillow opencv-python psutil"
set "INSTALLED_COUNT=0"

for %%p in (%PACKAGES%) do (
    echo [INSTALL] Instalando %%p...
    venv\Scripts\python.exe -m pip install "%%p" >nul 2>&1
    if !errorLevel! equ 0 (
        echo [OK] %%p instalado exitosamente
        set /a "INSTALLED_COUNT+=1"
    ) else (
        echo [ERROR] %%p fallo durante instalacion
    )
)

echo [INFO] Dependencias instaladas: %INSTALLED_COUNT%/7

if %INSTALLED_COUNT% LSS 5 (
    echo [ERROR] Muy pocas dependencias instaladas - instalacion no viable
    pause
    exit /b 1
)
echo [OK] Dependencias suficientes instaladas

REM Intentar instalar SLEAP
echo [INFO] Intentando instalar SLEAP (esto puede tomar 10-15 minutos)...
venv\Scripts\python.exe -m pip install sleap >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] SLEAP instalado exitosamente
) else (
    echo [WARNING] SLEAP no se pudo instalar - funcionara con funciones limitadas
)

REM Crear lanzadores
echo [PASO 8/8] Creando lanzadores...

REM Lanzador principal con verificaciones
(
echo @echo off
echo cd /d "%%~dp0"
echo echo Iniciando CinBehave...
echo if not exist venv\Scripts\activate.bat ^(
echo     echo ERROR: Entorno virtual no encontrado
echo     pause
echo     exit /b 1
echo ^)
echo call venv\Scripts\activate.bat
echo if not exist cinbehave_gui.py ^(
echo     echo ERROR: Aplicacion no encontrada
echo     pause
echo     exit /b 1
echo ^)
echo python cinbehave_gui.py
echo if %%errorLevel%% neq 0 ^(
echo     echo ERROR: CinBehave termino con error
echo ^)
echo pause
) > CinBehave.bat

REM Validador completo
(
echo @echo off
echo cd /d "%%~dp0"
echo echo ================================
echo echo   VALIDACION DE CINBEHAVE
echo echo ================================
echo call venv\Scripts\activate.bat
echo python -c "
echo import sys
echo print^('Python:', sys.version^)
echo print^(^)
echo modules = ['requests', 'numpy', 'pandas', 'matplotlib', 'PIL', 'cv2', 'psutil']
echo success = 0
echo for mod in modules:
echo     try:
echo         exec^(f'import {mod}'^)
echo         print^(f'[OK] {mod}'^)
echo         success += 1
echo     except:
echo         print^(f'[ERROR] {mod}'^)
echo print^(^)
echo try:
echo     import sleap
echo     print^(f'[OK] SLEAP {sleap.__version__}'^)
echo except:
echo     print^('[WARNING] SLEAP no disponible'^)
echo print^(^)
echo print^(f'Resultado: {success}/{len^(modules^)} modulos core OK'^)
echo "
echo echo ================================
echo pause
) > Validar_Instalacion.bat

echo [OK] Lanzadores creados

REM Validacion final
echo [VALIDACION] Probando instalacion...
venv\Scripts\python.exe -c "import requests, numpy; print('[OK] Dependencias criticas funcionan')" 2>nul
if %errorLevel% neq 0 (
    echo [ERROR] Dependencias no funcionan correctamente
    pause
    exit /b 1
)
echo [OK] Validacion final exitosa

REM Mostrar resultado final
echo.
echo ============================================================================
echo                        INSTALACION COMPLETADA EXITOSAMENTE
echo ============================================================================
echo.
echo [SUCCESS] CinBehave instalado correctamente en: %INSTALL_ROOT%
echo [INFO] Python: %PYTHON_CMD%
echo [INFO] Aplicacion: cinbehave_gui.py (%APP_SIZE% bytes)
echo [INFO] Dependencias: %INSTALLED_COUNT%/7 instaladas y verificadas
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
