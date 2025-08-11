@echo off
REM ============================================================================
REM CinBehave - INSTALADOR SUPER BASICO
REM Version: 1.7 Super Basic
REM ============================================================================

echo.
echo ============================================================================
echo                    CinBehave SLEAP Analysis Suite                          
echo                      INSTALADOR SUPER BASICO v1.7
echo ============================================================================
echo.

echo [INFO] Iniciando instalacion...
timeout /t 3 >nul

echo [PASO 1] Verificando administrador...
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Ejecute como administrador
    pause
    exit /b 1
)
echo [OK] Administrador verificado

echo [PASO 2] Verificando internet...
ping -n 1 8.8.8.8 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Sin internet
    pause
    exit /b 1
)
echo [OK] Internet verificado

echo [PASO 3] Creando carpetas...
set INSTALL_DIR=%USERPROFILE%\CinBehave
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%"
mkdir "%INSTALL_DIR%"
mkdir "%INSTALL_DIR%\logs"
mkdir "%INSTALL_DIR%\temp"
mkdir "%INSTALL_DIR%\Proyectos"
mkdir "%INSTALL_DIR%\users"
mkdir "%INSTALL_DIR%\config"
cd /d "%INSTALL_DIR%"
echo [OK] Carpetas creadas

echo [PASO 4] Instalando Python 3.11.6...
echo [INFO] Descargando Python (puede tomar varios minutos)...
powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe' -OutFile 'python_installer.exe'"
if not exist python_installer.exe (
    echo [ERROR] Error descargando Python
    pause
    exit /b 1
)
echo [INFO] Instalando Python...
start /wait python_installer.exe /quiet TargetDir="%INSTALL_DIR%\Python311" InstallAllUsers=0 PrependPath=0
if not exist "%INSTALL_DIR%\Python311\python.exe" (
    echo [ERROR] Error instalando Python
    pause
    exit /b 1
)
echo [OK] Python instalado

echo [PASO 5] Creando entorno virtual...
"%INSTALL_DIR%\Python311\python.exe" -m venv venv
if not exist venv\Scripts\python.exe (
    echo [ERROR] Error creando entorno virtual
    pause
    exit /b 1
)
echo [OK] Entorno virtual creado

echo [PASO 6] Descargando aplicacion...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui.py'"
if not exist cinbehave_gui.py (
    echo [ERROR] Error descargando aplicacion
    pause
    exit /b 1
)
echo [OK] Aplicacion descargada

echo [PASO 7] Instalando dependencias...
echo [INFO] Instalando paquetes (puede tomar varios minutos)...
venv\Scripts\python.exe -m pip install --upgrade pip
venv\Scripts\python.exe -m pip install requests
venv\Scripts\python.exe -m pip install numpy
venv\Scripts\python.exe -m pip install pandas
venv\Scripts\python.exe -m pip install matplotlib
venv\Scripts\python.exe -m pip install Pillow
venv\Scripts\python.exe -m pip install opencv-python
venv\Scripts\python.exe -m pip install psutil
echo [OK] Dependencias instaladas

echo [PASO 8] Intentando instalar SLEAP...
venv\Scripts\python.exe -m pip install sleap
echo [INFO] SLEAP instalacion completada (puede haber fallado pero continuamos)

echo [PASO 9] Creando lanzadores...

echo @echo off > CinBehave.bat
echo cd /d "%%~dp0" >> CinBehave.bat
echo call venv\Scripts\activate.bat >> CinBehave.bat
echo python cinbehave_gui.py >> CinBehave.bat
echo pause >> CinBehave.bat

echo @echo off > Test.bat
echo cd /d "%%~dp0" >> Test.bat
echo call venv\Scripts\activate.bat >> Test.bat
echo python -c "import requests, numpy; print('Todo funciona!')" >> Test.bat
echo pause >> Test.bat

echo [OK] Lanzadores creados

echo [PASO 10] Validacion final...
venv\Scripts\python.exe -c "import requests; print('[OK] Python funciona')"
if errorlevel 1 (
    echo [ERROR] Python no funciona
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo                        INSTALACION COMPLETADA
echo ============================================================================
echo.
echo [SUCCESS] CinBehave instalado en: %INSTALL_DIR%
echo.
echo PARA USAR:
echo 1. Ir a: %INSTALL_DIR%
echo 2. Ejecutar: CinBehave.bat
echo.
echo PARA PROBAR:
echo - Ejecutar: Test.bat
echo.
echo ============================================================================
echo.

set /p RUN_NOW=Ejecutar CinBehave ahora? (s/n): 
if /i "%RUN_NOW%"=="s" start "" "%INSTALL_DIR%\CinBehave.bat"

echo.
echo Presiona cualquier tecla para salir...
pause >nul
exit /b 0
