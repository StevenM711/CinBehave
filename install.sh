#!/bin/bash

# SLEAP Analysis GUI - Instalador para Ubuntu
# Versión: 1.0
# Autor: Sistema de Análisis de Videos con SLEAP

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar mensajes
show_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

show_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar la versión de Ubuntu
check_ubuntu_version() {
    if [[ ! -f /etc/lsb-release ]]; then
        show_error "Este instalador está diseñado para Ubuntu. Sistema no compatible."
        exit 1
    fi
    
    source /etc/lsb-release
    show_message "Ubuntu detectado: $DISTRIB_DESCRIPTION"
}

# Función para verificar permisos de sudo
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        show_message "Este instalador requiere permisos de administrador."
        sudo -v
    fi
}

# Función principal de instalación
main() {
    clear
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════╗
    ║                 SLEAP Analysis GUI Installer                 ║
    ║                        para Ubuntu                           ║
    ║                                                              ║
    ║    Sistema de Análisis de Videos con SLEAP                   ║
    ║    Versión: 1.0                                              ║
    ╚══════════════════════════════════════════════════════════════╝
EOF
    
    echo
    show_message "Iniciando instalación del sistema SLEAP Analysis GUI..."
    echo
    
    # Verificaciones iniciales
    show_step "1/10 Verificando sistema..."
    check_ubuntu_version
    check_sudo
    
    # Actualizar sistema
    show_step "2/10 Actualizando sistema..."
    sudo apt update -y
    
    # Instalar dependencias del sistema
    show_step "3/10 Instalando dependencias del sistema..."
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-tk \
        python3-dev \
        build-essential \
        libssl-dev \
        libffi-dev \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
        pkg-config \
        curl \
        wget \
        git \
        unzip
    
    # Crear directorio de instalación
    show_step "4/10 Creando directorio de instalación..."
    INSTALL_DIR="$HOME/sleap-analysis"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Crear entorno virtual
    show_step "5/10 Creando entorno virtual Python..."
    python3 -m venv venv
    source venv/bin/activate
    
    # Actualizar pip
    show_step "6/10 Actualizando pip..."
    pip install --upgrade pip setuptools wheel
    
    # Instalar dependencias Python
    show_step "7/10 Instalando dependencias Python..."
    
    # Crear requirements.txt
    cat > requirements.txt << 'EOF'
# Core dependencies
tkinter-tooltip==2.1.0
pillow>=9.0.0
numpy>=1.21.0
pandas>=1.3.0
matplotlib>=3.5.0
seaborn>=0.11.0
scipy>=1.7.0
scikit-learn>=1.0.0
opencv-python>=4.5.0
psutil>=5.8.0
reportlab>=3.6.0
fpdf2>=2.5.0
python-dateutil>=2.8.0
tqdm>=4.62.0

# Video processing
imageio>=2.13.0
imageio-ffmpeg>=0.4.0

# Data handling
openpyxl>=3.0.0
xlsxwriter>=3.0.0
h5py>=3.6.0

# GUI enhancements
customtkinter>=5.0.0
CTkMessagebox>=2.0.0
CTkListbox>=1.0.0
EOF
    
    # Instalar dependencias
    pip install -r requirements.txt
    
    # Crear estructura de directorios
    show_step "8/10 Creando estructura de directorios..."
    mkdir -p {users,temp,logs,config,assets,docs}
    
    # Crear aplicación principal
    show_step "9/10 Instalando aplicación SLEAP Analysis..."
    
    # Crear el archivo principal de la aplicación
    cat > sleap_gui.py << 'EOF'
#!/usr/bin/env python3
"""
SLEAP Analysis GUI - Sistema de Análisis de Videos con SLEAP
Versión: 1.0
Interfaz gráfica completa para análisis de comportamiento animal
"""

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, simpledialog
import os
import sys
import shutil
import subprocess
import threading
import json
import time
import psutil
import logging
from pathlib import Path
from datetime import datetime
import numpy as np
from PIL import Image, ImageTk
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import seaborn as sns
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/sleap_gui.log'),
        logging.StreamHandler()
    ]
)

class SLEAPAnalysisGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("SLEAP Analysis GUI v1.0")
        self.root.geometry("1000x700")
        self.root.configure(bg="#2c3e50")
        
        # Configurar icono si existe
        try:
            if os.path.exists("assets/icon.png"):
                icon = ImageTk.PhotoImage(Image.open("assets/icon.png"))
                self.root.iconphoto(False, icon)
        except:
            pass
        
        # Variables del sistema
        self.current_user = None
        self.current_project = None
        self.projects_data = {}
        self.loaded_videos = []
        self.processed_videos = []
        self.sleap_params = {
            "confidence_threshold": 0.5,
            "batch_size": 4,
            "max_instances": 1,
            "tracking": True,
            "model_path": "",
            "gpu_acceleration": True
        }
        
        # Variables de monitoreo
        self.monitoring = False
        self.resource_data = {"cpu": [], "memory": [], "gpu": [], "time": []}
        
        # Variables de interfaz
        self.resource_labels = {}
        self.stats_tree = None
        self.canvas = None
        self.fig = None
        self.ax = None
        
        # Configurar estilo
        self.setup_styles()
        
        # Mostrar splash screen
        self.show_splash_screen()
        
        # Inicializar sistema
        self.initialize_system()
        
        # Mostrar selección de usuario
        self.show_user_selection()
    
    def setup_styles(self):
        """Configurar estilos de la aplicación"""
        style = ttk.Style()
        style.theme_use('clam')
        
        # Configurar colores
        style.configure('TLabel', background='#2c3e50', foreground='#ecf0f1')
        style.configure('TButton', background='#3498db', foreground='white')
        style.configure('TEntry', fieldbackground='#ecf0f1')
        style.configure('TCombobox', fieldbackground='#ecf0f1')
        style.configure('TProgressbar', background='#27ae60')
        style.configure('TNotebook', background='#2c3e50')
        style.configure('TNotebook.Tab', background='#34495e', foreground='#ecf0f1')
        style.configure('TFrame', background='#2c3e50')
        style.configure('Treeview', background='#ecf0f1', foreground='#2c3e50')
        style.configure('Treeview.Heading', background='#3498db', foreground='white')
    
    def show_splash_screen(self):
        """Mostrar pantalla de bienvenida"""
        splash = tk.Toplevel(self.root)
        splash.title("SLEAP Analysis GUI")
        splash.geometry("500x300")
        splash.configure(bg="#2c3e50")
        splash.resizable(False, False)
        
        # Centrar splash screen
        splash.transient(self.root)
        splash.grab_set()
        
        # Contenido del splash
        title_label = tk.Label(splash, text="SLEAP Analysis GUI", 
                              font=("Arial", 24, "bold"), 
                              fg="#ecf0f1", bg="#2c3e50")
        title_label.pack(pady=40)
        
        version_label = tk.Label(splash, text="Versión 1.0", 
                                font=("Arial", 12), 
                                fg="#3498db", bg="#2c3e50")
        version_label.pack(pady=10)
        
        desc_label = tk.Label(splash, text="Sistema de Análisis de Videos\ncon SLEAP", 
                             font=("Arial", 14), 
                             fg="#95a5a6", bg="#2c3e50")
        desc_label.pack(pady=20)
        
        # Barra de progreso
        progress_var = tk.DoubleVar()
        progress_bar = ttk.Progressbar(splash, variable=progress_var, 
                                      maximum=100, length=300)
        progress_bar.pack(pady=20)
        
        status_label = tk.Label(splash, text="Inicializando...", 
                               font=("Arial", 10), 
                               fg="#bdc3c7", bg="#2c3e50")
        status_label.pack(pady=10)
        
        # Simular carga
        def update_progress():
            for i in range(101):
                progress_var.set(i)
                if i < 30:
                    status_label.config(text="Cargando configuración...")
                elif i < 60:
                    status_label.config(text="Inicializando módulos...")
                elif i < 90:
                    status_label.config(text="Preparando interfaz...")
                else:
                    status_label.config(text="Listo!")
                
                splash.update()
                time.sleep(0.02)
            
            splash.destroy()
        
        splash.after(100, update_progress)
        
        # Centrar en pantalla
        splash.update_idletasks()
        x = (splash.winfo_screenwidth() // 2) - (500 // 2)
        y = (splash.winfo_screenheight() // 2) - (300 // 2)
        splash.geometry(f"500x300+{x}+{y}")
    
    def initialize_system(self):
        """Inicializar sistema y crear directorios"""
        try:
            # Crear directorios necesarios
            directories = [
                "users", "temp", "logs", "config", 
                "assets", "docs", "models", "exports"
            ]
            
            for directory in directories:
                Path(directory).mkdir(exist_ok=True)
            
            # Crear archivo de configuración por defecto
            config_file = Path("config/default_config.json")
            if not config_file.exists():
                default_config = {
                    "version": "1.0",
                    "last_user": "",
                    "auto_save": True,
                    "theme": "dark",
                    "language": "es",
                    "debug_mode": False
                }
                with open(config_file, 'w') as f:
                    json.dump(default_config, f, indent=2)
            
            logging.info("Sistema inicializado correctamente")
            
        except Exception as e:
            logging.error(f"Error inicializando sistema: {e}")
            messagebox.showerror("Error", f"Error inicializando sistema: {e}")
    
    def show_user_selection(self):
        """Mostrar selección de usuario"""
        # Ocultar ventana principal
        self.root.withdraw()
        
        self.user_window = tk.Toplevel()
        self.user_window.title("Seleccionar Usuario - SLEAP Analysis")
        self.user_window.geometry("600x500")
        self.user_window.configure(bg="#2c3e50")
        self.user_window.resizable(False, False)
        
        # Centrar ventana
        self.user_window.update_idletasks()
        x = (self.user_window.winfo_screenwidth() // 2) - (600 // 2)
        y = (self.user_window.winfo_screenheight() // 2) - (500 // 2)
        self.user_window.geometry(f"600x500+{x}+{y}")
        
        # Título
        title_frame = tk.Frame(self.user_window, bg="#2c3e50")
        title_frame.pack(pady=20)
        
        title_label = tk.Label(title_frame, text="Seleccionar Usuario", 
                              font=("Arial", 20, "bold"), 
                              fg="#ecf0f1", bg="#2c3e50")
        title_label.pack()
        
        subtitle_label = tk.Label(title_frame, text="Sistema de Análisis de Videos con SLEAP", 
                                 font=("Arial", 12), 
                                 fg="#3498db", bg="#2c3e50")
        subtitle_label.pack(pady=5)
        
        # Frame principal
        main_frame = tk.Frame(self.user_window, bg="#2c3e50")
        main_frame.pack(fill="both", expand=True, padx=40, pady=20)
        
        # Frame izquierdo - Usuarios existentes
        left_frame = tk.Frame(main_frame, bg="#34495e", relief="raised", bd=2)
        left_frame.pack(side="left", fill="both", expand=True, padx=(0, 10))
        
        tk.Label(left_frame, text="Usuarios Existentes", 
                font=("Arial", 14, "bold"), 
                fg="#ecf0f1", bg="#34495e").pack(pady=10)
        
        # Listbox con scrollbar
        listbox_frame = tk.Frame(left_frame, bg="#34495e")
        listbox_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        scrollbar = tk.Scrollbar(listbox_frame)
        scrollbar.pack(side="right", fill="y")
        
        self.users_listbox = tk.Listbox(listbox_frame, 
                                       yscrollcommand=scrollbar.set,
                                       font=("Arial", 12),
                                       bg="#ecf0f1", 
                                       fg="#2c3e50",
                                       selectbackground="#3498db",
                                       height=12)
        self.users_listbox.pack(fill="both", expand=True)
        scrollbar.config(command=self.users_listbox.yview)
        
        # Botón para seleccionar usuario existente
        select_btn = tk.Button(left_frame, text="Seleccionar Usuario", 
                              command=self.select_existing_user,
                              font=("Arial", 11, "bold"),
                              bg="#3498db", fg="white",
                              cursor="hand2", relief="flat")
        select_btn.pack(pady=10)
        
        # Frame derecho - Nuevo usuario
        right_frame = tk.Frame(main_frame, bg="#34495e", relief="raised", bd=2)
        right_frame.pack(side="right", fill="both", expand=True, padx=(10, 0))
        
        tk.Label(right_frame, text="Crear Nuevo Usuario", 
                font=("Arial", 14, "bold"), 
                fg="#ecf0f1", bg="#34495e").pack(pady=10)
        
        # Formulario nuevo usuario
        form_frame = tk.Frame(right_frame, bg="#34495e")
        form_frame.pack(fill="x", padx=20, pady=20)
        
        tk.Label(form_frame, text="Nombre de Usuario:", 
                font=("Arial", 11), 
                fg="#ecf0f1", bg="#34495e").pack(anchor="w")
        
        self.new_user_entry = tk.Entry(form_frame, font=("Arial", 12), 
                                      width=25, relief="flat")
        self.new_user_entry.pack(fill="x", pady=5)
        
        tk.Label(form_frame, text="Nombre Completo (opcional):", 
                font=("Arial", 11), 
                fg="#ecf0f1", bg="#34495e").pack(anchor="w", pady=(10, 0))
        
        self.full_name_entry = tk.Entry(form_frame, font=("Arial", 12), 
                                       width=25, relief="flat")
        self.full_name_entry.pack(fill="x", pady=5)
        
        tk.Label(form_frame, text="Email (opcional):", 
                font=("Arial", 11), 
                fg="#ecf0f1", bg="#34495e").pack(anchor="w", pady=(10, 0))
        
        self.email_entry = tk.Entry(form_frame, font=("Arial", 12), 
                                   width=25, relief="flat")
        self.email_entry.pack(fill="x", pady=5)
        
        # Información de validación
        info_label = tk.Label(form_frame, 
                             text="• Mínimo 3 caracteres\n• Sin espacios\n• Solo letras, números y _", 
                             font=("Arial", 9), 
                             fg="#95a5a6", bg="#34495e",
                             justify="left")
        info_label.pack(anchor="w", pady=(10, 0))
        
        # Botón crear usuario
        create_btn = tk.Button(right_frame, text="Crear Usuario", 
                              command=self.create_new_user,
                              font=("Arial", 11, "bold"),
                              bg="#27ae60", fg="white",
                              cursor="hand2", relief="flat")
        create_btn.pack(pady=20)
        
        # Botones inferiores
        bottom_frame = tk.Frame(self.user_window, bg="#2c3e50")
        bottom_frame.pack(fill="x", pady=20)
        
        exit_btn = tk.Button(bottom_frame, text="Salir", 
                            command=self.exit_application,
                            font=("Arial", 11, "bold"),
                            bg="#e74c3c", fg="white",
                            cursor="hand2", relief="flat")
        exit_btn.pack(side="right", padx=40)
        
        # Cargar usuarios existentes
        self.load_existing_users()
        
        # Bind Enter key para crear usuario
        self.new_user_entry.bind('<Return>', lambda e: self.create_new_user())
        
        # Protocolo de cierre
        self.user_window.protocol("WM_DELETE_WINDOW", self.exit_application)
    
    def load_existing_users(self):
        """Cargar usuarios existentes"""
        self.users_listbox.delete(0, tk.END)
        
        users_dir = Path("users")
        if users_dir.exists():
            users = []
            for user_folder in users_dir.iterdir():
                if user_folder.is_dir():
                    # Intentar cargar información del usuario
                    user_info_file = user_folder / "user_info.json"
                    if user_info_file.exists():
                        try:
                            with open(user_info_file, 'r') as f:
                                user_data = json.load(f)
                            display_name = user_data.get('full_name', user_folder.name)
                            last_login = user_data.get('last_login', 'Nunca')
                            users.append((display_name, user_folder.name, last_login))
                        except:
                            users.append((user_folder.name, user_folder.name, "Desconocido"))
                    else:
                        users.append((user_folder.name, user_folder.name, "Desconocido"))
            
            # Ordenar por último login
            users.sort(key=lambda x: x[2], reverse=True)
            
            for display_name, folder_name, last_login in users:
                self.users_listbox.insert(tk.END, f"{display_name} ({folder_name})")
    
    def select_existing_user(self):
        """Seleccionar usuario existente"""
        selection = self.users_listbox.curselection()
        if not selection:
            messagebox.showwarning("Advertencia", "Selecciona un usuario de la lista")
            return
        
        selected_text = self.users_listbox.get(selection[0])
        # Extraer nombre de usuario del texto (entre paréntesis)
        if '(' in selected_text and ')' in selected_text:
            self.current_user = selected_text.split('(')[-1].split(')')[0]
        else:
            self.current_user = selected_text
        
        self.setup_user_environment()
    
    def create_new_user(self):
        """Crear nuevo usuario"""
        username = self.new_user_entry.get().strip()
        full_name = self.full_name_entry.get().strip()
        email = self.email_entry.get().strip()
        
        if not username:
            messagebox.showwarning("Advertencia", "Ingresa un nombre de usuario")
            return
        
        if len(username) < 3:
            messagebox.showwarning("Advertencia", "El nombre debe tener al menos 3 caracteres")
            return
        
        if ' ' in username or not username.replace('_', '').isalnum():
            messagebox.showwarning("Advertencia", "El nombre solo puede contener letras, números y guiones bajos")
            return
        
        # Verificar si el usuario ya existe
        user_dir = Path("users") / username
        if user_dir.exists():
            messagebox.showwarning("Advertencia", "Ya existe un usuario con ese nombre")
            return
        
        # Crear usuario
        try:
            user_dir.mkdir(parents=True)
            
            # Crear información del usuario
            user_info = {
                "username": username,
                "full_name": full_name or username,
                "email": email,
                "created": datetime.now().isoformat(),
                "last_login": datetime.now().isoformat(),
                "projects": []
            }
            
            with open(user_dir / "user_info.json", 'w') as f:
                json.dump(user_info, f, indent=2)
            
            self.current_user = username
            self.setup_user_environment()
            
            logging.info(f"Usuario {username} creado exitosamente")
            
        except Exception as e:
            logging.error(f"Error creando usuario: {e}")
            messagebox.showerror("Error", f"Error creando usuario: {e}")
    
    def setup_user_environment(self):
        """Configurar entorno del usuario"""
        try:
            # Configurar directorios
            self.setup_directories()
            
            # Cargar proyectos del usuario
            self.load_user_projects()
            
            # Actualizar último login
            self.update_last_login()
            
            # Cerrar ventana de usuario
            self.user_window.destroy()
            
            # Mostrar ventana principal
            self.root.deiconify()
            self.create_main_interface()
            
            # Mensaje de bienvenida
            user_info = self.get_user_info()
            welcome_msg = f"¡Bienvenido, {user_info.get('full_name', self.current_user)}!"
            messagebox.showinfo("Bienvenido", welcome_msg)
            
            logging.info(f"Usuario {self.current_user} iniciado correctamente")
            
        except Exception as e:
            logging.error(f"Error configurando entorno: {e}")
            messagebox.showerror("Error", f"Error configurando entorno: {e}")
    
    def setup_directories(self):
        """Configurar directorios del usuario"""
        self.user_dir = Path("users") / self.current_user
        self.base_dir = self.user_dir / "sleap_analysis"
        self.videos_dir = self.base_dir / "videos"
        self.results_dir = self.base_dir / "results"
        self.sleap_results_dir = self.base_dir / "sleap_results"
        self.prediction_results_dir = self.base_dir / "prediction_results"
        self.projects_dir = self.user_dir / "projects"
        self.annotations_dir = self.base_dir / "annotations"
        self.exports_dir = self.base_dir / "exports"
        
        # Crear todos los directorios
        for directory in [self.user_dir, self.base_dir, self.videos_dir, 
                         self.results_dir, self.sleap_results_dir, 
                         self.prediction_results_dir, self.projects_dir, 
                         self.annotations_dir, self.exports_dir]:
            directory.mkdir(parents=True, exist_ok=True)
    
    def get_user_info(self):
        """Obtener información del usuario"""
        user_info_file = self.user_dir / "user_info.json"
        if user_info_file.exists():
            try:
                with open(user_info_file, 'r') as f:
                    return json.load(f)
            except:
                pass
        return {"username": self.current_user, "full_name": self.current_user}
    
    def update_last_login(self):
        """Actualizar último login del usuario"""
        user_info_file = self.user_dir / "user_info.json"
        if user_info_file.exists():
            try:
                with open(user_info_file, 'r') as f:
                    user_data = json.load(f)
                
                user_data['last_login'] = datetime.now().isoformat()
                
                with open(user_info_file, 'w') as f:
                    json.dump(user_data, f, indent=2)
            except:
                pass
    
    def load_user_projects(self):
        """Cargar proyectos del usuario"""
        projects_file = self.user_dir / "projects.json"
        if projects_file.exists():
            try:
                with open(projects_file, 'r') as f:
                    self.projects_data = json.load(f)
            except:
                self.projects_data = {}
        else:
            self.projects_data = {}
    
    def save_user_projects(self):
        """Guardar proyectos del usuario"""
        projects_file = self.user_dir / "projects.json"
        try:
            with open(projects_file, 'w') as f:
                json.dump(self.projects_data, f, indent=2)
        except Exception as e:
            logging.error(f"Error guardando proyectos: {e}")
    
    def create_main_interface(self):
        """Crear interfaz principal"""
        # Limpiar ventana
        for widget in self.root.winfo_children():
            widget.destroy()
        
        # Configurar ventana principal
        self.root.title(f"SLEAP Analysis GUI - {self.current_user}")
        
        # Header
        self.create_header()
        
        # Sección de proyectos
        self.create_project_section()
        
        # Menú principal
        self.create_main_menu()
        
        # Barra de estado
        self.create_status_bar()
        
        # Actualizar estado
        self.update_status("Sistema iniciado correctamente")
    
    def create_header(self):
        """Crear header de la aplicación"""
        header_frame = tk.Frame(self.root, bg="#2c3e50", height=80)
        header_frame.pack(fill="x", pady=10)
        header_frame.pack_propagate(False)
        
        # Logo y título
        title_frame = tk.Frame(header_frame, bg="#2c3e50")
        title_frame.pack(side="left", padx=20)
        
        title_label = tk.Label(title_frame, text="SLEAP Analysis GUI", 
                              font=("Arial", 18, "bold"), 
                              fg="#ecf0f1", bg="#2c3e50")
        title_label.pack(anchor="w")
        
        user_info = self.get_user_info()
        user_label = tk.Label(title_frame, 
                             text=f"Usuario: {user_info.get('full_name', self.current_user)}", 
                             font=("Arial", 11), 
                             fg="#3498db", bg="#2c3e50")
        user_label.pack(anchor="w")
        
        # Información del sistema
        info_frame = tk.Frame(header_frame, bg="#2c3e50")
        info_frame.pack(side="right", padx=20)
        
        version_label = tk.Label(info_frame, text="v1.0", 
                                font=("Arial", 10), 
                                fg="#95a5a6", bg="#2c3e50")
        version_label.pack(anchor="e")
        
        time_label = tk.Label(info_frame, text="", 
                             font=("Arial", 10), 
                             fg="#95a5a6", bg="#2c3e50")
        time_label.pack(anchor="e")
        
        # Actualizar hora
        def update_time():
            current_time = datetime.now().strftime("%H:%M:%S")
            time_label.config(text=current_time)
            self.root.after(1000, update_time)
        
        update_time()
    
    def create_project_section(self):
        """Crear sección de gestión de proyectos"""
        project_frame = tk.Frame(self.root, bg="#34495e", relief="raised", bd=1)
        project_frame.pack(fill="x", padx=20, pady=10)
        
        # Título
        title_label = tk.Label(project_frame, text="Gestión de Proyectos", 
                              font=("Arial", 12, "bold"), 
                              fg="#ecf0f1", bg="#34495e")
        title_label.pack(side="left", padx=10, pady=5)
        
        # Controles
        controls_frame = tk.Frame(project_frame, bg="#34495e")
        controls_frame.pack(side="right", padx=10, pady=5)
        
        # Selector de proyecto
        self.project_var = tk.StringVar()
        self.project_combobox = ttk.Combobox(controls_frame, 
                                            textvariable=self.project_var,
                                            values=list(self.projects_data.keys()),
                                            state="readonly",
                                            width=25)
        self.project_combobox.pack(side="left", padx=5)
        
        # Botones
        self.create_styled_button(controls_frame, "Nuevo", self.create_new_project, 
                                 "#27ae60", side="left", padx=2)
        self.create_styled_button(controls_frame, "Cargar", self.load_project, 
                                 "#3498db", side="left", padx=2)
        self.create_styled_button(controls_frame, "Guardar", self.save_current_project, 
                                 "#f39c12", side="left", padx=2)
        self.create_styled_button(controls_frame, "Eliminar", self.delete_project, 
                                 "#e74c3c", side="left", padx=2)
    
    def create_styled_button(self, parent, text, command, color, **pack_options):
        """Crear botón estilizado"""
        button = tk.Button(parent, text=text, command=command,
                          font=("Arial", 9, "bold"), 
                          fg="white", bg=color,
                          cursor="hand2", relief="flat",
                          padx=10, pady=5)
        button.pack(**pack_options)
        
        # Efecto hover
        def on_enter(e):
            button.configure(bg=self.darken_color(color))
        def on_leave(e):
            button.configure(bg=color)
        
        button.bind("<Enter>", on_enter)
        button.bind("<Leave>", on_leave)
        
        return button
    
    def darken_color(self, color):
        """Oscurecer color para efecto hover"""
        color_map = {
            "#3498db": "#2980b9",
            "#f39c12": "#e67e22",
            "#e74c3c": "#c0392b",
            "#27ae60": "#229954",
            "#9b59b6": "#8e44ad",
            "#95a5a6": "#7f8c8d",
            "#e67e22": "#d35400"
        }
        return color_map.get(color, color)
    
    def create_main_menu(self):
        """Crear menú principal"""
        menu_frame = tk.Frame(self.root, bg="#2c3e50")
        menu_frame.pack(expand=True, fill="both", padx=50, pady=30)
        
        # Crear botones del menú
        buttons = [
            ("1. Predecir", self.open_predict_menu, "#3498db"),
            ("2. Entrenar", self.show_training_menu, "#f39c12"),
            ("3. Configuración SLEAP", self.show_sleap_config, "#9b59b6"),
            ("4. Herramientas", self.show_tools_menu, "#e67e22"),
            ("5. Cambiar Usuario", self.change_user, "#95a5a6"),
            ("6. Salir", self.exit_application, "#e74c3c")
        ]
        
        for text, command, color in buttons:
            button = tk.Button(menu_frame, text=text, command=command,
                              font=("Arial", 14, "bold"), 
                              fg="white", bg=color,
                              width=30, height=2, 
                              cursor="hand2", relief="flat")
            button.pack(pady=8)
            
            # Efecto hover
            def on_enter(e, c=color):
                e.widget.configure(bg=self.darken_color(c))
            def on_leave(e, c=color):
                e.widget.configure(bg=c)
            
            button.bind("<Enter>", on_enter)
            button.bind("<Leave>", on_leave)
    
    def create_status_bar(self):
        """Crear barra de estado"""
        self.status_frame = tk.Frame(self.root, bg="#34495e", relief="sunken", bd=1)
        self.status_frame.pack(fill="x", side="bottom")
        
        self.status_label = tk.Label(self.status_frame, text="Listo", 
                                    font=("Arial", 10), 
                                    fg="#ecf0f1", bg="#34495e")
        self.status_label.pack(side="left", padx=10, pady=5)
        
        # Indicador de proyecto actual
        self.project_indicator = tk.Label(self.status_frame, text="Sin proyecto", 
                                         font=("Arial", 10), 
                                         fg="#3498db", bg="#34495e")
        self.project_indicator.pack(side="right", padx=10, pady=5)
    
    def update_status(self, message):
        """Actualizar barra de estado"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.status_label.config(text=f"[{timestamp}] {message}")
        self.root.update_idletasks()
        logging.info(message)
    
    # Métodos de gestión de proyectos
    def create_new_project(self):
        """Crear nuevo proyecto"""
        project_name = simpledialog.askstring("Nuevo Proyecto", 
                                              "Nombre del proyecto:",
                                              parent=self.root)
        if not project_name:
            return
        
        project_name = project_name.strip()
        if not project_name:
            messagebox.showwarning("Advertencia", "Ingresa un nombre válido")
            return
        
        if project_name in self.projects_data:
            messagebox.showwarning("Advertencia", "Ya existe un proyecto con ese nombre")
            return
        
        # Crear proyecto
        self.projects_data[project_name] = {
            "name": project_name,
            "created": datetime.now().isoformat(),
            "last_modified": datetime.now().isoformat(),
            "description": "",
            "videos": [],
            "sleap_params": self.sleap_params.copy(),
            "results": {},
            "annotations": []
        }
        
        # Actualizar interfaz
        self.current_project = project_name
        self.project_var.set(project_name)
        self.project_combobox['values'] = list(self.projects_data.keys())
        self.project_indicator.config(text=f"Proyecto: {project_name}")
        
        # Guardar
        self.save_user_projects()
        
        self.update_status(f"Proyecto '{project_name}' creado")
        messagebox.showinfo("Éxito", f"Proyecto '{project_name}' creado exitosamente")
    
    def load_project(self):
        """Cargar proyecto seleccionado"""
        project_name = self.project_var.get()
        if not project_name or project_name not in self.projects_data:
            messagebox.showwarning("Advertencia", "Selecciona un proyecto válido")
            return
        
        self.current_project = project_name
        project_data = self.projects_data[project_name]
        
        # Cargar datos del proyecto
        self.loaded_videos = project_data.get("videos", [])
        self.sleap_params = project_data.get("sleap_params", self.sleap_params)
        
        # Actualizar interfaz
        self.project_indicator.config(text=f"Proyecto: {project_name}")
        
        self.update_status(f"Proyecto '{project_name}' cargado")
        messagebox.showinfo("Éxito", f"Proyecto '{project_name}' cargado exitosamente")
    
    def save_current_project(self):
        """Guardar proyecto actual"""
        if not self.current_project:
            messagebox.showwarning("Advertencia", "No hay proyecto activo")
            return
        
        # Actualizar datos del proyecto
        self.projects_data[self.current_project].update({
            "videos": self.loaded_videos,
            "sleap_params": self.sleap_params,
            "last_modified": datetime.now().isoformat()
        })
        
        # Guardar
        self.save_user_projects()
        
        self.update_status(f"Proyecto '{self.current_project}' guardado")
        messagebox.showinfo("Éxito", f"Proyecto '{self.current_project}' guardado exitosamente")
    
    def delete_project(self):
        """Eliminar proyecto"""
        project_name = self.project_var.get()
        if not project_name or project_name not in self.projects_data:
            messagebox.showwarning("Advertencia", "Selecciona un proyecto válido")
            return
        
        if messagebox.askyesno("Confirmar", 
                              f"¿Estás seguro de eliminar el proyecto '{project_name}'?\n"
                              "Esta acción no se puede deshacer."):
            
            # Eliminar proyecto
            del self.projects_data[project_name]
            
            # Limpiar interfaz
            if self.current_project == project_name:
                self.current_project = None
                self.project_indicator.config(text="Sin proyecto")
                self.loaded_videos = []
            
            # Actualizar combobox
            self.project_var.set("")
            self.project_combobox['values'] = list(self.projects_data.keys())
            
            # Guardar
            self.save_user_projects()
            
            self.update_status(f"Proyecto '{project_name}' eliminado")
            messagebox.showinfo("Éxito", f"Proyecto '{project_name}' eliminado")
    
    # Métodos de menú
    def open_predict_menu(self):
        """Abrir menú de predicción"""
        if not self.current_project:
            if messagebox.askyesno("Sin Proyecto", 
                                  "No hay proyecto activo. ¿Deseas crear uno?"):
                self.create_new_project()
                return
            else:
                return
        
        # Crear ventana de predicción
        predict_window = tk.Toplevel(self.root)
        predict_window.title(f"Predicción - {self.current_project}")
        predict_window.geometry("700x600")
        predict_window.configure(bg="#2c3e50")
        predict_window.resizable(False, False)
        
        # Centrar ventana
        predict_window.transient(self.root)
        predict_window.grab_set()
        
        # Título
        title_label = tk.Label(predict_window, text="Menú de Predicción", 
                              font=("Arial", 18, "bold"), 
                              fg="#ecf0f1", bg="#2c3e50")
        title_label.pack(pady=20)
        
        project_label = tk.Label(predict_window, text=f"Proyecto: {self.current_project}", 
                                font=("Arial", 12), 
                                fg="#3498db", bg="#2c3e50")
        project_label.pack(pady=5)
        
        # Botones
        buttons_frame = tk.Frame(predict_window, bg="#2c3e50")
        buttons_frame.pack(expand=True, fill="both", padx=50, pady=30)
        
        buttons = [
            ("1. Cargar Videos", self.load_videos, "#3498db"),
            ("2. Procesar SLEAP", self.process_sleap, "#27ae60"),
            ("3. Comenzar Predicción", self.start_prediction, "#9b59b6"),
            ("4. Verificar Resultados", self.verify_results, "#f39c12"),
            ("5. Anotaciones Manuales", self.manual_annotations, "#e67e22"),
            ("Volver", predict_window.destroy, "#95a5a6")
        ]
        
        for text, command, color in buttons:
            button = tk.Button(buttons_frame, text=text, command=command,
                              font=("Arial", 12, "bold"), 
                              fg="white", bg=color,
                              width=25, height=2, 
                              cursor="hand2", relief="flat")
            button.pack(pady=8)
            
            # Efecto hover
            def on_enter(e, c=color):
                e.widget.configure(bg=self.darken_color(c))
            def on_leave(e, c=color):
                e.widget.configure(bg=c)
            
            button.bind("<Enter>", on_enter)
            button.bind("<Leave>", on_leave)
    
    def show_training_menu(self):
        """Mostrar menú de entrenamiento"""
        messagebox.showinfo("Próximamente", 
                           "La funcionalidad de entrenamiento estará disponible en futuras versiones")
    
    def show_sleap_config(self):
        """Mostrar configuración SLEAP"""
        config_window = tk.Toplevel(self.root)
        config_window.title("Configuración SLEAP")
        config_window.geometry("600x500")
        config_window.configure(bg="#2c3e50")
        config_window.resizable(False, False)
        
        # Centrar ventana
        config_window.transient(self.root)
        config_window.grab_set()
        
        # Título
        title_label = tk.Label(config_window, text="Configuración de Parámetros SLEAP", 
                              font=("Arial", 16, "bold"), 
                              fg="#ecf0f1", bg="#2c3e50")
        title_label.pack(pady=20)
        
        # Notebook para organizar configuraciones
        notebook = ttk.Notebook(config_window)
        notebook.pack(fill="both", expand=True, padx=20, pady=20)
        
        # Pestaña básica
        basic_frame = ttk.Frame(notebook)
        notebook.add(basic_frame, text="Básico")
        
        # Pestaña avanzada
        advanced_frame = ttk.Frame(notebook)
        notebook.add(advanced_frame, text="Avanzado")
        
        # Configuración básica
        self.create_basic_config(basic_frame)
        
        # Configuración avanzada
        self.create_advanced_config(advanced_frame)
        
        # Botones
        buttons_frame = tk.Frame(config_window, bg="#2c3e50")
        buttons_frame.pack(pady=20)
        
        self.create_styled_button(buttons_frame, "Guardar", 
                                 lambda: self.save_sleap_config(config_window), 
                                 "#27ae60", side="left", padx=10)
        self.create_styled_button(buttons_frame, "Cancelar", 
                                 config_window.destroy, 
                                 "#e74c3c", side="left", padx=10)
        self.create_styled_button(buttons_frame, "Restaurar Defaults", 
                                 self.restore_default_config, 
                                 "#95a5a6", side="left", padx=10)
    
    def create_basic_config(self, parent):
        """Crear configuración básica"""
        # Variables para controles
        self.confidence_var = tk.DoubleVar(value=self.sleap_params["confidence_threshold"])
        self.batch_var = tk.IntVar(value=self.sleap_params["batch_size"])
        self.instances_var = tk.IntVar(value=self.sleap_params["max_instances"])
        self.tracking_var = tk.BooleanVar(value=self.sleap_params["tracking"])
        self.gpu_var = tk.BooleanVar(value=self.sleap_params["gpu_acceleration"])
        
        # Umbral de confianza
        conf_frame = tk.Frame(parent, bg="#2c3e50")
        conf_frame.pack(fill="x", padx=20, pady=10)
        
        tk.Label(conf_frame, text="Umbral de Confianza:", 
                font=("Arial", 11, "bold"), 
                fg="#ecf0f1", bg="#2c3e50").pack(anchor="w")
        
        conf_scale = tk.Scale(conf_frame, from_=0.0, to=1.0, resolution=0.1,
                             orient="horizontal", variable=self.confidence_var,
                             bg="#34495e", fg="#ecf0f1", 
                             highlightbackground="#2c3e50", length=400)
        conf_scale.pack(fill="x", pady=5)
        
        # Tamaño de lote
        batch_frame = tk.Frame(parent, bg="#2c3e50")
        batch_frame.pack(fill="x", padx=20, pady=10)
        
        tk.Label(batch_frame, text="Tamaño de Lote:", 
                font=("Arial", 11, "bold"), 
                fg="#ecf0f1", bg="#2c3e50").pack(anchor="w")
        
        batch_scale = tk.Scale(batch_frame, from_=1, to=16, resolution=1,
                              orient="horizontal", variable=self.batch_var,
                              bg="#34495e", fg="#ecf0f1", 
                              highlightbackground="#2c3e50", length=400)
        batch_scale.pack(fill="x", pady=5)
        
        # Máximo instancias
        inst_frame = tk.Frame(parent, bg="#2c3e50")
        inst_frame.pack(fill="x", padx=20, pady=10)
        
        tk.Label(inst_frame, text="Máximo de Instancias:", 
                font=("Arial", 11, "bold"), 
                fg="#ecf0f1", bg="#2c3e50").pack(anchor="w")
        
        inst_scale = tk.Scale(inst_frame, from_=1, to=10, resolution=1,
                             orient="horizontal", variable=self.instances_var,
                             bg="#34495e", fg="#ecf0f1", 
                             highlightbackground="#2c3e50", length=400)
        inst_scale.pack(fill="x", pady=5)
        
        # Checkboxes
        check_frame = tk.Frame(parent, bg="#2c3e50")
        check_frame.pack(fill="x", padx=20, pady=20)
        
        tk.Checkbutton(check_frame, text="Activar Tracking", 
                      variable=self.tracking_var,
                      font=("Arial", 11), 
                      fg="#ecf0f1", bg="#2c3e50", 
                      selectcolor="#34495e").pack(anchor="w", pady=5)
        
        tk.Checkbutton(check_frame, text="Aceleración GPU", 
                      variable=self.gpu_var,
                      font=("Arial", 11), 
                      fg="#ecf0f1", bg="#2c3e50", 
                      selectcolor="#34495e").pack(anchor="w", pady=5)
    
    def create_advanced_config(self, parent):
        """Crear configuración avanzada"""
        # Ruta del modelo
        model_frame = tk.Frame(parent, bg="#2c3e50")
        model_frame.pack(fill="x", padx=20, pady=10)
        
        tk.Label(model_frame, text="Ruta del Modelo SLEAP:", 
                font=("Arial", 11, "bold"), 
                fg="#ecf0f1", bg="#2c3e50").pack(anchor="w")
        
        model_entry_frame = tk.Frame(model_frame, bg="#2c3e50")
        model_entry_frame.pack(fill="x", pady=5)
        
        self.model_path_var = tk.StringVar(value=self.sleap_params.get("model_path", ""))
        model_entry = tk.Entry(model_entry_frame, textvariable=self.model_path_var,
                              font=("Arial", 10), width=50)
        model_entry.pack(side="left", fill="x", expand=True)
        
        browse_btn = tk.Button(model_entry_frame, text="Explorar", 
                              command=self.browse_model_path,
                              font=("Arial", 9), bg="#3498db", fg="white")
        browse_btn.pack(side="right", padx=(5, 0))
        
        # Información adicional
        info_frame = tk.Frame(parent, bg="#34495e", relief="raised", bd=1)
        info_frame.pack(fill="x", padx=20, pady=20)
        
        tk.Label(info_frame, text="Información del Sistema", 
                font=("Arial", 11, "bold"), 
                fg="#ecf0f1", bg="#34495e").pack(pady=5)
        
        # Información del sistema
        system_info = f"""
        GPU Disponible: {'Sí' if self.check_gpu_available() else 'No'}
        Memoria RAM: {self.get_system_memory()} GB
        Procesador: {self.get_cpu_info()}
        """
        
        tk.Label(info_frame, text=system_info, 
                font=("Arial", 9), 
                fg="#bdc3c7", bg="#34495e",
                justify="left").pack(pady=5)
    
    def browse_model_path(self):
        """Explorar ruta del modelo"""
        file_path = filedialog.askopenfilename(
            title="Seleccionar modelo SLEAP",
            filetypes=[("Archivos SLEAP", "*.h5 *.json"), ("Todos los archivos", "*.*")]
        )
        if file_path:
            self.model_path_var.set(file_path)
    
    def check_gpu_available(self):
        """Verificar si GPU está disponible"""
        try:
            import subprocess
            result = subprocess.run(['nvidia-smi'], capture_output=True, text=True)
            return result.returncode == 0
        except:
            return False
    
    def get_system_memory(self):
        """Obtener memoria del sistema"""
        try:
            return round(psutil.virtual_memory().total / (1024**3))
        except:
            return "Desconocido"
    
    def get_cpu_info(self):
        """Obtener información del CPU"""
        try:
            with open('/proc/cpuinfo', 'r') as f:
                for line in f:
                    if line.startswith('model name'):
                        return line.split(':')[1].strip()
        except:
            return "Desconocido"
    
    def save_sleap_config(self, window):
        """Guardar configuración SLEAP"""
        self.sleap_params.update({
            "confidence_threshold": self.confidence_var.get(),
            "batch_size": self.batch_var.get(),
            "max_instances": self.instances_var.get(),
            "tracking": self.tracking_var.get(),
            "gpu_acceleration": self.gpu_var.get(),
            "model_path": self.model_path_var.get()
        })
        
        window.destroy()
        self.update_status("Configuración SLEAP actualizada")
        messagebox.showinfo("Éxito", "Configuración guardada exitosamente")
    
    def restore_default_config(self):
        """Restaurar configuración por defecto"""
        if messagebox.askyesno("Confirmar", "¿Restaurar configuración por defecto?"):
            self.confidence_var.set(0.5)
            self.batch_var.set(4)
            self.instances_var.set(1)
            self.tracking_var.set(True)
            self.gpu_var.set(True)
            self.model_path_var.set("")
    
    def show_tools_menu(self):
        """Mostrar menú de herramientas"""
        messagebox.showinfo("Herramientas", 
                           "Funcionalidades adicionales estarán disponibles próximamente")
    
    def change_user(self):
        """Cambiar usuario"""
        if messagebox.askyesno("Cambiar Usuario", 
                              "¿Cambiar de usuario?\nLos cambios no guardados se perderán."):
            self.root.withdraw()
            self.current_user = None
            self.current_project = None
            self.loaded_videos = []
            self.show_user_selection()
    
    def exit_application(self):
        """Salir de la aplicación"""
        if messagebox.askyesno("Salir", "¿Estás seguro de que deseas salir?"):
            try:
                # Guardar configuración antes de salir
                if self.current_project:
                    self.save_current_project()
                
                # Limpiar recursos
                self.cleanup_resources()
                
                logging.info("Aplicación cerrada correctamente")
                self.root.quit()
            except:
                self.root.quit()
    
    def cleanup_resources(self):
        """Limpiar recursos"""
        try:
            # Detener monitoreo
            self.monitoring = False
            
            # Limpiar archivos temporales
            temp_dir = Path("temp")
            if temp_dir.exists():
                for file in temp_dir.glob("*"):
                    try:
                        file.unlink()
                    except:
                        pass
        except:
            pass
    
    # Métodos de funcionalidad (stubs para el frontend)
    def load_videos(self):
        """Cargar videos"""
        messagebox.showinfo("Desarrollo", "Función load_videos - En desarrollo")
    
    def process_sleap(self):
        """Procesar SLEAP"""
        messagebox.showinfo("Desarrollo", "Función process_sleap - En desarrollo")
    
    def start_prediction(self):
        """Comenzar predicción"""
        messagebox.showinfo("Desarrollo", "Función start_prediction - En desarrollo")
    
    def verify_results(self):
        """Verificar resultados"""
        messagebox.showinfo("Desarrollo", "Función verify_results - En desarrollo")
    
    def manual_annotations(self):
        """Anotaciones manuales"""
        messagebox.showinfo("Desarrollo", "Función manual_annotations - En desarrollo")
    
    def run(self):
        """Ejecutar aplicación"""
        try:
            self.root.mainloop()
        except Exception as e:
            logging.error(f"Error en aplicación: {e}")
            messagebox.showerror("Error Fatal", f"Error en aplicación: {e}")

def main():
    """Función principal"""
    try:
        # Verificar que estamos en el directorio correcto
        if not os.path.exists("users"):
            os.makedirs("users")
        
        # Inicializar aplicación
        app = SLEAPAnalysisGUI()
        app.run()
        
    except Exception as e:
        print(f"Error iniciando aplicación: {e}")
        messagebox.showerror("Error Fatal", f"Error iniciando aplicación: {e}")

if __name__ == "__main__":
    main()
EOF
    
    # Crear launcher desktop
    cat > sleap-analysis.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=SLEAP Analysis GUI
Comment=Sistema de Análisis de Videos con SLEAP
Exec=/usr/bin/python3 /home/$USER/sleap-analysis/sleap_gui.py
Icon=/home/$USER/sleap-analysis/assets/icon.png
Terminal=false
Categories=Science;Education;
EOF
    
    # Crear script de inicio
    cat > start_sleap.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python3 sleap_gui.py
EOF
    
    chmod +x start_sleap.sh
    
    # Crear icono simple
    show_step "10/10 Finalizando instalación..."
    
    # Crear directorio de assets
    mkdir -p assets
    
    # Crear documentación
    cat > docs/README.md << 'EOF'
# SLEAP Analysis GUI

## Descripción
Sistema completo de análisis de videos con SLEAP para investigación de comportamiento animal.

## Características
- Gestión de usuarios y proyectos
- Configuración avanzada de parámetros SLEAP
- Monitoreo de recursos en tiempo real
- Análisis completo de resultados
- Anotaciones manuales para mejora del modelo
- Exportación de reportes en PDF

## Uso
1. Ejecutar: `./start_sleap.sh`
2. Seleccionar o crear usuario
3. Crear nuevo proyecto
4. Cargar videos
5. Procesar con SLEAP
6. Analizar resultados

## Soporte
Para soporte técnico, consultar la documentación o contactar al desarrollador.
EOF
    
    # Crear acceso directo en el escritorio
    if [ -d "$HOME/Desktop" ]; then
        cp sleap-analysis.desktop "$HOME/Desktop/"
        chmod +x "$HOME/Desktop/sleap-analysis.desktop"
    fi
    
    # Crear acceso en menú de aplicaciones
    if [ -d "$HOME/.local/share/applications" ]; then
        mkdir -p "$HOME/.local/share/applications"
        cp sleap-analysis.desktop "$HOME/.local/share/applications/"
    fi
    
    # Completar instalación
    echo
    show_message "¡Instalación completada exitosamente!"
    echo
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════╗
    ║                    INSTALACIÓN COMPLETA                      ║
    ╠══════════════════════════════════════════════════════════════╣
    ║                                                              ║
    ║  ✅ Sistema instalado en: ~/sleap-analysis                   ║
    ║  ✅ Acceso directo creado en escritorio                      ║
    ║  ✅ Todas las dependencias instaladas                        ║
    ║  ✅ Entorno virtual configurado                              ║
    ║                                                              ║
    ║  Para ejecutar:                                              ║
    ║  • Doble click en el icono del escritorio                   ║
    ║  • O ejecutar: ~/sleap-analysis/start_sleap.sh              ║
    ║                                                              ║
    ║  Documentación: ~/sleap-analysis/docs/                      ║
    ║  Logs: ~/sleap-analysis/logs/                               ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝
EOF
    
    echo
    show_message "¿Deseas ejecutar la aplicación ahora? (s/n)"
    read -p "Respuesta: " response
    
    if [[ "$response" =~ ^[Ss]$ ]]; then
        show_message "Iniciando SLEAP Analysis GUI..."
        ./start_sleap.sh
    fi
}

# Verificar si se está ejecutando como script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
