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
    if (!app.isPackaged) {
        return path.join(getBackendDir(), 'data');
    }
    if (process.platform === 'win32') {
        const localAppData = process.env.LOCALAPPDATA || path.join(require('os').homedir(), 'AppData', 'Local');
        return path.join(localAppData, 'kiraAI-DeskTop');
    }
    // macOS: ~/Library/Application Support/kiraAI-DeskTop/backend
    // Linux: ~/.config/kiraAI-DeskTop/backend
    return path.join(app.getPath('userData'), 'backend');
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

function checkBackendHealth(interval = 1000, maxAttempts = 300) {
    return new Promise((resolve, reject) => {
        let attempts = 0;
        let settled = false;

        function scheduleNext() {
            if (settled) return;
            settled = true;
            setTimeout(() => {
                settled = false;
                check();
            }, interval);
        }

        function check() {
            if (isQuitting) {
                reject(new Error('Aborted'));
                return;
            }
            if (!backendProcess) {
                reject(new Error('Backend process exited before becoming healthy'));
                return;
            }
            attempts++;
            if (attempts > maxAttempts) {
                reject(new Error(`Backend health check timed out after ${maxAttempts} attempts`));
                return;
            }
            sendToLoadingWindow('backend-status', {
                progress: `正在检测后端服务... (${attempts}次)`
            });

            const req = http.get(`${BACKEND_URL}/api/health`, (res) => {
                if (res.statusCode === 200) {
                    resolve(true);
                } else {
                    scheduleNext();
                }
            });

            req.on('error', () => {
                scheduleNext();
            });

            req.setTimeout(5000, () => {
                req.destroy();
                scheduleNext();
            });
        }

        check();
    });
}

function startBackend() {
    return new Promise((resolve, reject) => {
        const backendDir = getBackendDir();

        if (!fs.existsSync(backendDir)) {
            const error = new Error(`后端目录未找到，请确保 backend 文件夹存在\n\n预期路径: ${backendDir}`);
            sendToLoadingWindow('backend-error', { message: error.message });
            reject(error);
            return;
        }

        const backendDataDir = getBackendDataDir();
        try {
            fs.mkdirSync(backendDataDir, { recursive: true });
        } catch (e) {
            const error = new Error(`无法创建数据目录\n\n路径: ${backendDataDir}\n错误: ${e.message}`);
            sendToLoadingWindow('backend-error', { message: error.message });
            reject(error);
            return;
        }

        const backendEnv = { ...process.env, KIRAAI_DATA_DIR: backendDataDir };

        sendToLoadingWindow('backend-status', { status: '正在启动后端服务...' });
        sendToLoadingWindow('backend-log', { line: `Working directory: ${backendDir}`, type: 'info' });
        sendToLoadingWindow('backend-log', { line: `Data directory: ${backendDataDir}`, type: 'info' });

        console.log(`Working directory: ${backendDir}`);
        console.log(`Data directory: ${backendDataDir}`);

        if (process.platform === 'win32') {
            try {
                execSync('taskkill /F /IM python.exe /FI "WINDOWTITLE eq KiraAI*"', { stdio: 'pipe' });
            } catch (e) {
            }
        }

        if (process.platform === 'win32') {
            const runBatPath = getRunBatPath();
            if (!fs.existsSync(runBatPath)) {
                const error = new Error(`后端启动脚本未找到\n\n预期路径: ${runBatPath}`);
                sendToLoadingWindow('backend-error', { message: error.message });
                reject(error);
                return;
            }
            sendToLoadingWindow('backend-log', { line: `Starting backend with: ${runBatPath}`, type: 'info' });
            console.log(`Starting backend with: ${runBatPath}`);
            backendProcess = spawn(runBatPath, [], {
                cwd: backendDir,
                stdio: ['ignore', 'pipe', 'pipe'],
                detached: false,
                windowsHide: true,
                env: backendEnv,
                shell: true
            });
        } else {
            const runShPath = path.join(backendDir, 'scripts', 'run.sh');
            if (!fs.existsSync(runShPath)) {
                const error = new Error(`后端启动脚本未找到\n\n预期路径: ${runShPath}`);
                sendToLoadingWindow('backend-error', { message: error.message });
                reject(error);
                return;
            }
            sendToLoadingWindow('backend-log', { line: `Starting backend with: ${runShPath}`, type: 'info' });
            console.log(`Starting backend with: ${runShPath}`);
            backendProcess = spawn('/bin/bash', [runShPath], {
                cwd: backendDir,
                stdio: ['ignore', 'pipe', 'pipe'],
                env: backendEnv
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
        alwaysOnTop: false,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js')
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
        icon: path.join(__dirname, 'assets', 'KD-LOGO.ico'),
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js')
        },
        show: false,
        backgroundColor: '#1a1a2e'
    });
    
    mainWindow.loadURL(`${BACKEND_URL}/login`);

    mainWindow.setMenuBarVisibility(false);

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
    
    mainWindow.on('close', async (event) => {
        if (isQuitting) {
            return;
        }
        const safeHide = () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
                mainWindow.hide();
            }
        };
        if (process.platform === 'darwin') {
            // macOS convention: closing the window only hides it; the app
            // (and backend) keep running. Use Cmd+Q or the Quit menu item
            // to actually exit, which triggers the before-quit handler.
            event.preventDefault();
            safeHide();
            return;
        }
        // Windows/Linux: confirm before shutting down the backend.
        event.preventDefault();
        const { response } = await dialog.showMessageBox(mainWindow, {
            type: 'question',
            buttons: ['退出', '取消'],
            defaultId: 1,
            cancelId: 1,
            title: 'KiraAI',
            message: '确认退出 KiraAI？',
            detail: '退出后后端服务将一并关闭，所有连接将断开。',
            icon: path.join(__dirname, 'assets', 'KD-LOGO.ico')
        });

        if (response === 0) {
            isQuitting = true;
            safeHide();
            stopBackend();
            setTimeout(() => {
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
        isQuitting = true;
        stopBackend();
        app.quit();
    }
});

app.on('activate', () => {
    if (mainWindow === null) {
        createWindow();
    } else if (!mainWindow.isVisible()) {
        mainWindow.show();
    }
});

app.on('before-quit', () => {
    isQuitting = true;
    stopBackend();
});

app.on('will-quit', () => {
    isQuitting = true;
    stopBackend();
});

ipcMain.handle('get-backend-url', () => BACKEND_URL);

ipcMain.handle('open-data-dir', async () => {
    const dataDir = getBackendDataDir();
    if (fs.existsSync(dataDir)) {
        const error = await shell.openPath(dataDir);
        if (error) {
            return { success: false, error: `打开目录失败: ${error}` };
        }
        return { success: true };
    }
    return { success: false, error: `目录不存在: ${dataDir}` };
});

ipcMain.handle('get-data-dir', () => {
    return getBackendDataDir();
});

ipcMain.handle('restart-backend', async () => {
    stopBackend();
    isQuitting = false;
    try {
        await startBackend();
        return { success: true };
    } catch (error) {
        return { success: false, error: error.message };
    }
});
