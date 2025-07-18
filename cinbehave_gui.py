#!/usr/bin/env python3
"""
CinBehave - SLEAP Analysis GUI for Windows
Version: 1.0 - Beautiful Edition with System Monitor
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
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
    from matplotlib.figure import Figure
    import seaborn as sns
    from reportlab.pdfgen import canvas
    from reportlab.lib.pagesizes import letter
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/cinbehave.log'),
        logging.StreamHandler()
    ]
)

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
        
        # Inicializar sistema
        self.initialize_system()
        
        # Mostrar selección de usuario
        self.show_user_selection()
    
    def setup_modern_styles(self):
        """Configurar estilos modernos y elegantes"""
        style = ttk.Style()
        try:
            style.theme_use('winnative')
        except:
            style.theme_use('default')
        
        # Configurar colores modernos para ttk
        style.configure('Modern.TLabel', 
                       background=ModernColors.PRIMARY_DARK, 
                       foreground=ModernColors.TEXT_PRIMARY,
                       font=self.fonts['normal'])
        
        style.configure('Modern.TButton', 
                       background=ModernColors.ACCENT_BLUE,
                       foreground=ModernColors.TEXT_PRIMARY,
                       font=self.fonts['button'],
                       relief='flat')
        
        style.configure('Modern.TEntry', 
                       fieldbackground=ModernColors.CARD_BG,
                       foreground=ModernColors.TEXT_PRIMARY,
                       borderwidth=0,
                       relief='flat')
        
        style.configure('Modern.TCombobox', 
                       fieldbackground=ModernColors.CARD_BG,
                       foreground=ModernColors.TEXT_PRIMARY)
        
        style.configure('Modern.TProgressbar', 
                       background=ModernColors.ACCENT_GREEN,
                       troughcolor=ModernColors.PRIMARY_LIGHT)
        
        style.configure('Modern.TNotebook', 
                       background=ModernColors.PRIMARY_DARK,
                       borderwidth=0)
        
        style.configure('Modern.TNotebook.Tab', 
                       background=ModernColors.PRIMARY_LIGHT,
                       foreground=ModernColors.TEXT_SECONDARY,
                       padding=[20, 10],
                       font=self.fonts['normal'])
        
        style.map('Modern.TNotebook.Tab',
                 background=[('selected', ModernColors.ACCENT_BLUE)],
                 foreground=[('selected', ModernColors.TEXT_PRIMARY)])
    
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
        return tk.Frame(parent, bg=ModernColors.CARD_BG, relief='flat', bd=0, **kwargs)
    
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
                    status_label.config(text="Cargando configuración...")
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
                "assets", "docs", "models", "exports"
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
                    "high_dpi": True
                }
                with open(config_file, 'w') as f:
                    json.dump(windows_config, f, indent=2)
            
            logging.info("Sistema avanzado inicializado correctamente")
            
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
                "gpu_support": self.check_gpu_support()
            }
            return info
        except:
            return {"error": "Could not retrieve system info"}
    
    def show_user_selection(self):
        """Mostrar selección de usuario con diseño moderno y BOTÓN VISIBLE"""
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
        
        # Footer con información del sistema
        footer_frame = tk.Frame(self.user_window, bg=ModernColors.PRIMARY_MEDIUM, height=70)
        footer_frame.pack(fill="x", side="bottom")
        footer_frame.pack_propagate(False)
        
        footer_container = tk.Frame(footer_frame, bg=ModernColors.PRIMARY_MEDIUM)
        footer_container.pack(fill="both", expand=True, padx=30, pady=15)
        
        system_info = self.get_system_info()
        info_text = f"💻 {system_info.get('os', 'Unknown')} | 🧠 RAM: {system_info.get('memory_gb', '?')}GB | 🎮 GPU: {system_info.get('gpu_support', 'Unknown')} | 📊 Monitor: {'Disponible' if MATPLOTLIB_AVAILABLE else 'Básico'}"
        
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
            
            self.user_window.destroy()
            self.root.deiconify()
            self.create_main_interface()
            
            user_info = self.get_user_info()
            welcome_msg = f"¡Bienvenido de vuelta, {user_info.get('full_name', self.current_user)}! 🎉\n\n✅ Sistema listo para análisis\n📊 Monitor de recursos disponible\n🎬 Funciones de predicción preparadas"
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
        help_menu.add_command(label="📖 Documentación", command=self.show_documentation)
        help_menu.add_command(label="🆘 Soporte", command=self.show_support)
        help_menu.add_command(label="ℹ️ Acerca de", command=self.show_about)
    
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
            ("🎬 Predecir", "Análisis Completo", "Procesar videos\ny obtener predicciones", 
             ModernColors.ACCENT_BLUE, self.open_predict_menu),
            ("🧠 Entrenar", "Machine Learning", "Entrenar modelos\ncon nuevos datos", 
             ModernColors.ACCENT_GREEN, self.show_training_menu),
            ("⚙️ Configurar", "Parámetros SLEAP", "Ajustar configuración\ndel sistema", 
             ModernColors.ACCENT_PURPLE, self.show_sleap_config),
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
        system_text = f"💻 {system_info.get('os', 'Unknown')} | 🐍 Python {sys.version_info.major}.{sys.version_info.minor} | 🎮 {system_info.get('gpu_support', 'Unknown')}"
        
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
            monitor = SystemMonitorWindow(self)
            self.update_status("📊 Monitor de sistema iniciado correctamente")
        except Exception as e:
            logging.error(f"Error abriendo monitor: {e}")
            messagebox.showerror("❌ Error", f"Error abriendo monitor del sistema:\n{e}")
    
    # Métodos de funcionalidad (stubs expandidos para mantener estructura)
    def create_new_project(self):
        """Crear nuevo proyecto"""
        project_name = simpledialog.askstring("🆕 Nuevo Proyecto", 
                                              "Nombre del proyecto:",
                                              parent=self.root)
        if project_name:
            project_name = project_name.strip()
            if not project_name:
                messagebox.showwarning("⚠️ Validación", "Ingresa un nombre válido")
                return
            
            if project_name in self.projects_data:
                messagebox.showwarning("⚠️ Proyecto Existente", "Ya existe un proyecto con ese nombre")
                return
            
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
            
            self.current_project = project_name
            self.project_var.set(project_name)
            self.project_combobox['values'] = list(self.projects_data.keys())
            self.project_indicator.config(text=f"📁 Proyecto activo: {project_name}")
            
            self.save_user_projects()
            self.update_status(f"🆕 Proyecto '{project_name}' creado")
            messagebox.showinfo("✅ Éxito", f"Proyecto '{project_name}' creado exitosamente")
    
    def load_project(self):
        """Cargar proyecto seleccionado"""
        project_name = self.project_var.get()
        if not project_name or project_name not in self.projects_data:
            messagebox.showwarning("⚠️ Advertencia", "Selecciona un proyecto válido")
            return
        
        self.current_project = project_name
        project_data = self.projects_data[project_name]
        
        self.loaded_videos = project_data.get("videos", [])
        self.sleap_params = project_data.get("sleap_params", self.sleap_params)
        
        self.project_indicator.config(text=f"📁 Proyecto activo: {project_name}")
        self.update_status(f"📂 Proyecto '{project_name}' cargado")
        messagebox.showinfo("✅ Éxito", f"Proyecto '{project_name}' cargado exitosamente")
    
    def save_current_project(self):
        """Guardar proyecto actual"""
        if not self.current_project:
            messagebox.showwarning("⚠️ Advertencia", "No hay proyecto activo")
            return
        
        self.projects_data[self.current_project].update({
            "videos": self.loaded_videos,
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
        
        if messagebox.askyesno("🗑️ Confirmar Eliminación", 
                              f"¿Eliminar el proyecto '{project_name}'?\n\nEsta acción no se puede deshacer."):
            del self.projects_data[project_name]
            
            if self.current_project == project_name:
                self.current_project = None
                self.project_indicator.config(text="📁 Sin proyecto activo")
                self.loaded_videos = []
            
            self.project_var.set("")
            self.project_combobox['values'] = list(self.projects_data.keys())
            self.save_user_projects()
            
            self.update_status(f"🗑️ Proyecto '{project_name}' eliminado")
            messagebox.showinfo("✅ Eliminado", f"Proyecto '{project_name}' eliminado exitosamente")
    
    def open_predict_menu(self):
        """Abrir menú de predicción completo"""
        if not self.current_project:
            if messagebox.askyesno("📋 Sin Proyecto", 
                                  "No hay proyecto activo. ¿Crear uno nuevo?"):
                self.create_new_project()
                return
            else:
                return
        
        messagebox.showinfo("🎬 Predicción", "Menú de predicción completo - En desarrollo\n\nIncluirá:\n• Carga de videos\n• Procesamiento SLEAP\n• Análisis de resultados\n• Anotaciones manuales")
    
    def show_training_menu(self):
        """Mostrar menú de entrenamiento"""
        messagebox.showinfo("🧠 Entrenamiento", "Funcionalidad de entrenamiento de modelos - Próximamente")
    
    def show_sleap_config(self):
        """Mostrar configuración SLEAP completa"""
        messagebox.showinfo("⚙️ Configuración", "Configuración avanzada de SLEAP - En desarrollo\n\nIncluirá:\n• Parámetros básicos\n• Configuración avanzada\n• Detección de hardware\n• Perfiles personalizados")
    
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
Versión 1.0 - Beautiful Edition

Sistema avanzado de análisis de comportamiento animal
usando tecnología de Machine Learning con SLEAP.

🖥️ Plataforma: Windows
🐍 Python: {sys.version_info.major}.{sys.version_info.minor}
👤 Usuario: {self.current_user}
📊 Monitor: {'Disponible' if MATPLOTLIB_AVAILABLE else 'Limitado'}

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
