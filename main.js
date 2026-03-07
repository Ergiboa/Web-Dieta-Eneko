// ══════════════════════════════════════════════════════
//  NutriCoach — Electron Main Process
//  Aplicación de escritorio (Windows / Mac / Linux)
// ══════════════════════════════════════════════════════

const { app, BrowserWindow, Menu, shell, dialog } = require('electron');
const path = require('path');

// Evitar múltiples instancias
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
}

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 800,
    minHeight: 600,
    icon: path.join(__dirname, 'icon-512.png'),
    title: 'NutriCoach',
    backgroundColor: '#08090a',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      // Permite cargar módulos ES (esm.sh, supabase, etc.)
      webSecurity: true,
    },
    // Barra de título personalizada
    titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'default',
    show: false, // No mostrar hasta que esté listo
  });

  // Cargar la página de login
  mainWindow.loadFile('login.html');

  // Mostrar ventana cuando esté lista (evita parpadeo blanco)
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  // Abrir enlaces externos en el navegador del sistema
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  // Menú personalizado
  const menuTemplate = [
    {
      label: 'NutriCoach',
      submenu: [
        {
          label: 'Acerca de NutriCoach',
          click: () => {
            dialog.showMessageBox(mainWindow, {
              type: 'info',
              title: 'NutriCoach',
              message: 'NutriCoach',
              detail: 'Plataforma de coaching nutricional y entrenamiento.\n\nVersión 1.0.0',
              buttons: ['OK']
            });
          }
        },
        { type: 'separator' },
        { role: 'quit', label: 'Salir' }
      ]
    },
    {
      label: 'Editar',
      submenu: [
        { role: 'undo',      label: 'Deshacer' },
        { role: 'redo',      label: 'Rehacer' },
        { type: 'separator' },
        { role: 'cut',       label: 'Cortar' },
        { role: 'copy',      label: 'Copiar' },
        { role: 'paste',     label: 'Pegar' },
        { role: 'selectAll', label: 'Seleccionar todo' }
      ]
    },
    {
      label: 'Ver',
      submenu: [
        { role: 'reload',          label: 'Recargar' },
        { role: 'forceReload',     label: 'Forzar recarga' },
        { type: 'separator' },
        { role: 'resetZoom',       label: 'Tamaño original' },
        { role: 'zoomIn',          label: 'Ampliar' },
        { role: 'zoomOut',         label: 'Reducir' },
        { type: 'separator' },
        { role: 'togglefullscreen', label: 'Pantalla completa' }
      ]
    },
    {
      label: 'Ventana',
      submenu: [
        { role: 'minimize', label: 'Minimizar' },
        { role: 'zoom',     label: 'Maximizar' },
        { role: 'close',    label: 'Cerrar' }
      ]
    }
  ];

  // En macOS quitar el menú vacío inicial
  if (process.platform === 'darwin') {
    menuTemplate[0].submenu.unshift(
      { type: 'separator' },
      { role: 'hide',       label: 'Ocultar NutriCoach' },
      { role: 'hideOthers', label: 'Ocultar otros' },
      { role: 'unhide',     label: 'Mostrar todo' }
    );
  }

  const menu = Menu.buildFromTemplate(menuTemplate);
  Menu.setApplicationMenu(menu);
}

// Segunda instancia — enfocar la ventana existente
app.on('second-instance', () => {
  if (mainWindow) {
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  }
});

app.whenReady().then(() => {
  createWindow();

  // macOS: recrear ventana al hacer click en el dock
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

// Cerrar app al cerrar todas las ventanas (Windows/Linux)
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});