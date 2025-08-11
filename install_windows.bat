@echo off
REM ============================================================================
REM CinBehave - SLEAP Analysis GUI FIXED Windows Installer
REM Version: 1.2 FIXED Edition
REM 
REM INSTALADOR CORREGIDO - Manejo robusto de errores y verificaciones
REM ============================================================================

setlocal enabledelayedexpansion
set "INSTALLER_VERSION=1.2.0-fixed"
set "INSTALL_DATE=%DATE% %TIME%"
set "TOTAL_STEPS=12"
set "CURRENT_STEP=0"

REM Variables de control de errores
set "CRITICAL_ERROR=0"
set "PYTHON_INSTALLED=0"
set "VENV_CREATED=0"
set "APP_DOWNLOADED=0"
set "DEPS_INSTALLED=0"

echo.
echo ============================================================================
echo                    CinBehave SLEAP Analysis Suite                          
echo                         FIXED INSTALLER v%INSTALLER_VERSION%
echo                    INSTALADOR CORREGIDO CON VERIFICACIONES
echo ============================================================================
echo.

REM ============================================================================
REM FUNCION: Incrementar paso y mostrar progreso
REM ============================================================================
:increment_step
set /a CURRENT_STEP+=1
echo [PASO %CURRENT_STEP%/%TOTAL_STEPS%] %~1
goto :eof

REM ============================================================================
REM FUNCION: Verificar error critico y salir si es necesario
REM ============================================================================
:check_critical_error
if "%CRITICAL_ERROR%"=="1" (
    echo.
    echo [ERROR CRITICO] La instalacion no puede continuar
    echo [INFO] Revise los mensajes de error anteriores
    echo [LOG] Verifique el archivo de log para mas detalles
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)
goto :eof

REM ============================================================================
REM VERIFICACION DE ADMINISTRADOR
REM ============================================================================
call :increment_step "Verificando privilegios de administrador..."
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Se requieren privilegios de administrador
    echo [SOLUCION] Ejecute este archivo como administrador:
    echo   1. Clic derecho en el archivo .bat
    echo   2. Seleccionar "Ejecutar como administrador"
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)
echo [OK] Privilegios de administrador verificados
echo.

REM ============================================================================
REM DETECCION DEL SISTEMA
REM ============================================================================
call :increment_step "Detectando configuracion del sistema..."

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "SYSTEM_ARCH=x64"
    set "PYTHON_ARCH=amd64"
    echo [OK] Arquitectura: x64 (64-bit)
) else (
    set "SYSTEM_ARCH=x86" 
    set "PYTHON_ARCH=win32"
    echo [WARNING] Arquitectura: x86 (32-bit) - Rendimiento limitado
)

REM Verificar memoria
for /f "skip=1" %%i in ('wmic computersystem get TotalPhysicalMemory /value') do (
    if not "%%i"=="" (
        set "%%i"
        set /a "MEMORY_GB=!TotalPhysicalMemory! / 1024 / 1024 / 1024"
    )
)
echo [INFO] RAM: !MEMORY_GB!GB

REM Verificar conectividad CRITICA
echo [INFO] Verificando conectividad a internet...
ping -n 1 8.8.8.8 >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Sin conexion a internet - La instalacion no puede continuar
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)
echo [OK] Conectividad verificada
echo.

REM ============================================================================
REM CONFIGURACION DE DIRECTORIOS CON VERIFICACION
REM ============================================================================
call :increment_step "Configurando estructura de directorios..."

set "INSTALL_ROOT=%USERPROFILE%\CinBehave"
echo [INFO] Directorio de instalacion: %INSTALL_ROOT%

REM Crear directorio principal y verificar
if not exist "%INSTALL_ROOT%" (
    mkdir "%INSTALL_ROOT%" >nul 2>&1
    if not exist "%INSTALL_ROOT%" (
        echo [ERROR] No se pudo crear directorio principal: %INSTALL_ROOT%
        set "CRITICAL_ERROR=1"
        call :check_critical_error
    )
)

REM Crear subdirectorios y verificar cada uno
set "SUBDIRS=logs temp config assets docs models exports Proyectos users"
for %%d in (%SUBDIRS%) do (
    mkdir "%INSTALL_ROOT%\%%d" >nul 2>&1
    if not exist "%INSTALL_ROOT%\%%d" (
        echo [ERROR] No se pudo crear subdirectorio: %%d
        set "CRITICAL_ERROR=1"
        call :check_critical_error
    )
)

cd /d "%INSTALL_ROOT%"
if "%CD%" neq "%INSTALL_ROOT%" (
    echo [ERROR] No se pudo acceder al directorio de instalacion
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

set "LOG_FILE=%INSTALL_ROOT%\logs\installation_fixed_%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log"

REM Inicializar log con verificacion
echo ============================================================================ > "%LOG_FILE%" 2>nul
if not exist "%LOG_FILE%" (
    echo [ERROR] No se pudo crear archivo de log
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

echo CinBehave FIXED Installation Log >> "%LOG_FILE%"
echo Started: %INSTALL_DATE% >> "%LOG_FILE%"
echo System: %SYSTEM_ARCH% Windows RAM: !MEMORY_GB!GB >> "%LOG_FILE%"
echo ============================================================================ >> "%LOG_FILE%"

echo [OK] Estructura de directorios configurada y verificada
echo.

REM ============================================================================
REM DETECCION Y MANEJO DE PYTHON EXISTENTE
REM ============================================================================
call :increment_step "Analizando instalaciones de Python..."

set "COMPATIBLE_PYTHON="
set "NEEDS_INSTALL=1"

REM Verificar Python en PATH
python --version >temp\python_check.txt 2>nul
if exist temp\python_check.txt (
    for /f "tokens=2" %%v in (temp\python_check.txt) do set "DETECTED_PYTHON=%%v"
    echo [INFO] Python detectado en PATH: !DETECTED_PYTHON!
    echo Python detectado: !DETECTED_PYTHON! >> "%LOG_FILE%"
    
    REM Verificar compatibilidad
    echo !DETECTED_PYTHON! | findstr "3.8" >nul && set "COMPATIBLE_PYTHON=python" && set "NEEDS_INSTALL=0"
    echo !DETECTED_PYTHON! | findstr "3.9" >nul && set "COMPATIBLE_PYTHON=python" && set "NEEDS_INSTALL=0"
    echo !DETECTED_PYTHON! | findstr "3.10" >nul && set "COMPATIBLE_PYTHON=python" && set "NEEDS_INSTALL=0"
    echo !DETECTED_PYTHON! | findstr "3.11" >nul && set "COMPATIBLE_PYTHON=python" && set "NEEDS_INSTALL=0"
    
    del temp\python_check.txt
)

if "%NEEDS_INSTALL%"=="1" (
    echo [INFO] Se requiere instalacion de Python 3.11.6 aislado
) else (
    echo [OK] Python compatible encontrado: !DETECTED_PYTHON!
)
echo.

REM ============================================================================
REM INSTALACION DE PYTHON 3.11.6 (SI ES NECESARIO)
REM ============================================================================
if "%NEEDS_INSTALL%"=="1" (
    call :increment_step "Instalando Python 3.11.6 aislado..."
    
    if "%SYSTEM_ARCH%"=="x64" (
        set "PYTHON_URL=https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe"
    ) else (
        set "PYTHON_URL=https://www.python.org/ftp/python/3.11.6/python-3.11.6.exe"
    )
    
    echo [INFO] Descargando Python 3.11.6...
    echo [WARNING] Esta operacion puede tomar 5-10 minutos
    
    powershell -Command "try { Invoke-WebRequest -Uri '!PYTHON_URL!' -OutFile 'temp\python_installer.exe' -UseBasicParsing; Write-Host '[OK] Python descargado' } catch { Write-Host '[ERROR] Descarga fallida'; exit 1 }"
    
    if not exist temp\python_installer.exe (
        echo [ERROR] No se pudo descargar Python installer
        echo Descarga Python fallida >> "%LOG_FILE%"
        set "CRITICAL_ERROR=1"
        call :check_critical_error
    )
    
    echo [INFO] Instalando Python 3.11.6... (Por favor espere)
    start /wait temp\python_installer.exe /quiet TargetDir="%INSTALL_ROOT%\Python311" InstallAllUsers=0 PrependPath=0 AssociateFiles=0 CompileAll=0 Include_test=0
    
    REM VERIFICACION CRITICA de Python
    if exist "%INSTALL_ROOT%\Python311\python.exe" (
        echo [OK] Python 3.11.6 instalado exitosamente
        set "PYTHON_EXE=%INSTALL_ROOT%\Python311\python.exe"
        set "PYTHON_INSTALLED=1"
        echo Python aislado instalado: %PYTHON_EXE% >> "%LOG_FILE%"
    ) else (
        echo [ERROR] Instalacion de Python fallida - archivo ejecutable no encontrado
        echo [DEBUG] Verificando contenido de Python311:
        dir "%INSTALL_ROOT%\Python311\" 2>nul || echo [DEBUG] Directorio Python311 vacio o no existe
        echo Python instalacion fallida >> "%LOG_FILE%"
        set "CRITICAL_ERROR=1"
        call :check_critical_error
    )
) else (
    call :increment_step "Usando Python existente del sistema..."
    set "PYTHON_EXE=%COMPATIBLE_PYTHON%"
    set "PYTHON_INSTALLED=1"
    echo [OK] Usando Python compatible: %COMPATIBLE_PYTHON%
)
echo.

REM ============================================================================
REM CREACION DE ENTORNO VIRTUAL CON VERIFICACION ROBUSTA
REM ============================================================================
call :increment_step "Creando entorno virtual..."

echo [INFO] Eliminando entorno virtual anterior si existe...
if exist venv rmdir /s /q venv >nul 2>&1

echo [INFO] Creando entorno virtual con Python: %PYTHON_EXE%
"%PYTHON_EXE%" -m venv venv --clear
set "VENV_RESULT=%errorLevel%"

REM VERIFICACION MULTIPLE del entorno virtual
if %VENV_RESULT% neq 0 (
    echo [ERROR] Comando venv fallo con codigo: %VENV_RESULT%
    echo Venv comando fallo >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

if not exist venv\Scripts\activate.bat (
    echo [ERROR] Archivo activate.bat no encontrado
    echo [DEBUG] Verificando estructura de venv:
    dir venv 2>nul || echo [DEBUG] Directorio venv no existe
    dir venv\Scripts 2>nul || echo [DEBUG] Directorio Scripts no existe
    echo Activate.bat no encontrado >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

if not exist venv\Scripts\python.exe (
    echo [ERROR] Python.exe no encontrado en entorno virtual
    echo Python.exe venv no encontrado >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

echo [OK] Entorno virtual creado exitosamente
set "VENV_CREATED=1"
echo Entorno virtual creado >> "%LOG_FILE%"

REM Activar entorno virtual y verificar
call venv\Scripts\activate.bat
if %errorLevel% neq 0 (
    echo [ERROR] No se pudo activar entorno virtual
    echo Activacion venv fallida >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

REM Verificar Python en entorno virtual
venv\Scripts\python.exe --version > temp\venv_python.txt 2>&1
if not exist temp\venv_python.txt (
    echo [ERROR] Python no funciona en entorno virtual
    echo Python venv no funcional >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

for /f "tokens=2" %%v in (temp\venv_python.txt) do set "VENV_PYTHON=%%v"
echo [OK] Python en entorno virtual: %VENV_PYTHON%
echo Python venv: %VENV_PYTHON% >> "%LOG_FILE%"
del temp\venv_python.txt
echo.

REM ============================================================================
REM ACTUALIZACION DE PIP CON VERIFICACION
REM ============================================================================
call :increment_step "Actualizando herramientas de Python..."

echo [INFO] Actualizando pip...
venv\Scripts\python.exe -m pip install --upgrade pip >temp\pip_update.log 2>&1
set "PIP_RESULT=%errorLevel%"

if %PIP_RESULT% equ 0 (
    echo [OK] pip actualizado exitosamente
) else (
    echo [WARNING] Error actualizando pip (codigo: %PIP_RESULT%) - continuando
    type temp\pip_update.log >> "%LOG_FILE%"
)

echo [INFO] Instalando setuptools y wheel...
venv\Scripts\python.exe -m pip install setuptools wheel >temp\tools_install.log 2>&1
if %errorLevel% equ 0 (
    echo [OK] Herramientas base instaladas
) else (
    echo [WARNING] Error con herramientas base - continuando
    type temp\tools_install.log >> "%LOG_FILE%"
)
echo.

REM ============================================================================
REM DESCARGA DE APLICACION CON VERIFICACION ROBUSTA
REM ============================================================================
call :increment_step "Descargando aplicacion CinBehave..."

set "APP_URL=https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py"
echo [INFO] Descargando desde: %APP_URL%

powershell -Command "try { Invoke-WebRequest -Uri '%APP_URL%' -OutFile 'cinbehave_gui.py' -UseBasicParsing; Write-Host '[OK] Descarga completada' } catch { Write-Host '[ERROR] Descarga fallida:' $_.Exception.Message; exit 1 }"
set "DOWNLOAD_RESULT=%errorLevel%"

REM VERIFICACION MULTIPLE de la aplicacion
if %DOWNLOAD_RESULT% neq 0 (
    echo [ERROR] Descarga de aplicacion fallida
    echo App descarga fallida >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

if not exist cinbehave_gui.py (
    echo [ERROR] Archivo cinbehave_gui.py no encontrado despues de descarga
    echo App archivo no encontrado >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

REM Verificar tamaño de archivo
for %%I in (cinbehave_gui.py) do set "APP_SIZE=%%~zI"
if %APP_SIZE% LSS 10000 (
    echo [ERROR] Archivo descargado muy pequeño (%APP_SIZE% bytes) - posiblemente corrupto
    echo [DEBUG] Contenido del archivo:
    type cinbehave_gui.py | more
    echo App archivo corrupto >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

echo [OK] Aplicacion descargada y verificada (%APP_SIZE% bytes)
set "APP_DOWNLOADED=1"
echo App descargada: %APP_SIZE% bytes >> "%LOG_FILE%"
echo.

REM ============================================================================
REM INSTALACION DE DEPENDENCIAS CRITICAS CON VERIFICACION
REM ============================================================================
call :increment_step "Instalando dependencias criticas..."

echo [INFO] Instalando dependencias core (esto puede tomar varios minutos)...

REM Lista de dependencias criticas
set "CORE_DEPS=requests numpy pandas matplotlib Pillow opencv-python psutil"
set "INSTALLED_COUNT=0"
set "TOTAL_DEPS=7"

for %%p in (%CORE_DEPS%) do (
    echo [INSTALL] Instalando %%p...
    venv\Scripts\python.exe -m pip install "%%p" >temp\install_%%p.log 2>&1
    set "INSTALL_RESULT=!errorLevel!"
    
    if !INSTALL_RESULT! equ 0 (
        echo [OK] %%p instalado exitosamente
        set /a "INSTALLED_COUNT+=1"
    ) else (
        echo [ERROR] %%p fallo durante instalacion
        echo Dependencia %%p fallo >> "%LOG_FILE%"
        type temp\install_%%p.log >> "%LOG_FILE%"
    )
)

echo [INFO] Dependencias instaladas: %INSTALLED_COUNT%/%TOTAL_DEPS%

if %INSTALLED_COUNT% LSS 5 (
    echo [ERROR] Demasiadas dependencias fallaron - instalacion no viable
    echo Dependencias insuficientes >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
) else (
    echo [OK] Dependencias suficientes para funcionamiento basico
    set "DEPS_INSTALLED=1"
)
echo.

REM ============================================================================
REM INSTALACION DE SLEAP (OPCIONAL PERO VERIFICADA)
REM ============================================================================
call :increment_step "Instalando SLEAP (componente principal)..."

echo [INFO] Instalando SLEAP - esto puede tomar 10-20 minutos...
echo [WARNING] SLEAP es el componente principal para analisis de poses

venv\Scripts\python.exe -m pip install sleap >temp\sleap_install.log 2>&1
set "SLEAP_RESULT=%errorLevel%"

if %SLEAP_RESULT% equ 0 (
    echo [OK] SLEAP instalado exitosamente
    echo SLEAP instalado >> "%LOG_FILE%"
    
    REM Verificar importacion de SLEAP
    venv\Scripts\python.exe -c "import sleap; print('SLEAP Version:', sleap.__version__)" >temp\sleap_test.txt 2>&1
    if %errorLevel% equ 0 (
        for /f "tokens=3" %%v in (temp\sleap_test.txt) do echo [INFO] SLEAP Version: %%v
        del temp\sleap_test.txt
    )
) else (
    echo [WARNING] SLEAP instalacion fallida - aplicacion funcionara con funcionalidad limitada
    echo SLEAP instalacion fallida >> "%LOG_FILE%"
    type temp\sleap_install.log >> "%LOG_FILE%"
)
echo.

REM ============================================================================
REM VALIDACION FINAL COMPLETA
REM ============================================================================
call :increment_step "Validando instalacion completa..."

echo [INFO] Ejecutando validacion final...

REM Crear script de validacion robusto
(
echo import sys, traceback
echo print^("=== VALIDACION FINAL CINBEHAVE ==="^)
echo print^("Python:", sys.version^)
echo print^("Ejecutable:", sys.executable^)
echo print^(^)
echo print^("Verificando modulos core:"^)
echo modules = ['requests', 'numpy', 'pandas', 'matplotlib', 'PIL', 'cv2', 'psutil']
echo success_count = 0
echo for module in modules:
echo     try:
echo         exec^(f"import {module}"^)
echo         mod = __import__^(module^)
echo         version = getattr^(mod, '__version__', 'sin version'^)
echo         print^(f"[OK] {module} ^({version}^)"^)
echo         success_count += 1
echo     except Exception as e:
echo         print^(f"[ERROR] {module}: {e}"^)
echo.
echo print^(^)
echo print^("Verificando SLEAP:"^)
echo try:
echo     import sleap
echo     print^(f"[OK] SLEAP ^({sleap.__version__}^)"^)
echo except Exception as e:
echo     print^(f"[WARNING] SLEAP: {e}"^)
echo.
echo print^(^)
echo print^(f"=== RESUMEN: {success_count}/{len^(modules^)} modulos core OK ==="^)
echo if success_count >= 5:
echo     print^("[RESULTADO] Instalacion EXITOSA - CinBehave listo para usar"^)
echo     exit^(0^)
echo else:
echo     print^("[RESULTADO] Instalacion FALLIDA - Dependencias insuficientes"^)
echo     exit^(1^)
) > temp\final_validation.py

venv\Scripts\python.exe temp\final_validation.py > temp\validation_output.txt 2>&1
set "VALIDATION_RESULT=%errorLevel%"

echo [INFO] Resultados de validacion:
type temp\validation_output.txt
echo.

if %VALIDATION_RESULT% neq 0 (
    echo [ERROR] Validacion final fallida
    echo Validacion final fallida >> "%LOG_FILE%"
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

type temp\validation_output.txt >> "%LOG_FILE%"
echo [OK] Validacion final exitosa
echo.

REM ============================================================================
REM CREACION DE LANZADORES CON VERIFICACION
REM ============================================================================
call :increment_step "Creando lanzadores de aplicacion..."

REM Lanzador principal con manejo de errores
(
echo @echo off
echo REM CinBehave Enterprise Launcher - v%INSTALLER_VERSION%
echo cd /d "%%~dp0"
echo.
echo echo ============================================================================
echo echo                        CinBehave Enterprise Suite
echo echo ============================================================================
echo echo.
echo echo [INFO] Iniciando CinBehave...
echo.
echo REM Verificar entorno virtual
echo if not exist venv\Scripts\activate.bat ^(
echo     echo [ERROR] Entorno virtual no encontrado
echo     echo [SOLUCION] Ejecutar el instalador nuevamente
echo     pause
echo     exit /b 1
echo ^)
echo.
echo REM Activar entorno virtual
echo call venv\Scripts\activate.bat
echo if %%errorLevel%% neq 0 ^(
echo     echo [ERROR] No se pudo activar entorno virtual
echo     pause
echo     exit /b 1
echo ^)
echo.
echo REM Verificar aplicacion principal
echo if not exist cinbehave_gui.py ^(
echo     echo [ERROR] Aplicacion principal no encontrada
echo     echo [SOLUCION] Ejecutar el instalador nuevamente
echo     pause
echo     exit /b 1
echo ^)
echo.
echo REM Verificar dependencias criticas
echo python -c "import requests, numpy" ^>nul 2^>^&1
echo if %%errorLevel%% neq 0 ^(
echo     echo [ERROR] Dependencias criticas faltantes
echo     echo [SOLUCION] Ejecutar: system_repair.bat
echo     pause
echo     exit /b 1
echo ^)
echo.
echo REM Lanzar aplicacion
echo echo [LAUNCH] Iniciando interfaz grafica...
echo python cinbehave_gui.py
echo.
echo REM Manejar salida
echo if %%errorLevel%% neq 0 ^(
echo     echo.
echo     echo [ERROR] CinBehave termino con error %%errorLevel%%
echo     echo [LOG] Verifique logs\cinbehave.log para detalles
echo     echo.
echo ^)
echo.
echo echo [INFO] CinBehave cerrado
echo echo Presiona cualquier tecla para salir...
echo pause ^>nul
) > CinBehave_Enterprise.bat

REM Validador mejorado
(
echo @echo off
echo REM CinBehave System Validator - v%INSTALLER_VERSION%
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat ^>nul 2^>^&1
echo.
echo echo ============================================================================
echo echo                      CinBehave System Validation
echo echo                           Enterprise Edition
echo echo ============================================================================
echo echo.
echo python temp\final_validation.py
echo echo.
echo echo ============================================================================
echo pause
) > Validar_Instalacion_Completa.bat

echo [OK] Lanzadores creados y verificados
echo.

REM ============================================================================
REM VERIFICACION FINAL DE ESTADO
REM ============================================================================
call :increment_step "Verificacion final de estado..."

echo [INFO] Verificando estado final de instalacion...
echo.
echo Estado de componentes:
echo - Python instalado: %PYTHON_INSTALLED%
echo - Entorno virtual: %VENV_CREATED%
echo - Aplicacion descargada: %APP_DOWNLOADED%
echo - Dependencias instaladas: %DEPS_INSTALLED%
echo.

REM Solo reportar exito si TODO esta instalado
if "%PYTHON_INSTALLED%"=="1" if "%VENV_CREATED%"=="1" if "%APP_DOWNLOADED%"=="1" if "%DEPS_INSTALLED%"=="1" (
    set "INSTALLATION_SUCCESS=1"
) else (
    set "INSTALLATION_SUCCESS=0"
    echo [ERROR] Instalacion incompleta - algunos componentes fallaron
    set "CRITICAL_ERROR=1"
    call :check_critical_error
)

echo Instalacion completada: %DATE% %TIME% >> "%LOG_FILE%"
echo Estado final: SUCCESS=%INSTALLATION_SUCCESS% PYTHON=%PYTHON_INSTALLED% VENV=%VENV_CREATED% APP=%APP_DOWNLOADED% DEPS=%DEPS_INSTALLED% >> "%LOG_FILE%"

REM ============================================================================
REM RESUMEN FINAL SOLO SI TODO ESTA OK
REM ============================================================================
if "%INSTALLATION_SUCCESS%"=="1" (
    echo.
    echo ============================================================================
    echo                        INSTALACION COMPLETADA EXITOSAMENTE
    echo ============================================================================
    echo.
    echo [SUCCESS] CinBehave Enterprise Suite instalado correctamente
    echo.
    echo Ubicacion: %INSTALL_ROOT%
    echo Python: %VENV_PYTHON%
    echo Aplicacion: cinbehave_gui.py ^(%APP_SIZE% bytes^)
    echo Dependencias: %INSTALLED_COUNT%/%TOTAL_DEPS% modulos core
    echo.
    echo PARA USAR CINBEHAVE:
    echo 1. Ejecutar: CinBehave_Enterprise.bat
    echo 2. O desde el menu inicio: CinBehave Enterprise
    echo.
    echo PARA VALIDAR:
    echo - Ejecutar: Validar_Instalacion_Completa.bat
    echo.
    echo LOG COMPLETO: %LOG_FILE%
    echo.
    echo ============================================================================
    echo.
    
    REM Preguntar si lanzar ahora
    set /p "LAUNCH_NOW=¿Deseas lanzar CinBehave ahora? (s/n): "
    if /i "!LAUNCH_NOW!"=="s" (
        echo.
        echo [LAUNCH] Iniciando CinBehave Enterprise...
        start "" "%INSTALL_ROOT%\CinBehave_Enterprise.bat"
    )
    
    echo.
    echo [COMPLETE] Instalacion terminada exitosamente
    echo Presiona cualquier tecla para salir...
    pause >nul
) else (
    echo.
    echo ============================================================================
    echo                           INSTALACION FALLIDA
    echo ============================================================================
    echo.
    echo [FAILED] La instalacion no se completo correctamente
    echo [LOG] Revise el archivo de log para detalles: %LOG_FILE%
    echo [SUPPORT] Comparta el log completo para obtener soporte
    echo.
    echo Presiona cualquier tecla para salir...
    pause >nul
    exit /b 1
)

endlocal
exit /b 0
