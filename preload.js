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

// macOS only: the login page hint hard-codes "data/webui.json", but on macOS
// the file actually lives at ~/Library/Application Support/kiraAI-DeskTop/
// backend/webui.json. The frontend SPA is auto-downloaded at runtime so we
// can't fix it in the source — patch the rendered DOM instead.
if (process.platform === 'darwin') {
    const ORIGINAL = 'data/webui.json';
    // Default fallback; the real path is fetched from main process below so
    // this stays in sync with getBackendDataDir() if it ever changes.
    let REPLACEMENT = '~/Library/Application Support/kiraAI-DeskTop/backend/webui.json';

    const patchTextNodes = (root) => {
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
        let node;
        while ((node = walker.nextNode())) {
            if (node.nodeValue && node.nodeValue.includes(ORIGINAL)) {
                node.nodeValue = node.nodeValue.split(ORIGINAL).join(REPLACEMENT);
            }
        }
    };

    // Resolve the real backend data dir from the main process; re-patch once
    // we have it in case the SPA already rendered with the fallback value.
    ipcRenderer.invoke('get-data-dir').then((dir) => {
        if (dir && typeof dir === 'string') {
            REPLACEMENT = `${dir}/webui.json`;
            if (document.body) patchTextNodes(document.body);
        }
    }).catch(() => {});

    window.addEventListener('DOMContentLoaded', () => {
        patchTextNodes(document.body);
        const observer = new MutationObserver((mutations) => {
            for (const m of mutations) {
                if (m.type === 'characterData') {
                    if (m.target.nodeValue && m.target.nodeValue.includes(ORIGINAL)) {
                        m.target.nodeValue = m.target.nodeValue.split(ORIGINAL).join(REPLACEMENT);
                    }
                } else {
                    m.addedNodes.forEach((n) => {
                        if (n.nodeType === Node.TEXT_NODE) {
                            if (n.nodeValue && n.nodeValue.includes(ORIGINAL)) {
                                n.nodeValue = n.nodeValue.split(ORIGINAL).join(REPLACEMENT);
                            }
                        } else if (n.nodeType === Node.ELEMENT_NODE) {
                            // Cheap pre-check before walking the subtree.
                            if (n.textContent && n.textContent.includes(ORIGINAL)) {
                                patchTextNodes(n);
                            }
                        }
                    });
                }
            }
        });
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            characterData: true
        });
    });
}
