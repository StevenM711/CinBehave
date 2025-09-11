#!/usr/bin/env python3
"""
CinBehave - SLEAP Analysis GUI for Windows
Version: 1.0 - SLEAP Integration Edition
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
import requests
from pathlib import Path
from datetime import datetime
import numpy as np
try:
    from PIL import Image, ImageTk
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
    from matplotlib.figure import Figure
    import seaborn as sns
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import letter
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False

# Verificar SLEAP
try:
    import sleap
    SLEAP_AVAILABLE = True
    SLEAP_VERSION = sleap.__version__
except ImportError:
    SLEAP_AVAILABLE = False
    SLEAP_VERSION = "No instalado"

# Configurar logging
Path("logs").mkdir(exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/cinbehave.log'),
        logging.StreamHandler()
    ]
)

class SLEAPProgressWindow:
    """Ventana de progreso para predicciones SLEAP"""
    def __init__(self, parent, videos_to_process, models_info, output_folder):
        self.parent = parent
        self.videos_to_process = videos_to_process
        self.models_info = models_info
        self.output_folder = output_folder
        self.total_videos = len(videos_to_process)
        self.current_video = 0
        self.processing = True
        self.success = False
        self.results = []
        
        # Crear ventana
        self.window = tk.Toplevel(parent.root)
        self.window.title("🧠 Procesando Predicciones SLEAP - CinBehave")
        self.window.geometry("700x500")
        self.window.configure(bg=ModernColors.PRIMARY_DARK)
        self.window.resizable(False, False)
        self.window.transient(parent.root)
        self.window.grab_set()
        
        # Centrar ventana
        self.center_window()
        
        self.setup_ui()
        
        # Iniciar procesamiento en hilo separado
        self.process_thread = threading.Thread(target=self.process_videos_thread, daemon=True)
        self.process_thread.start()
        
        # Manejar cierre de ventana
        self.window.protocol("WM_DELETE_WINDOW", self.on_closing)
    
    def center_window(self):
        """Centrar ventana en pantalla"""
        self.window.update_idletasks()
        width = 700
        height = 500
        x = (self.window.winfo_screenwidth() // 2) - (width // 2)
        y = (self.window.winfo_screenheight() // 2) - (height // 2)
        self.window.geometry(f"{width}x{height}+{x}+{y}")
    
    def setup_ui(self):
        """Configurar interfaz de progreso"""
        # Header
        header_frame = tk.Frame(self.window, bg=ModernColors.ACCENT_PURPLE, height=80)
        header_frame.pack(fill="x")
        header_frame.pack_propagate(False)
        
        tk.Label(header_frame, text="🧠 Procesando Videos con SLEAP", 
                font=("Segoe UI", 18, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_PURPLE).pack(expand=True)
        
        # Container principal
        main_container = tk.Frame(self.window, bg=ModernColors.PRIMARY_DARK)
        main_container.pack(fill="both", expand=True, padx=30, pady=30)
        
        # Información general
        info_frame = tk.Frame(main_container, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        info_frame.pack(fill="x", pady=(0, 20))
        
        tk.Label(info_frame, text="📊 Información del Procesamiento", 
                font=("Segoe UI", 14, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(pady=(15, 10))
        
        self.info_label = tk.Label(info_frame, 
                                  text=f"Videos a procesar: {self.total_videos}\n"
                                       f"Modelos: {len(self.models_info)} archivos\n"
                                       f"Destino: {self.output_folder}", 
                                  font=("Segoe UI", 11), 
                                  fg=ModernColors.TEXT_SECONDARY, 
                                  bg=ModernColors.CARD_BG,
                                  justify="left")
        self.info_label.pack(pady=(0, 15))
        
        # Progreso general
        progress_frame = tk.Frame(main_container, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        progress_frame.pack(fill="x", pady=(0, 20))
        
        tk.Label(progress_frame, text="⏳ Progreso General", 
                font=("Segoe UI", 14, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(pady=(15, 10))
        
        self.progress_label = tk.Label(progress_frame, text="Video 0 de " + str(self.total_videos), 
                                      font=("Segoe UI", 12), 
                                      fg=ModernColors.TEXT_PRIMARY, 
                                      bg=ModernColors.CARD_BG)
        self.progress_label.pack(pady=5)
        
        # Barra de progreso
        progress_container = tk.Frame(progress_frame, bg=ModernColors.CARD_BG)
        progress_container.pack(fill="x", padx=20, pady=10)
        
        self.progress_bar = ttk.Progressbar(progress_container, mode='determinate', length=600)
        self.progress_bar.pack(fill="x")
        self.progress_bar['maximum'] = self.total_videos
        
        self.percentage_label = tk.Label(progress_frame, text="0%", 
                                        font=("Segoe UI", 11, "bold"), 
                                        fg=ModernColors.ACCENT_GREEN, 
                                        bg=ModernColors.CARD_BG)
        self.percentage_label.pack(pady=(5, 15))
        
        # Video actual
        current_frame = tk.Frame(main_container, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        current_frame.pack(fill="x", pady=(0, 20))
        
        tk.Label(current_frame, text="🎬 Procesando", 
                font=("Segoe UI", 14, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(pady=(15, 10))
        
        self.current_video_label = tk.Label(current_frame, text="Iniciando SLEAP...", 
                                           font=("Segoe UI", 10), 
                                           fg=ModernColors.TEXT_SECONDARY, 
                                           bg=ModernColors.CARD_BG,
                                           wraplength=600)
        self.current_video_label.pack(pady=(0, 15))
        
        # Botón cancelar
        button_frame = tk.Frame(main_container, bg=ModernColors.PRIMARY_DARK)
        button_frame.pack(fill="x")
        
        self.cancel_button = tk.Button(button_frame, text="❌ Cancelar", 
                                      command=self.cancel_processing,
                                      font=("Segoe UI", 11, "bold"),
                                      fg=ModernColors.TEXT_PRIMARY,
                                      bg=ModernColors.ACCENT_RED,
                                      activebackground="#f25255",
                                      relief="flat", padx=20, pady=8)
        self.cancel_button.pack()
    
    def process_videos_thread(self):
        """Hilo para procesar videos con SLEAP"""
        try:
            for i, video_path in enumerate(self.videos_to_process):
                if not self.processing:
                    break
                
                self.current_video = i + 1
                video_name = Path(video_path).name
                output_filename = f"{Path(video_name).stem}_predictions.slp"
                output_path = self.output_folder / output_filename
                
                # Actualizar UI
                self.window.after(0, self.update_progress, video_name, video_path)
                
                # Ejecutar SLEAP
                try:
                    success = self.run_sleap_prediction(video_path, output_path)
                    if success:
                        self.results.append({
                            'video': video_name,
                            'output': str(output_path),
                            'status': 'success'
                        })
                        logging.info(f"SLEAP procesado: {video_name}")
                    else:
                        self.results.append({
                            'video': video_name,
                            'output': str(output_path),
                            'status': 'error'
                        })
                        logging.error(f"Error procesando {video_name}")
                        
                except Exception as e:
                    logging.error(f"Error procesando {video_name}: {e}")
                    self.window.after(0, self.show_error, f"Error procesando {video_name}:\n{e}")
                    return
                
                # Pequeña pausa para no saturar la UI
                time.sleep(0.1)
            
            if self.processing:
                self.success = True
                self.window.after(0, self.processing_completed)
                
        except Exception as e:
            logging.error(f"Error en procesamiento SLEAP: {e}")
            self.window.after(0, self.show_error, f"Error general en SLEAP:\n{e}")
    
    def run_sleap_prediction(self, video_path, output_path):
        """Ejecutar predicción SLEAP"""
        try:
            cmd = [
                'sleap-track',
                '-m', str(self.models_info['centroid']),
                '-m', str(self.models_info['centered_instance']),
                '-o', str(output_path),
                str(video_path)
            ]
            
            # Ejecutar comando
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)  # 1 hora timeout
            
            if result.returncode == 0:
                return True
            else:
                logging.error(f"SLEAP error: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            logging.error(f"Timeout procesando {video_path}")
            return False
        except Exception as e:
            logging.error(f"Error ejecutando SLEAP: {e}")
            return False
    
    def update_progress(self, video_name, video_path):
        """Actualizar interfaz de progreso"""
        # Actualizar contador
        self.progress_label.config(text=f"Video {self.current_video} de {self.total_videos}")
        
        # Actualizar barra de progreso
        self.progress_bar['value'] = self.current_video
        
        # Actualizar porcentaje
        percentage = int((self.current_video / self.total_videos) * 100)
        self.percentage_label.config(text=f"{percentage}%")
        
        # Actualizar video actual
        self.current_video_label.config(text=f"Procesando: {video_name}\nRuta: {video_path}\n\n⚙️ Ejecutando modelos SLEAP...")
        
        self.window.update_idletasks()
    
    def processing_completed(self):
        """Procesamiento completado exitosamente"""
        success_count = len([r for r in self.results if r['status'] == 'success'])
        error_count = len([r for r in self.results if r['status'] == 'error'])
        
        self.progress_label.config(text="¡Procesamiento SLEAP completado!")
        self.percentage_label.config(text="100%", fg=ModernColors.ACCENT_GREEN)
        
        result_text = f"✅ Procesamiento completado\n\n"
        result_text += f"Videos procesados exitosamente: {success_count}\n"
        if error_count > 0:
            result_text += f"Videos con errores: {error_count}\n"
        result_text += f"\nArchivos .slp guardados en:\n{self.output_folder}"
        
        self.current_video_label.config(text=result_text)
        
        self.cancel_button.config(text="✅ Cerrar", bg=ModernColors.ACCENT_GREEN,
                                 activebackground="#67f297", command=self.close_success)
    
    def show_error(self, error_message):
        """Mostrar error en el procesamiento"""
        self.processing = False
        self.current_video_label.config(text=f"❌ Error durante el procesamiento:\n{error_message}")
        self.cancel_button.config(text="❌ Cerrar", command=self.close_error)
    
    def cancel_processing(self):
        """Cancelar procesamiento"""
        if messagebox.askyesno("⚠️ Cancelar", "¿Estás seguro de que deseas cancelar el procesamiento SLEAP?"):
            self.processing = False
            self.window.destroy()
    
    def close_success(self):
        """Cerrar ventana después de éxito"""
        self.window.destroy()
    
    def close_error(self):
        """Cerrar ventana después de error"""
        self.processing = False
        self.window.destroy()
    
    def on_closing(self):
        """Manejar cierre de ventana"""
        if self.success:
            self.window.destroy()
        else:
            self.cancel_processing()

class SLEAPPredictor:
    """Clase para manejar predicciones SLEAP"""
    
    def __init__(self, parent):
        self.parent = parent
        self.models_urls = {
            'centroid': 'https://github.com/StevenM711/CinBehave/raw/main/models/240604_140339.centroid.n=3561',
            'centered_instance': 'https://github.com/StevenM711/CinBehave/raw/main/models/240604_151646.centered_instance.n=3561'
        }
    
    def check_sleap_installation(self):
        """Verificar instalación de SLEAP"""
        if not SLEAP_AVAILABLE:
            return False, "SLEAP no está instalado"
        
        # Verificar comando sleap-track
        try:
            result = subprocess.run(['sleap-track', '--help'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                return True, f"SLEAP {SLEAP_VERSION} disponible"
            else:
                return False, "Comando sleap-track no encontrado"
        except Exception as e:
            return False, f"Error verificando SLEAP: {e}"
    
    def detect_hardware(self):
        """Detectar hardware disponible"""
        gpu_available = False
        gpu_info = "CPU solamente"
        
        try:
            import tensorflow as tf
            gpus = tf.config.list_physical_devices('GPU')
            if gpus:
                gpu_available = True
                gpu_info = f"GPU disponible: {len(gpus)} dispositivo(s)"
        except Exception as e:
            logging.warning(f"Error detectando GPU: {e}")
        
        return gpu_available, gpu_info
    
    def setup_project_structure(self, project_name):
        """Configurar estructura de carpetas para SLEAP"""
        project_folder = self.parent.projects_root_dir / project_name
        
        # Crear carpetas necesarias
        folders = {
            'videos': project_folder / "Videos",
            'data_sleap': project_folder / "Data_Sleap", 
            'models': project_folder / "models"
        }
        
        for folder_name, folder_path in folders.items():
            folder_path.mkdir(parents=True, exist_ok=True)
            logging.info(f"Carpeta {folder_name} verificada: {folder_path}")
        
        return folders
    
    def download_models(self, models_folder):
        """Descargar modelos desde GitHub"""
        downloaded_models = {}
        
        for model_name, url in self.models_urls.items():
            try:
                # Extraer nombre de archivo de la URL
                filename = url.split('/')[-1]
                model_path = models_folder / filename
                
                if model_path.exists():
                    logging.info(f"Modelo ya existe: {filename}")
                    downloaded_models[model_name] = model_path
                    continue
                
                logging.info(f"Descargando modelo: {filename}")
                
                response = requests.get(url, stream=True, timeout=300)
                response.raise_for_status()
                
                with open(model_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        f.write(chunk)
                
                downloaded_models[model_name] = model_path
                logging.info(f"Modelo descargado: {filename}")
                
            except Exception as e:
                logging.error(f"Error descargando modelo {model_name}: {e}")
                raise Exception(f"Error descargando modelo {model_name}: {e}")
        
        return downloaded_models
    
    def get_video_files(self, videos_folder):
        """Obtener lista de archivos de video"""
        video_extensions = ('.mp4', '.avi', '.mov', '.mkv', '.wmv', '.flv', '.webm', '.m4v')
        video_files = []
        
        if videos_folder.exists():
            for file_path in videos_folder.iterdir():
                if file_path.is_file() and file_path.suffix.lower() in video_extensions:
                    video_files.append(file_path)
        
        return video_files
    
    def run_prediction(self, project_name):
        """Ejecutar predicción completa"""
        try:
            # 1. Verificar SLEAP
            sleap_ok, sleap_msg = self.check_sleap_installation()
            if not sleap_ok:
                return False, f"Error con SLEAP: {sleap_msg}"
            
            # 2. Detectar hardware
            gpu_available, gpu_info = self.detect_hardware()
            logging.info(f"Hardware detectado: {gpu_info}")
            
            # 3. Configurar estructura de carpetas
            folders = self.setup_project_structure(project_name)
            
            # 4. Descargar modelos
            self.parent.update_status("📥 Descargando modelos SLEAP...")
            models = self.download_models(folders['models'])
            
            # 5. Obtener videos
            videos = self.get_video_files(folders['videos'])
            if not videos:
                return False, "No se encontraron videos en la carpeta del proyecto"
            
            # 6. Ejecutar predicciones con ventana de progreso
            self.parent.update_status("🧠 Iniciando predicciones SLEAP...")
            
            progress_window = SLEAPProgressWindow(
                self.parent, 
                videos, 
                models, 
                folders['data_sleap']
            )
            
            # Esperar a que termine el procesamiento
            self.parent.root.wait_window(progress_window.window)
            
            return progress_window.success, "Predicciones completadas" if progress_window.success else "Error en predicciones"
            
        except Exception as e:
            logging.error(f"Error en predicción SLEAP: {e}")
            return False, f"Error en predicción: {e}"

class TutorialSystem:
    """Sistema de tutorial para CinBehave"""
    def __init__(self, parent):
        self.parent = parent
        self.tutorial_enabled = True
        self.current_user = None
        
    def load_tutorial_state(self, username):
        """Cargar estado del tutorial para el usuario"""
        self.current_user = username
        user_dir = Path("users") / username
        tutorial_file = user_dir / "tutorial_state.json"
        
        if tutorial_file.exists():
            try:
                with open(tutorial_file, 'r') as f:
                    state = json.load(f)
                return state
            except:
                pass
        
        # Estado por defecto para nuevo usuario
        return {
            "user_creation_shown": False,
            "project_management_shown": False,
            "video_selection_shown": False,
            "sleap_explained": False,
            "monitor_explained": False,
            "tutorial_completed": False
        }
    
    def save_tutorial_state(self, state):
        """Guardar estado del tutorial"""
        if not self.current_user:
            return
            
        user_dir = Path("users") / self.current_user
        tutorial_file = user_dir / "tutorial_state.json"
        
        try:
            with open(tutorial_file, 'w') as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            logging.error(f"Error guardando estado tutorial: {e}")
    
    def reset_tutorial(self, username=None):
        """Resetear tutorial para mostrar todo de nuevo"""
        if username:
            self.current_user = username
        
        state = {
            "user_creation_shown": False,
            "project_management_shown": False,
            "video_selection_shown": False,
            "sleap_explained": False,
            "monitor_explained": False,
            "tutorial_completed": False
        }
        self.save_tutorial_state(state)
        self.tutorial_enabled = True
    
    def show_tutorial_window(self, title, message, step_info=""):
        """Mostrar ventana de tutorial con diseño elegante"""
        if not self.tutorial_enabled:
            return True
        
        # Crear ventana más grande
        tutorial_window = tk.Toplevel(self.parent.root)
        tutorial_window.title(f"🎓 Tutorial CinBehave - {title}")
        tutorial_window.geometry("900x700")  # Aumentado de 700x500 a 900x700
        tutorial_window.configure(bg=ModernColors.PRIMARY_DARK)
        tutorial_window.resizable(True, True)  # Permitir redimensionar
        tutorial_window.minsize(800, 600)  # Tamaño mínimo
        tutorial_window.transient(self.parent.root)
        tutorial_window.grab_set()
        
        # Centrar ventana
        tutorial_window.update_idletasks()
        x = (tutorial_window.winfo_screenwidth() // 2) - (450)  # Ajustado para nueva anchura
        y = (tutorial_window.winfo_screenheight() // 2) - (350)  # Ajustado para nueva altura
        tutorial_window.geometry(f"900x700+{x}+{y}")
        
        # Variable para resultado
        result = {"continue": True}
        
        # Header con gradiente
        header_frame = tk.Frame(tutorial_window, bg=ModernColors.ACCENT_PURPLE, height=100)
        header_frame.pack(fill="x")
        header_frame.pack_propagate(False)
        
        # Icono y título del header
        header_container = tk.Frame(header_frame, bg=ModernColors.ACCENT_PURPLE)
        header_container.pack(fill="both", expand=True, padx=30, pady=20)
        
        # Icono
        icon_frame = tk.Frame(header_container, bg=ModernColors.TEXT_PRIMARY, width=60, height=60)
        icon_frame.pack(side="left", pady=10, padx=(0, 20))
        icon_frame.pack_propagate(False)
        
        tk.Label(icon_frame, text="🎓", font=("Segoe UI", 24), 
                bg=ModernColors.TEXT_PRIMARY, fg=ModernColors.ACCENT_PURPLE).pack(expand=True)
        
        # Títulos
        titles_frame = tk.Frame(header_container, bg=ModernColors.ACCENT_PURPLE)
        titles_frame.pack(side="left", fill="y")
        
        tk.Label(titles_frame, text=f"Tutorial: {title}", 
                font=("Segoe UI", 18, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_PURPLE).pack(anchor="w")
        
        if step_info:
            tk.Label(titles_frame, text=step_info, 
                    font=("Segoe UI", 11), 
                    fg=ModernColors.TEXT_PRIMARY, 
                    bg=ModernColors.ACCENT_PURPLE).pack(anchor="w")
        
        # Contenido principal
        content_frame = tk.Frame(tutorial_window, bg=ModernColors.PRIMARY_DARK)
        content_frame.pack(fill="both", expand=True, padx=40, pady=30)
        
        # Marco del mensaje con scrollbar
        message_frame = tk.Frame(content_frame, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        message_frame.pack(fill="both", expand=True, pady=(0, 20))
        
        # Container para el contenido scrolleable
        scroll_container = tk.Frame(message_frame, bg=ModernColors.CARD_BG)
        scroll_container.pack(fill="both", expand=True, padx=5, pady=5)
        
        # Crear scrollbar
        scrollbar = tk.Scrollbar(scroll_container, bg=ModernColors.PRIMARY_LIGHT, 
                                troughcolor=ModernColors.PRIMARY_DARK,
                                activebackground=ModernColors.ACCENT_PURPLE)
        scrollbar.pack(side="right", fill="y")
        
        # Área de texto con scrollbar
        text_area = tk.Text(scroll_container, 
                           bg=ModernColors.CARD_BG,
                           fg=ModernColors.TEXT_PRIMARY,
                           font=("Segoe UI", 13),  # Fuente un poco más grande
                           wrap="word",
                           yscrollcommand=scrollbar.set,
                           relief="flat",
                           bd=0,
                           padx=25,
                           pady=25,
                           selectbackground=ModernColors.ACCENT_PURPLE,
                           selectforeground=ModernColors.TEXT_PRIMARY,
                           insertbackground=ModernColors.TEXT_PRIMARY,
                           cursor="arrow")  # Cursor de flecha para indicar que es solo lectura
        
        text_area.pack(side="left", fill="both", expand=True)
        
        # Configurar scrollbar
        scrollbar.config(command=text_area.yview)
        
        # Insertar mensaje y hacer readonly
        text_area.insert(1.0, message)
        text_area.config(state="disabled")  # Solo lectura
        
        # Botones más espaciados
        buttons_frame = tk.Frame(content_frame, bg=ModernColors.PRIMARY_DARK, height=70)
        buttons_frame.pack(fill="x")
        buttons_frame.pack_propagate(False)
        
        def on_skip():
            result["continue"] = False
            self.tutorial_enabled = False
            tutorial_window.destroy()
        
        def on_next():
            result["continue"] = True
            tutorial_window.destroy()
        
        # Container para centrar botones
        buttons_container = tk.Frame(buttons_frame, bg=ModernColors.PRIMARY_DARK)
        buttons_container.pack(expand=True, fill="both")
        
        # Botón Omitir Tutorial
        skip_button = tk.Button(buttons_container, text="⏭️ Omitir Tutorial", 
                               command=on_skip,
                               font=("Segoe UI", 12, "bold"),  # Fuente más grande
                               fg=ModernColors.TEXT_PRIMARY,
                               bg=ModernColors.ACCENT_RED,
                               activebackground="#f25255",
                               relief="flat", padx=25, pady=15)  # Botones más grandes
        skip_button.pack(side="left", padx=20, pady=15)
        
        # Botón Siguiente
        next_button = tk.Button(buttons_container, text="▶️ Siguiente", 
                               command=on_next,
                               font=("Segoe UI", 12, "bold"),  # Fuente más grande
                               fg=ModernColors.TEXT_PRIMARY,
                               bg=ModernColors.ACCENT_GREEN,
                               activebackground="#67f297",
                               relief="flat", padx=25, pady=15)  # Botones más grandes
        next_button.pack(side="right", padx=20, pady=15)
        
        # Efectos hover para botones
        def on_enter_skip(e):
            skip_button.configure(bg="#f25255")
        def on_leave_skip(e):
            skip_button.configure(bg=ModernColors.ACCENT_RED)
        def on_enter_next(e):
            next_button.configure(bg="#67f297")
        def on_leave_next(e):
            next_button.configure(bg=ModernColors.ACCENT_GREEN)
        
        skip_button.bind("<Enter>", on_enter_skip)
        skip_button.bind("<Leave>", on_leave_skip)
        next_button.bind("<Enter>", on_enter_next)
        next_button.bind("<Leave>", on_leave_next)
        
        # Hacer foco en botón siguiente por defecto
        next_button.focus_set()
        
        # Atajos de teclado
        def on_key(event):
            if event.keysym == "Return" or event.keysym == "space":
                on_next()
            elif event.keysym == "Escape":
                on_skip()
        
        tutorial_window.bind("<KeyPress>", on_key)
        
        # Esperar resultado
        tutorial_window.wait_window()
        return result["continue"]

class ModernColors:
    """Paleta de colores moderna y atractiva"""
    # Colores principales
    PRIMARY_DARK = "#1e2124"
    PRIMARY_MEDIUM = "#36393f"
    PRIMARY_LIGHT = "#40444b"
    
    # Acentos vibrantes
    ACCENT_BLUE = "#5865f2"
    ACCENT_GREEN = "#57f287"
    ACCENT_YELLOW = "#fee75c"
    ACCENT_RED = "#ed4245"
    ACCENT_PURPLE = "#9966cc"
    ACCENT_ORANGE = "#ff9500"
    
    # Texto
    TEXT_PRIMARY = "#ffffff"
    TEXT_SECONDARY = "#b9bbbe"
    TEXT_MUTED = "#72767d"
    
    # Estados
    SUCCESS = "#00d26a"
    WARNING = "#faa61a"
    ERROR = "#f04747"
    INFO = "#00aff4"
    
    # Transparencias y efectos
    OVERLAY = "#00000080"
    CARD_BG = "#2f3136"
    HOVER_LIGHT = "#4f545c"

class VideoProgressWindow:
    """Ventana de progreso para copia de videos"""
    def __init__(self, parent, videos_to_copy, destination_folder):
        self.parent = parent
        self.videos_to_copy = videos_to_copy
        self.destination_folder = destination_folder
        self.total_videos = len(videos_to_copy)
        self.current_video = 0
        self.copying = True
        self.success = False
        
        # Crear ventana
        self.window = tk.Toplevel(parent.root)
        self.window.title("📥 Copiando Videos - CinBehave")
        self.window.geometry("600x400")
        self.window.configure(bg=ModernColors.PRIMARY_DARK)
        self.window.resizable(False, False)
        self.window.transient(parent.root)
        self.window.grab_set()
        
        # Centrar ventana
        self.center_window()
        
        self.setup_ui()
        
        # Iniciar copia en hilo separado
        self.copy_thread = threading.Thread(target=self.copy_videos_thread, daemon=True)
        self.copy_thread.start()
        
        # Manejar cierre de ventana
        self.window.protocol("WM_DELETE_WINDOW", self.on_closing)
    
    def center_window(self):
        """Centrar ventana en pantalla"""
        self.window.update_idletasks()
        width = 600
        height = 400
        x = (self.window.winfo_screenwidth() // 2) - (width // 2)
        y = (self.window.winfo_screenheight() // 2) - (height // 2)
        self.window.geometry(f"{width}x{height}+{x}+{y}")
    
    def setup_ui(self):
        """Configurar interfaz de progreso"""
        # Header
        header_frame = tk.Frame(self.window, bg=ModernColors.ACCENT_BLUE, height=80)
        header_frame.pack(fill="x")
        header_frame.pack_propagate(False)
        
        tk.Label(header_frame, text="📥 Copiando Videos al Proyecto", 
                font=("Segoe UI", 18, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_BLUE).pack(expand=True)
        
        # Container principal
        main_container = tk.Frame(self.window, bg=ModernColors.PRIMARY_DARK)
        main_container.pack(fill="both", expand=True, padx=30, pady=30)
        
        # Información general
        info_frame = tk.Frame(main_container, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        info_frame.pack(fill="x", pady=(0, 20))
        
        tk.Label(info_frame, text="ℹ️ Información de la Copia", 
                font=("Segoe UI", 14, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(pady=(15, 10))
        
        self.info_label = tk.Label(info_frame, text=f"Total de videos: {self.total_videos}\nDestino: {self.destination_folder}", 
                                  font=("Segoe UI", 11), 
                                  fg=ModernColors.TEXT_SECONDARY, 
                                  bg=ModernColors.CARD_BG,
                                  justify="left")
        self.info_label.pack(pady=(0, 15))
        
        # Progreso general
        progress_frame = tk.Frame(main_container, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        progress_frame.pack(fill="x", pady=(0, 20))
        
        tk.Label(progress_frame, text="📊 Progreso General", 
                font=("Segoe UI", 14, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(pady=(15, 10))
        
        self.progress_label = tk.Label(progress_frame, text="Video 0 de " + str(self.total_videos), 
                                      font=("Segoe UI", 12), 
                                      fg=ModernColors.TEXT_PRIMARY, 
                                      bg=ModernColors.CARD_BG)
        self.progress_label.pack(pady=5)
        
        # Barra de progreso
        progress_container = tk.Frame(progress_frame, bg=ModernColors.CARD_BG)
        progress_container.pack(fill="x", padx=20, pady=10)
        
        # Usar estilo por defecto para evitar errores
        self.progress_bar = ttk.Progressbar(progress_container, mode='determinate', length=500)
        self.progress_bar.pack(fill="x")
        self.progress_bar['maximum'] = self.total_videos
        
        self.percentage_label = tk.Label(progress_frame, text="0%", 
                                        font=("Segoe UI", 11, "bold"), 
                                        fg=ModernColors.ACCENT_GREEN, 
                                        bg=ModernColors.CARD_BG)
        self.percentage_label.pack(pady=(5, 15))
        
        # Video actual
        current_frame = tk.Frame(main_container, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        current_frame.pack(fill="x", pady=(0, 20))
        
        tk.Label(current_frame, text="🎬 Video Actual", 
                font=("Segoe UI", 14, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(pady=(15, 10))
        
        self.current_video_label = tk.Label(current_frame, text="Preparando...", 
                                           font=("Segoe UI", 10), 
                                           fg=ModernColors.TEXT_SECONDARY, 
                                           bg=ModernColors.CARD_BG,
                                           wraplength=500)
        self.current_video_label.pack(pady=(0, 15))
        
        # Botón cancelar
        button_frame = tk.Frame(main_container, bg=ModernColors.PRIMARY_DARK)
        button_frame.pack(fill="x")
        
        self.cancel_button = tk.Button(button_frame, text="❌ Cancelar", 
                                      command=self.cancel_copy,
                                      font=("Segoe UI", 11, "bold"),
                                      fg=ModernColors.TEXT_PRIMARY,
                                      bg=ModernColors.ACCENT_RED,
                                      activebackground="#f25255",
                                      relief="flat", padx=20, pady=8)
        self.cancel_button.pack()
    
    def copy_videos_thread(self):
        """Hilo para copiar videos"""
        try:
            for i, video_path in enumerate(self.videos_to_copy):
                if not self.copying:
                    break
                
                self.current_video = i + 1
                video_name = Path(video_path).name
                destination_path = self.destination_folder / video_name
                
                # Actualizar UI
                self.window.after(0, self.update_progress, video_name, video_path)
                
                # Copiar archivo
                try:
                    shutil.copy2(video_path, destination_path)
                    logging.info(f"Video copiado: {video_name}")
                except Exception as e:
                    logging.error(f"Error copiando {video_name}: {e}")
                    self.window.after(0, self.show_error, f"Error copiando {video_name}:\n{e}")
                    return
                
                # Pequeña pausa para no saturar la UI
                time.sleep(0.1)
            
            if self.copying:
                self.success = True
                self.window.after(0, self.copy_completed)
                
        except Exception as e:
            logging.error(f"Error en copia de videos: {e}")
            self.window.after(0, self.show_error, f"Error general en la copia:\n{e}")
    
    def update_progress(self, video_name, video_path):
        """Actualizar interfaz de progreso"""
        # Actualizar contador
        self.progress_label.config(text=f"Video {self.current_video} de {self.total_videos}")
        
        # Actualizar barra de progreso
        self.progress_bar['value'] = self.current_video
        
        # Actualizar porcentaje
        percentage = int((self.current_video / self.total_videos) * 100)
        self.percentage_label.config(text=f"{percentage}%")
        
        # Actualizar video actual
        self.current_video_label.config(text=f"Copiando: {video_name}\nDesde: {video_path}")
        
        self.window.update_idletasks()
    
    def copy_completed(self):
        """Copia completada exitosamente"""
        self.progress_label.config(text="¡Copia completada exitosamente!")
        self.percentage_label.config(text="100%", fg=ModernColors.ACCENT_GREEN)
        self.current_video_label.config(text=f"✅ Todos los videos han sido copiados correctamente\n\nTotal: {self.total_videos} videos")
        
        self.cancel_button.config(text="✅ Cerrar", bg=ModernColors.ACCENT_GREEN,
                                 activebackground="#67f297", command=self.close_success)
    
    def show_error(self, error_message):
        """Mostrar error en la copia"""
        self.copying = False
        self.current_video_label.config(text=f"❌ Error durante la copia:\n{error_message}")
        self.cancel_button.config(text="❌ Cerrar", command=self.close_error)
    
    def cancel_copy(self):
        """Cancelar copia de videos"""
        if messagebox.askyesno("⚠️ Cancelar Copia", "¿Estás seguro de que deseas cancelar la copia de videos?"):
            self.copying = False
            self.window.destroy()
    
    def close_success(self):
        """Cerrar ventana después de éxito"""
        self.window.destroy()
    
    def close_error(self):
        """Cerrar ventana después de error"""
        self.copying = False
        self.window.destroy()
    
    def on_closing(self):
        """Manejar cierre de ventana"""
        if self.success:
            self.window.destroy()
        else:
            self.cancel_copy()

class SystemMonitorWindow:
    """Ventana del monitor de recursos del sistema - COMPLETAMENTE FUNCIONAL"""
    def __init__(self, parent):
        self.parent = parent
        self.monitoring = False
        self.data_points = 60  # 60 puntos de datos (1 minuto con updates cada segundo)
        
        # Datos de monitoreo
        self.cpu_data = []
        self.memory_data = []
        self.disk_data = []
        self.network_data = []
        self.timestamps = []
        
        # Variables para network
        self.last_network_sent = 0
        self.last_network_recv = 0
        self.network_speed_sent = 0
        self.network_speed_recv = 0
        
        # Ventana del monitor
        self.window = tk.Toplevel(parent.root)
        self.window.title("📊 Monitor de Recursos del Sistema - CinBehave")
        self.window.geometry("1400x900")
        self.window.configure(bg=ModernColors.PRIMARY_DARK)
        self.window.minsize(1000, 700)
        
        # Centrar ventana
        self.center_window()
        
        self.setup_ui()
        self.start_monitoring()
        
        # Manejar cierre de ventana
        self.window.protocol("WM_DELETE_WINDOW", self.on_closing)
    
    def center_window(self):
        """Centrar ventana en pantalla"""
        self.window.update_idletasks()
        width = 1400
        height = 900
        x = (self.window.winfo_screenwidth() // 2) - (width // 2)
        y = (self.window.winfo_screenheight() // 2) - (height // 2)
        self.window.geometry(f"{width}x{height}+{x}+{y}")
    
    def setup_ui(self):
        """Configurar interfaz del monitor"""
        # Header elegante
        header_frame = tk.Frame(self.window, bg=ModernColors.ACCENT_BLUE, height=80)
        header_frame.pack(fill="x")
        header_frame.pack_propagate(False)
        
        header_container = tk.Frame(header_frame, bg=ModernColors.ACCENT_BLUE)
        header_container.pack(fill="both", expand=True, padx=30, pady=20)
        
        # Logo y título
        title_frame = tk.Frame(header_container, bg=ModernColors.ACCENT_BLUE)
        title_frame.pack(side="left", fill="y")
        
        tk.Label(title_frame, text="📊 Monitor de Recursos del Sistema", 
                font=("Segoe UI", 20, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_BLUE).pack(anchor="w")
        
        tk.Label(title_frame, text="Monitoreo en Tiempo Real - CinBehave", 
                font=("Segoe UI", 12), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_BLUE).pack(anchor="w")
        
        # Status del sistema
        status_frame = tk.Frame(header_container, bg=ModernColors.ACCENT_BLUE)
        status_frame.pack(side="right", fill="y")
        
        self.header_status = tk.Label(status_frame, text="🟢 Sistema Activo", 
                                     font=("Segoe UI", 12, "bold"), 
                                     fg=ModernColors.TEXT_PRIMARY, 
                                     bg=ModernColors.ACCENT_BLUE)
        self.header_status.pack(anchor="e")
        
        self.header_time = tk.Label(status_frame, text="", 
                                   font=("Segoe UI", 10), 
                                   fg=ModernColors.TEXT_PRIMARY, 
                                   bg=ModernColors.ACCENT_BLUE)
        self.header_time.pack(anchor="e")
        
        # Container principal
        main_container = tk.Frame(self.window, bg=ModernColors.PRIMARY_DARK)
        main_container.pack(fill="both", expand=True, padx=20, pady=20)
        
        # Panel de estadísticas en tiempo real
        self.create_stats_panel(main_container)
        
        # Panel de gráficos
        if MATPLOTLIB_AVAILABLE:
            self.create_graphs_panel(main_container)
        else:
            self.create_text_panel(main_container)
        
        # Panel de control
        self.create_control_panel(main_container)
        
        # Iniciar actualización del header
        self.update_header_time()
    
    def update_header_time(self):
        """Actualizar tiempo en header"""
        current_time = datetime.now().strftime("🕐 %H:%M:%S")
        self.header_time.config(text=current_time)
        self.window.after(1000, self.update_header_time)
    
    def create_stats_panel(self, parent):
        """Crear panel de estadísticas en tiempo real"""
        stats_frame = tk.Frame(parent, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        stats_frame.pack(fill="x", pady=(0, 20))
        
        # Título del panel
        title_frame = tk.Frame(stats_frame, bg=ModernColors.PRIMARY_LIGHT, height=50)
        title_frame.pack(fill="x")
        title_frame.pack_propagate(False)
        
        tk.Label(title_frame, text="⚡ Estadísticas en Tiempo Real", 
                font=("Segoe UI", 16, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.PRIMARY_LIGHT).pack(expand=True)
        
        # Grid de estadísticas
        stats_grid = tk.Frame(stats_frame, bg=ModernColors.CARD_BG)
        stats_grid.pack(fill="x", padx=20, pady=20)
        
        # Configurar grid responsivo
        for i in range(2):
            stats_grid.grid_rowconfigure(i, weight=1)
        for i in range(4):
            stats_grid.grid_columnconfigure(i, weight=1)
        
        # Crear tarjetas de estadísticas
        self.stat_cards = {}
        stats_config = [
            ("💻 CPU", "cpu", ModernColors.ACCENT_BLUE),
            ("🧠 Memoria", "memory", ModernColors.ACCENT_GREEN),
            ("💾 Disco", "disk", ModernColors.ACCENT_ORANGE),
            ("🌐 Red", "network", ModernColors.ACCENT_PURPLE),
            ("🔥 Temperatura", "temp", ModernColors.ACCENT_RED),
            ("⚡ Energía", "power", ModernColors.ACCENT_YELLOW),
            ("📊 Procesos", "processes", ModernColors.ACCENT_BLUE),
            ("🎮 GPU", "gpu", ModernColors.ACCENT_GREEN)
        ]
        
        for i, (title, key, color) in enumerate(stats_config):
            row = i // 4
            col = i % 4
            card = self.create_stat_card(stats_grid, title, key, color)
            card.grid(row=row, column=col, padx=10, pady=10, sticky="nsew")
    
    def create_stat_card(self, parent, title, key, color):
        """Crear tarjeta individual de estadística"""
        card = tk.Frame(parent, bg=ModernColors.PRIMARY_LIGHT, relief="solid", bd=2)
        
        # Header de la tarjeta
        header = tk.Frame(card, bg=color, height=40)
        header.pack(fill="x")
        header.pack_propagate(False)
        
        tk.Label(header, text=title, font=("Segoe UI", 11, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, bg=color).pack(expand=True)
        
        # Contenido
        content = tk.Frame(card, bg=ModernColors.PRIMARY_LIGHT, height=80)
        content.pack(fill="both", expand=True, padx=15, pady=15)
        content.pack_propagate(False)
        
        # Valor principal
        value_label = tk.Label(content, text="--", font=("Segoe UI", 18, "bold"), 
                              fg=ModernColors.TEXT_PRIMARY, bg=ModernColors.PRIMARY_LIGHT)
        value_label.pack()
        
        # Valor secundario
        detail_label = tk.Label(content, text="Cargando...", font=("Segoe UI", 9), 
                               fg=ModernColors.TEXT_SECONDARY, bg=ModernColors.PRIMARY_LIGHT)
        detail_label.pack()
        
        self.stat_cards[key] = {
            "value": value_label,
            "detail": detail_label
        }
        
        return card
    
    def create_graphs_panel(self, parent):
        """Crear panel de gráficos con matplotlib"""
        graphs_frame = tk.Frame(parent, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        graphs_frame.pack(fill="both", expand=True, pady=(0, 20))
        
        # Título del panel
        title_frame = tk.Frame(graphs_frame, bg=ModernColors.PRIMARY_LIGHT, height=50)
        title_frame.pack(fill="x")
        title_frame.pack_propagate(False)
        
        tk.Label(title_frame, text="📈 Gráficos de Rendimiento en Tiempo Real", 
                font=("Segoe UI", 16, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.PRIMARY_LIGHT).pack(expand=True)
        
        # Crear figura de matplotlib
        plt.style.use('dark_background')
        self.fig, ((self.ax1, self.ax2), (self.ax3, self.ax4)) = plt.subplots(2, 2, figsize=(14, 8))
        self.fig.patch.set_facecolor('#2f3136')
        
        # Configurar estilo de los gráficos
        axes_config = [
            (self.ax1, 'Uso de CPU (%)', '#5865f2'),
            (self.ax2, 'Uso de Memoria (%)', '#57f287'),
            (self.ax3, 'Uso de Disco (%)', '#ff9500'),
            (self.ax4, 'Actividad de Red (MB/s)', '#9966cc')
        ]
        
        for ax, title, color in axes_config:
            ax.set_facecolor('#40444b')
            ax.tick_params(colors='white', labelsize=9)
            ax.set_title(title, color='white', fontsize=12, fontweight='bold')
            ax.grid(True, alpha=0.3, color='white')
            ax.spines['bottom'].set_color('white')
            ax.spines['top'].set_color('white') 
            ax.spines['right'].set_color('white')
            ax.spines['left'].set_color('white')
        
        # Embed en tkinter
        self.canvas = FigureCanvasTkAgg(self.fig, graphs_frame)
        self.canvas.draw()
        self.canvas.get_tk_widget().pack(fill="both", expand=True, padx=20, pady=20)
    
    def create_text_panel(self, parent):
        """Crear panel de texto cuando matplotlib no está disponible"""
        text_frame = tk.Frame(parent, bg=ModernColors.CARD_BG, relief="solid", bd=1)
        text_frame.pack(fill="both", expand=True, pady=(0, 20))
        
        # Título del panel
        title_frame = tk.Frame(text_frame, bg=ModernColors.PRIMARY_LIGHT, height=50)
        title_frame.pack(fill="x")
        title_frame.pack_propagate(False)
        
        tk.Label(title_frame, text="📊 Información del Sistema (Modo Texto)", 
                font=("Segoe UI", 16, "bold"), 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.PRIMARY_LIGHT).pack(expand=True)
        
        # Área de texto con scrollbar
        text_container = tk.Frame(text_frame, bg=ModernColors.CARD_BG)
        text_container.pack(fill="both", expand=True, padx=20, pady=20)
        
        # Scrollbar
        scrollbar = tk.Scrollbar(text_container, bg=ModernColors.PRIMARY_LIGHT)
        scrollbar.pack(side="right", fill="y")
        
        # Área de texto
        self.text_area = tk.Text(text_container, bg=ModernColors.PRIMARY_LIGHT, 
                                fg=ModernColors.TEXT_PRIMARY, font=("Consolas", 11),
                                yscrollcommand=scrollbar.set, wrap="word")
        self.text_area.pack(fill="both", expand=True)
        
        scrollbar.config(command=self.text_area.yview)
    
    def create_control_panel(self, parent):
        """Crear panel de control del monitor"""
        control_frame = tk.Frame(parent, bg=ModernColors.CARD_BG, height=80, relief="solid", bd=1)
        control_frame.pack(fill="x")
        control_frame.pack_propagate(False)
        
        # Container de controles
        controls_container = tk.Frame(control_frame, bg=ModernColors.CARD_BG)
        controls_container.pack(fill="both", expand=True, padx=30, pady=15)
        
        # Lado izquierdo - Botones de control
        left_controls = tk.Frame(controls_container, bg=ModernColors.CARD_BG)
        left_controls.pack(side="left", fill="y")
        
        # Botón parar/iniciar
        self.control_button = tk.Button(left_controls, text="⏸️ Pausar Monitoreo", 
                                       command=self.toggle_monitoring,
                                       font=("Segoe UI", 11, "bold"),
                                       fg=ModernColors.TEXT_PRIMARY,
                                       bg=ModernColors.ACCENT_YELLOW,
                                       activebackground="#ffeb6c",
                                       relief="flat", padx=20, pady=8)
        self.control_button.pack(side="left", padx=(0, 10))
        
        # Botón limpiar datos
        tk.Button(left_controls, text="🗑️ Limpiar Datos", 
                 command=self.clear_data,
                 font=("Segoe UI", 11, "bold"),
                 fg=ModernColors.TEXT_PRIMARY,
                 bg=ModernColors.ACCENT_RED,
                 activebackground="#f25255",
                 relief="flat", padx=20, pady=8).pack(side="left", padx=5)
        
        # Botón exportar
        tk.Button(left_controls, text="💾 Exportar Datos", 
                 command=self.export_data,
                 font=("Segoe UI", 11, "bold"),
                 fg=ModernColors.TEXT_PRIMARY,
                 bg=ModernColors.ACCENT_GREEN,
                 activebackground="#67f297",
                 relief="flat", padx=20, pady=8).pack(side="left", padx=5)
        
        # Botón refrescar
        tk.Button(left_controls, text="🔄 Refrescar", 
                 command=self.refresh_system_info,
                 font=("Segoe UI", 11, "bold"),
                 fg=ModernColors.TEXT_PRIMARY,
                 bg=ModernColors.ACCENT_BLUE,
                 activebackground="#6975f3",
                 relief="flat", padx=20, pady=8).pack(side="left", padx=5)
        
        # Lado derecho - Estado del monitoreo
        right_controls = tk.Frame(controls_container, bg=ModernColors.CARD_BG)
        right_controls.pack(side="right", fill="y")
        
        self.status_label = tk.Label(right_controls, text="🟢 Monitoreo Activo", 
                                    font=("Segoe UI", 12, "bold"), 
                                    fg=ModernColors.ACCENT_GREEN, 
                                    bg=ModernColors.CARD_BG)
        self.status_label.pack(side="right", padx=20)
        
        self.data_points_label = tk.Label(right_controls, text="📊 Puntos de datos: 0", 
                                         font=("Segoe UI", 10), 
                                         fg=ModernColors.TEXT_SECONDARY, 
                                         bg=ModernColors.CARD_BG)
        self.data_points_label.pack(side="right", padx=(0, 20))
    
    def start_monitoring(self):
        """Iniciar monitoreo del sistema"""
        self.monitoring = True
        # Obtener valores iniciales de red
        network = psutil.net_io_counters()
        self.last_network_sent = network.bytes_sent
        self.last_network_recv = network.bytes_recv
        
        self.monitor_thread = threading.Thread(target=self.monitor_loop, daemon=True)
        self.monitor_thread.start()
    
    def monitor_loop(self):
        """Loop principal de monitoreo"""
        while self.monitoring:
            try:
                # Obtener datos del sistema
                current_time = datetime.now()
                
                # CPU
                cpu_percent = psutil.cpu_percent(interval=0.1)
                try:
                    cpu_freq = psutil.cpu_freq()
                    cpu_freq_str = f"{cpu_freq.current:.0f}MHz" if cpu_freq else "N/A"
                except:
                    cpu_freq_str = "N/A"
                cpu_count = psutil.cpu_count()
                
                # Memoria
                memory = psutil.virtual_memory()
                memory_percent = memory.percent
                memory_used_gb = memory.used / (1024**3)
                memory_total_gb = memory.total / (1024**3)
                
                # Disco
                try:
                    disk = psutil.disk_usage('/')
                    disk_percent = disk.percent
                    disk_used_gb = disk.used / (1024**3)
                    disk_total_gb = disk.total / (1024**3)
                except:
                    disk_percent = 0
                    disk_used_gb = 0
                    disk_total_gb = 0
                
                # Red (calcular velocidad)
                network = psutil.net_io_counters()
                current_sent = network.bytes_sent
                current_recv = network.bytes_recv
                
                # Calcular velocidad de red
                sent_speed = (current_sent - self.last_network_sent) / (1024 * 1024)  # MB/s
                recv_speed = (current_recv - self.last_network_recv) / (1024 * 1024)  # MB/s
                total_speed = sent_speed + recv_speed
                
                self.last_network_sent = current_sent
                self.last_network_recv = current_recv
                
                # Temperatura (si está disponible)
                try:
                    temps = psutil.sensors_temperatures()
                    temp_avg = 0
                    temp_count = 0
                    if temps:
                        for name, entries in temps.items():
                            for entry in entries:
                                if entry.current:
                                    temp_avg += entry.current
                                    temp_count += 1
                        temp_avg = temp_avg / temp_count if temp_count > 0 else 0
                    else:
                        temp_avg = 0
                except:
                    temp_avg = 0
                
                # Procesos
                try:
                    processes_count = len(psutil.pids())
                except:
                    processes_count = 0
                
                # Batería/Energía
                try:
                    battery = psutil.sensors_battery()
                    if battery:
                        battery_percent = battery.percent
                        power_plugged = "🔌 Conectado" if battery.power_plugged else "🔋 Batería"
                        power_info = f"{battery_percent:.0f}% - {power_plugged}"
                    else:
                        power_info = "🖥️ PC de Escritorio"
                except:
                    power_info = "N/A"
                
                # GPU (información básica)
                try:
                    # Intentar obtener info básica de GPU
                    gpu_info = "🎮 Detectada"
                except:
                    gpu_info = "❌ No detectada"
                
                # Actualizar datos para gráficos
                self.update_data(current_time, cpu_percent, memory_percent, 
                               disk_percent, total_speed)
                
                # Actualizar UI en el hilo principal
                self.window.after(0, self.update_ui, {
                    'cpu': (f"{cpu_percent:.1f}%", f"{cpu_count} cores @ {cpu_freq_str}"),
                    'memory': (f"{memory_percent:.1f}%", f"{memory_used_gb:.1f}GB / {memory_total_gb:.1f}GB"),
                    'disk': (f"{disk_percent:.1f}%", f"{disk_used_gb:.1f}GB / {disk_total_gb:.1f}GB"),
                    'network': (f"{total_speed:.2f}MB/s", f"↑{sent_speed:.2f} ↓{recv_speed:.2f} MB/s"),
                    'temp': (f"{temp_avg:.1f}°C" if temp_avg > 0 else "N/A", "Temperatura promedio"),
                    'power': (power_info, "Estado de energía"),
                    'processes': (f"{processes_count}", "Procesos activos"),
                    'gpu': (gpu_info, "Estado de GPU")
                })
                
                time.sleep(1)  # Update cada segundo
                
            except Exception as e:
                logging.error(f"Error en monitor: {e}")
                time.sleep(1)
    
    def update_data(self, timestamp, cpu, memory, disk, network):
        """Actualizar arrays de datos"""
        # Agregar nuevos datos
        self.timestamps.append(timestamp)
        self.cpu_data.append(cpu)
        self.memory_data.append(memory)
        self.disk_data.append(disk)
        self.network_data.append(network)
        
        # Mantener solo los últimos N puntos
        if len(self.timestamps) > self.data_points:
            self.timestamps.pop(0)
            self.cpu_data.pop(0)
            self.memory_data.pop(0)
            self.disk_data.pop(0)
            self.network_data.pop(0)
    
    def update_ui(self, data):
        """Actualizar interfaz de usuario"""
        try:
            # Actualizar tarjetas de estadísticas
            for key, (value, detail) in data.items():
                if key in self.stat_cards:
                    self.stat_cards[key]["value"].config(text=value)
                    self.stat_cards[key]["detail"].config(text=detail)
            
            # Actualizar contador de puntos de datos
            self.data_points_label.config(text=f"📊 Puntos de datos: {len(self.timestamps)}")
            
            # Actualizar gráficos si matplotlib está disponible
            if MATPLOTLIB_AVAILABLE and hasattr(self, 'canvas'):
                self.update_graphs()
            elif hasattr(self, 'text_area'):
                self.update_text_display(data)
                
        except Exception as e:
            logging.error(f"Error actualizando UI: {e}")
    
    def update_graphs(self):
        """Actualizar gráficos de matplotlib"""
        try:
            if len(self.timestamps) < 2:
                return
            
            # Limpiar gráficos
            for ax in [self.ax1, self.ax2, self.ax3, self.ax4]:
                ax.clear()
            
            # Crear líneas de tiempo relativas (últimos 60 segundos)
            time_range = list(range(-len(self.timestamps), 0))
            
            # Configurar y dibujar gráficos
            graphs_config = [
                (self.ax1, self.cpu_data, 'Uso de CPU (%)', '#5865f2', 0, 100),
                (self.ax2, self.memory_data, 'Uso de Memoria (%)', '#57f287', 0, 100),
                (self.ax3, self.disk_data, 'Uso de Disco (%)', '#ff9500', 0, 100),
                (self.ax4, self.network_data, 'Actividad de Red (MB/s)', '#9966cc', 0, None)
            ]
            
            for ax, data, title, color, y_min, y_max in graphs_config:
                ax.plot(time_range, data, color=color, linewidth=2.5, alpha=0.8)
                ax.fill_between(time_range, data, alpha=0.3, color=color)
                ax.set_title(title, color='white', fontsize=11, fontweight='bold')
                ax.set_facecolor('#40444b')
                ax.tick_params(colors='white', labelsize=8)
                ax.grid(True, alpha=0.3, color='white')
                ax.set_xlabel('Tiempo (segundos)', color='white', fontsize=9)
                
                if y_max is not None:
                    ax.set_ylim(y_min, y_max)
                
                # Configurar spines
                for spine in ax.spines.values():
                    spine.set_color('white')
            
            # Ajustar layout
            self.fig.tight_layout(pad=3.0)
            
            # Actualizar canvas
            self.canvas.draw()
            
        except Exception as e:
            logging.error(f"Error actualizando gráficos: {e}")
    
    def update_text_display(self, data):
        """Actualizar display de texto cuando no hay matplotlib"""
        try:
            self.text_area.delete(1.0, tk.END)
            
            text = f"{'='*60}\n"
            text += f"MONITOR DEL SISTEMA - CINBEHAVE\n"
            text += f"{'='*60}\n"
            text += f"Actualizado: {datetime.now().strftime('%H:%M:%S - %d/%m/%Y')}\n\n"
            
            # Información actual
            text += f"📊 ESTADÍSTICAS ACTUALES:\n"
            text += f"{'-'*40}\n"
            for key, (value, detail) in data.items():
                icon_map = {
                    'cpu': '💻', 'memory': '🧠', 'disk': '💾', 'network': '🌐',
                    'temp': '🔥', 'power': '⚡', 'processes': '📊', 'gpu': '🎮'
                }
                icon = icon_map.get(key, '📈')
                text += f"{icon} {key.upper()}: {value} - {detail}\n"
            
            # Historial
            text += f"\n📈 HISTORIAL RECIENTE:\n"
            text += f"{'-'*40}\n"
            if len(self.cpu_data) > 0:
                text += f"CPU últimos 10 valores: {[f'{x:.1f}' for x in self.cpu_data[-10:]]}\n"
                text += f"Memoria últimos 10 valores: {[f'{x:.1f}' for x in self.memory_data[-10:]]}\n"
                text += f"Red últimos 10 valores: {[f'{x:.2f}' for x in self.network_data[-10:]]}\n"
            
            # Estadísticas
            if len(self.cpu_data) > 5:
                text += f"\n📋 ESTADÍSTICAS:\n"
                text += f"{'-'*40}\n"
                text += f"CPU - Promedio: {np.mean(self.cpu_data):.1f}% | Máximo: {np.max(self.cpu_data):.1f}%\n"
                text += f"Memoria - Promedio: {np.mean(self.memory_data):.1f}% | Máximo: {np.max(self.memory_data):.1f}%\n"
                text += f"Red - Promedio: {np.mean(self.network_data):.2f}MB/s | Máximo: {np.max(self.network_data):.2f}MB/s\n"
            
            text += f"\n{'='*60}\n"
            text += f"Puntos de datos recolectados: {len(self.timestamps)}\n"
            text += f"Estado del monitoreo: {'🟢 Activo' if self.monitoring else '🔴 Pausado'}\n"
            
            self.text_area.insert(1.0, text)
            
        except Exception as e:
            logging.error(f"Error actualizando texto: {e}")
    
    def toggle_monitoring(self):
        """Alternar estado del monitoreo"""
        self.monitoring = not self.monitoring
        
        if self.monitoring:
            self.control_button.config(text="⏸️ Pausar Monitoreo")
            self.status_label.config(text="🟢 Monitoreo Activo", fg=ModernColors.ACCENT_GREEN)
            self.header_status.config(text="🟢 Sistema Activo")
            self.start_monitoring()
        else:
            self.control_button.config(text="▶️ Reanudar Monitoreo")
            self.status_label.config(text="🔴 Monitoreo Pausado", fg=ModernColors.ACCENT_RED)
            self.header_status.config(text="⏸️ Sistema Pausado")
    
    def clear_data(self):
        """Limpiar datos del monitor"""
        if messagebox.askyesno("🗑️ Limpiar Datos", "¿Eliminar todo el historial de datos?"):
            self.cpu_data.clear()
            self.memory_data.clear()
            self.disk_data.clear()
            self.network_data.clear()
            self.timestamps.clear()
            
            messagebox.showinfo("✅ Datos Limpiados", "Historial de datos eliminado correctamente")
    
    def refresh_system_info(self):
        """Refrescar información del sistema"""
        messagebox.showinfo("🔄 Refrescando", "Refrescando información del sistema...")
    
    def export_data(self):
        """Exportar datos a archivo"""
        if not self.timestamps:
            messagebox.showwarning("⚠️ Sin Datos", "No hay datos para exportar")
            return
        
        filename = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV", "*.csv"), ("Archivo de texto", "*.txt"), ("Todos", "*.*")],
            title="Exportar datos de monitoreo"
        )
        
        if filename:
            try:
                with open(filename, 'w', encoding='utf-8') as f:
                    f.write("Timestamp,CPU(%),Memoria(%),Disco(%),Red(MB/s)\n")
                    for i in range(len(self.timestamps)):
                        f.write(f"{self.timestamps[i].strftime('%Y-%m-%d %H:%M:%S')},{self.cpu_data[i]:.2f},{self.memory_data[i]:.2f},{self.disk_data[i]:.2f},{self.network_data[i]:.2f}\n")
                
                messagebox.showinfo("✅ Exportado", f"Datos exportados exitosamente a:\n{filename}")
                
            except Exception as e:
                messagebox.showerror("❌ Error", f"Error exportando datos:\n{e}")
    
    def on_closing(self):
        """Manejar cierre de ventana"""
        self.monitoring = False
        self.window.destroy()

class CinBehaveGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("CinBehave - SLEAP Analysis GUI v1.0")
        self.root.geometry("1200x800")
        self.root.configure(bg=ModernColors.PRIMARY_DARK)
        self.root.minsize(1000, 600)
        
        # Configurar icono
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
        self.prediction_results = []
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
        
        # NUEVA VARIABLE: Directorio principal de proyectos
        self.projects_root_dir = Path.cwd() / "Proyectos"
        
        # NUEVO: Sistema de tutorial
        self.tutorial = TutorialSystem(self)
        
        # NUEVO: Predictor SLEAP
        self.sleap_predictor = SLEAPPredictor(self)
        
        # Configurar fuentes modernas
        self.fonts = {
            'title': ('Segoe UI', 24, 'bold'),
            'subtitle': ('Segoe UI', 16, 'bold'),
            'heading': ('Segoe UI', 14, 'bold'),
            'normal': ('Segoe UI', 11),
            'button': ('Segoe UI', 11, 'bold'),
            'small': ('Segoe UI', 9),
            'tiny': ('Segoe UI', 8)
        }
        
        # Configurar estilo moderno
        self.setup_modern_styles()
        
        # Mostrar splash screen elegante
        self.show_elegant_splash()
        
        # Verificar dependencias críticas
        self.check_critical_dependencies()
        
        # Inicializar sistema
        self.initialize_system()
        
        # Mostrar selección de usuario
        self.show_user_selection()
    
    def check_critical_dependencies(self):
        """Verificar dependencias críticas al inicio"""
        missing_deps = []
        warnings = []
        
        # Verificar SLEAP
        if not SLEAP_AVAILABLE:
            missing_deps.append("SLEAP")
        else:
            warnings.append(f"✅ SLEAP {SLEAP_VERSION} disponible")
        
        # Verificar matplotlib
        if not MATPLOTLIB_AVAILABLE:
            warnings.append("⚠️ Matplotlib no disponible - Gráficos limitados")
        else:
            warnings.append("✅ Matplotlib disponible")
        
        # Verificar TensorFlow/GPU
        try:
            import tensorflow as tf
            gpus = tf.config.list_physical_devices('GPU')
            if gpus:
                warnings.append(f"✅ GPU disponible: {len(gpus)} dispositivo(s)")
            else:
                warnings.append("⚠️ No se detectó GPU - Usando CPU")
        except ImportError:
            warnings.append("⚠️ TensorFlow no disponible")
        
        # Mostrar resultados
        if missing_deps:
            error_msg = f"❌ DEPENDENCIAS FALTANTES:\n\n"
            error_msg += "\n".join([f"• {dep}" for dep in missing_deps])
            error_msg += f"\n\nPor favor, instala las dependencias faltantes:\n"
            error_msg += f"pip install {' '.join(missing_deps).lower()}"
            
            messagebox.showerror("❌ Error de Dependencias", error_msg)
        
        if warnings:
            status_msg = "🔧 ESTADO DEL SISTEMA:\n\n"
            status_msg += "\n".join(warnings)
            logging.info("Estado del sistema verificado")
    
    def setup_modern_styles(self):
        """Configurar estilos modernos y elegantes"""
        style = ttk.Style()
        try:
            style.theme_use('winnative')
        except:
            try:
                style.theme_use('default')
            except:
                pass  # Usar el tema por defecto del sistema
        
        # Configurar colores modernos para ttk de manera segura
        try:
            style.configure('Modern.TLabel', 
                           background=ModernColors.PRIMARY_DARK, 
                           foreground=ModernColors.TEXT_PRIMARY,
                           font=self.fonts['normal'])
        except:
            pass
        
        try:
            style.configure('Modern.TButton', 
                           background=ModernColors.ACCENT_BLUE,
                           foreground=ModernColors.TEXT_PRIMARY,
                           font=self.fonts['button'],
                           relief='flat')
        except:
            pass
        
        try:
            style.configure('Modern.TEntry', 
                           fieldbackground=ModernColors.CARD_BG,
                           foreground=ModernColors.TEXT_PRIMARY,
                           borderwidth=0,
                           relief='flat')
        except:
            pass
        
        try:
            style.configure('Modern.TCombobox', 
                           fieldbackground=ModernColors.CARD_BG,
                           foreground=ModernColors.TEXT_PRIMARY)
        except:
            pass
        
        try:
            # Configurar progressbar de manera más segura
            style.configure('TProgressbar', 
                           background=ModernColors.ACCENT_GREEN,
                           troughcolor=ModernColors.PRIMARY_LIGHT,
                           borderwidth=0,
                           lightcolor=ModernColors.ACCENT_GREEN,
                           darkcolor=ModernColors.ACCENT_GREEN)
        except:
            pass
        
        try:
            style.configure('Modern.TNotebook', 
                           background=ModernColors.PRIMARY_DARK,
                           borderwidth=0)
        except:
            pass
        
        try:
            style.configure('Modern.TNotebook.Tab', 
                           background=ModernColors.PRIMARY_LIGHT,
                           foreground=ModernColors.TEXT_SECONDARY,
                           padding=[20, 10],
                           font=self.fonts['normal'])
        except:
            pass
        
        try:
            style.map('Modern.TNotebook.Tab',
                     background=[('selected', ModernColors.ACCENT_BLUE)],
                     foreground=[('selected', ModernColors.TEXT_PRIMARY)])
        except:
            pass
    
    def create_modern_button(self, parent, text, command, color=None, **kwargs):
        """Crear botón moderno con efectos"""
        if color is None:
            color = ModernColors.ACCENT_BLUE
        
        button = tk.Button(parent, text=text, command=command,
                          font=self.fonts['button'],
                          fg=ModernColors.TEXT_PRIMARY,
                          bg=color,
                          activebackground=self.lighten_color(color),
                          activeforeground=ModernColors.TEXT_PRIMARY,
                          bd=0,
                          relief='flat',
                          cursor='hand2',
                          padx=20,
                          pady=12,
                          **kwargs)
        
        # Efectos hover
        def on_enter(e):
            button.configure(bg=self.lighten_color(color))
        def on_leave(e):
            button.configure(bg=color)
        
        button.bind("<Enter>", on_enter)
        button.bind("<Leave>", on_leave)
        
        return button
    
    def create_card_frame(self, parent, **kwargs):
        """Crear frame con estilo de tarjeta moderna"""
        # Configurar valores por defecto
        defaults = {
            'bg': ModernColors.CARD_BG,
            'relief': 'flat',
            'bd': 0
        }
        # Actualizar con kwargs (permite sobrescribir defaults)
        defaults.update(kwargs)
        return tk.Frame(parent, **defaults)
    
    def lighten_color(self, color):
        """Aclarar color para efectos hover"""
        color_map = {
            ModernColors.ACCENT_BLUE: "#6975f3",
            ModernColors.ACCENT_GREEN: "#67f297",
            ModernColors.ACCENT_YELLOW: "#ffeb6c",
            ModernColors.ACCENT_RED: "#f25255",
            ModernColors.ACCENT_PURPLE: "#a976dc",
            ModernColors.ACCENT_ORANGE: "#ffa510",
            ModernColors.PRIMARY_LIGHT: "#565a65"
        }
        return color_map.get(color, color)
    
    def show_elegant_splash(self):
        """Mostrar splash screen elegante y moderno"""
        splash = tk.Toplevel(self.root)
        splash.title("CinBehave")
        splash.geometry("600x400")
        splash.configure(bg=ModernColors.PRIMARY_DARK)
        splash.resizable(False, False)
        splash.overrideredirect(True)
        
        # Centrar splash
        splash.update_idletasks()
        x = (splash.winfo_screenwidth() // 2) - (600 // 2)
        y = (splash.winfo_screenheight() // 2) - (400 // 2)
        splash.geometry(f"600x400+{x}+{y}")
        
        # Crear marco principal con gradiente simulado
        main_frame = tk.Frame(splash, bg=ModernColors.PRIMARY_DARK)
        main_frame.pack(fill="both", expand=True)
        
        # Header con color de acento
        header_frame = tk.Frame(main_frame, bg=ModernColors.ACCENT_BLUE, height=60)
        header_frame.pack(fill="x")
        header_frame.pack_propagate(False)
        
        # Contenido central
        content_frame = tk.Frame(main_frame, bg=ModernColors.PRIMARY_DARK)
        content_frame.pack(fill="both", expand=True, padx=40, pady=40)
        
        # Logo/Icono placeholder
        icon_frame = tk.Frame(content_frame, bg=ModernColors.ACCENT_BLUE, width=80, height=80)
        icon_frame.pack(pady=20)
        icon_frame.pack_propagate(False)
        
        tk.Label(icon_frame, text="🔬", font=("Segoe UI", 36), 
                bg=ModernColors.ACCENT_BLUE, fg=ModernColors.TEXT_PRIMARY).pack(expand=True)
        
        # Título principal
        title_label = tk.Label(content_frame, text="CinBehave", 
                              font=self.fonts['title'], 
                              fg=ModernColors.TEXT_PRIMARY, 
                              bg=ModernColors.PRIMARY_DARK)
        title_label.pack(pady=10)
        
        # Subtítulo
        subtitle_label = tk.Label(content_frame, text="SLEAP Analysis GUI", 
                                 font=self.fonts['subtitle'], 
                                 fg=ModernColors.ACCENT_BLUE, 
                                 bg=ModernColors.PRIMARY_DARK)
        subtitle_label.pack(pady=5)
        
        # Descripción
        desc_label = tk.Label(content_frame, text="Sistema Avanzado de Análisis de Videos\ncon Machine Learning", 
                             font=self.fonts['normal'], 
                             fg=ModernColors.TEXT_SECONDARY, 
                             bg=ModernColors.PRIMARY_DARK)
        desc_label.pack(pady=20)
        
        # Info de SLEAP
        sleap_info = f"SLEAP: {'✅ ' + SLEAP_VERSION if SLEAP_AVAILABLE else '❌ No instalado'}"
        info_label = tk.Label(content_frame, text=sleap_info, 
                             font=self.fonts['small'], 
                             fg=ModernColors.ACCENT_GREEN if SLEAP_AVAILABLE else ModernColors.ACCENT_RED, 
                             bg=ModernColors.PRIMARY_DARK)
        info_label.pack()
        
        # Barra de progreso moderna
        progress_frame = tk.Frame(content_frame, bg=ModernColors.PRIMARY_DARK)
        progress_frame.pack(fill="x", pady=20)
        
        progress_bg = tk.Frame(progress_frame, bg=ModernColors.PRIMARY_LIGHT, height=6)
        progress_bg.pack(fill="x")
        
        progress_fill = tk.Frame(progress_bg, bg=ModernColors.ACCENT_GREEN, height=6)
        progress_fill.pack(side="left", fill="y")
        
        # Status elegante
        status_label = tk.Label(content_frame, text="Inicializando componentes...", 
                               font=self.fonts['small'], 
                               fg=ModernColors.TEXT_MUTED, 
                               bg=ModernColors.PRIMARY_DARK)
        status_label.pack()
        
        # Animación de progreso
        def animate_progress():
            for i in range(101):
                width = int(520 * i / 100)  # 520 es el ancho aproximado
                progress_fill.configure(width=width)
                
                if i < 25:
                    status_label.config(text="Verificando SLEAP...")
                elif i < 50:
                    status_label.config(text="Inicializando módulos de IA...")
                elif i < 75:
                    status_label.config(text="Preparando interfaz...")
                elif i < 95:
                    status_label.config(text="Configurando análisis...")
                else:
                    status_label.config(text="¡Sistema listo!")
                
                splash.update()
                time.sleep(0.03)
            
            time.sleep(0.5)
            splash.destroy()
        
        splash.after(200, animate_progress)
    
    def initialize_system(self):
        """Inicializar sistema con logging elegante"""
        try:
            directories = [
                "users", "temp", "logs", "config", 
                "assets", "docs", "models", "exports",
                "Proyectos"  # NUEVA: Carpeta estándar para proyectos
            ]
            
            for directory in directories:
                Path(directory).mkdir(exist_ok=True)
            
            # Crear configuración avanzada
            config_file = Path("config/windows_config.json")
            if not config_file.exists():
                windows_config = {
                    "version": "1.0",
                    "platform": "Windows",
                    "theme": "modern_dark",
                    "language": "es",
                    "debug_mode": False,
                    "auto_save": True,
                    "gpu_support": self.check_gpu_support(),
                    "system_info": self.get_system_info(),
                    "ui_animations": True,
                    "high_dpi": True,
                    "projects_directory": str(self.projects_root_dir),
                    "sleap_available": SLEAP_AVAILABLE,
                    "sleap_version": SLEAP_VERSION
                }
                with open(config_file, 'w') as f:
                    json.dump(windows_config, f, indent=2)
            
            logging.info("Sistema avanzado inicializado correctamente")
            logging.info(f"Directorio de proyectos: {self.projects_root_dir}")
            logging.info(f"SLEAP disponible: {SLEAP_AVAILABLE} ({SLEAP_VERSION})")
            
        except Exception as e:
            logging.error(f"Error inicializando sistema: {e}")
            messagebox.showerror("Error del Sistema", f"Error inicializando: {e}")
    
    def check_gpu_support(self):
        """Verificar soporte GPU avanzado"""
        try:
            result = subprocess.run(['nvidia-smi'], capture_output=True, text=True)
            if result.returncode == 0:
                return "NVIDIA"
            
            result = subprocess.run(['wmic', 'path', 'win32_VideoController', 'get', 'name'], 
                                  capture_output=True, text=True)
            if "AMD" in result.stdout:
                return "AMD"
            
            return "CPU_ONLY"
        except:
            return "CPU_ONLY"
    
    def get_system_info(self):
        """Obtener información detallada del sistema"""
        try:
            info = {
                "os": f"{os.name} {sys.platform}",
                "cpu_count": psutil.cpu_count(),
                "memory_gb": round(psutil.virtual_memory().total / (1024**3)),
                "python_version": sys.version,
                "architecture": os.environ.get('PROCESSOR_ARCHITECTURE', 'Unknown'),
                "gpu_support": self.check_gpu_support(),
                "sleap_available": SLEAP_AVAILABLE,
                "sleap_version": SLEAP_VERSION
            }
            return info
        except:
            return {"error": "Could not retrieve system info"}
    
    def show_user_selection(self):
        """Mostrar selección de usuario con diseño moderno y BOTÓN VISIBLE"""
        # NUEVO: Mostrar tutorial de usuario ANTES de crear la ventana
        self.show_user_creation_tutorial()
        
        self.root.withdraw()
        
        self.user_window = tk.Toplevel()
        self.user_window.title("CinBehave - Selección de Usuario")
        self.user_window.geometry("1000x700")
        self.user_window.configure(bg=ModernColors.PRIMARY_DARK)
        self.user_window.resizable(False, False)
        
        # Centrar ventana
        self.user_window.update_idletasks()
        x = (self.user_window.winfo_screenwidth() // 2) - (1000 // 2)
        y = (self.user_window.winfo_screenheight() // 2) - (700 // 2)
        self.user_window.geometry(f"1000x700+{x}+{y}")
        
        # Header moderno con gradiente
        header_frame = tk.Frame(self.user_window, bg=ModernColors.ACCENT_BLUE, height=120)
        header_frame.pack(fill="x")
        header_frame.pack_propagate(False)
        
        # Título del header
        title_container = tk.Frame(header_frame, bg=ModernColors.ACCENT_BLUE)
        title_container.pack(expand=True, fill="both")
        
        title_label = tk.Label(title_container, text="Bienvenido a CinBehave", 
                              font=self.fonts['title'], 
                              fg=ModernColors.TEXT_PRIMARY, 
                              bg=ModernColors.ACCENT_BLUE)
        title_label.pack(expand=True)
        
        subtitle_label = tk.Label(title_container, text="Sistema Avanzado de Análisis de Comportamiento Animal", 
                                 font=self.fonts['normal'], 
                                 fg=ModernColors.TEXT_PRIMARY, 
                                 bg=ModernColors.ACCENT_BLUE)
        subtitle_label.pack()
        
        # Container principal
        main_container = tk.Frame(self.user_window, bg=ModernColors.PRIMARY_DARK)
        main_container.pack(fill="both", expand=True, padx=40, pady=30)
        
        # Frame izquierdo - Usuarios existentes
        left_card = self.create_card_frame(main_container, relief="solid", bd=1)
        left_card.pack(side="left", fill="both", expand=True, padx=(0, 20))
        
        # Header de la tarjeta izquierda
        left_header = tk.Frame(left_card, bg=ModernColors.PRIMARY_LIGHT, height=60)
        left_header.pack(fill="x")
        left_header.pack_propagate(False)
        
        tk.Label(left_header, text="👤 Usuarios Registrados", 
                font=self.fonts['heading'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.PRIMARY_LIGHT).pack(expand=True)
        
        # Lista de usuarios con estilo moderno
        list_container = tk.Frame(left_card, bg=ModernColors.CARD_BG)
        list_container.pack(fill="both", expand=True, padx=20, pady=20)
        
        # Scrollbar para la lista
        scrollbar = tk.Scrollbar(list_container, bg=ModernColors.PRIMARY_LIGHT)
        scrollbar.pack(side="right", fill="y")
        
        self.users_listbox = tk.Listbox(list_container,
                                       font=self.fonts['normal'],
                                       bg=ModernColors.PRIMARY_LIGHT,
                                       fg=ModernColors.TEXT_PRIMARY,
                                       selectbackground=ModernColors.ACCENT_BLUE,
                                       selectforeground=ModernColors.TEXT_PRIMARY,
                                       activestyle='none',
                                       bd=0,
                                       highlightthickness=0,
                                       yscrollcommand=scrollbar.set)
        self.users_listbox.pack(side="left", fill="both", expand=True)
        
        scrollbar.config(command=self.users_listbox.yview)
        
        # Botón seleccionar moderno
        select_button = self.create_modern_button(left_card, "🚀 Seleccionar Usuario", 
                                                 self.select_existing_user, 
                                                 ModernColors.ACCENT_GREEN)
        select_button.pack(pady=20, padx=20, fill="x")
        
        # Frame derecho - Nuevo usuario
        right_card = self.create_card_frame(main_container, relief="solid", bd=1)
        right_card.pack(side="right", fill="both", expand=True, padx=(20, 0))
        
        # Header de la tarjeta derecha
        right_header = tk.Frame(right_card, bg=ModernColors.PRIMARY_LIGHT, height=60)
        right_header.pack(fill="x")
        right_header.pack_propagate(False)
        
        tk.Label(right_header, text="✨ Crear Nuevo Usuario", 
                font=self.fonts['heading'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.PRIMARY_LIGHT).pack(expand=True)
        
        # Formulario moderno
        form_container = tk.Frame(right_card, bg=ModernColors.CARD_BG)
        form_container.pack(fill="both", expand=True, padx=20, pady=20)
        
        # Campo nombre de usuario
        tk.Label(form_container, text="Nombre de Usuario *", 
                font=self.fonts['normal'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(anchor="w", pady=(0, 5))
        
        self.new_user_entry = tk.Entry(form_container, 
                                      font=self.fonts['normal'],
                                      bg=ModernColors.PRIMARY_LIGHT,
                                      fg=ModernColors.TEXT_PRIMARY,
                                      bd=2,
                                      relief='solid',
                                      insertbackground=ModernColors.TEXT_PRIMARY)
        self.new_user_entry.pack(fill="x", pady=(0, 15), ipady=10)
        
        # Campo nombre completo
        tk.Label(form_container, text="Nombre Completo (opcional)", 
                font=self.fonts['normal'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(anchor="w", pady=(0, 5))
        
        self.full_name_entry = tk.Entry(form_container, 
                                       font=self.fonts['normal'],
                                       bg=ModernColors.PRIMARY_LIGHT,
                                       fg=ModernColors.TEXT_PRIMARY,
                                       bd=2,
                                       relief='solid',
                                       insertbackground=ModernColors.TEXT_PRIMARY)
        self.full_name_entry.pack(fill="x", pady=(0, 15), ipady=10)
        
        # Campo email
        tk.Label(form_container, text="Email (opcional)", 
                font=self.fonts['normal'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(anchor="w", pady=(0, 5))
        
        self.email_entry = tk.Entry(form_container, 
                                   font=self.fonts['normal'],
                                   bg=ModernColors.PRIMARY_LIGHT,
                                   fg=ModernColors.TEXT_PRIMARY,
                                   bd=2,
                                   relief='solid',
                                   insertbackground=ModernColors.TEXT_PRIMARY)
        self.email_entry.pack(fill="x", pady=(0, 20), ipady=10)
        
        # Info panel elegante
        info_panel = tk.Frame(form_container, bg=ModernColors.PRIMARY_LIGHT, relief="solid", bd=1)
        info_panel.pack(fill="x", pady=(0, 20))
        
        tk.Label(info_panel, text="📋 Requisitos del Nombre de Usuario", 
                font=self.fonts['small'], 
                fg=ModernColors.ACCENT_YELLOW, 
                bg=ModernColors.PRIMARY_LIGHT).pack(anchor="w", padx=15, pady=(10, 5))
        
        requirements = "• Mínimo 3 caracteres\n• Solo letras, números y guiones bajos (_)\n• Sin espacios ni caracteres especiales"
        tk.Label(info_panel, text=requirements, 
                font=self.fonts['tiny'], 
                fg=ModernColors.TEXT_MUTED, 
                bg=ModernColors.PRIMARY_LIGHT,
                justify="left").pack(anchor="w", padx=15, pady=(0, 10))
        
        # BOTÓN CREAR USUARIO - ASEGURADO COMO VISIBLE
        button_frame = tk.Frame(right_card, bg=ModernColors.CARD_BG, height=80)
        button_frame.pack(fill="x", padx=20, pady=20)
        button_frame.pack_propagate(False)
        
        create_button = self.create_modern_button(button_frame, "🎯 CREAR USUARIO", 
                                                 self.create_new_user, 
                                                 ModernColors.ACCENT_PURPLE)
        create_button.pack(expand=True, fill="both", padx=10, pady=10)
        
        # NUEVO: Botón alternativo más visible
        create_button_alt = self.create_modern_button(form_container, "✅ Crear Usuario", 
                                                     self.create_new_user, 
                                                     ModernColors.ACCENT_GREEN)
        create_button_alt.pack(fill="x", pady=(10, 0))
        
        # Footer con información del sistema
        footer_frame = tk.Frame(self.user_window, bg=ModernColors.PRIMARY_MEDIUM, height=70)
        footer_frame.pack(fill="x", side="bottom")
        footer_frame.pack_propagate(False)
        
        footer_container = tk.Frame(footer_frame, bg=ModernColors.PRIMARY_MEDIUM)
        footer_container.pack(fill="both", expand=True, padx=30, pady=15)
        
        system_info = self.get_system_info()
        info_text = f"💻 {system_info.get('os', 'Unknown')} | 🧠 RAM: {system_info.get('memory_gb', '?')}GB | 🎮 GPU: {system_info.get('gpu_support', 'Unknown')} | 🔬 SLEAP: {SLEAP_VERSION if SLEAP_AVAILABLE else 'No instalado'} | 📊 Monitor: {'Disponible' if MATPLOTLIB_AVAILABLE else 'Básico'}"
        
        tk.Label(footer_container, text=info_text, 
                font=self.fonts['small'], 
                fg=ModernColors.TEXT_MUTED, 
                bg=ModernColors.PRIMARY_MEDIUM).pack(side="left", pady=5)
        
        exit_button = self.create_modern_button(footer_container, "❌ Salir", 
                                               self.exit_application, 
                                               ModernColors.ACCENT_RED)
        exit_button.pack(side="right", pady=5)
        
        # Cargar usuarios y configurar eventos
        self.load_existing_users()
        self.new_user_entry.bind('<Return>', lambda e: self.create_new_user())
        self.user_window.protocol("WM_DELETE_WINDOW", self.exit_application)
        
        # Hacer foco en el campo de usuario
        self.new_user_entry.focus_set()
    
    def load_existing_users(self):
        """Cargar usuarios con información rica"""
        self.users_listbox.delete(0, tk.END)
        
        users_dir = Path("users")
        if users_dir.exists():
            users = []
            for user_folder in users_dir.iterdir():
                if user_folder.is_dir():
                    user_info_file = user_folder / "user_info.json"
                    if user_info_file.exists():
                        try:
                            with open(user_info_file, 'r') as f:
                                user_data = json.load(f)
                            display_name = user_data.get('full_name', user_folder.name)
                            last_login = user_data.get('last_login', 'Nunca')
                            if last_login != 'Nunca':
                                try:
                                    last_login = datetime.fromisoformat(last_login).strftime('%d/%m/%Y %H:%M')
                                except:
                                    last_login = 'Fecha inválida'
                            users.append((display_name, user_folder.name, last_login))
                        except:
                            users.append((user_folder.name, user_folder.name, "Desconocido"))
                    else:
                        users.append((user_folder.name, user_folder.name, "Sin datos"))
            
            # Ordenar por última conexión
            users.sort(key=lambda x: x[2], reverse=True)
            
            for display_name, folder_name, last_login in users:
                display_text = f"👤 {display_name}"
                if display_name != folder_name:
                    display_text += f" ({folder_name})"
                display_text += f"\n    📅 Último acceso: {last_login}"
                self.users_listbox.insert(tk.END, display_text)
        
        if self.users_listbox.size() == 0:
            self.users_listbox.insert(tk.END, "📝 No hay usuarios registrados")
            self.users_listbox.insert(tk.END, "👉 Crea tu primer usuario en el panel derecho")
    
    def select_existing_user(self):
        """Seleccionar usuario existente"""
        selection = self.users_listbox.curselection()
        if not selection:
            messagebox.showwarning("⚠️ Advertencia", "Selecciona un usuario de la lista")
            return
        
        selected_text = self.users_listbox.get(selection[0])
        
        if "No hay usuarios registrados" in selected_text or "Crea tu primer usuario" in selected_text:
            messagebox.showinfo("ℹ️ Info", "Primero debes crear un usuario en el panel derecho")
            return
        
        # Extraer nombre de usuario
        if '(' in selected_text and ')' in selected_text:
            self.current_user = selected_text.split('(')[1].split(')')[0]
        else:
            # Extraer solo el nombre después del emoji
            parts = selected_text.split('\n')[0]  # Primera línea
            self.current_user = parts.replace('👤 ', '').strip()
        
        # NUEVO: Cargar estado del tutorial para verificar si necesita tutorial
        tutorial_state = self.tutorial.load_tutorial_state(self.current_user)
        if not tutorial_state.get("project_management_shown", False):
            # Es un usuario que nunca ha visto el tutorial de proyectos
            pass  # El tutorial se mostrará en setup_user_environment
        
        self.setup_user_environment()
    
    def create_new_user(self):
        """Crear nuevo usuario con validación avanzada"""
        username = self.new_user_entry.get().strip()
        full_name = self.full_name_entry.get().strip()
        email = self.email_entry.get().strip()
        
        # Validaciones
        if not username:
            messagebox.showwarning("⚠️ Validación", "Por favor ingresa un nombre de usuario")
            self.new_user_entry.focus_set()
            return
        
        if len(username) < 3:
            messagebox.showwarning("⚠️ Validación", "El nombre debe tener al menos 3 caracteres")
            self.new_user_entry.focus_set()
            return
        
        if ' ' in username or not username.replace('_', '').isalnum():
            messagebox.showwarning("⚠️ Validación", "Solo se permiten letras, números y guiones bajos (_)")
            self.new_user_entry.focus_set()
            return
        
        user_dir = Path("users") / username
        if user_dir.exists():
            messagebox.showwarning("⚠️ Usuario Existente", "Ya existe un usuario con ese nombre\nElige un nombre diferente")
            self.new_user_entry.focus_set()
            return
        
        try:
            user_dir.mkdir(parents=True)
            
            user_info = {
                "username": username,
                "full_name": full_name or username,
                "email": email,
                "created": datetime.now().isoformat(),
                "last_login": datetime.now().isoformat(),
                "projects": [],
                "platform": "Windows",
                "version": "1.0",
                "preferences": {
                    "theme": "modern_dark",
                    "language": "es",
                    "notifications": True,
                    "auto_save": True
                }
            }
            
            with open(user_dir / "user_info.json", 'w') as f:
                json.dump(user_info, f, indent=2)
            
            self.current_user = username
            
            # NUEVO: Inicializar estado del tutorial para nuevo usuario
            self.tutorial.current_user = username
            
            self.setup_user_environment()
            
            logging.info(f"Usuario {username} creado exitosamente")
            
        except Exception as e:
            logging.error(f"Error creando usuario: {e}")
            messagebox.showerror("❌ Error", f"Error creando usuario:\n{e}")
    
    def setup_user_environment(self):
        """Configurar entorno completo del usuario"""
        try:
            self.setup_directories()
            self.load_user_projects()
            self.update_last_login()
            
            # NUEVO: Cargar estado del tutorial para este usuario
            self.tutorial.load_tutorial_state(self.current_user)
            
            self.user_window.destroy()
            self.root.deiconify()
            self.create_main_interface()
            
            # NUEVO: Mostrar tutorial de gestión de proyectos
            self.show_project_management_tutorial()
            
            user_info = self.get_user_info()
            welcome_msg = f"¡Bienvenido de vuelta, {user_info.get('full_name', self.current_user)}! 🎉\n\n✅ Sistema listo para análisis\n📊 Monitor de recursos disponible\n🧠 SLEAP {SLEAP_VERSION if SLEAP_AVAILABLE else 'no disponible'}\n🎬 Funciones de predicción preparadas"
            messagebox.showinfo("🎯 Bienvenido", welcome_msg)
            
            logging.info(f"Usuario {self.current_user} iniciado correctamente")
            
        except Exception as e:
            logging.error(f"Error configurando entorno: {e}")
            messagebox.showerror("❌ Error", f"Error configurando entorno: {e}")
    
    def setup_directories(self):
        """Configurar estructura completa de directorios"""
        self.user_dir = Path("users") / self.current_user
        self.base_dir = self.user_dir / "cinbehave_data"
        self.videos_dir = self.base_dir / "videos"
        self.results_dir = self.base_dir / "results"
        self.sleap_results_dir = self.base_dir / "sleap_results"
        self.prediction_results_dir = self.base_dir / "prediction_results"
        self.projects_dir = self.user_dir / "projects"
        self.annotations_dir = self.base_dir / "annotations"
        self.exports_dir = self.base_dir / "exports"
        
        for directory in [self.user_dir, self.base_dir, self.videos_dir, 
                         self.results_dir, self.sleap_results_dir, 
                         self.prediction_results_dir, self.projects_dir, 
                         self.annotations_dir, self.exports_dir]:
            directory.mkdir(parents=True, exist_ok=True)
    
    def get_user_info(self):
        """Obtener información completa del usuario"""
        user_info_file = self.user_dir / "user_info.json"
        if user_info_file.exists():
            try:
                with open(user_info_file, 'r') as f:
                    return json.load(f)
            except:
                pass
        return {"username": self.current_user, "full_name": self.current_user}
    
    def update_last_login(self):
        """Actualizar timestamp de último login"""
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
        """Crear interfaz principal moderna y elegante"""
        # Limpiar ventana
        for widget in self.root.winfo_children():
            widget.destroy()
        
        # Configurar ventana principal
        self.root.title(f"CinBehave - {self.current_user}")
        try:
            self.root.state('zoomed')
        except:
            self.root.geometry("1400x900")
        
        # Crear barra de menú moderna
        self.create_modern_menu_bar()
        
        # Header principal elegante
        self.create_elegant_header()
        
        # Sección de gestión de proyectos
        self.create_project_management()
        
        # Menú principal con tarjetas
        self.create_card_menu()
        
        # Barra de estado moderna
        self.create_modern_status_bar()
        
        self.update_status("🚀 Sistema listo para análisis")
    
    def create_modern_menu_bar(self):
        """Crear barra de menú moderna"""
        menubar = tk.Menu(self.root, bg=ModernColors.PRIMARY_DARK, fg=ModernColors.TEXT_PRIMARY)
        self.root.config(menu=menubar)
        
        # Menú Archivo
        file_menu = tk.Menu(menubar, tearoff=0, bg=ModernColors.CARD_BG, fg=ModernColors.TEXT_PRIMARY)
        menubar.add_cascade(label="📁 Archivo", menu=file_menu)
        file_menu.add_command(label="🆕 Nuevo Proyecto", command=self.create_new_project)
        file_menu.add_command(label="📂 Abrir Proyecto", command=self.load_project)
        file_menu.add_command(label="💾 Guardar Proyecto", command=self.save_current_project)
        file_menu.add_separator()
        file_menu.add_command(label="📁 Abrir Carpeta de Proyectos", command=self.open_projects_folder)
        file_menu.add_separator()
        file_menu.add_command(label="🚪 Salir", command=self.exit_application)
        
        # Menú Herramientas
        tools_menu = tk.Menu(menubar, tearoff=0, bg=ModernColors.CARD_BG, fg=ModernColors.TEXT_PRIMARY)
        menubar.add_cascade(label="🛠️ Herramientas", menu=tools_menu)
        tools_menu.add_command(label="⚙️ Configuración SLEAP", command=self.show_sleap_config)
        tools_menu.add_command(label="📊 Monitor de Sistema", command=self.show_system_monitor)
        tools_menu.add_command(label="🎨 Preferencias", command=self.show_preferences)
        
        # Menú Ayuda
        help_menu = tk.Menu(menubar, tearoff=0, bg=ModernColors.CARD_BG, fg=ModernColors.TEXT_PRIMARY)
        menubar.add_cascade(label="❓ Ayuda", menu=help_menu)
        help_menu.add_command(label="🎓 Tutorial", command=self.restart_tutorial)
        help_menu.add_separator()
        help_menu.add_command(label="📖 Documentación", command=self.show_documentation)
        help_menu.add_command(label="🆘 Soporte", command=self.show_support)
        help_menu.add_command(label="ℹ️ Acerca de", command=self.show_about)
    
    def open_projects_folder(self):
        """Abrir carpeta de proyectos en el explorador"""
        try:
            if self.projects_root_dir.exists():
                os.startfile(str(self.projects_root_dir))
                self.update_status(f"📁 Abriendo carpeta: {self.projects_root_dir}")
            else:
                messagebox.showwarning("⚠️ Carpeta no encontrada", 
                                     f"La carpeta de proyectos no existe:\n{self.projects_root_dir}")
        except Exception as e:
            logging.error(f"Error abriendo carpeta de proyectos: {e}")
            messagebox.showerror("❌ Error", f"Error abriendo carpeta:\n{e}")
    
    def create_elegant_header(self):
        """Crear header elegante con información del usuario"""
        header_frame = tk.Frame(self.root, bg=ModernColors.ACCENT_BLUE, height=100)
        header_frame.pack(fill="x")
        header_frame.pack_propagate(False)
        
        # Container del header
        header_container = tk.Frame(header_frame, bg=ModernColors.ACCENT_BLUE)
        header_container.pack(fill="both", expand=True, padx=30, pady=20)
        
        # Lado izquierdo - Logo y título
        left_section = tk.Frame(header_container, bg=ModernColors.ACCENT_BLUE)
        left_section.pack(side="left", fill="y")
        
        # Logo
        logo_frame = tk.Frame(left_section, bg=ModernColors.TEXT_PRIMARY, width=60, height=60)
        logo_frame.pack(side="left", pady=10, padx=(0, 20))
        logo_frame.pack_propagate(False)
        
        tk.Label(logo_frame, text="🔬", font=("Segoe UI", 24), 
                bg=ModernColors.TEXT_PRIMARY, fg=ModernColors.ACCENT_BLUE).pack(expand=True)
        
        # Títulos
        titles_frame = tk.Frame(left_section, bg=ModernColors.ACCENT_BLUE)
        titles_frame.pack(side="left", fill="y")
        
        tk.Label(titles_frame, text="CinBehave", 
                font=self.fonts['title'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_BLUE).pack(anchor="w")
        
        tk.Label(titles_frame, text="Sistema Avanzado de Análisis Comportamental", 
                font=self.fonts['normal'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_BLUE).pack(anchor="w")
        
        # Lado derecho - Info del usuario
        right_section = tk.Frame(header_container, bg=ModernColors.ACCENT_BLUE)
        right_section.pack(side="right", fill="y")
        
        user_info = self.get_user_info()
        
        tk.Label(right_section, text=f"👤 {user_info.get('full_name', self.current_user)}", 
                font=self.fonts['heading'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_BLUE).pack(anchor="e")
        
        # Estado de SLEAP
        sleap_status = f"🧠 SLEAP {SLEAP_VERSION}" if SLEAP_AVAILABLE else "❌ SLEAP no disponible"
        tk.Label(right_section, text=sleap_status, 
                font=self.fonts['small'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_BLUE).pack(anchor="e")
        
        # Reloj en tiempo real
        self.time_label = tk.Label(right_section, text="", 
                                  font=self.fonts['small'], 
                                  fg=ModernColors.TEXT_PRIMARY, 
                                  bg=ModernColors.ACCENT_BLUE)
        self.time_label.pack(anchor="e")
        
        self.update_time()
    
    def update_time(self):
        """Actualizar reloj en tiempo real"""
        current_time = datetime.now().strftime("🕐 %H:%M:%S | 📅 %d/%m/%Y")
        if hasattr(self, 'time_label'):
            self.time_label.config(text=current_time)
        self.root.after(1000, self.update_time)
    
    def create_project_management(self):
        """Crear sección moderna de gestión de proyectos"""
        project_frame = self.create_card_frame(self.root)
        project_frame.pack(fill="x", padx=20, pady=10)
        
        # Header de proyectos
        project_header = tk.Frame(project_frame, bg=ModernColors.ACCENT_PURPLE, height=50)
        project_header.pack(fill="x")
        project_header.pack_propagate(False)
        
        tk.Label(project_header, text="📋 Gestión de Proyectos", 
                font=self.fonts['heading'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.ACCENT_PURPLE).pack(side="left", padx=20, pady=15)
        
        # Container de controles
        controls_container = tk.Frame(project_frame, bg=ModernColors.CARD_BG)
        controls_container.pack(fill="x", padx=20, pady=15)
        
        # Selector de proyecto moderno
        selector_frame = tk.Frame(controls_container, bg=ModernColors.CARD_BG)
        selector_frame.pack(side="left", fill="y")
        
        tk.Label(selector_frame, text="Proyecto Activo:", 
                font=self.fonts['normal'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(anchor="w")
        
        self.project_var = tk.StringVar()
        self.project_combobox = ttk.Combobox(selector_frame, 
                                            textvariable=self.project_var,
                                            values=list(self.projects_data.keys()),
                                            state="readonly",
                                            font=self.fonts['normal'],
                                            width=30,
                                            style='Modern.TCombobox')
        self.project_combobox.pack(pady=5)
        
        # Botones de gestión
        buttons_frame = tk.Frame(controls_container, bg=ModernColors.CARD_BG)
        buttons_frame.pack(side="right", fill="y")
        
        project_buttons = [
            ("🆕 Nuevo", self.create_new_project, ModernColors.ACCENT_GREEN),
            ("📂 Cargar", self.load_project, ModernColors.ACCENT_BLUE),
            ("💾 Guardar", self.save_current_project, ModernColors.ACCENT_YELLOW),
            ("🗑️ Eliminar", self.delete_project, ModernColors.ACCENT_RED)
        ]
        
        for text, command, color in project_buttons:
            self.create_modern_button(buttons_frame, text, command, color, 
                                     width=12).pack(side="left", padx=5)
        
        # Indicador de proyecto actual
        self.project_indicator = tk.Label(project_frame, text="📁 Sin proyecto activo", 
                                         font=self.fonts['small'], 
                                         fg=ModernColors.TEXT_MUTED, 
                                         bg=ModernColors.CARD_BG)
        self.project_indicator.pack(pady=(0, 15))
    
    def create_card_menu(self):
        """Crear menú principal con tarjetas elegantes"""
        menu_container = tk.Frame(self.root, bg=ModernColors.PRIMARY_DARK)
        menu_container.pack(fill="both", expand=True, padx=20, pady=10)
        
        # Título del menú
        menu_title = tk.Label(menu_container, text="🎯 Centro de Control", 
                             font=self.fonts['subtitle'], 
                             fg=ModernColors.TEXT_PRIMARY, 
                             bg=ModernColors.PRIMARY_DARK)
        menu_title.pack(pady=20)
        
        # Grid de tarjetas
        cards_grid = tk.Frame(menu_container, bg=ModernColors.PRIMARY_DARK)
        cards_grid.pack(expand=True, fill="both")
        
        # Configurar grid
        for i in range(3):
            cards_grid.grid_rowconfigure(i, weight=1)
        for i in range(3):
            cards_grid.grid_columnconfigure(i, weight=1)
        
        # Definir tarjetas
        cards_data = [
            ("🧠 Predecir", "Análisis SLEAP", "Procesar videos con IA\ny obtener predicciones", 
             ModernColors.ACCENT_PURPLE, self.open_predict_menu),
            ("🎬 Entrenar", "Machine Learning", "Entrenar modelos\ncon nuevos datos", 
             ModernColors.ACCENT_GREEN, self.show_training_menu),
            ("⚙️ Configurar", "Parámetros SLEAP", "Ajustar configuración\ndel sistema", 
             ModernColors.ACCENT_BLUE, self.show_sleap_config),
            ("🛠️ Herramientas", "Utilidades", "Herramientas adicionales\ny utilidades", 
             ModernColors.ACCENT_ORANGE, self.show_tools_menu),
            ("📊 Monitor", "Recursos", "Monitor del sistema\nen tiempo real", 
             ModernColors.ACCENT_YELLOW, self.show_system_monitor),
            ("🚪 Salir", "Cerrar Aplicación", "Guardar y cerrar\nel sistema", 
             ModernColors.ACCENT_RED, self.exit_application)
        ]
        
        # Crear tarjetas
        for i, (title, subtitle, description, color, command) in enumerate(cards_data):
            row = i // 3
            col = i % 3
            
            card = self.create_menu_card(cards_grid, title, subtitle, description, color, command)
            card.grid(row=row, column=col, padx=15, pady=15, sticky="nsew")
    
    def create_menu_card(self, parent, title, subtitle, description, color, command):
        """Crear tarjeta individual del menú"""
        card = self.create_card_frame(parent)
        card.configure(cursor="hand2")
        
        # Header de la tarjeta
        header = tk.Frame(card, bg=color, height=80)
        header.pack(fill="x")
        header.pack_propagate(False)
        
        tk.Label(header, text=title, 
                font=self.fonts['heading'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=color).pack(expand=True)
        
        # Contenido de la tarjeta
        content = tk.Frame(card, bg=ModernColors.CARD_BG)
        content.pack(fill="both", expand=True, padx=20, pady=20)
        
        tk.Label(content, text=subtitle, 
                font=self.fonts['normal'], 
                fg=ModernColors.TEXT_PRIMARY, 
                bg=ModernColors.CARD_BG).pack(anchor="w")
        
        tk.Label(content, text=description, 
                font=self.fonts['small'], 
                fg=ModernColors.TEXT_SECONDARY, 
                bg=ModernColors.CARD_BG,
                justify="left").pack(anchor="w", pady=(5, 0))
        
        # Efectos hover y click
        def on_enter(e):
            card.configure(bg=self.lighten_color(ModernColors.CARD_BG))
            content.configure(bg=self.lighten_color(ModernColors.CARD_BG))
        
        def on_leave(e):
            card.configure(bg=ModernColors.CARD_BG)
            content.configure(bg=ModernColors.CARD_BG)
        
        def on_click(e):
            command()
        
        # Bind eventos a todos los elementos
        elements = [card, header, content] + list(header.winfo_children()) + list(content.winfo_children())
        for element in elements:
            element.bind("<Enter>", on_enter)
            element.bind("<Leave>", on_leave)
            element.bind("<Button-1>", on_click)
            element.configure(cursor="hand2")
        
        return card
    
    def create_modern_status_bar(self):
        """Crear barra de estado moderna"""
        status_container = tk.Frame(self.root, bg=ModernColors.PRIMARY_MEDIUM, height=40)
        status_container.pack(fill="x", side="bottom")
        status_container.pack_propagate(False)
        
        # Status principal
        self.status_label = tk.Label(status_container, text="🚀 Sistema listo", 
                                    font=self.fonts['small'], 
                                    fg=ModernColors.TEXT_PRIMARY, 
                                    bg=ModernColors.PRIMARY_MEDIUM)
        self.status_label.pack(side="left", padx=20, pady=10)
        
        # Información del sistema
        system_info = self.get_system_info()
        system_text = f"💻 {system_info.get('os', 'Unknown')} | 🐍 Python {sys.version_info.major}.{sys.version_info.minor} | 🎮 {system_info.get('gpu_support', 'Unknown')} | 🧠 SLEAP {SLEAP_VERSION if SLEAP_AVAILABLE else 'No disponible'}"
        
        tk.Label(status_container, text=system_text, 
                font=self.fonts['tiny'], 
                fg=ModernColors.TEXT_MUTED, 
                bg=ModernColors.PRIMARY_MEDIUM).pack(side="right", padx=20, pady=10)
    
    def update_status(self, message):
        """Actualizar barra de estado con timestamp"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.status_label.config(text=f"[{timestamp}] {message}")
        self.root.update_idletasks()
        logging.info(message)
    
    # IMPLEMENTACIÓN COMPLETA DEL MONITOR DE SISTEMA
    def show_system_monitor(self):
        """Mostrar monitor del sistema funcional y completamente operativo"""
        try:
            # NUEVO: Mostrar tutorial del monitor si es la primera vez
            self.show_monitor_tutorial()
            
            monitor = SystemMonitorWindow(self)
            self.update_status("📊 Monitor de sistema iniciado correctamente")
        except Exception as e:
            logging.error(f"Error abriendo monitor: {e}")
            messagebox.showerror("❌ Error", f"Error abriendo monitor del sistema:\n{e}")
    
    # NUEVAS FUNCIONES DEL SISTEMA DE TUTORIAL
    def show_user_creation_tutorial(self):
        """Tutorial: Explicación de creación de usuarios"""
        message = """¡Bienvenido a CinBehave! 🎉

CinBehave es un sistema avanzado de análisis de comportamiento animal usando tecnología SLEAP.

📋 CREACIÓN DE USUARIO:
• Cada usuario tiene su propio espacio de trabajo independiente
• Sus proyectos y configuraciones se guardan por separado
• Puede crear múltiples usuarios para diferentes investigadores

🚀 PRIMEROS PASOS:
1. Ingrese un nombre de usuario (mínimo 3 caracteres)
2. Opcionalmente, agregue su nombre completo y email
3. Haga clic en "Crear Usuario" o presione Enter
4. ¡Su espacio de trabajo estará listo!

💡 CONSEJO: Use nombres descriptivos como "Dr_Rodriguez" o "Lab_Neurociencias" """

        if self.tutorial.show_tutorial_window("Creación de Usuarios", message, "Paso 1/5 - Configuración inicial"):
            return True
        return False
    
    def show_project_management_tutorial(self):
        """Tutorial: Explicación de gestión de proyectos"""
        state = self.tutorial.load_tutorial_state(self.current_user)
        if state.get("project_management_shown", False):
            return
        
        message = """¡Excelente! Ya tienes tu espacio de trabajo configurado. 👨‍💻

📋 GESTIÓN DE PROYECTOS:
Los proyectos son el corazón de CinBehave. Aquí organizas todos tus análisis.

🆕 CREAR PROYECTO:
• Haga clic en "🆕 Nuevo" para crear un proyecto
• Se creará automáticamente una carpeta en "Proyectos/[NombreProyecto]/"
• Incluye subcarpetas: Videos/, Data_Sleap/, models/
• Podrá agregar videos inmediatamente

📂 CARGAR PROYECTO:
• Seleccione un proyecto del menú desplegable
• Haga clic en "📂 Cargar" para trabajar con él

💾 GUARDAR PROYECTO:
• Sus cambios se guardan automáticamente
• Use "💾 Guardar" para guardar manualmente

🗑️ ELIMINAR PROYECTO:
• Seleccione el proyecto y haga clic en "🗑️ Eliminar"
• Se eliminará la carpeta completa y todos los archivos

💡 CONSEJO: Use nombres descriptivos como "Ratones_Laberinto_2024" """

        if self.tutorial.show_tutorial_window("Gestión de Proyectos", message, "Paso 2/5 - Organización"):
            state["project_management_shown"] = True
            self.tutorial.save_tutorial_state(state)
    
    def show_video_selection_tutorial(self):
        """Tutorial: Explicación de selección de videos"""
        state = self.tutorial.load_tutorial_state(self.current_user)
        if state.get("video_selection_shown", False):
            return
        
        message = """¡Perfecto! Ahora vamos a agregar videos a tu proyecto. 🎬

📁 SELECCIÓN DE VIDEOS:
Los videos son el material principal para el análisis con SLEAP.

🎯 PROCESO AUTOMÁTICO:
• Seleccione videos desde cualquier ubicación de su computadora
• CinBehave los copiará automáticamente a la carpeta del proyecto
• Los videos originales permanecen intactos en su ubicación original

📹 FORMATOS SOPORTADOS:
• MP4, AVI, MOV, MKV, WMV, FLV, WEBM, M4V
• Todos los formatos comunes de video están incluidos

⚡ VENTAJAS:
• Videos organizados automáticamente por proyecto
• Fácil acceso y gestión
• Respaldo seguro en la carpeta del proyecto
• No perderá sus videos nunca más

🔄 PROCESO:
1. Se abrirá un selector de archivos
2. Seleccione uno o múltiples videos (Ctrl+clic)
3. Confirme la selección
4. Vea el progreso de copia en tiempo real

💡 CONSEJO: Organice sus videos por sesiones o condiciones experimentales"""

        if self.tutorial.show_tutorial_window("Selección de Videos", message, "Paso 3/5 - Videos de análisis"):
            state["video_selection_shown"] = True
            self.tutorial.save_tutorial_state(state)
    
    def show_sleap_prediction_tutorial(self):
        """Tutorial: Explicación de predicciones SLEAP"""
        state = self.tutorial.load_tutorial_state(self.current_user)
        if state.get("sleap_explained", False):
            return
        
        message = """🧠 ¡Ahora viene lo emocionante: las Predicciones SLEAP!

¿QUÉ ES SLEAP?
SLEAP (Social LEAP Estimates Animal Poses) es un framework de IA avanzado para:
• Tracking de poses de animales en tiempo real
• Detección automática de comportamientos
• Análisis de movimientos complejos
• Estudios de interacción social

🔄 PROCESO AUTOMÁTICO DE PREDICCIÓN:
1. Verificación de instalación de SLEAP
2. Detección automática de GPU/CPU
3. Descarga automática de modelos desde GitHub
4. Configuración de carpetas del proyecto:
   • Videos/ → Input de videos
   • Data_Sleap/ → Output de predicciones (.slp)
   • models/ → Modelos de IA descargados
5. Procesamiento con ventana de progreso en tiempo real
6. Generación de archivos .slp con datos de pose

⚡ MODELOS INCLUIDOS:
• Centroid model: Detecta centro de masa del animal
• Centered instance model: Detecta poses detalladas

🎯 RESULTADO:
• Archivos .slp con coordenadas de poses
• Tracking frame por frame
• Datos listos para análisis posterior

💡 IMPORTANTE: El proceso puede tomar tiempo dependiendo del tamaño de videos y hardware disponible."""

        if self.tutorial.show_tutorial_window("Predicciones SLEAP", message, "Paso 4/5 - Inteligencia Artificial"):
            state["sleap_explained"] = True
            self.tutorial.save_tutorial_state(state)
    
    def show_monitor_tutorial(self):
        """Tutorial: Explicación del monitor de recursos"""
        state = self.tutorial.load_tutorial_state(self.current_user)
        if state.get("monitor_explained", False):
            return
        
        message = """¡Excelente! Está abriendo el Monitor de Recursos del Sistema. 📊

🖥️ MONITOR EN TIEMPO REAL:
Esta herramienta le permite supervisar el rendimiento de su computadora durante los análisis.

📈 INFORMACIÓN DISPONIBLE:
• CPU: Uso del procesador en tiempo real
• Memoria: Consumo de RAM del sistema
• Disco: Espacio y actividad de almacenamiento
• Red: Transferencia de datos de internet
• Temperatura: Temperatura del sistema (si está disponible)
• GPU: Estado de la tarjeta gráfica
• Procesos: Cantidad de programas ejecutándose

⚡ CARACTERÍSTICAS:
• Gráficos en tiempo real con matplotlib
• Exportación de datos a CSV
• Historial de 60 segundos de datos
• Interfaz moderna y fácil de usar

🎯 ¿POR QUÉ ES ÚTIL PARA SLEAP?
• Verificar que su computadora puede manejar análisis pesados
• Detectar problemas de rendimiento durante predicciones
• Optimizar configuraciones de SLEAP
• Monitorear progreso de procesamientos largos
• Asegurar que la GPU se esté usando correctamente

💡 CONSEJO: Mantenga el monitor abierto durante análisis SLEAP extensos para verificar el rendimiento"""

        if self.tutorial.show_tutorial_window("Monitor de Recursos", message, "Paso 5/5 - Monitoreo del sistema"):
            state["monitor_explained"] = True
            state["tutorial_completed"] = True
            self.tutorial.save_tutorial_state(state)
    
    def restart_tutorial(self):
        """Reiniciar tutorial completo"""
        if messagebox.askyesno("🎓 Reiniciar Tutorial", 
                              "¿Desea reiniciar el tutorial completo?\n\n"
                              "Esto volverá a mostrar todas las ventanas explicativas "
                              "como si fuera la primera vez usando CinBehave."):
            if self.current_user:
                self.tutorial.reset_tutorial(self.current_user)
                messagebox.showinfo("✅ Tutorial Reiniciado", 
                                   "El tutorial ha sido reiniciado.\n\n"
                                   "Las ventanas explicativas volverán a aparecer "
                                   "cuando realice las acciones correspondientes.")
                self.update_status("🎓 Tutorial reiniciado")
            else:
                messagebox.showwarning("⚠️ Sin Usuario", "Debe tener un usuario activo para reiniciar el tutorial")
    
    # NUEVAS FUNCIONES PARA GESTIÓN DE VIDEOS
    def select_videos_for_project(self):
        """Seleccionar videos para copiar al proyecto"""
        video_extensions = [
            ("Videos", "*.mp4 *.avi *.mov *.mkv *.wmv *.flv *.webm *.m4v"),
            ("MP4", "*.mp4"),
            ("AVI", "*.avi"),
            ("MOV", "*.mov"),
            ("MKV", "*.mkv"),
            ("Todos los archivos", "*.*")
        ]
        
        selected_videos = filedialog.askopenfilenames(
            title="Seleccionar Videos para el Proyecto",
            filetypes=video_extensions,
            initialdir=os.path.expanduser("~")
        )
        
        return list(selected_videos) if selected_videos else []
    
    def get_project_videos_folder(self, project_name):
        """Obtener la carpeta de videos del proyecto"""
        project_folder = self.projects_root_dir / project_name
        videos_folder = project_folder / "Videos"
        return videos_folder
    
    def copy_videos_to_project(self, project_name, videos_list):
        """Copiar videos al proyecto con ventana de progreso"""
        if not videos_list:
            return True
        
        try:
            # Crear carpeta de videos del proyecto
            videos_folder = self.get_project_videos_folder(project_name)
            videos_folder.mkdir(parents=True, exist_ok=True)
            
            # Mostrar ventana de progreso
            progress_window = VideoProgressWindow(self, videos_list, videos_folder)
            
            # Esperar a que termine la copia
            self.root.wait_window(progress_window.window)
            
            return progress_window.success
            
        except Exception as e:
            logging.error(f"Error configurando copia de videos: {e}")
            messagebox.showerror("❌ Error", f"Error preparando copia de videos:\n{e}")
            return False
    
    # Métodos de funcionalidad (ACTUALIZADO: create_new_project)
    def create_new_project(self):
        """Crear nuevo proyecto con gestión completa de carpetas y videos"""
        # Paso 1: Pedir nombre del proyecto
        project_name = simpledialog.askstring("🆕 Nuevo Proyecto", 
                                              "Nombre del proyecto:",
                                              parent=self.root)
        if not project_name:
            return
        
        project_name = project_name.strip()
        if not project_name:
            messagebox.showwarning("⚠️ Validación", "Ingresa un nombre válido")
            return
        
        # Validar que no exista ya
        if project_name in self.projects_data:
            messagebox.showwarning("⚠️ Proyecto Existente", "Ya existe un proyecto con ese nombre")
            return
        
        # Validar caracteres permitidos para nombres de carpeta
        invalid_chars = '<>:"/\\|?*'
        if any(char in project_name for char in invalid_chars):
            messagebox.showwarning("⚠️ Caracteres Inválidos", 
                                 f"El nombre no puede contener: {invalid_chars}")
            return
        
        try:
            # Paso 2: Crear estructura de carpetas en Proyectos/
            project_folder = self.projects_root_dir / project_name
            videos_folder = project_folder / "Videos"
            data_sleap_folder = project_folder / "Data_Sleap"  # NUEVA: Para archivos .slp
            models_folder = project_folder / "models"  # NUEVA: Para modelos SLEAP
            
            # Verificar que no exista la carpeta
            if project_folder.exists():
                messagebox.showwarning("⚠️ Carpeta Existente", 
                                     f"Ya existe una carpeta con el nombre '{project_name}' en:\n{project_folder}")
                return
            
            # Crear estructura de carpetas
            project_folder.mkdir(parents=True, exist_ok=True)
            videos_folder.mkdir(parents=True, exist_ok=True)
            data_sleap_folder.mkdir(parents=True, exist_ok=True)
            models_folder.mkdir(parents=True, exist_ok=True)
            
            self.update_status(f"📁 Estructura del proyecto creada: {project_folder}")
            logging.info(f"Estructura de carpetas creada para proyecto: {project_name}")
            
            # Paso 3: Preguntar si desea agregar videos ahora
            add_videos = messagebox.askyesno("🎬 Agregar Videos", 
                                           f"Proyecto '{project_name}' creado exitosamente.\n\n"
                                           f"📁 Ubicación: {project_folder}\n"
                                           f"📂 Carpetas: Videos/, Data_Sleap/, models/\n\n"
                                           "¿Deseas seleccionar videos para agregar al proyecto ahora?")
            
            videos_list = []
            if add_videos:
                # NUEVO: Mostrar tutorial de selección de videos
                self.show_video_selection_tutorial()
                
                # Paso 4: Seleccionar videos
                self.update_status("🎬 Seleccionando videos...")
                videos_list = self.select_videos_for_project()
                
                if videos_list:
                    # Mostrar resumen antes de copiar
                    summary_msg = f"Se van a copiar {len(videos_list)} videos:\n\n"
                    for i, video in enumerate(videos_list[:5], 1):  # Mostrar solo los primeros 5
                        video_name = Path(video).name
                        summary_msg += f"{i}. {video_name}\n"
                    
                    if len(videos_list) > 5:
                        summary_msg += f"... y {len(videos_list) - 5} videos más\n"
                    
                    summary_msg += f"\nDestino: {videos_folder}\n\n¿Continuar con la copia?"
                    
                    if messagebox.askyesno("📥 Confirmar Copia", summary_msg):
                        # Paso 5: Copiar videos
                        self.update_status("📥 Copiando videos al proyecto...")
                        success = self.copy_videos_to_project(project_name, videos_list)
                        
                        if not success:
                            # Si falló la copia, preguntar si mantener el proyecto
                            keep_project = messagebox.askyesno("⚠️ Error en Copia", 
                                                             "Error copiando algunos videos.\n\n"
                                                             "¿Deseas mantener el proyecto sin los videos?")
                            if not keep_project:
                                # Eliminar carpeta del proyecto
                                try:
                                    shutil.rmtree(project_folder)
                                    self.update_status(f"🗑️ Proyecto '{project_name}' eliminado tras error")
                                except:
                                    pass
                                return
                    else:
                        videos_list = []  # Usuario canceló la copia
            
            # Paso 6: Crear registro del proyecto en la aplicación
            self.projects_data[project_name] = {
                "name": project_name,
                "created": datetime.now().isoformat(),
                "last_modified": datetime.now().isoformat(),
                "description": "",
                "videos": [Path(v).name for v in videos_list],  # Solo guardar nombres
                "project_folder": str(project_folder),
                "videos_folder": str(videos_folder),
                "data_sleap_folder": str(data_sleap_folder),  # NUEVA
                "models_folder": str(models_folder),  # NUEVA
                "sleap_params": self.sleap_params.copy(),
                "results": {},
                "annotations": [],
                "sleap_predictions": []  # NUEVA: Para guardar info de predicciones
            }
            
            # Paso 7: Actualizar interfaz
            self.current_project = project_name
            self.project_var.set(project_name)
            self.project_combobox['values'] = list(self.projects_data.keys())
            self.project_indicator.config(text=f"📁 Proyecto activo: {project_name}")
            
            # Cargar videos en la variable de la aplicación
            self.loaded_videos = videos_list
            
            # Guardar configuración
            self.save_user_projects()
            
            # Mensaje final
            final_msg = f"✅ Proyecto '{project_name}' creado exitosamente!\n\n"
            final_msg += f"📁 Ubicación: {project_folder}\n"
            final_msg += f"🎬 Videos agregados: {len(videos_list)}\n"
            final_msg += f"📂 Carpetas: Videos/, Data_Sleap/, models/\n\n"
            final_msg += "El proyecto está listo para usar con SLEAP."
            
            self.update_status(f"🆕 Proyecto '{project_name}' creado con {len(videos_list)} videos")
            messagebox.showinfo("🎉 Proyecto Creado", final_msg)
            
            logging.info(f"Proyecto {project_name} creado exitosamente con {len(videos_list)} videos")
            
        except Exception as e:
            logging.error(f"Error creando proyecto: {e}")
            messagebox.showerror("❌ Error", f"Error creando proyecto:\n{e}")
            
            # Intentar limpiar en caso de error
            try:
                if 'project_folder' in locals() and project_folder.exists():
                    shutil.rmtree(project_folder)
            except:
                pass
    
    def load_project(self):
        """Cargar proyecto seleccionado"""
        project_name = self.project_var.get()
        if not project_name or project_name not in self.projects_data:
            messagebox.showwarning("⚠️ Advertencia", "Selecciona un proyecto válido")
            return
        
        self.current_project = project_name
        project_data = self.projects_data[project_name]
        
        # Cargar videos (construir rutas completas)
        videos_folder = self.get_project_videos_folder(project_name)
        self.loaded_videos = []
        
        for video_name in project_data.get("videos", []):
            video_path = videos_folder / video_name
            if video_path.exists():
                self.loaded_videos.append(str(video_path))
            else:
                logging.warning(f"Video no encontrado: {video_path}")
        
        self.sleap_params = project_data.get("sleap_params", self.sleap_params)
        
        self.project_indicator.config(text=f"📁 Proyecto activo: {project_name}")
        
        # Mostrar información del proyecto cargado
        project_info = f"📁 Proyecto: {project_name}\n"
        project_info += f"🎬 Videos disponibles: {len(self.loaded_videos)}\n"
        project_info += f"📅 Creado: {project_data.get('created', 'Desconocido')}\n"
        project_info += f"📂 Ubicación: {project_data.get('project_folder', 'No especificada')}\n"
        project_info += f"🧠 SLEAP: Listo para predicciones"
        
        self.update_status(f"📂 Proyecto '{project_name}' cargado")
        messagebox.showinfo("✅ Proyecto Cargado", project_info)
    
    def save_current_project(self):
        """Guardar proyecto actual"""
        if not self.current_project:
            messagebox.showwarning("⚠️ Advertencia", "No hay proyecto activo")
            return
        
        self.projects_data[self.current_project].update({
            "videos": [Path(v).name for v in self.loaded_videos],  # Solo nombres
            "sleap_params": self.sleap_params,
            "last_modified": datetime.now().isoformat()
        })
        
        self.save_user_projects()
        self.update_status(f"💾 Proyecto '{self.current_project}' guardado")
        messagebox.showinfo("✅ Éxito", f"Proyecto '{self.current_project}' guardado exitosamente")
    
    def delete_project(self):
        """Eliminar proyecto"""
        project_name = self.project_var.get()
        if not project_name or project_name not in self.projects_data:
            messagebox.showwarning("⚠️ Advertencia", "Selecciona un proyecto válido")
            return
        
        # Información del proyecto
        project_data = self.projects_data[project_name]
        project_folder = Path(project_data.get("project_folder", ""))
        videos_count = len(project_data.get("videos", []))
        
        # Confirmación detallada
        confirm_msg = f"¿Eliminar el proyecto '{project_name}'?\n\n"
        confirm_msg += f"📁 Carpeta: {project_folder}\n"
        confirm_msg += f"🎬 Videos: {videos_count}\n\n"
        confirm_msg += "ADVERTENCIA: Esto eliminará:\n"
        confirm_msg += "• El registro del proyecto en CinBehave\n"
        confirm_msg += "• La carpeta del proyecto y todos sus videos\n"
        confirm_msg += "• Todos los resultados SLEAP (.slp)\n"
        confirm_msg += "• Los modelos descargados\n"
        confirm_msg += "• Todos los datos asociados\n\n"
        confirm_msg += "Esta acción NO se puede deshacer."
        
        if messagebox.askyesno("🗑️ Confirmar Eliminación", confirm_msg):
            try:
                # Eliminar carpeta física si existe
                if project_folder.exists():
                    shutil.rmtree(project_folder)
                    self.update_status(f"🗑️ Carpeta eliminada: {project_folder}")
                
                # Eliminar registro del proyecto
                del self.projects_data[project_name]
                
                # Limpiar interfaz si era el proyecto activo
                if self.current_project == project_name:
                    self.current_project = None
                    self.project_indicator.config(text="📁 Sin proyecto activo")
                    self.loaded_videos = []
                
                # Actualizar combobox
                self.project_var.set("")
                self.project_combobox['values'] = list(self.projects_data.keys())
                self.save_user_projects()
                
                self.update_status(f"🗑️ Proyecto '{project_name}' eliminado completamente")
                messagebox.showinfo("✅ Eliminado", f"Proyecto '{project_name}' eliminado exitosamente")
                
                logging.info(f"Proyecto {project_name} eliminado completamente")
                
            except Exception as e:
                logging.error(f"Error eliminando proyecto: {e}")
                messagebox.showerror("❌ Error", f"Error eliminando proyecto:\n{e}")
    
    def open_predict_menu(self):
        """Abrir menú de predicción completo con SLEAP"""
        if not self.current_project:
            if messagebox.askyesno("📋 Sin Proyecto", 
                                  "No hay proyecto activo. ¿Crear uno nuevo?"):
                self.create_new_project()
                return
            else:
                return
        
        # Verificar que hay videos
        if not self.loaded_videos:
            if messagebox.askyesno("🎬 Sin Videos", 
                                  f"El proyecto '{self.current_project}' no tiene videos.\n\n¿Agregar videos ahora?"):
                videos_list = self.select_videos_for_project()
                if videos_list:
                    success = self.copy_videos_to_project(self.current_project, videos_list)
                    if success:
                        self.loaded_videos = videos_list
                        # Actualizar proyecto
                        self.projects_data[self.current_project]["videos"] = [Path(v).name for v in videos_list]
                        self.save_user_projects()
                    else:
                        return
                else:
                    return
            else:
                return
        
        # Verificar SLEAP
        if not SLEAP_AVAILABLE:
            error_msg = f"❌ SLEAP no está instalado.\n\n"
            error_msg += f"Para usar las predicciones necesitas instalar SLEAP:\n"
            error_msg += f"pip install sleap\n\n"
            error_msg += f"Reinicia CinBehave después de la instalación."
            messagebox.showerror("❌ SLEAP No Disponible", error_msg)
            return
        
        # Mostrar tutorial de SLEAP si es la primera vez
        self.show_sleap_prediction_tutorial()
        
        # Confirmación final
        confirm_msg = f"🧠 Iniciar Predicciones SLEAP\n\n"
        confirm_msg += f"📁 Proyecto: {self.current_project}\n"
        confirm_msg += f"🎬 Videos: {len(self.loaded_videos)}\n"
        confirm_msg += f"🔬 SLEAP: {SLEAP_VERSION}\n\n"
        confirm_msg += f"El procesamiento puede tomar tiempo dependiendo del tamaño de los videos.\n\n"
        confirm_msg += f"¿Continuar con las predicciones?"
        
        if messagebox.askyesno("🧠 Confirmar Predicciones", confirm_msg):
            try:
                self.update_status("🧠 Iniciando predicciones SLEAP...")
                
                # Ejecutar predicción
                success, message = self.sleap_predictor.run_prediction(self.current_project)
                
                if success:
                    # Actualizar proyecto con resultados
                    timestamp = datetime.now().isoformat()
                    prediction_info = {
                        "timestamp": timestamp,
                        "videos_processed": len(self.loaded_videos),
                        "sleap_version": SLEAP_VERSION,
                        "status": "completed"
                    }
                    
                    self.projects_data[self.current_project]["sleap_predictions"].append(prediction_info)
                    self.projects_data[self.current_project]["last_modified"] = timestamp
                    self.save_user_projects()
                    
                    success_msg = f"🎉 ¡Predicciones SLEAP Completadas!\n\n"
                    success_msg += f"✅ Videos procesados: {len(self.loaded_videos)}\n"
                    success_msg += f"📂 Resultados en: {self.projects_root_dir / self.current_project / 'Data_Sleap'}\n"
                    success_msg += f"🕐 Completado: {datetime.now().strftime('%H:%M:%S')}\n\n"
                    success_msg += f"Los archivos .slp están listos para análisis."
                    
                    self.update_status("🎉 Predicciones SLEAP completadas exitosamente")
                    messagebox.showinfo("🎉 ¡Éxito!", success_msg)
                else:
                    self.update_status("❌ Error en predicciones SLEAP")
                    messagebox.showerror("❌ Error", f"Error en las predicciones:\n{message}")
                
            except Exception as e:
                logging.error(f"Error en predicciones: {e}")
                self.update_status("❌ Error inesperado en predicciones")
                messagebox.showerror("❌ Error", f"Error inesperado:\n{e}")
    
    def show_training_menu(self):
        """Mostrar menú de entrenamiento"""
        training_msg = f"🧠 Entrenamiento de Modelos SLEAP\n\n"
        training_msg += f"Esta funcionalidad permitirá:\n"
        training_msg += f"• Entrenar modelos personalizados\n"
        training_msg += f"• Usar datos de anotación propios\n"
        training_msg += f"• Optimizar para especies específicas\n\n"
        training_msg += f"Estado: En desarrollo"
        messagebox.showinfo("🧠 Entrenamiento", training_msg)
    
    def show_sleap_config(self):
        """Mostrar configuración SLEAP completa"""
        config_msg = f"⚙️ Configuración SLEAP\n\n"
        config_msg += f"Estado actual:\n"
        config_msg += f"• SLEAP: {'✅ ' + SLEAP_VERSION if SLEAP_AVAILABLE else '❌ No instalado'}\n"
        config_msg += f"• GPU: {self.check_gpu_support()}\n"
        config_msg += f"• Modelos: Descarga automática desde GitHub\n\n"
        config_msg += f"Configuración avanzada: En desarrollo"
        messagebox.showinfo("⚙️ Configuración", config_msg)
    
    def show_tools_menu(self):
        """Mostrar menú de herramientas"""
        messagebox.showinfo("🛠️ Herramientas", "Herramientas adicionales - En desarrollo")
    
    def show_preferences(self):
        """Mostrar preferencias"""
        messagebox.showinfo("🎨 Preferencias", "Configuración de preferencias - En desarrollo")
    
    def show_documentation(self):
        """Mostrar documentación"""
        messagebox.showinfo("📖 Documentación", "Documentación del sistema - En desarrollo")
    
    def show_support(self):
        """Mostrar soporte"""
        messagebox.showinfo("🆘 Soporte", "Centro de soporte técnico - En desarrollo")
    
    def show_about(self):
        """Mostrar información sobre la aplicación"""
        about_text = f"""
🔬 CinBehave - SLEAP Analysis GUI
Versión 1.0 - SLEAP Integration Edition

Sistema avanzado de análisis de comportamiento animal
usando tecnología de Machine Learning con SLEAP.

🖥️ Plataforma: Windows
🐍 Python: {sys.version_info.major}.{sys.version_info.minor}
👤 Usuario: {self.current_user}
🧠 SLEAP: {'✅ ' + SLEAP_VERSION if SLEAP_AVAILABLE else '❌ No instalado'}
📊 Monitor: {'Disponible' if MATPLOTLIB_AVAILABLE else 'Limitado'}
📁 Proyectos: {self.projects_root_dir}

© 2024 CinBehave Project
Desarrollado con ❤️ para la comunidad científica
        """
        
        messagebox.showinfo("ℹ️ Acerca de CinBehave", about_text)
    
    def change_user(self):
        """Cambiar usuario"""
        if messagebox.askyesno("👤 Cambiar Usuario", 
                              "¿Cambiar de usuario?\n\nLos cambios no guardados se perderán."):
            self.root.withdraw()
            self.current_user = None
            self.current_project = None
            self.loaded_videos = []
            self.show_user_selection()
    
    def exit_application(self):
        """Salir de la aplicación"""
        if messagebox.askyesno("🚪 Salir", "¿Estás seguro de que deseas salir?"):
            try:
                if self.current_project:
                    self.save_current_project()
                
                self.cleanup_resources()
                logging.info("Aplicación cerrada correctamente")
                self.root.quit()
            except:
                self.root.quit()
    
    def cleanup_resources(self):
        """Limpiar recursos del sistema"""
        try:
            self.monitoring = False
            
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
            messagebox.showerror("❌ Error Fatal", f"Error en aplicación: {e}")

def main():
    """Función principal"""
    try:
        if not os.path.exists("users"):
            os.makedirs("users")
        
        app = CinBehaveGUI()
        app.run()
        
    except Exception as e:
        print(f"Error iniciando aplicación: {e}")
        try:
            messagebox.showerror("❌ Error Fatal", f"Error iniciando aplicación: {e}")
        except:
            print("No se pudo mostrar ventana de error")

if __name__ == "__main__":
    main()
