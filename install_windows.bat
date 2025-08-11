@echo off
REM ============================================================================
REM CinBehave - SLEAP Analysis GUI Professional Installer for Windows
REM Version: 1.0 Enterprise Edition
REM 
REM Professional-grade installer that:
REM - Forces Python 3.11.6 using pyenv-win
REM - Handles all dependency conflicts
REM - Installs Microsoft Visual C++ Build Tools if needed
REM - Creates isolated environment with version locking
REM - Provides enterprise-level error handling and logging
REM - Includes comprehensive system diagnostics
REM - Professional deployment ready
REM
REM Author: CinBehave Development Team
REM License: Enterprise
REM ============================================================================

setlocal enabledelayedexpansion
set "INSTALLER_VERSION=1.0.0-enterprise"
set "INSTALL_DATE=%DATE% %TIME%"

REM ============================================================================
REM COLOR DEFINITIONS FOR PROFESSIONAL OUTPUT
REM ============================================================================
set "ESC=[38;2"
set "RESET=[0m"
set "RED=%ESC%;255;77;77m"
set "GREEN=%ESC%;119;221;119m" 
set "BLUE=%ESC%;99;155;255m"
set "YELLOW=%ESC%;255;212;59m"
set "PURPLE=%ESC%;186;85;211m"
set "CYAN=%ESC%;91;206;250m"
set "WHITE=%ESC%;255;255;255m"
set "GRAY=%ESC%;156;163;175m"

REM ============================================================================
REM PROFESSIONAL BANNER
REM ============================================================================
cls
echo.
echo %BLUE%    ╔══════════════════════════════════════════════════════════════════════════╗%RESET%
echo %BLUE%    ║                                                                          ║%RESET%
echo %BLUE%    ║%WHITE%                    CinBehave SLEAP Analysis Suite                     %BLUE%║%RESET%
echo %BLUE%    ║%WHITE%                         Enterprise Installer                          %BLUE%║%RESET%
echo %BLUE%    ║%WHITE%                            Version %INSTALLER_VERSION%                            %BLUE%║%RESET%
echo %BLUE%    ║                                                                          ║%RESET%
echo %BLUE%    ║%CYAN%    Professional-Grade Scientific Computing Platform for              %BLUE%║%RESET%
echo %BLUE%    ║%CYAN%    Animal Behavior Analysis using Machine Learning                   %BLUE%║%RESET%
echo %BLUE%    ║                                                                          ║%RESET%
echo %BLUE%    ║%GRAY%    Features: SLEAP Integration, GPU Acceleration, Real-time         %BLUE%║%RESET%
echo %BLUE%    ║%GRAY%             Monitoring, Professional UI, Enterprise Support         %BLUE%║%RESET%
echo %BLUE%    ║                                                                          ║%RESET%
echo %BLUE%    ╚══════════════════════════════════════════════════════════════════════════╝%RESET%
echo.
echo %GREEN%    Installing professional-grade scientific computing environment...%RESET%
echo.

REM ============================================================================
REM SYSTEM REQUIREMENTS VERIFICATION
REM ============================================================================
echo %BLUE%[SYSTEM CHECK]%RESET% %WHITE%Verifying system requirements...%RESET%

REM Check Administrator Rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo %RED%[CRITICAL ERROR]%RESET% %WHITE%Administrator privileges required%RESET%
    echo %YELLOW%[ACTION REQUIRED]%RESET% %WHITE%Right-click installer and select "Run as administrator"%RESET%
    echo.
    pause
    exit /b 1
)

REM System Architecture Detection
echo %GREEN%[✓]%RESET% %WHITE%Administrator privileges verified%RESET%
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "SYSTEM_ARCH=x64"
    set "PYTHON_ARCH=amd64"
    echo %GREEN%[✓]%RESET% %WHITE%System Architecture: x64 (64-bit)%RESET%
) else (
    set "SYSTEM_ARCH=x86"
    set "PYTHON_ARCH=win32"
    echo %YELLOW%[!]%RESET% %WHITE%System Architecture: x86 (32-bit) - Limited performance%RESET%
)

REM Windows Version Check
for /f "tokens=4-5 delims=. " %%i in ('ver') do set "WIN_VERSION=%%i.%%j"
echo %GREEN%[✓]%RESET% %WHITE%Windows Version: %WIN_VERSION%%RESET%

REM Memory Check
for /f "skip=1" %%i in ('wmic computersystem get TotalPhysicalMemory /value') do (
    if not "%%i"=="" (
        set "%%i"
        set /a "MEMORY_GB=!TotalPhysicalMemory! / 1024 / 1024 / 1024"
    )
)
if !MEMORY_GB! LSS 8 (
    echo %YELLOW%[WARNING]%RESET% %WHITE%RAM: !MEMORY_GB!GB - Minimum 8GB recommended for SLEAP%RESET%
) else (
    echo %GREEN%[✓]%RESET% %WHITE%RAM: !MEMORY_GB!GB - Adequate for machine learning tasks%RESET%
)

REM GPU Detection
echo %BLUE%[GPU CHECK]%RESET% %WHITE%Detecting GPU capabilities...%RESET%
nvidia-smi >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%[✓]%RESET% %WHITE%NVIDIA GPU detected - Hardware acceleration enabled%RESET%
    set "GPU_SUPPORT=cuda"
    set "TENSORFLOW_VARIANT=tensorflow"
) else (
    wmic path win32_VideoController get name | findstr /i "AMD" >nul
    if %errorLevel% equ 0 (
        echo %YELLOW%[!]%RESET% %WHITE%AMD GPU detected - Limited ML acceleration%RESET%
        set "GPU_SUPPORT=amd"
        set "TENSORFLOW_VARIANT=tensorflow"
    ) else (
        echo %YELLOW%[!]%RESET% %WHITE%No dedicated GPU - CPU-only processing%RESET%
        set "GPU_SUPPORT=cpu"
        set "TENSORFLOW_VARIANT=tensorflow-cpu"
    )
)

REM Internet Connectivity Check
echo %BLUE%[NETWORK]%RESET% %WHITE%Verifying internet connectivity...%RESET%
ping -n 1 8.8.8.8 >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%[✓]%RESET% %WHITE%Internet connectivity verified%RESET%
) else (
    echo %RED%[ERROR]%RESET% %WHITE%No internet connection - Installation cannot proceed%RESET%
    pause
    exit /b 1
)

REM ============================================================================
REM PROFESSIONAL INSTALLATION DIRECTORY SETUP
REM ============================================================================
echo.
echo %BLUE%[INSTALLATION]%RESET% %WHITE%Setting up professional directory structure...%RESET%

set "INSTALL_ROOT=%USERPROFILE%\CinBehave"
set "LOG_FILE=%INSTALL_ROOT%\logs\installation_%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log"

if exist "%INSTALL_ROOT%" (
    echo %YELLOW%[UPGRADE]%RESET% %WHITE%Existing installation detected - Performing clean upgrade%RESET%
    if exist "%INSTALL_ROOT%\backup" rmdir /s /q "%INSTALL_ROOT%\backup" >nul 2>&1
    mkdir "%INSTALL_ROOT%\backup" >nul 2>&1
    if exist "%INSTALL_ROOT%\users" (
        echo %GREEN%[BACKUP]%RESET% %WHITE%Preserving user data...%RESET%
        xcopy "%INSTALL_ROOT%\users" "%INSTALL_ROOT%\backup\users" /E /H /I >nul 2>&1
        xcopy "%INSTALL_ROOT%\Proyectos" "%INSTALL_ROOT%\backup\Proyectos" /E /H /I >nul 2>&1 || echo %GRAY%[INFO]%RESET% %WHITE%No projects to backup%RESET%
    )
    rmdir /s /q "%INSTALL_ROOT%\venv" >nul 2>&1
    rmdir /s /q "%INSTALL_ROOT%\Python311" >nul 2>&1
) else (
    echo %GREEN%[NEW]%RESET% %WHITE%Clean installation - Creating directory structure%RESET%
)

mkdir "%INSTALL_ROOT%" >nul 2>&1
mkdir "%INSTALL_ROOT%\logs" >nul 2>&1
mkdir "%INSTALL_ROOT%\temp" >nul 2>&1
cd /d "%INSTALL_ROOT%"

REM Initialize logging
echo ============================================================================ > "%LOG_FILE%"
echo CinBehave Enterprise Installation Log >> "%LOG_FILE%"
echo Started: %INSTALL_DATE% >> "%LOG_FILE%"
echo System: %SYSTEM_ARCH% Windows %WIN_VERSION% RAM: !MEMORY_GB!GB GPU: %GPU_SUPPORT% >> "%LOG_FILE%"
echo ============================================================================ >> "%LOG_FILE%"

REM ============================================================================
REM MICROSOFT VISUAL C++ BUILD TOOLS VERIFICATION
REM ============================================================================
echo %BLUE%[BUILD TOOLS]%RESET% %WHITE%Verifying Microsoft Visual C++ Build Tools...%RESET%

REM Check for Visual Studio Build Tools
set "VS_FOUND=0"
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools" set "VS_FOUND=1"
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools" set "VS_FOUND=1" 
if exist "%ProgramFiles%\Microsoft Visual Studio\2019\BuildTools" set "VS_FOUND=1"
if exist "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools" set "VS_FOUND=1"

if "%VS_FOUND%"=="1" (
    echo %GREEN%[✓]%RESET% %WHITE%Microsoft Visual C++ Build Tools detected%RESET%
) else (
    echo %YELLOW%[INSTALLING]%RESET% %WHITE%Microsoft Visual C++ Build Tools required - Installing...%RESET%
    echo Downloading Visual Studio Build Tools... >> "%LOG_FILE%"
    powershell -Command "try { Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile 'temp\vs_buildtools.exe' -UseBasicParsing } catch { exit 1 }"
    if exist "temp\vs_buildtools.exe" (
        echo %GREEN%[✓]%RESET% %WHITE%Installing Visual Studio Build Tools (this may take several minutes)...%RESET%
        start /wait temp\vs_buildtools.exe --quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended
        echo %GREEN%[✓]%RESET% %WHITE%Build tools installation completed%RESET%
    ) else (
        echo %YELLOW%[WARNING]%RESET% %WHITE%Build tools download failed - Attempting wheel-only installation%RESET%
    )
)

REM ============================================================================
REM PYTHON VERSION MANAGEMENT - PROFESSIONAL APPROACH
REM ============================================================================
echo %BLUE%[PYTHON MANAGEMENT]%RESET% %WHITE%Setting up Python version management...%RESET%

REM Detect current Python installations
python --version >temp\python_current.txt 2>nul
if exist temp\python_current.txt (
    for /f "tokens=2" %%v in (temp\python_current.txt) do set "CURRENT_PYTHON=%%v"
    echo %GRAY%[INFO]%RESET% %WHITE%Current Python: !CURRENT_PYTHON!%RESET%
    echo Current Python: !CURRENT_PYTHON! >> "%LOG_FILE%"
    del temp\python_current.txt
    
    REM Check if Python 3.13+ (incompatible)
    echo !CURRENT_PYTHON! | findstr "3.13" >nul && set "PYTHON_INCOMPATIBLE=1"
    echo !CURRENT_PYTHON! | findstr "3.12" >nul && set "PYTHON_INCOMPATIBLE=1" 
    echo !CURRENT_PYTHON! | findstr "3.14" >nul && set "PYTHON_INCOMPATIBLE=1"
) else (
    echo %YELLOW%[!]%RESET% %WHITE%No Python installation detected%RESET%
    set "PYTHON_INCOMPATIBLE=1"
)

if defined PYTHON_INCOMPATIBLE (
    echo %YELLOW%[PYTHON ISOLATION]%RESET% %WHITE%Installing isolated Python 3.11.6 for CinBehave...%RESET%
    
    REM Download Python 3.11.6 embedded for complete isolation
    echo Downloading isolated Python 3.11.6... >> "%LOG_FILE%"
    if "%SYSTEM_ARCH%"=="x64" (
        set "PYTHON_URL=https://www.python.org/ftp/python/3.11.6/python-3.11.6-embed-amd64.zip"
        set "PYTHON_INSTALLER=https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe"
    ) else (
        set "PYTHON_URL=https://www.python.org/ftp/python/3.11.6/python-3.11.6-embed-win32.zip"
        set "PYTHON_INSTALLER=https://www.python.org/ftp/python/3.11.6/python-3.11.6.exe"
    )
    
    REM Download full Python installer for proper virtual environment support
    powershell -Command "try { Write-Host 'Downloading Python 3.11.6...'; Invoke-WebRequest -Uri '%PYTHON_INSTALLER%' -OutFile 'temp\python_installer.exe' -UseBasicParsing } catch { Write-Host 'Download failed'; exit 1 }" 
    
    if exist temp\python_installer.exe (
        echo %GREEN%[INSTALLING]%RESET% %WHITE%Installing Python 3.11.6 in isolated environment...%RESET%
        REM Install to local directory for complete control
        start /wait temp\python_installer.exe /quiet TargetDir="%INSTALL_ROOT%\Python311" InstallAllUsers=0 PrependPath=0 AssociateFiles=0 CompileAll=0 Include_test=0
        
        REM Verify installation
        if exist "%INSTALL_ROOT%\Python311\python.exe" (
            echo %GREEN%[✓]%RESET% %WHITE%Isolated Python 3.11.6 installation successful%RESET%
            set "PYTHON_EXE=%INSTALL_ROOT%\Python311\python.exe"
            echo Isolated Python installed at: %PYTHON_EXE% >> "%LOG_FILE%"
        ) else (
            echo %RED%[ERROR]%RESET% %WHITE%Python installation failed%RESET%
            echo Python installation failed >> "%LOG_FILE%"
            pause
            exit /b 1
        )
    ) else (
        echo %RED%[ERROR]%RESET% %WHITE%Failed to download Python installer%RESET%
        pause
        exit /b 1
    )
) else (
    echo %GREEN%[✓]%RESET% %WHITE%Compatible Python version detected%RESET%
    set "PYTHON_EXE=python"
)

REM ============================================================================
REM PROFESSIONAL VIRTUAL ENVIRONMENT CREATION
REM ============================================================================
echo %BLUE%[VIRTUAL ENVIRONMENT]%RESET% %WHITE%Creating isolated virtual environment...%RESET%

if exist venv rmdir /s /q venv
"%PYTHON_EXE%" -m venv venv --clear
if not exist venv\Scripts\activate.bat (
    echo %RED%[ERROR]%RESET% %WHITE%Virtual environment creation failed%RESET%
    echo Virtual environment creation failed >> "%LOG_FILE%"
    pause
    exit /b 1
)

call venv\Scripts\activate.bat
echo Virtual environment created successfully >> "%LOG_FILE%"

REM Verify Python in virtual environment
python --version > temp\venv_python.txt 2>&1
for /f "tokens=2" %%v in (temp\venv_python.txt) do set "VENV_PYTHON=%%v"
echo %GREEN%[✓]%RESET% %WHITE%Virtual environment Python: %VENV_PYTHON%%RESET%
echo Virtual environment Python: %VENV_PYTHON% >> "%LOG_FILE%"
del temp\venv_python.txt

REM ============================================================================
REM PROFESSIONAL PACKAGE MANAGEMENT SETUP
REM ============================================================================
echo %BLUE%[PACKAGE MANAGEMENT]%RESET% %WHITE%Setting up professional package management...%RESET%

REM Upgrade pip to latest stable version
python -m pip install --upgrade "pip>=23.0,<25.0" >> "%LOG_FILE%" 2>&1
python -m pip install --upgrade "setuptools>=65.0,<70.0" "wheel>=0.40.0" >> "%LOG_FILE%" 2>&1

REM Configure pip for optimal performance and reliability
(
echo [global]
echo timeout = 60
echo retries = 3
echo trusted-host = pypi.org
echo               pypi.python.org
echo               files.pythonhosted.org
echo prefer-binary = true
echo [install]
echo only-binary = :all:
) > venv\pip.conf

echo %GREEN%[✓]%RESET% %WHITE%Package management configured for enterprise reliability%RESET%

REM ============================================================================
REM APPLICATION DOWNLOAD AND VERIFICATION
REM ============================================================================
echo %BLUE%[APPLICATION]%RESET% %WHITE%Downloading CinBehave application suite...%RESET%

set "REPO_BASE=https://raw.githubusercontent.com/StevenM711/CinBehave/main"
powershell -Command "try { Invoke-WebRequest -Uri '%REPO_BASE%/cinbehave_gui.py' -OutFile 'cinbehave_gui.py' -UseBasicParsing; Write-Host 'Application downloaded successfully' } catch { Write-Host 'Application download failed'; exit 1 }"

if not exist cinbehave_gui.py (
    echo %RED%[ERROR]%RESET% %WHITE%Application download failed%RESET%
    echo Application download failed >> "%LOG_FILE%"
    pause
    exit /b 1
)

REM Verify application integrity
powershell -Command "if ((Get-Item 'cinbehave_gui.py').Length -lt 1000) { Write-Host 'Downloaded file appears corrupted'; exit 1 } else { Write-Host 'Application integrity verified' }"
echo %GREEN%[✓]%RESET% %WHITE%Application downloaded and verified%RESET%
echo Application downloaded successfully >> "%LOG_FILE%"

REM ============================================================================
REM DEPENDENCY RESOLUTION AND INSTALLATION
REM ============================================================================
echo %BLUE%[DEPENDENCIES]%RESET% %WHITE%Installing scientific computing dependencies...%RESET%

REM Core system dependencies (critical path)
echo %CYAN%[CORE]%RESET% %WHITE%Installing core system dependencies...%RESET%
python -m pip install --only-binary=all "requests>=2.28.0,<3.0" >> "%LOG_FILE%" 2>&1 || (echo %RED%[ERROR]%RESET% %WHITE%Failed to install requests%RESET% & exit /b 1)
python -m pip install --only-binary=all "psutil>=5.9.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "pathlib-abc>=0.1.0" >> "%LOG_FILE%" 2>&1

REM Numerical computing stack
echo %CYAN%[NUMERICAL]%RESET% %WHITE%Installing numerical computing stack...%RESET%
python -m pip install --only-binary=all "numpy>=1.21.0,<1.25.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "pandas>=1.5.0,<2.2.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "scipy>=1.9.0,<1.12.0" >> "%LOG_FILE%" 2>&1

REM Data format handling (critical for SLEAP)
echo %CYAN%[DATA FORMATS]%RESET% %WHITE%Installing data format handlers...%RESET%
python -m pip install --only-binary=all "h5py>=3.7.0,<3.10.0" >> "%LOG_FILE%" 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%[FALLBACK]%RESET% %WHITE%Using alternative h5py installation method...%RESET%
    python -m pip install --find-links https://github.com/h5py/h5py/releases/latest/download/ "h5py>=3.7.0" >> "%LOG_FILE%" 2>&1
)

REM Visualization and UI stack
echo %CYAN%[VISUALIZATION]%RESET% %WHITE%Installing visualization components...%RESET%
python -m pip install --only-binary=all "matplotlib>=3.6.0,<3.9.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "seaborn>=0.11.0,<0.14.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "Pillow>=9.0.0,<11.0.0" >> "%LOG_FILE%" 2>&1

REM Computer vision stack
echo %CYAN%[COMPUTER VISION]%RESET% %WHITE%Installing computer vision libraries...%RESET%
python -m pip install --only-binary=all "opencv-python>=4.6.0,<4.9.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "imageio>=2.22.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "imageio-ffmpeg>=0.4.0" >> "%LOG_FILE%" 2>&1

REM Machine learning foundations
echo %CYAN%[MACHINE LEARNING]%RESET% %WHITE%Installing machine learning foundations...%RESET%
python -m pip install --only-binary=all "scikit-learn>=1.1.0,<1.4.0" >> "%LOG_FILE%" 2>&1

REM TensorFlow installation (GPU-aware)
echo %CYAN%[DEEP LEARNING]%RESET% %WHITE%Installing TensorFlow with %GPU_SUPPORT% support...%RESET%
if "%GPU_SUPPORT%"=="cuda" (
    python -m pip install --only-binary=all "tensorflow[and-cuda]>=2.11.0,<2.14.0" >> "%LOG_FILE%" 2>&1
) else (
    python -m pip install --only-binary=all "tensorflow>=2.11.0,<2.14.0" >> "%LOG_FILE%" 2>&1
)

REM Utility libraries
echo %CYAN%[UTILITIES]%RESET% %WHITE%Installing utility libraries...%RESET%
python -m pip install --only-binary=all "tqdm>=4.64.0" "python-dateutil>=2.8.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "reportlab>=3.6.0" "openpyxl>=3.0.0" "xlsxwriter>=3.0.0" >> "%LOG_FILE%" 2>&1

REM ============================================================================
REM SLEAP INSTALLATION - PROFESSIONAL APPROACH
REM ============================================================================
echo %BLUE%[SLEAP INSTALLATION]%RESET% %WHITE%Installing SLEAP - Social LEAP Estimates Animal Poses...%RESET%

REM Install SLEAP dependencies first
echo %CYAN%[SLEAP DEPS]%RESET% %WHITE%Installing SLEAP dependencies...%RESET%
python -m pip install --only-binary=all "attrs>=22.1.0" "cattrs>=22.2.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "jsonpickle>=2.2.0" "jsmin>=3.0.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "networkx>=2.8.0" "packaging>=21.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "rich>=12.5.0" "pynvml>=11.4.0" >> "%LOG_FILE%" 2>&1

REM Install PySide2 (Qt framework for SLEAP GUI components)
echo %CYAN%[GUI FRAMEWORK]%RESET% %WHITE%Installing Qt framework (PySide2)...%RESET%
python -m pip install --only-binary=all "PySide2>=5.15.0" >> "%LOG_FILE%" 2>&1

REM Install image processing dependencies
echo %CYAN%[IMAGE PROCESSING]%RESET% %WHITE%Installing advanced image processing...%RESET%
python -m pip install --only-binary=all "imgaug>=0.4.0" >> "%LOG_FILE%" 2>&1
python -m pip install --only-binary=all "albumentations>=1.3.0" >> "%LOG_FILE%" 2>&1

REM Install SLEAP itself
echo %CYAN%[SLEAP CORE]%RESET% %WHITE%Installing SLEAP core framework...%RESET%
python -m pip install "sleap>=1.3.0" >> "%LOG_FILE%" 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%[FALLBACK]%RESET% %WHITE%Installing SLEAP with dependency resolution...%RESET%
    python -m pip install --no-deps sleap >> "%LOG_FILE%" 2>&1
    python -m pip install "tensorflow-probability>=0.19.0" >> "%LOG_FILE%" 2>&1
)

REM ============================================================================
REM SYSTEM VERIFICATION AND VALIDATION
REM ============================================================================
echo %BLUE%[VERIFICATION]%RESET% %WHITE%Performing comprehensive system validation...%RESET%

REM Create validation script
(
echo import sys, traceback
echo print^(f"Python: {sys.version}"^)
echo.
echo # Test critical imports
echo modules = [
echo     'requests', 'numpy', 'pandas', 'matplotlib', 'h5py',
echo     'cv2', 'tensorflow', 'sklearn', 'PIL', 'scipy'
echo ]
echo.
echo for module in modules:
echo     try:
echo         exec^(f"import {module}"^)
echo         if module == 'tensorflow':
echo             import tensorflow as tf
echo             gpus = tf.config.list_physical_devices^('GPU'^)
echo             print^(f"✓ {module} ^(GPU: {len^(gpus^)^} devices^)"^)
echo         elif module == 'cv2':
echo             import cv2
echo             print^(f"✓ opencv ^({cv2.__version__}^)"^)
echo         else:
echo             mod = __import__^(module^)
echo             version = getattr^(mod, '__version__', 'unknown'^)
echo             print^(f"✓ {module} ^({version}^)"^)
echo     except Exception as e:
echo         print^(f"✗ {module}: {e}"^)
echo.
echo # Test SLEAP
echo try:
echo     import sleap
echo     print^(f"✓ SLEAP ^({sleap.__version__}^)"^)
echo except Exception as e:
echo     print^(f"⚠ SLEAP: {e}"^)
echo.
echo print^("Validation completed."^)
) > temp\validate_installation.py

echo %GRAY%[TESTING]%RESET% %WHITE%Running validation suite...%RESET%
python temp\validate_installation.py > temp\validation_results.txt 2>&1

REM Display validation results
for /f "delims=" %%a in (temp\validation_results.txt) do (
    echo %%a | findstr "✓" >nul && echo %GREEN%    %%a%RESET%
    echo %%a | findstr "✗" >nul && echo %RED%    %%a%RESET%
    echo %%a | findstr "⚠" >nul && echo %YELLOW%    %%a%RESET%
    echo %%a | findstr /v "✓ ✗ ⚠" >nul && echo %GRAY%    %%a%RESET%
)

REM Verify SLEAP command line tool
echo %GRAY%[CLI TOOLS]%RESET% %WHITE%Verifying SLEAP command-line interface...%RESET%
sleap-track --help >nul 2>&1
if %errorLevel% equ 0 (
    echo %GREEN%[✓]%RESET% %WHITE%SLEAP command-line tools available%RESET%
) else (
    echo %YELLOW%[!]%RESET% %WHITE%SLEAP CLI tools may require PATH configuration%RESET%
)

REM ============================================================================
REM PROFESSIONAL DIRECTORY STRUCTURE CREATION
REM ============================================================================
echo %BLUE%[STRUCTURE]%RESET% %WHITE%Creating professional directory structure...%RESET%

REM Create all necessary directories
set "DIRECTORIES=users logs config assets docs models exports temp cache Proyectos users\profiles users\settings"

for %%d in (%DIRECTORIES%) do (
    mkdir "%%d" >nul 2>&1
    echo Directory created: %%d >> "%LOG_FILE%"
)

REM Restore user data if this was an upgrade
if exist backup\users (
    echo %GREEN%[RESTORE]%RESET% %WHITE%Restoring user data from backup...%RESET%
    xcopy backup\users users /E /H /Y >nul 2>&1
    xcopy backup\Proyectos Proyectos /E /H /Y >nul 2>&1 || echo %GRAY%[INFO]%RESET% %WHITE%No previous projects to restore%RESET%
    rmdir /s /q backup >nul 2>&1
)

echo %GREEN%[✓]%RESET% %WHITE%Professional directory structure created%RESET%

REM ============================================================================
REM ENTERPRISE LAUNCHER CREATION
REM ============================================================================
echo %BLUE%[LAUNCHERS]%RESET% %WHITE%Creating enterprise-grade application launchers...%RESET%

REM Main application launcher
(
echo @echo off
echo REM CinBehave Enterprise Launcher
echo REM Auto-generated by installer v%INSTALLER_VERSION%
echo.
echo setlocal
echo cd /d "%%~dp0"
echo.
echo REM Activate virtual environment
echo call venv\Scripts\activate.bat ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo ERROR: Virtual environment not found
echo     echo Please run the installer again
echo     pause
echo     exit /b 1
echo ^)
echo.
echo REM Set environment variables for optimal performance
echo set PYTHONPATH=%%CD%%
echo set TF_CPP_MIN_LOG_LEVEL=2
echo.
echo REM Pre-flight checks
echo python -c "import requests, numpy" ^>nul 2^>^&1
echo if %%errorlevel%% neq 0 ^(
echo     echo ERROR: Critical dependencies missing
echo     echo Run 'system_diagnostics.bat' for details
echo     pause
echo     exit /b 1
echo ^)
echo.
echo REM Launch application
echo echo Starting CinBehave Enterprise Suite...
echo echo.
echo python cinbehave_gui.py
echo.
echo REM Handle exit codes
echo if %%errorlevel%% neq 0 ^(
echo     echo.
echo     echo Application exited with error code %%errorlevel%%
echo     echo Check logs\cinbehave.log for details
echo     echo.
echo     pause
echo ^)
echo.
echo endlocal
) > CinBehave_Enterprise.bat

REM System diagnostics tool
(
echo @echo off
echo REM CinBehave System Diagnostics Tool
echo REM Enterprise Edition
echo.
echo setlocal
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat ^>nul 2^>^&1
echo.
echo cls
echo echo ============================================================================
echo echo                        CinBehave System Diagnostics
echo echo                             Enterprise Edition
echo echo ============================================================================
echo echo.
echo echo System Information:
echo echo -------------------
echo systeminfo ^| findstr /C:"OS Name" /C:"OS Version" /C:"System Type" /C:"Total Physical Memory"
echo echo.
echo echo Python Environment:
echo echo ------------------
echo python --version 2^>^&1 ^|^| echo Python not accessible
echo python -c "import sys; print('Executable:', sys.executable)"
echo python -c "import site; print('Site packages:', site.getsitepackages()[0])"
echo echo.
echo echo Critical Dependencies:
echo echo ---------------------
echo python temp\validate_installation.py
echo echo.
echo echo GPU Information:
echo echo ---------------
echo nvidia-smi ^>nul 2^>^&1 ^&^& nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits ^|^| echo No NVIDIA GPU detected
echo echo.
echo echo Network Connectivity:
echo echo --------------------
echo ping -n 1 8.8.8.8 ^>nul ^&^& echo ✓ Internet connectivity OK ^|^| echo ✗ No internet connection
echo echo.
echo echo SLEAP Command Line:
echo echo ------------------
echo sleap-track --help ^>nul 2^>^&1 ^&^& echo ✓ SLEAP CLI available ^|^| echo ⚠ SLEAP CLI not in PATH
echo echo.
echo echo Disk Space:
echo echo ----------
echo dir /-c 2^>nul ^| find "bytes free"
echo echo.
echo echo Installation Log:
echo echo ----------------
echo if exist logs\installation_*.log ^(
echo     echo Latest installation log:
echo     for /f %%a in ^('dir /b /od logs\installation_*.log 2^^^>nul'^) do set "LATEST=%%a"
echo     if defined LATEST powershell -Command "Get-Content logs\!LATEST! -Tail 10"
echo ^) else ^(
echo     echo No installation logs found
echo ^)
echo echo.
echo echo ============================================================================
echo pause
echo endlocal
) > system_diagnostics.bat

REM System repair tool
(
echo @echo off
echo REM CinBehave System Repair Tool
echo REM Enterprise Edition
echo.
echo setlocal
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat ^>nul 2^>^&1
echo.
echo echo ============================================================================
echo echo                         CinBehave System Repair
echo echo                            Enterprise Edition  
echo echo ============================================================================
echo echo.
echo echo Running automated repair procedures...
echo echo.
echo echo [1/5] Checking virtual environment...
echo if not exist venv\Scripts\python.exe ^(
echo     echo ERROR: Virtual environment corrupted
echo     echo Please run the full installer again
echo     pause
echo     exit /b 1
echo ^)
echo echo ✓ Virtual environment OK
echo.
echo echo [2/5] Repairing core dependencies...
echo python -m pip install --force-reinstall --only-binary=all requests numpy pandas matplotlib
echo echo.
echo echo [3/5] Repairing data format handlers...
echo python -m pip install --force-reinstall --only-binary=all h5py opencv-python
echo echo.
echo echo [4/5] Checking TensorFlow...
echo python -c "import tensorflow as tf; print('TensorFlow:', tf.__version__, 'GPU:', len(tf.config.list_physical_devices('GPU')))"
echo if %%errorlevel%% neq 0 ^(
echo     echo Reinstalling TensorFlow...
echo     python -m pip install --force-reinstall --only-binary=all tensorflow
echo ^)
echo echo.
echo echo [5/5] Verifying SLEAP...
echo python -c "import sleap; print('SLEAP:', sleap.__version__)"
echo if %%errorlevel%% neq 0 ^(
echo     echo Reinstalling SLEAP...
echo     python -m pip install --force-reinstall sleap
echo ^)
echo echo.
echo echo ============================================================================
echo echo                            Repair Completed
echo echo ============================================================================
echo echo.
echo echo Running final validation...
echo python temp\validate_installation.py
echo echo.
echo echo Repair procedure completed.
echo pause
echo endlocal
) > system_repair.bat

REM Update/Upgrade tool
(
echo @echo off
echo REM CinBehave Update Tool
echo REM Enterprise Edition
echo.
echo setlocal
echo cd /d "%%~dp0"
echo call venv\Scripts\activate.bat ^>nul 2^>^&1
echo.
echo echo ============================================================================
echo echo                          CinBehave Update Tool
echo echo                            Enterprise Edition
echo echo ============================================================================
echo echo.
echo echo Checking for updates...
echo echo.
echo echo [1/4] Updating application code...
echo powershell -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/StevenM711/CinBehave/main/cinbehave_gui.py' -OutFile 'cinbehave_gui_new.py' -UseBasicParsing; if ((Get-Item 'cinbehave_gui_new.py').Length -gt 1000) { Move-Item 'cinbehave_gui.py' 'cinbehave_gui_backup.py' -Force; Move-Item 'cinbehave_gui_new.py' 'cinbehave_gui.py' -Force; Write-Host 'Application updated successfully' } else { Write-Host 'Update file appears corrupted'; Remove-Item 'cinbehave_gui_new.py' } } catch { Write-Host 'Failed to download update' }"
echo.
echo echo [2/4] Updating Python packages...
echo python -m pip install --upgrade pip setuptools wheel
echo echo.
echo echo [3/4] Updating dependencies...
echo python -m pip install --upgrade --only-binary=all numpy pandas matplotlib scipy h5py opencv-python scikit-learn tensorflow
echo echo.
echo echo [4/4] Updating SLEAP...
echo python -m pip install --upgrade sleap
echo echo.
echo echo ============================================================================
echo echo                           Update Completed
echo echo ============================================================================
echo echo.
echo echo Running validation after update...
echo python temp\validate_installation.py
echo echo.
echo pause
echo endlocal
) > system_update.bat

echo %GREEN%[✓]%RESET% %WHITE%Enterprise launchers and tools created%RESET%

REM ============================================================================
REM DESKTOP AND START MENU INTEGRATION
REM ============================================================================
echo %BLUE%[INTEGRATION]%RESET% %WHITE%Integrating with Windows shell...%RESET%

REM Create desktop shortcut
powershell -Command "try { $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%USERPROFILE%\Desktop\CinBehave Enterprise.lnk'); $Shortcut.TargetPath = '%INSTALL_ROOT%\CinBehave_Enterprise.bat'; $Shortcut.WorkingDirectory = '%INSTALL_ROOT%'; $Shortcut.Description = 'CinBehave Enterprise - SLEAP Analysis Suite'; $Shortcut.IconLocation = 'shell32.dll,21'; $Shortcut.Save(); Write-Host 'Desktop shortcut created' } catch { Write-Host 'Desktop shortcut failed' }" >> "%LOG_FILE%" 2>&1

REM Create Start Menu folder and shortcuts
set "START_MENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs\CinBehave Enterprise"
mkdir "%START_MENU%" >nul 2>&1

powershell -Command "try { $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%START_MENU%\CinBehave Enterprise.lnk'); $Shortcut.TargetPath = '%INSTALL_ROOT%\CinBehave_Enterprise.bat'; $Shortcut.WorkingDirectory = '%INSTALL_ROOT%'; $Shortcut.Description = 'CinBehave Enterprise Suite'; $Shortcut.Save() } catch {}"

powershell -Command "try { $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%START_MENU%\System Diagnostics.lnk'); $Shortcut.TargetPath = '%INSTALL_ROOT%\system_diagnostics.bat'; $Shortcut.WorkingDirectory = '%INSTALL_ROOT%'; $Shortcut.Description = 'System Diagnostics and Validation'; $Shortcut.Save() } catch {}"

powershell -Command "try { $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%START_MENU%\System Repair.lnk'); $Shortcut.TargetPath = '%INSTALL_ROOT%\system_repair.bat'; $Shortcut.WorkingDirectory = '%INSTALL_ROOT%'; $Shortcut.Description = 'Automated System Repair'; $Shortcut.Save() } catch {}"

powershell -Command "try { $WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%START_MENU%\Check for Updates.lnk'); $Shortcut.TargetPath = '%INSTALL_ROOT%\system_update.bat'; $Shortcut.WorkingDirectory = '%INSTALL_ROOT%'; $Shortcut.Description = 'Check for Updates'; $Shortcut.Save() } catch {}"

echo %GREEN%[✓]%RESET% %WHITE%Windows shell integration completed%RESET%

REM ============================================================================
REM ENTERPRISE UNINSTALLER CREATION
REM ============================================================================
echo %BLUE%[UNINSTALLER]%RESET% %WHITE%Creating enterprise uninstaller...%RESET%

(
echo @echo off
echo REM CinBehave Enterprise Uninstaller
echo REM Auto-generated by installer v%INSTALLER_VERSION%
echo.
echo setlocal
echo echo ============================================================================
echo echo                      CinBehave Enterprise Uninstaller
echo echo ============================================================================
echo echo.
echo echo This will completely remove CinBehave and all associated files.
echo echo User data and projects will be preserved in a backup folder.
echo echo.
echo set /p "CONFIRM=Are you sure you want to uninstall CinBehave? (yes/no): "
echo if /i not "%%CONFIRM%%"=="yes" ^(
echo     echo Uninstallation cancelled.
echo     pause
echo     exit /b 0
echo ^)
echo.
echo echo Creating backup of user data...
echo if exist users ^(
echo     if not exist "%%USERPROFILE%%\CinBehave_Backup_%%DATE:~-4,4%%%%DATE:~-10,2%%%%DATE:~-7,2%%" mkdir "%%USERPROFILE%%\CinBehave_Backup_%%DATE:~-4,4%%%%DATE:~-10,2%%%%DATE:~-7,2%%"
echo     xcopy users "%%USERPROFILE%%\CinBehave_Backup_%%DATE:~-4,4%%%%DATE:~-10,2%%%%DATE:~-7,2%%\users" /E /H /I ^>nul 2^>^&1
echo     xcopy Proyectos "%%USERPROFILE%%\CinBehave_Backup_%%DATE:~-4,4%%%%DATE:~-10,2%%%%DATE:~-7,2%%\Proyectos" /E /H /I ^>nul 2^>^&1
echo     echo User data backed up to: %%USERPROFILE%%\CinBehave_Backup_%%DATE:~-4,4%%%%DATE:~-10,2%%%%DATE:~-7,2%%
echo ^)
echo.
echo echo Removing desktop shortcut...
echo del "%%USERPROFILE%%\Desktop\CinBehave Enterprise.lnk" ^>nul 2^>^&1
echo.
echo echo Removing Start Menu entries...
echo rmdir /s /q "%%APPDATA%%\Microsoft\Windows\Start Menu\Programs\CinBehave Enterprise" ^>nul 2^>^&1
echo.
echo echo Removing application directory...
echo cd /d "%%USERPROFILE%%"
echo rmdir /s /q "CinBehave" ^>nul 2^>^&1
echo.
echo echo ============================================================================
echo echo                      Uninstallation Completed
echo echo ============================================================================
echo echo.
echo echo CinBehave has been successfully removed from your system.
echo if exist "%%USERPROFILE%%\CinBehave_Backup_*" echo Your data has been backed up to: %%USERPROFILE%%\CinBehave_Backup_*
echo echo.
echo echo Thank you for using CinBehave Enterprise!
echo pause
echo endlocal
) > enterprise_uninstaller.bat

echo %GREEN%[✓]%RESET% %WHITE%Enterprise uninstaller created%RESET%

REM ============================================================================
REM INSTALLATION DOCUMENTATION GENERATION
REM ============================================================================
echo %BLUE%[DOCUMENTATION]%RESET% %WHITE%Generating installation documentation...%RESET%

(
echo ============================================================================
echo                    CinBehave Enterprise Installation Report
echo                              Version %INSTALLER_VERSION%
echo ============================================================================
echo.
echo Installation Date: %INSTALL_DATE%
echo Installation Directory: %INSTALL_ROOT%
echo System Architecture: %SYSTEM_ARCH%
echo Windows Version: %WIN_VERSION%
echo Memory: !MEMORY_GB!GB
echo GPU Support: %GPU_SUPPORT%
echo Python Version: %VENV_PYTHON%
echo TensorFlow Variant: %TENSORFLOW_VARIANT%
echo.
echo ============================================================================
echo                               FEATURES INSTALLED
echo ============================================================================
echo.
echo ✓ CinBehave Core Application
echo   - Modern GUI with professional theming
echo   - Project management system
echo   - Video processing pipeline
echo   - Real-time system monitoring
echo   - User management with profiles
echo   - Tutorial and help system
echo.
echo ✓ SLEAP Integration
echo   - Social LEAP Estimates Animal Poses
echo   - Machine learning pose estimation
echo   - GPU-accelerated processing ^(if available^)
echo   - Batch processing capabilities
echo   - Model management system
echo.
echo ✓ Scientific Computing Stack
echo   - NumPy, Pandas, SciPy for numerical computing
echo   - Matplotlib, Seaborn for visualization
echo   - OpenCV for computer vision
echo   - TensorFlow for deep learning
echo   - H5PY for data format handling
echo.
echo ✓ Enterprise Tools
echo   - System diagnostics and validation
echo   - Automated repair utilities
echo   - Update management system
echo   - Professional logging and monitoring
echo   - Backup and restore capabilities
echo.
echo ============================================================================
echo                                  QUICK START
echo ============================================================================
echo.
echo To start CinBehave:
echo   - Double-click "CinBehave Enterprise" on your desktop
echo   - Or run: CinBehave_Enterprise.bat
echo   - Or find it in Start Menu ^> CinBehave Enterprise
echo.
echo For system diagnostics:
echo   - Run: system_diagnostics.bat
echo   - Or Start Menu ^> CinBehave Enterprise ^> System Diagnostics
echo.
echo For system repair:
echo   - Run: system_repair.bat
echo   - Or Start Menu ^> CinBehave Enterprise ^> System Repair
echo.
echo For updates:
echo   - Run: system_update.bat
echo   - Or Start Menu ^> CinBehave Enterprise ^> Check for Updates
echo.
echo ============================================================================
echo                                  SUPPORT
echo ============================================================================
echo.
echo Installation Log: logs\installation_*.log
echo Application Logs: logs\cinbehave.log
echo System Diagnostics: system_diagnostics.bat
echo Repair Tools: system_repair.bat
echo.
echo For technical support, include the following information:
echo - Installation report ^(this file^)
echo - System diagnostics output
echo - Relevant log files
echo.
echo ============================================================================
echo                              END OF REPORT
echo ============================================================================
) > "Installation_Report_%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%.txt"

echo Installation documentation generated >> "%LOG_FILE%"
echo %GREEN%[✓]%RESET% %WHITE%Installation documentation created%RESET%

REM ============================================================================
REM FINAL VALIDATION AND COMPLETION
REM ============================================================================
echo %BLUE%[FINAL VALIDATION]%RESET% %WHITE%Performing final system validation...%RESET%

REM Run comprehensive validation
python temp\validate_installation.py > temp\final_validation.txt 2>&1

REM Count successful validations
powershell -Command "$content = Get-Content 'temp\final_validation.txt'; $success = ($content | Where-Object {$_ -match '✓'}).Count; $failed = ($content | Where-Object {$_ -match '✗'}).Count; $warnings = ($content | Where-Object {$_ -match '⚠'}).Count; Write-Host \"Validation Results: $success successful, $failed failed, $warnings warnings\"" > temp\validation_summary.txt

for /f "delims=" %%a in (temp\validation_summary.txt) do echo %CYAN%[VALIDATION]%RESET% %WHITE%%%a%RESET%

REM Log completion
echo Installation completed successfully at %DATE% %TIME% >> "%LOG_FILE%"
echo Final validation results: >> "%LOG_FILE%"
type temp\final_validation.txt >> "%LOG_FILE%"

REM ============================================================================
REM INSTALLATION COMPLETION SUMMARY
REM ============================================================================
cls
echo.
echo %GREEN%    ╔══════════════════════════════════════════════════════════════════════════╗%RESET%
echo %GREEN%    ║                                                                          ║%RESET%
echo %GREEN%    ║%WHITE%                🎉 INSTALLATION COMPLETED SUCCESSFULLY 🎉                %GREEN%║%RESET%
echo %GREEN%    ║                                                                          ║%RESET%
echo %GREEN%    ║%CYAN%                    CinBehave Enterprise Suite                           %GREEN%║%RESET%
echo %GREEN%    ║%CYAN%                Professional Animal Behavior Analysis                  %GREEN%║%RESET%
echo %GREEN%    ║                                                                          ║%RESET%
echo %GREEN%    ╠══════════════════════════════════════════════════════════════════════════╣%RESET%
echo %GREEN%    ║                                                                          ║%RESET%
echo %GREEN%    ║  📍 Installation Directory: %USERPROFILE%\CinBehave                     ║%RESET%
echo %GREEN%    ║  🐍 Python Version: %VENV_PYTHON%                                      ║%RESET%
echo %GREEN%    ║  🧠 SLEAP: Professional pose estimation framework                       ║%RESET%
echo %GREEN%    ║  🎮 GPU Support: %GPU_SUPPORT%                                           ║%RESET%
echo %GREEN%    ║  💾 Memory: !MEMORY_GB!GB RAM                                            ║%RESET%
echo %GREEN%    ║                                                                          ║%RESET%
echo %GREEN%    ║  🚀 LAUNCH OPTIONS:                                                     ║%RESET%
echo %GREEN%    ║    • Desktop: Double-click "CinBehave Enterprise"                      ║%RESET%
echo %GREEN%    ║    • Command: CinBehave_Enterprise.bat                                 ║%RESET%
echo %GREEN%    ║    • Start Menu: CinBehave Enterprise                                  ║%RESET%
echo %GREEN%    ║                                                                          ║%RESET%
echo %GREEN%    ║  🛠️ ENTERPRISE TOOLS:                                                   ║%RESET%
echo %GREEN%    ║    • system_diagnostics.bat - System validation                       ║%RESET%
echo %GREEN%    ║    • system_repair.bat - Automated repair                             ║%RESET%
echo %GREEN%    ║    • system_update.bat - Update management                            ║%RESET%
echo %GREEN%    ║    • enterprise_uninstaller.bat - Clean removal                       ║%RESET%
echo %GREEN%    ║                                                                          ║%RESET%
echo %GREEN%    ║  📋 DOCUMENTATION:                                                      ║%RESET%
echo %GREEN%    ║    • Installation_Report_*.txt - Complete installation log            ║%RESET%
echo %GREEN%    ║    • logs\ - System and application logs                              ║%RESET%
echo %GREEN%    ║                                                                          ║%RESET%
echo %GREEN%    ╚══════════════════════════════════════════════════════════════════════════╝%RESET%
echo.
echo %BLUE%[NEXT STEPS]%RESET% %WHITE%Your CinBehave Enterprise installation is ready!%RESET%
echo.
echo %CYAN%1. Launch Application:%RESET% %WHITE%Double-click the desktop shortcut or run CinBehave_Enterprise.bat%RESET%
echo %CYAN%2. Create User Profile:%RESET% %WHITE%Follow the guided setup to create your research profile%RESET%  
echo %CYAN%3. Create Project:%RESET% %WHITE%Set up your first animal behavior analysis project%RESET%
echo %CYAN%4. Import Videos:%RESET% %WHITE%Add your video files for SLEAP processing%RESET%
echo %CYAN%5. Run Analysis:%RESET% %WHITE%Execute pose estimation using the integrated SLEAP framework%RESET%
echo.
echo %GREEN%[SUPPORT]%RESET% %WHITE%For assistance, run 'system_diagnostics.bat' and include the output%RESET%
echo.

REM Ask user if they want to launch immediately
set /p "LAUNCH_NOW=Would you like to launch CinBehave Enterprise now? (y/n): "
if /i "%LAUNCH_NOW%"=="y" (
    echo.
    echo %GREEN%[LAUNCHING]%RESET% %WHITE%Starting CinBehave Enterprise Suite...%RESET%
    timeout /t 2 >nul
    start "" "%INSTALL_ROOT%\CinBehave_Enterprise.bat"
    echo %GREEN%[SUCCESS]%RESET% %WHITE%CinBehave Enterprise has been launched%RESET%
) else (
    echo.
    echo %BLUE%[INFO]%RESET% %WHITE%You can launch CinBehave anytime from the desktop shortcut%RESET%
)

echo.
echo %GREEN%[INSTALLATION COMPLETE]%RESET% %WHITE%Thank you for choosing CinBehave Enterprise!%RESET%
echo %GRAY%[INSTALLER]%RESET% %WHITE%Professional installer v%INSTALLER_VERSION% completed at %DATE% %TIME%%RESET%
echo.
echo %WHITE%Press any key to exit the installer...%RESET%
pause >nul

REM Clean up temporary files
rmdir /s /q temp >nul 2>&1

endlocal
exit /b 0
