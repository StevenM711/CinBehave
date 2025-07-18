#!/usr/bin/env python3
"""
CinBehave - SLEAP Analysis GUI for Windows
Version: 1.0
Complete interface for animal behavior analysis using SLEAP
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
try:
    from PIL import Image, ImageTk
except ImportError:
    pass
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
        logging.FileHandler('logs/cinbehave.log'),
        logging.StreamHandler()
    ]
)

class CinBehaveGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("CinBehave - SLEAP Analysis GUI v1.0")
        self.root.geometry("1000x700")
        self.root.configure(bg="#2c3e50")
        
        # Configurar icono de Windows
        try:
            if os.path.exists("assets/icon.ico"):
                self.root.iconbitmap("assets/icon.ico")
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
        
        # Configurar estilo para Windows
        self.setup_windows_styles()
        
        # Mostrar splash screen
        self.show_splash_screen()
        
        # Inicializar sistema
        self.initialize_system()
        
        # Mostrar selección de usuario
        self.show_user_selection()
    
    def setup_windows_styles(self):
        """Configurar estilos específicos para Windows"""
        style = ttk.Style()
        
        # Usar tema nativo de Windows
        try:
            style.theme_use('winnative')
        except:
            style.theme_use('default')
        
        # Configurar colores específicos para Windows
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
        
        # Configurar fuentes para Windows
        self.fonts = {
            'title': ('Segoe UI', 20, 'bold'),
            'subtitle': ('Segoe UI', 14, 'bold'),
            'normal': ('Segoe UI', 10),
            'button': ('Segoe UI', 10, 'bold'),
            'small': ('Segoe UI', 9)
        }
    
    def show_splash_screen(self):
        """Mostrar pantalla de bienvenida estilo Windows"""
        splash = tk.Toplevel(self.root)
        splash.title("CinBehave")
        splash.geometry("500x300")
        splash.configure(bg="#2c3e50")
        splash.resizable(False, False)
        
        # Remover decoraciones de ventana
        splash.overrideredirect(True)
        
        # Centrar splash screen
        splash.update_idletasks()
        x = (splash.winfo_screenwidth() // 2) - (500 // 2)
        y = (splash.winfo_screenheight() // 2) - (300 // 2)
        splash.geometry(f"500x300+{x}+{y}")
        
        # Borde
        border_frame = tk.Frame(splash, bg="#3498db", relief="raised", bd=2)
        border_frame.pack(fill="both", expand=True)
        
        # Contenido
        content_frame = tk.Frame(border_frame, bg="#2c3e50")
        content_frame.pack(fill="both", expand=True, padx=2, pady=2)
        
        # Logo placeholder
        logo_frame = tk.Frame(content_frame, bg="#2c3e50")
        logo_frame.pack(pady=30)
        
        # Título
        title_label = tk.Label(content_frame, text="CinBehave", 
                              font=self.fonts['title'], 
                              fg="#ecf0f1", bg="#2c3e50")
        title_label.pack(pady=10)
        
        version_label = tk.Label(content_frame, text="SLEAP Analysis GUI v1.0", 
                                font=self.fonts['normal'], 
                                fg="#3498db", bg="#2c3e50")
        version_label.pack(pady=5)
        
        desc_label = tk.Label(content_frame, text="Sistema de Análisis de Videos\ncon SLEAP", 
                             font=self.fonts['normal'], 
                             fg="#95a5a6", bg="#2c3e50")
        desc_label.pack(pady=20)
        
        # Barra de progreso
        progress_var = tk.DoubleVar()
        progress_bar = ttk.Progressbar(content_frame, variable=progress_var, 
                                      maximum=100, length=300)
        progress_bar.pack(pady=10)
        
        status_label = tk.Label(content_frame, text="Inicializando...", 
                               font=self.fonts['small'], 
                               fg="#bdc3c7", bg="#2c3e50")
        status_label.pack(pady=5)
        
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
                    status_label.config(text="¡Listo!")
                
                splash.update()
                time.sleep(0.03)
            
            splash.destroy()
        
        splash.after(100, update_progress)
    
    def initialize_system(self):
        """Inicializar sistema en Windows"""
        try:
            # Crear directorios necesarios
            directories = [
                "users", "temp", "logs", "config", 
                "assets", "docs", "models", "exports"
            ]
            
            for directory in directories:
                Path(directory).mkdir(exist_ok=True)
            
            # Crear archivo de configuración específico para Windows
            config_file = Path("config/windows_config.json")
            if not config_file.exists():
                windows_config = {
                    "version": "1.0",
                    "platform": "Windows",
                    "last_user": "",
                    "auto_save": True,
                    "theme": "windows_dark",
                    "language": "es",
                    "debug_mode": False,
                    "gpu_support": self.check_gpu_support(),
                    "system_info": self.get_system_info()
                }
                with open(config_file, 'w') as f:
                    json.dump(windows_config, f, indent=2)
            
            logging.info("Sistema Windows inicializado correctamente")
            
        except Exception as e:
            logging.error(f"Error inicializando sistema: {e}")
            messagebox.showerror("Error", f"Error inicializando sistema: {e}")
    
    def check_gpu_support(self):
        """Verificar soporte GPU en Windows"""
        try:
            # Verificar NVIDIA GPU
            result = subprocess.run(['nvidia-smi'], capture_output=True, text=True)
            if result.returncode == 0:
                return "NVIDIA"
            
            # Verificar AMD GPU (usando wmic)
            result = subprocess.run(['wmic', 'path', 'win32_VideoController', 'get', 'name'], 
                                  capture_output=True, text=True)
            if "AMD" in result.stdout:
                return "AMD"
            
            return "CPU_ONLY"
        except:
            return "CPU_ONLY"
    
    def get_system_info(self):
        """Obtener información del sistema Windows"""
        try:
            info = {
                "os": f"{os.name} {sys.platform}",
                "cpu_count": psutil.cpu_count(),
                "memory_gb": round(psutil.virtual_memory().total / (1024**3)),
                "python_version": sys.version,
                "architecture": os.environ.get('PROCESSOR_ARCHITECTURE', 'Unknown')
            }
            return info
        except:
            return {"error": "Could not retrieve system info"}
    
    def show_user_selection(self):
        """Mostrar selección de usuario estilo Windows"""
        # Ocultar ventana principal
        self.root.withdraw()
        
        self.user_window = tk.Toplevel()
        self.user_window.title("Seleccionar Usuario - CinBehave")
        self.user_window.geometry("650x550")
        self.user_window.configure(bg="#2c3e50")
        self.user_window.resizable(False, False)
        
        # Centrar ventana
        self.user_window.update_idletasks()
        x = (self.user_window.winfo_screenwidth() // 2) - (650 // 2)
        y = (self.user_window.winfo_screenheight() // 2) - (550 // 2)
        self.user_window.geometry(f"650x550+{x}+{y}")
        
        # Header con gradiente simulado
        header_frame = tk.Frame(self.user_window, bg="#34495e", height=80)
        header_frame.pack(fill="x")
        header_frame.pack_propagate(False)
        
        title_label = tk.Label(header_frame, text="Seleccionar Usuario", 
                              font=self.fonts['title'], 
                              fg="#ecf0f1", bg="#34495e")
        title_label.pack(pady=20)
        
        subtitle_label = tk.Label(header_frame, text="CinBehave - Sistema de Análisis de Videos con SLEAP", 
                                 font=self.fonts['normal'], 
                                 fg="#3498db", bg="#34495e")
        subtitle_label.pack()
        
        # Frame principal
        main_frame = tk.Frame(self.user_window, bg="#2c3e50")
        main_frame.pack(fill="both", expand=True, padx=30, pady=20)
        
        # Frame izquierdo - Usuarios existentes
        left_frame = tk.LabelFrame(main_frame, text="Usuarios Existentes", 
                                  font=self.fonts['subtitle'],
                                  fg="#ecf0f1", bg="#2c3e50")
        left_frame.pack(side="left", fill="both", expand=True, padx=(0, 15))
        
        # Listbox con estilo Windows
        listbox_frame = tk.Frame(left_frame, bg="#2c3e50")
        listbox_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Scrollbar
        scrollbar = tk.Scrollbar(listbox_frame)
        scrollbar.pack(side="right", fill="y")
        
        self.users_listbox = tk.Listbox(listbox_frame, 
                                       yscrollcommand=scrollbar.set,
                                       font=self.fonts['normal'],
                                       bg="#ecf0f1", 
                                       fg="#2c3e50",
                                       selectbackground="#3498db",
                                       selectforeground="white",
                                       height=12)
        self.users_listbox.pack(fill="both", expand=True)
        scrollbar.config(command=self.users_listbox.yview)
        
        # Botón para seleccionar usuario existente
        select_btn = tk.Button(left_frame, text="Seleccionar Usuario", 
                              command=self.select_existing_user,
                              font=self.fonts['button'],
                              bg="#3498db", fg="white",
                              cursor="hand2", relief="raised",
                              padx=20, pady=5)
        select_btn.pack(pady=10)
        
        # Frame derecho - Nuevo usuario
        right_frame = tk.LabelFrame(main_frame, text="Crear Nuevo Usuario", 
                                   font=self.fonts['subtitle'],
                                   fg="#ecf0f1", bg="#2c3e50")
        right_frame.pack(side="right", fill="both", expand=True, padx=(15, 0))
        
        # Formulario nuevo usuario
        form_frame = tk.Frame(right_frame, bg="#2c3e50")
        form_frame.pack(fill="x", padx=15, pady=15)
        
        # Campos del formulario
        tk.Label(form_frame, text="Nombre de Usuario:", 
                font=self.fonts['normal'], 
                fg="#ecf0f1", bg="#2c3e50").pack(anchor="w")
        
        self.new_user_entry = tk.Entry(form_frame, font=self.fonts['normal'], 
                                      width=25, relief="sunken")
        self.new_user_entry.pack(fill="x", pady=5)
        
        tk.Label(form_frame, text="Nombre Completo (opcional):", 
                font=self.fonts['normal'], 
                fg="#ecf0f1", bg="#2c3e50").pack(anchor="w", pady=(15, 0))
        
        self.full_name_entry = tk.Entry(form_frame, font=self.fonts['normal'], 
                                       width=25, relief="sunken")
        self.full_name_entry.pack(fill="x", pady=5)
        
        tk.Label(form_frame, text="Email (opcional):", 
                font=self.fonts['normal'], 
                fg="#ecf0f1", bg="#2c3e50").pack(anchor="w", pady=(15, 0))
        
        self.email_entry = tk.Entry(form_frame, font=self.fonts['normal'], 
                                   width=25, relief="sunken")
        self.email_entry.pack(fill="x", pady=5)
        
        # Información de validación
        info_frame = tk.Frame(form_frame, bg="#34495e", relief="sunken", bd=1)
        info_frame.pack(fill="x", pady=(15, 0))
        
        info_label = tk.Label(info_frame, 
                             text="Requisitos:\n• Mínimo 3 caracteres\n• Sin espacios\n• Solo letras, números y _", 
                             font=self.fonts['small'], 
                             fg="#bdc3c7", bg="#34495e",
                             justify="left")
        info_label.pack(padx=10, pady=5)
        
        # Botón crear usuario
        create_btn = tk.Button(right_frame, text="Crear Usuario", 
                              command=self.create_new_user,
                              font=self.fonts['button'],
                              bg="#27ae60", fg="white",
                              cursor="hand2", relief="raised",
                              padx=20, pady=5)
        create_btn.pack(pady=15)
        
        # Botones inferiores
        bottom_frame = tk.Frame(self.user_window, bg="#34495e")
        bottom_frame.pack(fill="x", pady=10)
        
        # Información del sistema
        system_info = self.get_system_info()
        info_text = f"Sistema: {system_info.get('os', 'Unknown')} | RAM: {system_info.get('memory_gb', 'Unknown')}GB | GPU: {self.check_gpu_support()}"
        
        info_label = tk.Label(bottom_frame, text=info_text, 
                             font=self.fonts['small'], 
                             fg="#bdc3c7", bg="#34495e")
        info_label.pack(side="left", padx=20)
        
        exit_btn = tk.Button(bottom_frame, text="Salir", 
                            command=self.exit_application,
                            font=self.fonts['button'],
                            bg="#e74c3c", fg="white",
                            cursor="hand2", relief="raised",
                            padx=20, pady=5)
        exit_btn.pack(side="right", padx=20)
        
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
                
        # Agregar usuario de ejemplo si no hay ninguno
        if self.users_listbox.size() == 0:
            self.users_listbox.insert(tk.END, "Usuario de Ejemplo (ejemplo)")
    
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
                "projects": [],
                "platform": "Windows",
                "preferences": {
                    "theme": "windows_dark",
                    "language": "es",
                    "notifications": True
                }
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
        self.base_dir = self.user_dir / "cinbehave_data"
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
        """Crear interfaz principal estilo Windows"""
        # Limpiar ventana
        for widget in self.root.winfo_children():
            widget.destroy()
        
        # Configurar ventana principal
        self.root.title(f"CinBehave - {self.current_user}")
        try:
            self.root.state('zoomed')  # Maximizar en Windows
        except:
            pass
        
        # Crear barra de menú
        self.create_menu_bar()
        
        # Header
        self.create_header()
        
        # Toolbar
        self.create_toolbar()
        
        # Sección de proyectos
        self.create_project_section()
        
        # Menú principal
        self.create_main_menu()
        
        # Barra de estado
        self.create_status_bar()
        
        # Actualizar estado
        self.update_status("Sistema iniciado correctamente")
    
    def create_menu_bar(self):
        """Crear barra de menú estilo Windows"""
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)
        
        # Menú Archivo
        file_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Archivo", menu=file_menu)
        file_menu.add_command(label="Nuevo Proyecto", command=self.create_new_project)
        file_menu.add_command(label="Abrir Proyecto", command=self.load_project)
        file_menu.add_command(label="Guardar Proyecto", command=self.save_current_project)
        file_menu.add_separator()
        file_menu.add_command(label="Salir", command=self.exit_application)
        
        # Menú Herramientas
        tools_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Herramientas", menu=tools_menu)
        tools_menu.add_command(label="Configuración SLEAP", command=self.show_sleap_config)
        tools_menu.add_command(label="Monitor de Sistema", command=self.show_system_monitor)
        
        # Menú Ayuda
        help_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Ayuda", menu=help_menu)
        help_menu.add_command(label="Documentación", command=self.show_documentation)
        help_menu.add_command(label="Acerca de", command=self.show_about)
    
    def create_header(self):
        """Crear header estilo Windows"""
        header_frame = tk.Frame(self.root, bg="#34495e", height=100)
        header_frame.pack(fill="x", pady=5)
        header_frame.pack_propagate(False)
        
        # Logo y título
        title_frame = tk.Frame(header_frame, bg="#34495e")
        title_frame.pack(side="left", padx=30, pady=20)
        
        title_label = tk.Label(title_frame, text="CinBehave", 
                              font=self.fonts['title'], 
                              fg="#ecf0f1", bg="#34495e")
        title_label.pack(anchor="w")
        
        user_info = self.get_user_info()
        user_label = tk.Label(title_frame, 
                             text=f"Usuario: {user_info.get('full_name', self.current_user)}", 
                             font=self.fonts['normal'], 
                             fg="#3498db", bg="#34495e")
        user_label.pack(anchor="w")
        
        # Información del sistema
        info_frame = tk.Frame(header_frame, bg="#34495e")
        info_frame.pack(side="right", padx=30, pady=20)
        
        version_label = tk.Label(info_frame, text="v1.0 - Windows", 
                                font=self.fonts['small'], 
                                fg="#95a5a6", bg="#34495e")
        version_label.pack(anchor="e")
        
        time_label = tk.Label(info_frame, text="", 
                             font=self.fonts['small'], 
                             fg="#95a5a6", bg="#34495e")
        time_label.pack(anchor="e")
        
        # Actualizar hora
        def update_time():
            current_time = datetime.now().strftime("%H:%M:%S")
            time_label.config(text=current_time)
            self.root.after(1000, update_time)
        
        update_time()
    
    def create_toolbar(self):
        """Crear toolbar estilo Windows"""
        toolbar_frame = tk.Frame(self.root, bg="#2c3e50", relief="raised", bd=1)
        toolbar_frame.pack(fill="x", padx=5, pady=2)
        
        # Botones de acceso rápido
        self.create_toolbar_button(toolbar_frame, "Nuevo", self.create_new_project, 
                                  "Crear nuevo proyecto")
        self.create_toolbar_button(toolbar_frame, "Abrir", self.load_project, 
                                  "Abrir proyecto existente")
        self.create_toolbar_button(toolbar_frame, "Guardar", self.save_current_project, 
                                  "Guardar proyecto actual")
        
        # Separador
        separator = tk.Frame(toolbar_frame, bg="#34495e", width=2)
        separator.pack(side="left", fill="y", padx=5, pady=2)
        
        self.create_toolbar_button(toolbar_frame, "Configurar", self.show_sleap_config, 
                                  "Configuración SLEAP")
        self.create_toolbar_button(toolbar_frame, "Monitor", self.show_system_monitor, 
                                  "Monitor del sistema")
    
    def create_toolbar_button(self, parent, text, command, tooltip):
        """Crear botón de toolbar"""
        button = tk.Button(parent, text=text, command=command,
                          font=self.fonts['small'], 
                          bg="#3498db", fg="white",
                          relief="raised", bd=1,
                          padx=10, pady=2)
        button.pack(side="left", padx=2, pady=2)
        
        return button
    
    def create_project_section(self):
        """Crear sección de gestión de proyectos"""
        project_frame = tk.Frame(self.root, bg="#34495e", relief="raised", bd=1)
        project_frame.pack(fill="x", padx=10, pady=5)
        
        # Título
        title_label = tk.Label(project_frame, text="Gestión de Proyectos", 
                              font=self.fonts['subtitle'], 
                              fg="#ecf0f1", bg="#34495e")
        title_label.pack(side="left", padx=15, pady=8)
        
        # Controles
        controls_frame = tk.Frame(project_frame, bg="#34495e")
        controls_frame.pack(side="right", padx=15, pady=8)
        
        # Selector de proyecto
        self.project_var = tk.StringVar()
        self.project_combobox = ttk.Combobox(controls_frame, 
                                            textvariable=self.project_var,
                                            values=list(self.projects_data.keys()),
                                            state="readonly",
                                            font=self.fonts['normal'],
                                            width=30)
        self.project_combobox.pack(side="left", padx=5)
        
        # Botones
        self.create_styled_button(controls_frame, "Nuevo", self.create_new_project, 
                                 "#27ae60", side="left", padx=3)
        self.create_styled_button(controls_frame, "Cargar", self.load_project, 
                                 "#3498db", side="left", padx=3)
        self.create_styled_button(controls_frame, "Guardar", self.save_current_project, 
                                 "#f39c12", side="left", padx=3)
        self.create_styled_button(controls_frame, "Eliminar", self.delete_project, 
                                 "#e74c3c", side="left", padx=3)
    
    def create_styled_button(self, parent, text, command, color, **pack_options):
        """Crear botón estilizado para Windows"""
        button = tk.Button(parent, text=text, command=command,
                          font=self.fonts['small'], 
                          fg="white", bg=color,
                          cursor="hand2", relief="raised", bd=1,
                          padx=12, pady=4)
        button.pack(**pack_options)
        
        # Efecto hover
        def on_enter(e):
            button.configure(bg=self.darken_color(color), relief="raised")
        def on_leave(e):
            button.configure(bg=color, relief="raised")
        
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
        """Crear menú principal estilo Windows"""
        menu_frame = tk.Frame(self.root, bg="#2c3e50")
        menu_frame.pack(expand=True, fill="both", padx=40, pady=20)
        
        # Título del menú
        menu_title = tk.Label(menu_frame, text="Menú Principal", 
                             font=self.fonts['subtitle'], 
                             fg="#ecf0f1", bg="#2c3e50")
        menu_title.pack(pady=10)
        
        # Crear grid de botones
        buttons_frame = tk.Frame(menu_frame, bg="#2c3e50")
        buttons_frame.pack(expand=True)
        
        # Botones del menú en grid 2x3
        buttons = [
            ("1. Predecir", self.open_predict_menu, "#3498db"),
            ("2. Entrenar", self.show_training_menu, "#f39c12"),
            ("3. Configuración SLEAP", self.show_sleap_config, "#9b59b6"),
            ("4. Herramientas", self.show_tools_menu, "#e67e22"),
            ("5. Cambiar Usuario", self.change_user, "#95a5a6"),
            ("6. Salir", self.exit_application, "#e74c3c")
        ]
        
        for i, (text, command, color) in enumerate(buttons):
            row = i // 2
            col = i % 2
            
            button = tk.Button(buttons_frame, text=text, command=command,
                              font=self.fonts['button'], 
                              fg="white", bg=color,
                              width=25, height=3, 
                              cursor="hand2", relief="raised", bd=2)
            button.grid(row=row, column=col, padx=15, pady=10, sticky="ew")
            
            # Efecto hover
            def on_enter(e, c=color):
                e.widget.configure(bg=self.darken_color(c), relief="raised")
            def on_leave(e, c=color):
                e.widget.configure(bg=c, relief="raised")
            
            button.bind("<Enter>", on_enter)
            button.bind("<Leave>", on_leave)
        
        # Configurar grid
        buttons_frame.grid_columnconfigure(0, weight=1)
        buttons_frame.grid_columnconfigure(1, weight=1)
    
    def create_status_bar(self):
        """Crear barra de estado estilo Windows"""
        self.status_frame = tk.Frame(self.root, bg="#34495e", relief="sunken", bd=1)
        self.status_frame.pack(fill="x", side="bottom")
        
        # Status principal
        self.status_label = tk.Label(self.status_frame, text="Listo", 
                                    font=self.fonts['small'], 
                                    fg="#ecf0f1", bg="#34495e")
        self.status_label.pack(side="left", padx=10, pady=3)
        
        # Separador
        separator = tk.Frame(self.status_frame, bg="#2c3e50", width=1)
        separator.pack(side="left", fill="y", padx=5, pady=1)
        
        # Indicador de proyecto actual
        self.project_indicator = tk.Label(self.status_frame, text="Sin proyecto", 
                                         font=self.fonts['small'], 
                                         fg="#3498db", bg="#34495e")
        self.project_indicator.pack(side="left", padx=10, pady=3)
        
        # Información del sistema en la derecha
        system_info = tk.Label(self.status_frame, text=f"Windows | Python {sys.version_info.major}.{sys.version_info.minor}", 
                              font=self.fonts['small'], 
                              fg="#95a5a6", bg="#34495e")
        system_info.pack(side="right", padx=10, pady=3)
    
    def update_status(self, message):
        """Actualizar barra de estado"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.status_label.config(text=f"[{timestamp}] {message}")
        self.root.update_idletasks()
        logging.info(message)
    
    # Métodos de funcionalidad (stubs para implementar)
    def create_new_project(self):
        """Crear nuevo proyecto"""
        project_name = simpledialog.askstring("Nuevo Proyecto", "Nombre del proyecto:")
        if project_name:
            messagebox.showinfo("Desarrollo", f"Proyecto '{project_name}' - En desarrollo")
    
    def load_project(self):
        """Cargar proyecto"""
        messagebox.showinfo("Desarrollo", "Función load_project - En desarrollo")
    
    def save_current_project(self):
        """Guardar proyecto actual"""
        messagebox.showinfo("Desarrollo", "Función save_current_project - En desarrollo")
    
    def delete_project(self):
        """Eliminar proyecto"""
        messagebox.showinfo("Desarrollo", "Función delete_project - En desarrollo")
    
    def open_predict_menu(self):
        """Abrir menú de predicción"""
        messagebox.showinfo("Desarrollo", "Función open_predict_menu - En desarrollo")
    
    def show_training_menu(self):
        """Mostrar menú de entrenamiento"""
        messagebox.showinfo("Próximamente", "La funcionalidad de entrenamiento estará disponible pronto")
    
    def show_sleap_config(self):
        """Mostrar configuración SLEAP"""
        messagebox.showinfo("Desarrollo", "Función show_sleap_config - En desarrollo")
    
    def show_tools_menu(self):
        """Mostrar menú de herramientas"""
        messagebox.showinfo("Desarrollo", "Función show_tools_menu - En desarrollo")
    
    def show_system_monitor(self):
        """Mostrar monitor del sistema"""
        messagebox.showinfo("Desarrollo", "Función show_system_monitor - En desarrollo")
    
    def show_documentation(self):
        """Mostrar documentación"""
        doc_path = Path("docs/README.md")
        if doc_path.exists():
            os.startfile(doc_path)
        else:
            messagebox.showinfo("Documentación", "Documentación no disponible")
    
    def show_about(self):
        """Mostrar información sobre la aplicación"""
        about_text = f"""
CinBehave - SLEAP Analysis GUI
Versión 1.0

Sistema de análisis de videos con SLEAP
para investigación de comportamiento animal.

Desarrollado para Windows
Python {sys.version_info.major}.{sys.version_info.minor}

© 2024 CinBehave Project
        """
        
        messagebox.showinfo("Acerca de CinBehave", about_text)
    
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
        app = CinBehaveGUI()
        app.run()
        
    except Exception as e:
        print(f"Error iniciando aplicación: {e}")
        try:
            messagebox.showerror("Error Fatal", f"Error iniciando aplicación: {e}")
        except:
            print("No se pudo mostrar ventana de error")

if __name__ == "__main__":
    main()
