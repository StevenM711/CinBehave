@echo off
REM ============================================================================
REM CinBehave - SLEAP Analysis GUI DEBUG Installer for Windows
REM Version: 1.1 Debug Edition
REM 
REM INSTALADOR CON DEBUG MEJORADO - NO SE CIERRA AUTOMATICAMENTE
REM ============================================================================

setlocal enabledelayedexpansion
set "INSTALLER_VERSION=1.1.0-debug"
set "INSTALL_DATE=%DATE% %TIME%"

echo.
echo ============================================================================
echo                    CinBehave SLEAP Analysis Suite                          
echo                         DEBUG INSTALLER v%INSTALLER_VERSION%
echo ============================================================================
echo.
echo [DEBUG] Iniciando instalador con debugging completo...
echo [DEBUG] Fecha y hora: %INSTALL_DATE%
echo [DEBUG] Directorio actual: %CD%
echo [DEBUG] Variables de entorno verificadas
echo.
pause

REM ============================================================================
REM VERIFICACION DE ADMINISTRADOR
REM ============================================================================
echo [STEP 1/10] Verificando privilegios de administrador...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Se requieren privilegios de administrador
    echo [SOLUCION] Ejecute este archivo como administrador:
    echo 1. Clic derecho en el archivo .bat
    echo 2. Seleccionar "Ejecutar como administrador"
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)
echo [OK] Privilegios de administrador verificados
echo.
pause

REM ============================================================================
REM DETECCION DEL SISTEMA
REM ============================================================================
echo [STEP 2/10] Detectando configuracion del sistema...

REM Detectar arquitectura
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "SYSTEM_ARCH=x64"
    echo [OK] Arquitectura detectada: x64 (64-bit)
) else (
    set "SYSTEM_ARCH=x86"
    echo [WARNING] Arquitectura detectada: x86 (32-bit) - Rendimiento limitado
)

REM Detectar version de Windows
for /f "tokens=4-5 delims=. " %%i in ('ver') do set "WIN_VERSION=%%i.%%j"
echo [OK] Windows Version: %WIN_VERSION%

REM Verificar memoria
for /f "skip=1" %%i in ('wmic computersystem get TotalPhysicalMemory /value') do (
    if not "%%i"=="" (
        set "%%i"
        set /a "MEMORY_GB=!TotalPhysicalMemory! / 1024 / 1024 / 1024"
    )
)
if !MEMORY_GB! LSS 8 (
    echo [WARNING] RAM: !MEMORY_GB!GB - Se recomienda minimo 8GB para SLEAP
) else (
    echo [OK] RAM: !MEMORY_GB!GB - Adecuada para machine learning
)

REM Verificar conectividad
echo [DEBUG] Verificando conectividad a internet...
ping -n 1 8.8.8.8 >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Conectividad a internet verificada
) else (
    echo [ERROR] Sin conexion a internet - La instalacion no puede continuar
    echo [SOLUCION] Verifique su conexion a internet e intente nuevamente
    echo.
    pause
    exit /b 1
)

echo.
echo [DEBUG] Configuracion del sistema completada
pause

REM ============================================================================
REM CONFIGURACION DE DIRECTORIOS
REM ============================================================================
echo [STEP 3/10] Configurando estructura de directorios...

set "INSTALL_ROOT=%USERPROFILE%\CinBehave"
echo [DEBUG] Directorio de instalacion: %INSTALL_ROOT%

REM Crear directorio de logs
if not exist "%INSTALL_ROOT%\logs" mkdir "%INSTALL_ROOT%\logs" >nul 2>&1

set "LOG_FILE=%INSTALL_ROOT%\logs\installation_debug_%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log"
echo [DEBUG] Archivo de log: %LOG_FILE%

REM Inicializar log
echo ============================================================================ > "%LOG_FILE%"
echo CinBehave DEBUG Installation Log >> "%LOG_FILE%"
echo Started: %INSTALL_DATE% >> "%LOG_FILE%"
echo System: %SYSTEM_ARCH% Windows %WIN_VERSION% RAM: !MEMORY_GB!GB >> "%LOG_FILE%"
echo ============================================================================ >> "%LOG_FILE%"

if exist "%INSTALL_ROOT%" (
    echo [WARNING] Instalacion existente detectada
    echo [DEBUG] Respaldando instalacion anterior...
    if exist "%INSTALL_ROOT%\backup" rmdir /s /q "%INSTALL_ROOT%\backup" >nul 2>&1
    mkdir "%INSTALL_ROOT%\backup" >nul 2>&1
    if exist "%INSTALL_ROOT%\users" (
        echo [DEBUG] Respaldando datos de usuario...
        xcopy "%INSTALL_ROOT%\users" "%INSTALL_ROOT%\backup\users" /E /H /I >nul 2>&1
        echo [OK] Datos de usuario respaldados
    )
)

mkdir "%INSTALL_ROOT%" >nul 2>&1
mkdir "%INSTALL_ROOT%\temp" >nul 2>&1
cd /d "%INSTALL_ROOT%"

echo [OK] Estructura de directorios configurada
echo [DEBUG] Directorio actual: %CD%
echo.
pause

REM ============================================================================
REM DETECCION DE PYTHON
REM ============================================================================
echo [STEP 4/10] Detectando instalacion de Python...

python --version >temp\python_current.txt 2>nul
if exist temp\python_current.txt (
    for /f "tokens=2" %%v in (temp\python_current.txt) do set "CURRENT_PYTHON=%%v"
    echo [OK] Python detectado: !CURRENT_PYTHON!
    echo Python detectado: !CURRENT_PYTHON! >> "%LOG_FILE%"
    del temp\python_current.txt
    
    REM Verificar compatibilidad
    echo !CURRENT_PYTHON! | findstr "3.13" >nul && set "PYTHON_INCOMPATIBLE=1"
    echo !CURRENT_PYTHON! | findstr "3.12" >nul && set "PYTHON_INCOMPATIBLE=1"
    echo !CURRENT_PYTHON! | findstr "3.14" >nul && set "PYTHON_INCOMPATIBLE=1"
    
    if defined PYTHON_INCOMPATIBLE (
        echo [WARNING] Version de Python incompatible: !CURRENT_PYTHON!
        echo [INFO] Se instalara Python 3.11.6 aislado para CinBehave
        set "NEED_PYTHON_INSTALL=1"
    ) else (
        echo [OK] Version de Python compatible
        set "PYTHON_EXE=python"
        set "NEED_PYTHON_INSTALL=0"
    )
) else (
    echo [WARNING] Python no detectado
    echo [INFO] Se instalara Python 3.11.6 para CinBehave
    set "NEED_PYTHON_INSTALL=1"
)

echo.
echo [DEBUG] Estado de Python determinado
pause

REM ============================================================================
REM INSTALACION DE PYTHON (SI ES NECESARIO)
REM ============================================================================
if "%NEED_PYTHON_INSTALL%"=="1" (
    echo [STEP 5/10] Instalando Python 3.11.6 aislado...
    
    if "%SYSTEM_ARCH%"=="x64" (
        set "PYTHON_INSTALLER=https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe"
    ) else (
        set "PYTHON_INSTALLER=https://www.python.org/ftp/python/3.11.6/python-3.11.6.exe"
    )
    
    echo [DEBUG] Descargando Python desde: !PYTHON_INSTALLER!
    echo [INFO] Esto puede tomar varios minutos...
    
    powershell -Command "try { Write-Host '[DOWNLOAD] Descargando Python 3.11.6...'; Invoke-WebRequest -Uri '!PYTHON_INSTALLER!' -OutFile 'temp\python_installer.exe' -UseBasicParsing } catch { Write-Host '[ERROR] Descarga fallida'; exit 1 }"
    
    if exist temp\python_installer.exe (
        echo [OK] Python installer descargado
        echo [INSTALL] Instalando Python 3.11.6...
        echo [INFO] Esta operacion puede tomar 5-10 minutos
        
        start /wait temp\python_installer.exe /quiet TargetDir="%INSTALL_ROOT%\Python311" InstallAllUsers=0 PrependPath=0 AssociateFiles=0 CompileAll=0 Include_test=0
        
        if exist "%INSTALL_ROOT%\Python311\python.exe" (
            echo [OK] Python 3.11.6 instalado exitosamente
            set "PYTHON_EXE=%INSTALL_ROOT%\Python311\python.exe"
            echo Python aislado instalado: %PYTHON_EXE% >> "%LOG_FILE%"
        ) else (
            echo [ERROR] Instalacion de Python fallida
            echo [DEBUG] Verificando archivos en %INSTALL_ROOT%\Python311\
            dir "%INSTALL_ROOT%\Python311\" 2>nul || echo [DEBUG] Directorio Python311 no existe
            echo.
            echo [ERROR] La instalacion no puede continuar sin Python
            echo Presiona cualquier tecla para salir...
            pause >nul
            exit /b 1
        )
    ) else (
        echo [ERROR] No se pudo descargar el instalador de Python
        echo [DEBUG] Verificando conectividad...
        ping -n 1 8.8.8.8 >nul && echo [DEBUG] Internet OK || echo [DEBUG] Sin internet
        echo.
        echo [ERROR] La instalacion no puede continuar
        echo Presiona cualquier tecla para salir...
        pause >nul
        exit /b 1
    )
) else (
    echo [STEP 5/10] Usando Python existente...
    echo [OK] Python compatible encontrado: %CURRENT_PYTHON%
)

echo.
echo [DEBUG] Configuracion de Python completada
pause

REM ============================================================================
REM CREAR ENTORNO VIRTUAL
REM ============================================================================
echo [STEP 6/10] Creando entorno virtual...

echo [DEBUG] Eliminando entorno virtual anterior...
if exist venv rmdir /s /q venv >nul 2>&1

echo [DEBUG] Creando nuevo entorno virtual...
echo [INFO] Ejecutando: "%PYTHON_EXE%" -m venv venv --clear

"%PYTHON_EXE%" -m venv venv --clear
if %errorLevel% neq 0 (
    echo [ERROR] Fallo al crear entorno virtual
    echo [DEBUG] Codigo de error: %errorLevel%
    echo [DEBUG] Verificando Python ejecutable...
    "%PYTHON_EXE%" --version 2>nul || echo [DEBUG] Python no ejecutable
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)

if not exist venv\Scripts\activate.bat (
    echo [ERROR] Entorno virtual no creado correctamente
    echo [DEBUG] Verificando estructura de venv...
    dir venv 2>nul || echo [DEBUG] Carpeta venv no existe
    dir venv\Scripts 2>nul || echo [DEBUG] Carpeta Scripts no existe
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)

echo [OK] Entorno virtual creado exitosamente
echo [DEBUG] Activando entorno virtual...

call venv\Scripts\activate.bat
if %errorLevel% neq 0 (
    echo [ERROR] No se pudo activar el entorno virtual
    echo [DEBUG] Codigo de error: %errorLevel%
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)

echo [OK] Entorno virtual activado

REM Verificar Python en entorno virtual
python --version > temp\venv_python.txt 2>&1
if exist temp\venv_python.txt (
    for /f "tokens=2" %%v in (temp\venv_python.txt) do set "VENV_PYTHON=%%v"
    echo [OK] Python en venv: %VENV_PYTHON%
    del temp\venv_python.txt
) else (
    echo [ERROR] Python no disponible en entorno virtual
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)

echo Entorno virtual creado: %VENV_PYTHON% >> "%LOG_FILE%"
echo.
echo [DEBUG] Entorno virtual configurado correctamente
pause

REM ============================================================================
REM ACTUALIZAR PIP
REM ============================================================================
echo [STEP 7/10] Actualizando herramientas de Python...

echo [DEBUG] Actualizando pip...
python -m pip install --upgrade "pip>=23.0,<25.0"
if %errorLevel% neq 0 (
    echo [WARNING] Error actualizando pip (codigo: %errorLevel%)
    echo [INFO] Continuando con version actual...
) else (
    echo [OK] pip actualizado
)

echo [DEBUG] Instalando setuptools y wheel...
python -m pip install --upgrade "setuptools>=65.0" "wheel>=0.40.0"
if %errorLevel% neq 0 (
    echo [WARNING] Error con setuptools/wheel (codigo: %errorLevel%)
    echo [INFO] Continuando...
) else (
    echo [OK] setuptools y wheel actualizados
)

echo.
echo [DEBUG] Herramientas de Python actualizadas
pause

REM ============================================================================
REM DESCARGAR APLICACION
REM ============================================================================
echo [STEP 8/10] Descargando aplicacion CinBehave...

set "REPO_BASE=https://raw.githubusercontent.com/StevenM711/CinBehave/main"
echo [DEBUG] Descargando desde: %REPO_BASE%

powershell -Command "try { Write-Host '[DOWNLOAD] Descargando cinbehave_gui.py...'; Invoke-WebRequest -Uri '%REPO_BASE%/cinbehave_gui.py' -OutFile 'cinbehave_gui.py' -UseBasicParsing; Write-Host '[OK] Descarga completada' } catch { Write-Host '[ERROR] Error en descarga'; Write-Host $_.Exception.Message; exit 1 }"

if not exist cinbehave_gui.py (
    echo [ERROR] No se pudo descargar la aplicacion
    echo [DEBUG] Verificando conectividad a GitHub...
    ping -n 1 github.com >nul && echo [DEBUG] GitHub accesible || echo [DEBUG] GitHub no accesible
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)

REM Verificar integridad
for %%I in (cinbehave_gui.py) do set "FILE_SIZE=%%~zI"
if %FILE_SIZE% LSS 1000 (
    echo [ERROR] Archivo descargado parece corrupto (tamaño: %FILE_SIZE% bytes)
    echo [DEBUG] Contenido del archivo:
    type cinbehave_gui.py 2>nul | more
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)

echo [OK] Aplicacion descargada exitosamente (tamaño: %FILE_SIZE% bytes)
echo Aplicacion descargada: %FILE_SIZE% bytes >> "%LOG_FILE%"
echo.
echo [DEBUG] Descarga de aplicacion completada
pause

REM ============================================================================
REM INSTALAR DEPENDENCIAS CORE
REM ============================================================================
echo [STEP 9/10] Instalando dependencias principales...

echo [DEBUG] Instalando dependencias core (esto puede tomar varios minutos)...

REM Lista de paquetes core con versiones especificas
set "CORE_PACKAGES=requests numpy>=1.21.0,<1.25.0 pandas>=1.5.0,<2.2.0 matplotlib>=3.6.0 Pillow>=9.0.0 opencv-python>=4.6.0 psutil>=5.9.0"

for %%p in (%CORE_PACKAGES%) do (
    echo [INSTALL] Instalando %%p...
    python -m pip install --only-binary=all "%%p"
    if !errorLevel! neq 0 (
        echo [WARNING] Error instalando %%p (codigo: !errorLevel!)
        echo [INFO] Intentando sin restriccion binary...
        python -m pip install "%%p"
        if !errorLevel! neq 0 (
            echo [ERROR] Fallo critico instalando %%p
            echo Error instalando %%p >> "%LOG_FILE%"
        ) else (
            echo [OK] %%p instalado (sin binary)
        )
    ) else (
        echo [OK] %%p instalado
    )
)

echo.
echo [DEBUG] Instalacion de dependencias core completada
pause

REM ============================================================================
REM INSTALAR SLEAP (OPCIONAL)
REM ============================================================================
echo [STEP 10/10] Instalando SLEAP...

echo [DEBUG] Intentando instalar SLEAP...
echo [INFO] SLEAP es opcional - la aplicacion funcionara sin el
echo [INFO] Esto puede tomar 10-15 minutos...

python -m pip install sleap
if %errorLevel% equ 0 (
    echo [OK] SLEAP instalado exitosamente
    echo SLEAP instalado >> "%LOG_FILE%"
) else (
    echo [WARNING] No se pudo instalar SLEAP (codigo: %errorLevel%)
    echo [INFO] La aplicacion funcionara sin SLEAP, pero con funcionalidad limitada
    echo SLEAP fallo >> "%LOG_FILE%"
)

echo.
echo [DEBUG] Instalacion de SLEAP completada
pause

REM ============================================================================
REM VALIDACION FINAL
REM ============================================================================
echo [VALIDATION] Validando instalacion...

echo [DEBUG] Creando script de validacion...
(
echo import sys, traceback
echo print("=== VALIDACION DE CINBEHAVE ===")
echo print("Python:", sys.version^)
echo print("Directorio:", sys.executable^)
echo print^(^)
echo modules = ['requests', 'numpy', 'pandas', 'matplotlib', 'PIL', 'cv2', 'psutil']
echo print("Verificando modulos core:")
echo for module in modules:
echo     try:
echo         exec(f"import {module}")
echo         mod = __import__(module^)
echo         version = getattr(mod, '__version__', 'sin version'^)
echo         print(f"[OK] {module} ({version}^)")
echo     except Exception as e:
echo         print(f"[ERROR] {module}: {e}")
echo.
echo print^(^)
echo print("Verificando SLEAP:")
echo try:
echo     import sleap
echo     print(f"[OK] SLEAP ({sleap.__version__}^)")
echo except Exception as e:
echo     print(f"[WARNING] SLEAP: {e}")
echo.
echo print^(^)
echo print("=== VALIDACION COMPLETADA ===")
) > temp\validate.py

echo [DEBUG] Ejecutando validacion...
python temp\validate.py
echo.

REM ============================================================================
REM CREAR LANZADORES
REM ============================================================================
echo [DEBUG] Creando lanzadores...

(
echo @echo off
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat
echo python cinbehave_gui.py
echo echo.
echo echo [INFO] CinBehave cerrado
echo pause
) > CinBehave.bat

(
echo @echo off
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat
echo python temp\validate.py
echo echo.
echo pause
) > Validar_Instalacion.bat

echo [OK] Lanzadores creados

REM ============================================================================
REM COMPLETADO
REM ============================================================================
echo.
echo ============================================================================
echo                        INSTALACION COMPLETADA
echo ============================================================================
echo.
echo [SUCCESS] CinBehave ha sido instalado exitosamente!
echo.
echo Ubicacion: %INSTALL_ROOT%
echo Python: %VENV_PYTHON%
echo.
echo PARA USAR CINBEHAVE:
echo 1. Ejecutar: CinBehave.bat
echo 2. O desde la linea de comandos: 
echo    cd "%INSTALL_ROOT%"
echo    call venv\Scripts\activate.bat
echo    python cinbehave_gui.py
echo.
echo PARA VALIDAR:
echo - Ejecutar: Validar_Instalacion.bat
echo.
echo LOG COMPLETO: %LOG_FILE%
echo.
echo ============================================================================

REM PREGUNTAR SI LANZAR AHORA
set /p "LAUNCH_NOW=¿Deseas lanzar CinBehave ahora? (s/n): "
if /i "%LAUNCH_NOW%"=="s" (
    echo.
    echo [LAUNCH] Iniciando CinBehave...
    start "" "%INSTALL_ROOT%\CinBehave.bat"
)

echo.
echo [COMPLETE] Instalacion terminada. Presiona cualquier tecla para salir...
pause >nul

endlocal
exit /b 0
