const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const http = require('http');

const DEFAULT_HOST = '127.0.0.1';
const DEFAULT_PORT = 5267;

let HOST = DEFAULT_HOST;
let PORT = DEFAULT_PORT;
let BACKEND_URL = `http://${HOST}:${PORT}`;

let mainWindow = null;
let loadingWindow = null;
let backendProcess = null;
let isQuitting = false;

function getBackendDir() {
    if (app.isPackaged) {
        return path.join(process.resourcesPath, 'backend');
    }
    return path.join(__dirname, 'backend');
}

function getRunBatPath() {
    return path.join(getBackendDir(), 'scripts', 'run.bat');
}

function getBackendDataDir() {
    return path.join(getBackendDir(), 'data');
}

function loadBackendConfig() {
    try {
        const configPath = path.join(getBackendDataDir(), 'webui.json');
        if (fs.existsSync(configPath)) {
            const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
            if (config.host) HOST = config.host === '0.0.0.0' ? '127.0.0.1' : config.host;
            if (config.port) PORT = config.port;
            BACKEND_URL = `http://${HOST}:${PORT}`;
            console.log(`Loaded backend config: ${BACKEND_URL}`);
        }
    } catch (e) {
        console.warn('Failed to load backend config, using defaults:', e.message);
    }
}

function sendToLoadingWindow(channel, data) {
    if (loadingWindow && !loadingWindow.isDestroyed()) {
        loadingWindow.webContents.send(channel, data);
    }
}

function checkBackendHealth(interval = 1000) {
    return new Promise((resolve, reject) => {
        let attempts = 0;
        
        function check() {
            attempts++;
            sendToLoadingWindow('backend-status', {
                progress: `正在检测后端服务... (${attempts}次)`
            });
            
            const req = http.get(`${BACKEND_URL}/api/health`, (res) => {
                if (res.statusCode === 200) {
                    resolve(true);
                } else {
                    setTimeout(check, interval);
                }
            });
            
            req.on('error', () => {
                setTimeout(check, interval);
            });
            
            req.setTimeout(2000, () => {
                req.destroy();
                setTimeout(check, interval);
            });
        }
        
        check();
    });
}

function startBackend() {
    return new Promise((resolve, reject) => {
        const backendDir = getBackendDir();
        const runBatPath = getRunBatPath();
        
        if (!fs.existsSync(runBatPath)) {
            const error = new Error(`后端目录未找到，请确保 backend 文件夹存在\n\n预期路径: ${runBatPath}`);
            sendToLoadingWindow('backend-error', { message: error.message });
            reject(error);
            return;
        }
        
        sendToLoadingWindow('backend-status', { status: '正在启动后端服务...' });
        sendToLoadingWindow('backend-log', { line: `Starting backend with: ${runBatPath}`, type: 'info' });
        sendToLoadingWindow('backend-log', { line: `Working directory: ${backendDir}`, type: 'info' });
        
        console.log(`Starting backend with: ${runBatPath}`);
        console.log(`Working directory: ${backendDir}`);
        
        if (process.platform === 'win32') {
            try {
                execSync('taskkill /F /IM python.exe /FI "WINDOWTITLE eq KiraAI*"', { stdio: 'pipe' });
            } catch (e) {
            }
        }
        
        if (process.platform === 'win32') {
            backendProcess = spawn('cmd.exe', ['/c', runBatPath], {
                cwd: backendDir,
                stdio: ['ignore', 'pipe', 'pipe'],
                detached: false,
                windowsHide: true,
                env: process.env
            });
        } else {
            const runShPath = path.join(backendDir, 'scripts', 'run.sh');
            backendProcess = spawn('/bin/bash', [runShPath], {
                cwd: backendDir,
                stdio: ['ignore', 'pipe', 'pipe'],
                env: process.env
            });
        }
        
        backendProcess.stdout.on('data', (data) => {
            const line = data.toString().trim();
            console.log(`[Backend] ${line}`);
            sendToLoadingWindow('backend-log', { line: line, type: 'info' });
        });
        
        backendProcess.stderr.on('data', (data) => {
            const line = data.toString().trim();
            console.error(`[Backend Error] ${line}`);
            const type = line.toLowerCase().includes('error') ? 'error' : 
                         line.toLowerCase().includes('warning') ? 'warn' : 'info';
            sendToLoadingWindow('backend-log', { line: line, type: type });
        });
        
        backendProcess.on('error', (err) => {
            console.error('Failed to start backend:', err);
            sendToLoadingWindow('backend-error', { message: `Failed to start backend: ${err.message}` });
            if (!isQuitting) {
                reject(new Error(`Failed to start backend: ${err.message}`));
            }
        });
        
        backendProcess.on('close', (code) => {
            console.log(`Backend process exited with code ${code}`);
            sendToLoadingWindow('backend-log', { line: `Backend process exited with code ${code}`, type: code === 0 ? 'info' : 'warn' });
            backendProcess = null;
        });
        
        checkBackendHealth()
            .then(() => {
                console.log('Backend is ready!');
                sendToLoadingWindow('backend-ready', {});
                resolve();
            })
            .catch(reject);
    });
}

function stopBackend() {
    if (backendProcess && backendProcess.pid) {
        console.log('Stopping backend...');
        isQuitting = true;
        
        if (process.platform === 'win32') {
            try {
                execSync('taskkill /F /T /PID ' + backendProcess.pid, { stdio: 'pipe' });
            } catch (e) {
                console.warn('Failed to kill backend process:', e.message);
            }
        } else {
            try {
                backendProcess.kill('SIGTERM');
            } catch (e) {
                console.warn('Failed to kill backend process:', e.message);
            }
        }
        
        backendProcess = null;
    }
}

function createLoadingWindow() {
    loadingWindow = new BrowserWindow({
        width: 500,
        height: 400,
        minWidth: 200,
        minHeight: 150,
        resizable: true,
        frame: false,
        transparent: true,
        alwaysOnTop: false,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false
        },
        backgroundColor: '#1a1a1a'
    });
    
    loadingWindow.loadFile(path.join(__dirname, 'loading.html'));
    
    loadingWindow.on('closed', () => {
        loadingWindow = null;
    });
    
    return loadingWindow;
}

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 1400,
        height: 900,
        minWidth: 1000,
        minHeight: 700,
        title: 'KiraAI',
        icon: path.join(__dirname, 'assets', 'icon.png'),
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js')
        },
        show: false,
        backgroundColor: '#1a1a2e'
    });
    
    mainWindow.loadURL(`${BACKEND_URL}/login`);
    
    mainWindow.once('ready-to-show', () => {
        if (loadingWindow && !loadingWindow.isDestroyed()) {
            loadingWindow.close();
        }
        mainWindow.show();
    });
    
    setTimeout(() => {
        if (mainWindow && !mainWindow.isVisible()) {
            if (loadingWindow && !loadingWindow.isDestroyed()) {
                loadingWindow.close();
            }
            mainWindow.show();
        }
    }, 10000);
    
    mainWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription, validatedURL) => {
        console.error('Failed to load:', errorCode, errorDescription, validatedURL);
        setTimeout(() => {
            if (mainWindow && !isQuitting) {
                mainWindow.loadURL(`${BACKEND_URL}/login`);
            }
        }, 3000);
    });
    
    mainWindow.webContents.setWindowOpenHandler(({ url }) => {
        shell.openExternal(url);
        return { action: 'deny' };
    });
    
    mainWindow.on('close', (event) => {
        if (!isQuitting) {
            event.preventDefault();
            mainWindow.hide();
            stopBackend();
            setTimeout(() => {
                isQuitting = true;
                app.quit();
            }, 2000);
        }
    });
    
    mainWindow.on('closed', () => {
        mainWindow = null;
    });
}

app.whenReady().then(async () => {
    try {
        console.log('Starting KiraAI Desktop...');
        
        createLoadingWindow();
        
        loadBackendConfig();
        
        await startBackend();
        createWindow();
    } catch (error) {
        console.error('Failed to start:', error);
        sendToLoadingWindow('backend-error', { message: error.message });
        setTimeout(() => {
            dialog.showErrorBox('Startup Error', `Failed to start KiraAI:\n${error.message}\n\nPlease make sure Python 3.10+ is installed and backend folder exists.`);
            app.quit();
        }, 1000);
    }
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        stopBackend();
        app.quit();
    }
});

app.on('activate', () => {
    if (mainWindow === null) {
        createWindow();
    }
});

app.on('before-quit', () => {
    stopBackend();
});

app.on('will-quit', () => {
    stopBackend();
});

ipcMain.handle('get-backend-url', () => BACKEND_URL);

ipcMain.handle('restart-backend', async () => {
    stopBackend();
    try {
        await startBackend();
        return { success: true };
    } catch (error) {
        return { success: false, error: error.message };
    }
});
