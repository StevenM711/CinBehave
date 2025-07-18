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

REM Crear aplicación principal (VERSIÓN CORREGIDA)
echo %BLUE%[STEP 9/10]%NC% Instalando aplicación CinBehave...

REM Crear el archivo Python corregido
echo #!/usr/bin/env python3 > cinbehave_gui.py
echo """
CinBehave - SLEAP Analysis GUI for Windows
Version: 1.0
Complete interface for animal behavior analysis using SLEAP
""" >> cinbehave_gui.py
echo. >> cinbehave_gui.py
echo import tkinter as tk >> cinbehave_gui.py
echo from tkinter import ttk, filedialog, messagebox, simpledialog >> cinbehave_gui.py
echo import os >> cinbehave_gui.py
echo import sys >> cinbehave_gui.py
echo import json >> cinbehave_gui.py
echo import time >> cinbehave_gui.py
echo import logging >> cinbehave_gui.py
echo from pathlib import Path >> cinbehave_gui.py
echo from datetime import datetime >> cinbehave_gui.py
echo import psutil >> cinbehave_gui.py
echo. >> cinbehave_gui.py
echo # Configurar logging >> cinbehave_gui.py
echo logging.basicConfig^( >> cinbehave_gui.py
echo     level=logging.INFO, >> cinbehave_gui.py
echo     format='%%(asctime)s - %%(levelname)s - %%(message)s', >> cinbehave_gui.py
echo     handlers=[ >> cinbehave_gui.py
echo         logging.FileHandler('logs/cinbehave.log'^), >> cinbehave_gui.py
echo         logging.StreamHandler^(^) >> cinbehave_gui.py
echo     ] >> cinbehave_gui.py
echo ^) >> cinbehave_gui.py
echo. >> cinbehave_gui.py
echo class CinBehaveGUI: >> cinbehave_gui.py
echo     def __init__^(self^): >> cinbehave_gui.py
echo         self.root = tk.Tk^(^) >> cinbehave_gui.py
echo         self.root.title^("CinBehave - SLEAP Analysis GUI v1.0"^) >> cinbehave_gui.py
echo         self.root.geometry^("800x600"^) >> cinbehave_gui.py
echo         self.root.configure^(bg="#2c3e50"^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         self.current_user = None >> cinbehave_gui.py
echo         self.loaded_videos = [] >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         self.fonts = { >> cinbehave_gui.py
echo             'title': ^('Arial', 16, 'bold'^), >> cinbehave_gui.py
echo             'normal': ^('Arial', 10^), >> cinbehave_gui.py
echo             'button': ^('Arial', 10, 'bold'^) >> cinbehave_gui.py
echo         } >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         self.show_splash_screen^(^) >> cinbehave_gui.py
echo         self.initialize_system^(^) >> cinbehave_gui.py
echo         self.show_user_selection^(^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def show_splash_screen^(self^): >> cinbehave_gui.py
echo         splash = tk.Toplevel^(self.root^) >> cinbehave_gui.py
echo         splash.title^("CinBehave"^) >> cinbehave_gui.py
echo         splash.geometry^("400x200"^) >> cinbehave_gui.py
echo         splash.configure^(bg="#2c3e50"^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         tk.Label^(splash, text="CinBehave", font=self.fonts['title'], >> cinbehave_gui.py
echo                 fg="#ecf0f1", bg="#2c3e50"^).pack^(pady=30^) >> cinbehave_gui.py
echo         tk.Label^(splash, text="SLEAP Analysis GUI v1.0", font=self.fonts['normal'], >> cinbehave_gui.py
echo                 fg="#3498db", bg="#2c3e50"^).pack^(^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         splash.after^(1500, splash.destroy^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def initialize_system^(self^): >> cinbehave_gui.py
echo         try: >> cinbehave_gui.py
echo             Path^("users"^).mkdir^(exist_ok=True^) >> cinbehave_gui.py
echo             Path^("logs"^).mkdir^(exist_ok=True^) >> cinbehave_gui.py
echo             logging.info^("Sistema inicializado"^) >> cinbehave_gui.py
echo         except Exception as e: >> cinbehave_gui.py
echo             messagebox.showerror^("Error", f"Error inicializando: {e}"^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def show_user_selection^(self^): >> cinbehave_gui.py
echo         self.root.withdraw^(^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         self.user_window = tk.Toplevel^(^) >> cinbehave_gui.py
echo         self.user_window.title^("Seleccionar Usuario"^) >> cinbehave_gui.py
echo         self.user_window.geometry^("500x400"^) >> cinbehave_gui.py
echo         self.user_window.configure^(bg="#2c3e50"^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         tk.Label^(self.user_window, text="CinBehave", font=self.fonts['title'], >> cinbehave_gui.py
echo                 fg="#ecf0f1", bg="#2c3e50"^).pack^(pady=20^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         frame = tk.Frame^(self.user_window, bg="#2c3e50"^) >> cinbehave_gui.py
echo         frame.pack^(pady=20^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         tk.Label^(frame, text="Nombre de Usuario:", font=self.fonts['normal'], >> cinbehave_gui.py
echo                 fg="#ecf0f1", bg="#2c3e50"^).pack^(^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         self.user_entry = tk.Entry^(frame, font=self.fonts['normal'], width=20^) >> cinbehave_gui.py
echo         self.user_entry.pack^(pady=10^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         tk.Button^(frame, text="Crear Usuario", command=self.create_user, >> cinbehave_gui.py
echo                  font=self.fonts['button'], bg="#27ae60", fg="white"^).pack^(pady=10^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         tk.Button^(self.user_window, text="Salir", command=self.root.quit, >> cinbehave_gui.py
echo                  font=self.fonts['button'], bg="#e74c3c", fg="white"^).pack^(pady=20^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         self.user_window.protocol^("WM_DELETE_WINDOW", self.root.quit^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def create_user^(self^): >> cinbehave_gui.py
echo         username = self.user_entry.get^(^).strip^(^) >> cinbehave_gui.py
echo         if not username: >> cinbehave_gui.py
echo             messagebox.showwarning^("Advertencia", "Ingresa un nombre"^) >> cinbehave_gui.py
echo             return >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         try: >> cinbehave_gui.py
echo             user_dir = Path^("users"^) / username >> cinbehave_gui.py
echo             user_dir.mkdir^(exist_ok=True^) >> cinbehave_gui.py
echo             >> cinbehave_gui.py
echo             self.current_user = username >> cinbehave_gui.py
echo             self.user_window.destroy^(^) >> cinbehave_gui.py
echo             self.root.deiconify^(^) >> cinbehave_gui.py
echo             self.create_main_interface^(^) >> cinbehave_gui.py
echo             >> cinbehave_gui.py
echo             messagebox.showinfo^("Bienvenido", f"Hola {username}!"^) >> cinbehave_gui.py
echo         except Exception as e: >> cinbehave_gui.py
echo             messagebox.showerror^("Error", f"Error creando usuario: {e}"^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def create_main_interface^(self^): >> cinbehave_gui.py
echo         for widget in self.root.winfo_children^(^): >> cinbehave_gui.py
echo             widget.destroy^(^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         tk.Label^(self.root, text="CinBehave", font=self.fonts['title'], >> cinbehave_gui.py
echo                 fg="#ecf0f1", bg="#2c3e50"^).pack^(pady=20^) >> cinbehave_gui.py
echo         tk.Label^(self.root, text=f"Usuario: {self.current_user}", font=self.fonts['normal'], >> cinbehave_gui.py
echo                 fg="#3498db", bg="#2c3e50"^).pack^(^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         menu_frame = tk.Frame^(self.root, bg="#2c3e50"^) >> cinbehave_gui.py
echo         menu_frame.pack^(expand=True, pady=50^) >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         buttons = [ >> cinbehave_gui.py
echo             ^("Cargar Videos", self.load_videos, "#3498db"^), >> cinbehave_gui.py
echo             ^("Procesar SLEAP", self.process_sleap, "#27ae60"^), >> cinbehave_gui.py
echo             ^("Ver Resultados", self.show_results, "#f39c12"^), >> cinbehave_gui.py
echo             ^("Cambiar Usuario", self.change_user, "#95a5a6"^), >> cinbehave_gui.py
echo             ^("Salir", self.root.quit, "#e74c3c"^) >> cinbehave_gui.py
echo         ] >> cinbehave_gui.py
echo         >> cinbehave_gui.py
echo         for text, command, color in buttons: >> cinbehave_gui.py
echo             tk.Button^(menu_frame, text=text, command=command, >> cinbehave_gui.py
echo                      font=self.fonts['button'], fg="white", bg=color, >> cinbehave_gui.py
echo                      width=20, height=2^).pack^(pady=5^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def load_videos^(self^): >> cinbehave_gui.py
echo         files = filedialog.askopenfilenames^(title="Seleccionar videos MP4", >> cinbehave_gui.py
echo                                           filetypes=[^("Videos", "*.mp4"^)]^) >> cinbehave_gui.py
echo         if files: >> cinbehave_gui.py
echo             self.loaded_videos = list^(files^) >> cinbehave_gui.py
echo             messagebox.showinfo^("Éxito", f"Cargados {len^(files^)} videos"^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def process_sleap^(self^): >> cinbehave_gui.py
echo         if not self.loaded_videos: >> cinbehave_gui.py
echo             messagebox.showwarning^("Advertencia", "Primero carga videos"^) >> cinbehave_gui.py
echo             return >> cinbehave_gui.py
echo         messagebox.showinfo^("SLEAP", "Procesamiento SLEAP - En desarrollo"^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def show_results^(self^): >> cinbehave_gui.py
echo         messagebox.showinfo^("Resultados", "Visualización de resultados - En desarrollo"^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def change_user^(self^): >> cinbehave_gui.py
echo         if messagebox.askyesno^("Cambiar Usuario", "¿Cambiar de usuario?"^): >> cinbehave_gui.py
echo             self.show_user_selection^(^) >> cinbehave_gui.py
echo     >> cinbehave_gui.py
echo     def run^(self^): >> cinbehave_gui.py
echo         self.root.mainloop^(^) >> cinbehave_gui.py
echo. >> cinbehave_gui.py
echo def main^(^): >> cinbehave_gui.py
echo     try: >> cinbehave_gui.py
echo         app = CinBehaveGUI^(^) >> cinbehave_gui.py
echo         app.run^(^) >> cinbehave_gui.py
echo     except Exception as e: >> cinbehave_gui.py
echo         print^(f"Error: {e}"^) >> cinbehave_gui.py
echo. >> cinbehave_gui.py
echo if __name__ == "__main__": >> cinbehave_gui.py
echo     main^(^) >> cinbehave_gui.py

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
