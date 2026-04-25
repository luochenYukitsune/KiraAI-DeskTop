const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
    getBackendUrl: () => ipcRenderer.invoke('get-backend-url'),
    restartBackend: () => ipcRenderer.invoke('restart-backend'),

    onBackendStatus: (cb) => ipcRenderer.on('backend-status', (_e, data) => cb(data)),
    onBackendLog: (cb) => ipcRenderer.on('backend-log', (_e, data) => cb(data)),
    onBackendReady: (cb) => ipcRenderer.on('backend-ready', () => cb()),
    onBackendError: (cb) => ipcRenderer.on('backend-error', (_e, data) => cb(data)),

    platform: process.platform,
    isElectron: true
});
