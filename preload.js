const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
    getBackendUrl: () => ipcRenderer.invoke('get-backend-url'),
    restartBackend: () => ipcRenderer.invoke('restart-backend'),
    
    platform: process.platform,
    isElectron: true
});
