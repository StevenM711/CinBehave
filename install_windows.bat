@echo off
setlocal EnableExtensions

rem ------------------------------------------------------------
rem CinBehave installer (ASCII only)
rem Works on Win10/11. No unicode, no colors.
rem Optional: set SKIP_SLEAP=1 before running to skip sleap/tensorflow.
rem ------------------------------------------------------------

set "APP_DIR=%USERPROFILE%\CinBehave"
set "VENV_DIR=%APP_DIR%\venv"
set "REQS_URL=https://raw.githubusercontent.com/StevenM711/CinBehave/main/requirements.txt"
set "REQS_FILE=%APP_DIR%\requirements.txt"

set "PY_VER=3.11.9"
set "PY_EXE=python-%PY_VER%-amd64.exe"
set "PY_URL=https://www.python.org/ftp/python/%PY_VER%/%PY_EXE%"
set "TMP_PY=%TEMP%\%PY_EXE%"

echo.
echo === CinBehave installer ===
echo Target dir: %APP_DIR%
echo.

if not exist "%APP_DIR%" (
  mkdir "%APP_DIR%" || (echo [ERROR] cannot create %APP_DIR% & goto :fail)
)

rem Check Python 3.11
py -3.11 -V >nul 2>&1
if errorlevel 1 (
  echo [INFO] Python 3.11 not found. Downloading and installing...
  call :download "%PY_URL%" "%TMP_PY%" || (echo [ERROR] download failed & goto :fail)
  start /wait "" "%TMP_PY%" /quiet InstallAllUsers=1 PrependPath=1 Include_pip=1
  if errorlevel 1 (echo [ERROR] Python installer failed & goto :fail)
  py -3.11 -V >nul 2>&1 || (echo [ERROR] Python 3.11 still not found after install & goto :fail)
) else (
  for /f "tokens=1,2*" %%A in ('py -3.11 -V 2^>nul') do echo [INFO] Detected %%A %%B %%C
)

rem Create venv
if not exist "%VENV_DIR%" (
  echo [INFO] Creating venv...
  py -3.11 -m venv "%VENV_DIR%" || (echo [ERROR] venv creation failed & goto :fail)
) else (
  echo [INFO] Reusing existing venv
)

call "%VENV_DIR%\Scripts\activate.bat" || (echo [ERROR] cannot activate venv & goto :fail)

echo [INFO] Upgrading pip...
python -m pip install --upgrade pip setuptools wheel || (echo [ERROR] pip upgrade failed & goto :fail)

echo [INFO] Fetching requirements.txt...
call :download "%REQS_URL%" "%REQS_FILE%" || (echo [ERROR] cannot download requirements.txt & goto :fail)

set "REQS_TO_USE=%REQS_FILE%"
if "%SKIP_SLEAP%"=="1" (
  echo [INFO] SKIP_SLEAP=1 -> filtering sleap and tensorflow
  set "REQS_LIGHT=%APP_DIR%\requirements_nosleap.txt"
  >"%REQS_LIGHT%" (
    for /f "usebackq delims=" %%L in ("%REQS_FILE%") do (
      echo %%L| findstr /i /b "sleap tensorflow" >nul
      if errorlevel 1 echo %%L
    )
  )
  set "REQS_TO_USE=%REQS_LIGHT%"
)

echo [INFO] Installing dependencies...
python -m pip install -r "%REQS_TO_USE%"
if errorlevel 1 (echo [ERROR] pip install failed & goto :fail)

echo.
echo === DONE ===
echo To use:
echo   1) "%VENV_DIR%\Scripts\activate.bat"
echo   2) python cinbehave_guii.py
echo.
pause
exit /b 0

:download
rem :download URL OUTFILE
set "URL=%~1"
set "OUT=%~2"
del /q "%OUT%" >nul 2>&1
curl -L -o "%OUT%" "%URL%" >nul 2>&1
if exist "%OUT%" exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%OUT%'" >nul 2>&1
if exist "%OUT%" exit /b 0
exit /b 1

:fail
echo.
echo ==== INSTALL FAILED ====
echo Open a terminal and run this BAT to see the full error.
echo ========================
echo.
pause
exit /b 1
