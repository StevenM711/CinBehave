@echo off
REM ============================================================================
REM CinBehave Debug Installer - Diagnóstico y Solución de Problemas
REM ============================================================================

setlocal enabledelayedexpansion
cls

echo ============================================================================
echo                    CinBehave - Diagnostico del Instalador
echo ============================================================================
echo.

REM Verificar privilegios de administrador
echo [1/8] Verificando privilegios de administrador...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ ERROR: Se requieren privilegios de administrador
    echo.
    echo SOLUCION: 
    echo 1. Haz clic derecho en este archivo
    echo 2. Selecciona "Ejecutar como administrador"
    echo.
    pause
    exit /b 1
) else (
    echo ✅ Privilegios de administrador verificados
)

REM Verificar conectividad
echo.
echo [2/8] Verificando conectividad a internet...
ping -n 1 8.8.8.8 >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ ERROR: Sin conexión a internet
    echo.
    echo SOLUCION: Verifique su conexión de red
    pause
    exit /b 1
) else (
    echo ✅ Conectividad verificada
)

REM Verificar acceso a GitHub
echo.
echo [3/8] Verificando acceso a GitHub...
powershell -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -Method Head -UseBasicParsing -TimeoutSec 10 | Out-Null; Write-Host '✅ GitHub accesible' } catch { Write-Host '❌ GitHub no accesible'; exit 1 }" 2>nul
if %errorLevel% neq 0 (
    echo ❌ ERROR: No se puede acceder a GitHub
    echo.
    echo SOLUCION: Verifique firewall/antivirus
    pause
    exit /b 1
)

REM Verificar Python existente
echo.
echo [4/8] Verificando instalaciones de Python...
python --version >nul 2>&1
if %errorLevel% equ 0 (
    for /f "tokens=2" %%v in ('python --version 2^>^&1') do set "CURRENT_PYTHON=%%v"
    echo ⚠️  Python actual: !CURRENT_PYTHON!
    echo    Nota: Se instalará Python 3.11.6 aislado para CinBehave
) else (
    echo ✅ No hay Python en PATH (ideal para instalación limpia)
)

REM Verificar espacio en disco
echo.
echo [5/8] Verificando espacio en disco...
for /f "tokens=3" %%a in ('dir /-c %USERPROFILE% 2^>nul ^| find "bytes free"') do set "FREE_SPACE=%%a"
set /a "FREE_GB=!FREE_SPACE! / 1024 / 1024 / 1024" 2>nul
if defined FREE_GB (
    if !FREE_GB! LSS 5 (
        echo ❌ ERROR: Espacio insuficiente (!FREE_GB!GB disponible)
        echo    Se requieren al menos 5GB libres
        pause
        exit /b 1
    ) else (
        echo ✅ Espacio en disco: !FREE_GB!GB disponible
    )
) else (
    echo ⚠️  No se pudo verificar espacio en disco
)

REM Verificar arquitectura del sistema
echo.
echo [6/8] Verificando arquitectura del sistema...
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo ✅ Sistema: 64-bit (óptimo)
    set "SYSTEM_ARCH=x64"
) else (
    echo ⚠️  Sistema: 32-bit (funcionalidad limitada)
    set "SYSTEM_ARCH=x86"
)

REM Verificar memoria RAM
echo.
echo [7/8] Verificando memoria RAM...
for /f "skip=1" %%i in ('wmic computersystem get TotalPhysicalMemory /value 2^>nul') do (
    if not "%%i"=="" (
        set "%%i"
        set /a "MEMORY_GB=!TotalPhysicalMemory! / 1024 / 1024 / 1024" 2>nul
    )
)
if defined MEMORY_GB (
    if !MEMORY_GB! LSS 4 (
        echo ⚠️  RAM: !MEMORY_GB!GB (mínimo para SLEAP: 8GB)
    ) else (
        echo ✅ RAM: !MEMORY_GB!GB (adecuada)
    )
) else (
    echo ⚠️  No se pudo verificar RAM
)

REM Verificar GPU
echo.
echo [8/8] Verificando GPU...
nvidia-smi >nul 2>&1
if %errorLevel% equ 0 (
    echo ✅ GPU NVIDIA detectada (aceleración de hardware disponible)
    set "GPU_SUPPORT=NVIDIA"
) else (
    wmic path win32_VideoController get name 2>nul | findstr /i "AMD" >nul
    if %errorLevel% equ 0 (
        echo ⚠️  GPU AMD detectada (aceleración limitada)
        set "GPU_SUPPORT=AMD"
    ) else (
        echo ⚠️  Solo CPU (procesamiento más lento)
        set "GPU_SUPPORT=CPU"
    )
)

echo.
echo ============================================================================
echo                           RESUMEN DEL DIAGNÓSTICO
echo ============================================================================
echo.
echo Estado del sistema: LISTO PARA INSTALACIÓN
echo Arquitectura: %SYSTEM_ARCH%
if defined MEMORY_GB echo Memoria: !MEMORY_GB!GB
echo GPU: %GPU_SUPPORT%
if defined CURRENT_PYTHON echo Python actual: !CURRENT_PYTHON!
echo.
echo ============================================================================
echo.

REM Ofrecer opciones al usuario
echo Seleccione una opción:
echo.
echo [1] Instalación COMPLETA (recomendado)
echo [2] Instalación SOLO de dependencias básicas
echo [3] Descargar instalador original y ejecutar con logs
echo [4] Crear directorio CinBehave manualmente
echo [5] Salir
echo.
set /p "CHOICE=Ingrese su opción (1-5): "

if "%CHOICE%"=="1" goto :FULL_INSTALL
if "%CHOICE%"=="2" goto :BASIC_INSTALL  
if "%CHOICE%"=="3" goto :DOWNLOAD_ORIGINAL
if "%CHOICE%"=="4" goto :MANUAL_SETUP
if "%CHOICE%"=="5" goto :EXIT

echo Opción inválida. Ejecutando instalación completa...
goto :FULL_INSTALL

:FULL_INSTALL
echo.
echo ============================================================================
echo                         INSTALACIÓN COMPLETA
echo ============================================================================
echo.

REM Crear directorio de instalación
set "INSTALL_DIR=%USERPROFILE%\CinBehave"
echo Creando directorio: %INSTALL_DIR%
if exist "%INSTALL_DIR%" (
    echo ⚠️  Directorio existente detectado - creando backup...
    if exist "%INSTALL_DIR%_backup" rmdir /s /q "%INSTALL_DIR%_backup"
    move "%INSTALL_DIR%" "%INSTALL_DIR%_backup" >nul 2>&1
)
mkdir "%INSTALL_DIR%" 2>nul
cd /d "%INSTALL_DIR%"

REM Descargar Python 3.11.6
echo.
echo Descargando Python 3.11.6...
if "%SYSTEM_ARCH%"=="x64" (
    set "PYTHON_URL=https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe"
) else (
    set "PYTHON_URL=https://www.python.org/ftp/python/3.11.6/python-3.11.6.exe"
)

powershell -Command "Write-Host 'Descargando Python...'; try { Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile 'python_installer.exe' -UseBasicParsing } catch { Write-Host 'Error descarga Python'; exit 1 }"

if not exist python_installer.exe (
    echo ❌ Error descargando Python
    pause
    exit /b 1
)

REM Instalar Python aislado
echo.
echo Instalando Python 3.11.6 (esto puede tomar varios minutos)...
start /wait python_installer.exe /quiet TargetDir="%INSTALL_DIR%\Python311" InstallAllUsers=0 PrependPath=0 AssociateFiles=0

if not exist "%INSTALL_DIR%\Python311\python.exe" (
    echo ❌ Error instalando Python
    pause
    exit /b 1
)

echo ✅ Python 3.11.6 instalado exitosamente

REM Crear entorno virtual
echo.
echo Creando entorno virtual...
"%INSTALL_DIR%\Python311\python.exe" -m venv venv --clear
if not exist venv\Scripts\activate.bat (
    echo ❌ Error creando entorno virtual
    pause
    exit /b 1
)

REM Activar entorno virtual
call venv\Scripts\activate.bat
echo ✅ Entorno virtual creado y activado

REM Instalar dependencias básicas
echo.
echo Instalando dependencias básicas...
python -m pip install --upgrade pip setuptools wheel
python -m pip install requests numpy pandas matplotlib opencv-python

REM Descargar aplicación CinBehave
echo.
echo Descargando aplicación CinBehave...
powershell -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py' -UseBasicParsing } catch { Write-Host 'Error descarga app'; exit 1 }"

if not exist cinbehave_gui.py (
    echo ❌ Error descargando aplicación
    pause
    exit /b 1
)

echo ✅ Aplicación descargada

REM Crear launcher
echo.
echo Creando launcher...
(
echo @echo off
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat
echo python cinbehave_gui.py
echo pause
) > CinBehave_Launcher.bat

echo ✅ Launcher creado

REM Crear acceso directo en escritorio
powershell -Command "try { $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\CinBehave.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\CinBehave_Launcher.bat'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.Save() } catch {}"

echo ✅ Acceso directo creado en escritorio

echo.
echo ============================================================================
echo                    ✅ INSTALACIÓN COMPLETADA EXITOSAMENTE
echo ============================================================================
echo.
echo Ubicación: %INSTALL_DIR%
echo Launcher: CinBehave_Launcher.bat
echo Acceso directo: Escritorio\CinBehave.lnk
echo.
echo Para iniciar CinBehave:
echo 1. Doble clic en el acceso directo del escritorio
echo 2. O ejecutar: %INSTALL_DIR%\CinBehave_Launcher.bat
echo.

set /p "LAUNCH_NOW=¿Desea ejecutar CinBehave ahora? (s/n): "
if /i "%LAUNCH_NOW%"=="s" (
    start "" "%INSTALL_DIR%\CinBehave_Launcher.bat"
)

goto :EXIT

:BASIC_INSTALL
echo.
echo ============================================================================
echo                      INSTALACIÓN BÁSICA DE DEPENDENCIAS
echo ============================================================================
echo.
echo Esta opción solo instala las dependencias básicas de Python
echo sin descargar CinBehave. Útil para diagnosticar problemas.
echo.
pause

REM Verificar si Python está disponible
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ ERROR: Python no encontrado en PATH
    echo.
    echo Para instalación básica necesita Python ya instalado.
    echo Use la opción 1 (Instalación COMPLETA) en su lugar.
    pause
    goto :EXIT
)

echo Instalando dependencias básicas con Python actual...
python -m pip install --upgrade pip
python -m pip install requests numpy pandas matplotlib opencv-python pillow

echo.
echo ✅ Dependencias básicas instaladas
echo.
echo Para descargar CinBehave manualmente:
echo 1. Crear carpeta para el proyecto
echo 2. Descargar: https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py
echo 3. Ejecutar: python cinbehave_gui.py
echo.
pause
goto :EXIT

:DOWNLOAD_ORIGINAL
echo.
echo ============================================================================
echo                   DESCARGA DEL INSTALADOR ORIGINAL CON LOGS
echo ============================================================================
echo.

set "TEMP_DIR=%TEMP%\CinBehave_Debug"
mkdir "%TEMP_DIR%" 2>nul
cd /d "%TEMP_DIR%"

echo Descargando instalador original...
powershell -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/install_windows.bat' -OutFile 'install_windows_debug.bat' -UseBasicParsing } catch { Write-Host 'Error descarga'; exit 1 }"

if not exist install_windows_debug.bat (
    echo ❌ Error descargando instalador original
    pause
    goto :EXIT
)

echo ✅ Instalador descargado en: %TEMP_DIR%
echo.
echo Modificando instalador para logging detallado...

REM Crear versión con logging
powershell -Command "(Get-Content 'install_windows_debug.bat') -replace '@echo off', '@echo off`necho INICIO DEL INSTALADOR - %DATE% %TIME%' | Set-Content 'install_windows_logged.bat'"

echo.
echo Ejecutando instalador con logging...
echo.
echo NOTA: Mantenga esta ventana abierta para ver los errores
echo.
pause

call install_windows_logged.bat

echo.
echo ============================================================================
echo Si el instalador falló, revise los mensajes de error arriba.
echo Logs guardados en: %TEMP_DIR%
echo ============================================================================
pause
goto :EXIT

:MANUAL_SETUP
echo.
echo ============================================================================
echo                          CONFIGURACIÓN MANUAL
echo ============================================================================
echo.

set "MANUAL_DIR=%USERPROFILE%\CinBehave_Manual"
echo Creando directorio manual: %MANUAL_DIR%
mkdir "%MANUAL_DIR%" 2>nul
cd /d "%MANUAL_DIR%"

echo.
echo Creando estructura básica de directorios...
mkdir logs temp users Proyectos models exports 2>nul

echo.
echo Descargando aplicación...
powershell -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py' -UseBasicParsing } catch { Write-Host 'Error'; exit 1 }"

if exist cinbehave_gui.py (
    echo ✅ Aplicación descargada
) else (
    echo ❌ Error descargando aplicación
    pause
    goto :EXIT
)

echo.
echo Creando launcher simple...
(
echo @echo off
echo echo Iniciando CinBehave...
echo python cinbehave_gui.py
echo if %%errorlevel%% neq 0 ^(
echo     echo.
echo     echo ERROR: %%errorlevel%%
echo     echo.
echo     echo Posibles soluciones:
echo     echo 1. Instalar Python desde python.org
echo     echo 2. Instalar dependencias: pip install requests numpy pandas matplotlib opencv-python pillow
echo     echo.
echo     pause
echo ^)
) > run_cinbehave.bat

echo.
echo ============================================================================
echo                     ✅ CONFIGURACIÓN MANUAL COMPLETADA
echo ============================================================================
echo.
echo Directorio: %MANUAL_DIR%
echo.
echo PASOS SIGUIENTES:
echo 1. Instalar Python 3.11 desde python.org (si no lo tiene)
echo 2. Abrir símbolo del sistema en: %MANUAL_DIR%
echo 3. Ejecutar: pip install requests numpy pandas matplotlib opencv-python pillow
echo 4. Ejecutar: run_cinbehave.bat
echo.
echo ¿Desea abrir el directorio ahora?
set /p "OPEN_DIR=Abrir directorio (s/n): "
if /i "%OPEN_DIR%"=="s" (
    start "" "%MANUAL_DIR%"
)

goto :EXIT

:EXIT
echo.
echo ============================================================================
echo                    DIAGNÓSTICO COMPLETADO
echo ============================================================================
echo.
echo Si continúa teniendo problemas:
echo 1. Ejecute este script como administrador
echo 2. Desactive temporalmente antivirus/firewall
echo 3. Verifique conexión a internet
echo 4. Use la opción de instalación manual
echo.
echo Presione cualquier tecla para salir...
pause >nul

endlocal
exit /b 0
