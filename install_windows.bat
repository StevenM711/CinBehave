@echo off
REM CinBehave - SLEAP Analysis GUI Installer for Windows
REM Version: 1.0
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

REM Crear requirements.txt
echo %BLUE%[STEP 8/10]%NC% Creando archivo de dependencias...
(
echo # Core dependencies
echo numpy>=1.21.0
echo pandas>=1.3.0
echo matplotlib>=3.5.0
echo seaborn>=0.11.0
echo scipy>=1.7.0
echo scikit-learn>=1.0.0
echo opencv-python>=4.5.0
echo psutil>=5.8.0
echo reportlab>=3.6.0
echo fpdf2>=2.5.0
echo python-dateutil>=2.8.0
echo tqdm>=4.62.0
echo pillow>=9.0.0
echo # Video processing
echo imageio>=2.13.0
echo imageio-ffmpeg>=0.4.0
echo # Data handling
echo openpyxl>=3.0.0
echo xlsxwriter>=3.0.0
echo h5py>=3.6.0
echo # GUI enhancements
echo customtkinter>=5.0.0
) > requirements.txt

REM Instalar dependencias
echo %BLUE%[STEP 9/10]%NC% Instalando dependencias Python...
echo %GREEN%[INFO]%NC% Esto puede tomar varios minutos...
python -m pip install -r requirements.txt

REM Crear aplicación principal
echo %BLUE%[STEP 10/10]%NC% Instalando aplicación CinBehave...

REM Crear el archivo principal
(
echo import tkinter as tk
echo from tkinter import ttk, filedialog, messagebox, simpledialog
echo import os
echo import sys
echo import shutil
echo import subprocess
echo import threading
echo import json
echo import time
echo import psutil
echo import logging
echo from pathlib import Path
echo from datetime import datetime
echo import numpy as np
echo from PIL import Image, ImageTk
echo import matplotlib.pyplot as plt
echo from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
echo from matplotlib.figure import Figure
echo import seaborn as sns
echo from reportlab.pdfgen import canvas
echo from reportlab.lib.pagesizes import letter
echo from reportlab.lib.units import inch
echo.
echo # Configurar logging
echo logging.basicConfig(
echo     level=logging.INFO,
echo     format='%%%%^(asctime^)s - %%%%^(levelname^)s - %%%%^(message^)s',
echo     handlers=[
echo         logging.FileHandler('logs/cinbehave.log'^),
echo         logging.StreamHandler(^)
echo     ]
echo ^)
echo.
echo class CinBehaveGUI:
echo     def __init__(self^):
echo         self.root = tk.Tk(^)
echo         self.root.title("CinBehave - SLEAP Analysis GUI v1.0"^)
echo         self.root.geometry("1000x700"^)
echo         self.root.configure(bg="#2c3e50"^)
echo         
echo         # Configurar icono
echo         try:
echo             if os.path.exists("assets/icon.ico"^):
echo                 self.root.iconbitmap("assets/icon.ico"^)
echo         except:
echo             pass
echo         
echo         # Variables del sistema
echo         self.current_user = None
echo         self.current_project = None
echo         self.projects_data = {}
echo         self.loaded_videos = []
echo         self.sleap_params = {
echo             "confidence_threshold": 0.5,
echo             "batch_size": 4,
echo             "max_instances": 1,
echo             "tracking": True,
echo             "model_path": "",
echo             "gpu_acceleration": True
echo         }
echo         
echo         # Configurar estilo
echo         self.setup_styles(^)
echo         
echo         # Mostrar splash screen
echo         self.show_splash_screen(^)
echo         
echo         # Inicializar sistema
echo         self.initialize_system(^)
echo         
echo         # Mostrar selección de usuario
echo         self.show_user_selection(^)
echo     
echo     def setup_styles(self^):
echo         """Configurar estilos de Windows"""
echo         style = ttk.Style(^)
echo         style.theme_use('winnative'^)
echo         
echo         # Configurar colores para Windows
echo         style.configure('TLabel', background='#2c3e50', foreground='#ecf0f1'^)
echo         style.configure('TButton', background='#3498db'^)
echo         style.configure('TEntry', fieldbackground='#ecf0f1'^)
echo         style.configure('TCombobox', fieldbackground='#ecf0f1'^)
echo         style.configure('TProgressbar', background='#27ae60'^)
echo         style.configure('TNotebook', background='#2c3e50'^)
echo         style.configure('TFrame', background='#2c3e50'^)
echo         style.configure('Treeview', background='#ecf0f1'^)
echo     
echo     def show_splash_screen(self^):
echo         """Mostrar pantalla de bienvenida"""
echo         splash = tk.Toplevel(self.root^)
echo         splash.title("CinBehave"^)
echo         splash.geometry("500x300"^)
echo         splash.configure(bg="#2c3e50"^)
echo         splash.resizable(False, False^)
echo         
echo         # Centrar splash
echo         splash.transient(self.root^)
echo         splash.grab_set(^)
echo         
echo         title_label = tk.Label(splash, text="CinBehave", 
echo                               font=("Arial", 24, "bold"^), 
echo                               fg="#ecf0f1", bg="#2c3e50"^)
echo         title_label.pack(pady=40^)
echo         
echo         version_label = tk.Label(splash, text="SLEAP Analysis GUI v1.0", 
echo                                 font=("Arial", 12"^), 
echo                                 fg="#3498db", bg="#2c3e50"^)
echo         version_label.pack(pady=10^)
echo         
echo         # Centrar en pantalla
echo         splash.update_idletasks(^)
echo         x = (splash.winfo_screenwidth(^) // 2^) - (500 // 2^)
echo         y = (splash.winfo_screenheight(^) // 2^) - (300 // 2^)
echo         splash.geometry(f"500x300+{x}+{y}"^)
echo         
echo         # Cerrar splash después de 3 segundos
echo         splash.after(3000, splash.destroy^)
echo     
echo     def initialize_system(self^):
echo         """Inicializar sistema"""
echo         try:
echo             # Crear directorios necesarios
echo             directories = [
echo                 "users", "temp", "logs", "config", 
echo                 "assets", "docs", "models", "exports"
echo             ]
echo             
echo             for directory in directories:
echo                 Path(directory^).mkdir(exist_ok=True^)
echo             
echo             logging.info("Sistema Windows inicializado correctamente"^)
echo             
echo         except Exception as e:
echo             logging.error(f"Error inicializando sistema: {e}"^)
echo             messagebox.showerror("Error", f"Error inicializando sistema: {e}"^)
echo     
echo     def show_user_selection(self^):
echo         """Mostrar selección de usuario"""
echo         self.root.withdraw(^)
echo         
echo         self.user_window = tk.Toplevel(^)
echo         self.user_window.title("Seleccionar Usuario - CinBehave"^)
echo         self.user_window.geometry("600x500"^)
echo         self.user_window.configure(bg="#2c3e50"^)
echo         
echo         # Título
echo         title_label = tk.Label(self.user_window, text="Seleccionar Usuario", 
echo                               font=("Arial", 18, "bold"^), 
echo                               fg="#ecf0f1", bg="#2c3e50"^)
echo         title_label.pack(pady=20^)
echo         
echo         # Crear interfaz de usuario básica
echo         messagebox.showinfo("Desarrollo", "Sistema base instalado correctamente.\nLa funcionalidad completa estará disponible pronto."^)
echo         
echo         # Cerrar aplicación por ahora
echo         self.root.quit(^)
echo     
echo     def run(self^):
echo         """Ejecutar aplicación"""
echo         try:
echo             self.root.mainloop(^)
echo         except Exception as e:
echo             logging.error(f"Error en aplicación: {e}"^)
echo             messagebox.showerror("Error", f"Error en aplicación: {e}"^)
echo.
echo def main(^):
echo     """Función principal"""
echo     try:
echo         app = CinBehaveGUI(^)
echo         app.run(^)
echo     except Exception as e:
echo         print(f"Error: {e}"^)
echo         messagebox.showerror("Error", f"Error: {e}"^)
echo.
echo if __name__ == "__main__":
echo     main(^)
) > cinbehave_gui.py

REM Crear estructura de directorios
mkdir users 2>nul
mkdir temp 2>nul
mkdir logs 2>nul
mkdir config 2>nul
mkdir assets 2>nul
mkdir docs 2>nul
mkdir models 2>nul
mkdir exports 2>nul

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

REM Crear documentación
(
echo # CinBehave - SLEAP Analysis GUI
echo.
echo ## Instalación completada exitosamente
echo.
echo ### Para ejecutar:
echo 1. Doble clic en el icono del escritorio "CinBehave"
echo 2. O ejecutar: start_cinbehave.bat
echo.
echo ### Estructura:
echo - cinbehave_gui.py: Aplicación principal
echo - start_cinbehave.bat: Script de inicio
echo - venv/: Entorno virtual Python
echo - users/: Datos de usuarios
echo - logs/: Logs del sistema
echo.
echo ### Soporte:
echo - Logs en: logs/cinbehave.log
echo - Configuración en: config/
echo.
echo Version: 1.0
echo Platform: Windows
) > docs\README.md

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
echo    ║                                                              ║
echo    ║  Para ejecutar:                                              ║
echo    ║  • Doble clic en el icono del escritorio                    ║
echo    ║  • O ejecutar: start_cinbehave.bat                          ║
echo    ║                                                              ║
echo    ║  Documentación: docs\README.md                              ║
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
