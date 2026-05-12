const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
    getBackendUrl: () => ipcRenderer.invoke('get-backend-url'),
    restartBackend: () => ipcRenderer.invoke('restart-backend'),
    openDataDir: () => ipcRenderer.invoke('open-data-dir'),
    getDataDir: () => ipcRenderer.invoke('get-data-dir'),

    onBackendStatus: (cb) => {
        const listener = (_e, data) => cb(data);
        ipcRenderer.on('backend-status', listener);
        return () => ipcRenderer.removeListener('backend-status', listener);
    },
    onBackendLog: (cb) => {
        const listener = (_e, data) => cb(data);
        ipcRenderer.on('backend-log', listener);
        return () => ipcRenderer.removeListener('backend-log', listener);
    },
    onBackendReady: (cb) => {
        const listener = () => cb();
        ipcRenderer.once('backend-ready', listener);
        return () => ipcRenderer.removeListener('backend-ready', listener);
    },
    onBackendError: (cb) => {
        const listener = (_e, data) => cb(data);
        ipcRenderer.on('backend-error', listener);
        return () => ipcRenderer.removeListener('backend-error', listener);
    },

    platform: process.platform,
    isElectron: true
});
