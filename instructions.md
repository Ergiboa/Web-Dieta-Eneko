# INSTRUCCIONES — NutriCoach PWA + Electron

## ESTRUCTURA FINAL DE ARCHIVOS

Tu carpeta del proyecto debe quedar así:

```
nutricoach/
├── app.html          ← (ya lo tienes, modificar)
├── login.html        ← (ya lo tienes, modificar)
├── manifest.json     ← NUEVO
├── sw.js             ← NUEVO
├── main.js           ← NUEVO (Electron)
├── package.json      ← NUEVO (Electron)
├── icon-192.png      ← NUEVO (crear tú)
└── icon-512.png      ← NUEVO (crear tú)
```

---

## PASO 1 — Crear los iconos

1. Ve a https://favicon.io/favicon-generator/
2. Pon:
   - Text: NC
   - Background: Rounded
   - Background color: #c2f24f
   - Font color: #08090a
   - Font size: 110
3. Pulsa "Generate"
4. Descarga el ZIP
5. Del ZIP coge "android-chrome-192x192.png" → renómbralo a **icon-192.png**
6. Del ZIP coge "android-chrome-512x512.png" → renómbralo a **icon-512.png**
7. Pon ambos en la carpeta del proyecto

---

## PASO 2 — Modificar login.html

Busca esta línea (está dentro del `<head>`):
```
<title>NutriCoach — Acceder</title>
```

Añade JUSTO DESPUÉS:
```html
<link rel="manifest" href="manifest.json">
<meta name="theme-color" content="#c2f24f">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="NutriCoach">
<link rel="apple-touch-icon" href="icon-192.png">
```

Luego busca la línea (al final del archivo):
```
</body>
```

Añade JUSTO ANTES:
```html
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js')
        .then(() => console.log('[PWA] Service Worker registrado'))
        .catch(e => console.warn('[PWA] Error SW:', e));
    });
  }
</script>
```

---

## PASO 3 — Modificar app.html

Busca esta línea (está dentro del `<head>`):
```
<title>NutriCoach</title>
```

Añade JUSTO DESPUÉS:
```html
<link rel="manifest" href="manifest.json">
<meta name="theme-color" content="#c2f24f">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="NutriCoach">
<link rel="apple-touch-icon" href="icon-192.png">
```

Luego busca la línea (al final del archivo):
```
<div id="toast"></div>
</body>
```

Añade JUSTO ANTES de `<div id="toast">`:
```html
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js')
        .then(() => console.log('[PWA] Service Worker registrado'))
        .catch(e => console.warn('[PWA] Error SW:', e));
    });
  }
</script>
```

---

## PASO 4 — Subir a hosting (necesario para la PWA)

Las PWA solo funcionan en HTTPS, no en local. Necesitas subir los archivos.

### Opción gratuita recomendada: Netlify

1. Ve a https://netlify.com y crea cuenta gratis
2. Arrastra toda la carpeta del proyecto a la zona de "drag and drop"
3. Netlify te dará una URL tipo: https://nutricoach-abc123.netlify.app
4. ¡Ya funciona la PWA!

### Para un dominio propio (opcional)
- En Netlify puedes añadir un dominio personalizado desde "Domain settings"

---

## PASO 5 — Instalar la PWA en el móvil

### Android (Chrome):
1. Abre la URL en Chrome
2. Aparece un banner "Añadir a pantalla de inicio" — pulsa "Instalar"
3. O ve al menú (⋮) → "Añadir a pantalla de inicio"

### iPhone (Safari):
1. Abre la URL en Safari
2. Pulsa el botón compartir (cuadrado con flecha hacia arriba)
3. "Añadir a pantalla de inicio"
4. Pulsa "Añadir"

### Ordenador (Chrome/Edge):
1. Abre la URL
2. En la barra de URL aparece un icono de instalar (📥)
3. Pulsa "Instalar NutriCoach"

---

## PASO 6 — Crear el instalador de escritorio (Electron)

Esto genera un archivo .exe para Windows que el cliente descarga e instala.

### Requisitos previos:
- Tener Node.js instalado: https://nodejs.org (versión LTS)
- Tener VS Code

### En la terminal de VS Code (Ctrl + `):

```bash
# 1. Instalar dependencias
npm install

# 2. Probar que funciona en local
npm start

# 3. Generar el instalador .exe para Windows
npm run build:win
```

El archivo instalador estará en:
```
nutricoach/dist/NutriCoach Setup 1.0.0.exe
```

### Para compartir con clientes:
- Sube el .exe a Google Drive, Dropbox, o a tu web de Netlify
- El cliente lo descarga, doble click, y se instala como cualquier programa

---

## RESUMEN PARA EL CLIENTE

| Dispositivo | Cómo instalar |
|-------------|---------------|
| Android | Abrir web en Chrome → "Añadir a pantalla de inicio" |
| iPhone | Abrir web en Safari → Compartir → "Añadir a pantalla de inicio" |
| Windows | Descargar el .exe y ejecutarlo, O instalar desde Chrome/Edge |
| Mac/Linux | Instalar desde Chrome/Edge |

---

## SOLUCIÓN DE PROBLEMAS

**La PWA no aparece en móvil:**
- Asegúrate de que la web esté en HTTPS (Netlify lo hace automáticamente)
- Limpia la caché del navegador
- La primera visita debe completarse correctamente

**El .exe no se instala:**
- Windows puede mostrar "Protección de Windows Defender"
- Pulsa "Más información" → "Ejecutar de todas formas"
- Esto pasa porque el .exe no está firmado digitalmente (requiere pago)

**Error al hacer npm install:**
- Asegúrate de tener Node.js instalado: ejecuta `node --version` en la terminal
- Si da error de permisos, abre VS Code como administrador