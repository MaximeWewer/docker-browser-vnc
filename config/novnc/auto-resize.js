(function() {
    const API_PORT = 6081;
    const RESIZE_DELAY = 300;
    let enabled = false;
    let timeout = null;
    let btn = null;
    let status = null;

    const api = `http://${location.hostname}:${API_PORT}`;

    async function resize(w, h) {
        try {
            showStatus(`Resizing to ${w}x${h}...`);
            const r = await fetch(`${api}/resize?width=${w}&height=${h}`);
            const data = await r.json();
            if (data.success) {
                showStatus(`${w}x${h}`);
                return true;
            }
        } catch(e) {
            showStatus('Resize failed');
        }
        return false;
    }

    function getSize() {
        return {
            w: Math.floor(window.innerWidth / 8) * 8,
            h: Math.floor(window.innerHeight / 8) * 8
        };
    }

    function onResize() {
        if (!enabled) return;
        clearTimeout(timeout);
        timeout = setTimeout(() => {
            const {w, h} = getSize();
            resize(w, h);
        }, RESIZE_DELAY);
    }

    function showStatus(msg) {
        if (status) {
            status.textContent = msg;
            status.style.opacity = '1';
            setTimeout(() => { status.style.opacity = '0'; }, 2000);
        }
    }

    function toggle() {
        enabled = !enabled;
        updateButton();
        if (enabled) {
            const {w, h} = getSize();
            resize(w, h);
        } else {
            showStatus('Auto-resize OFF');
        }
        try { localStorage.setItem('vnc_autoresize', enabled); } catch(e) {}
    }

    function updateButton() {
        if (!btn) return;
        btn.style.background = enabled ? '#2a9d5c' : '#444';
        btn.title = enabled ? 'Auto-resize ON (click to disable)' : 'Auto-resize OFF (click to enable)';
    }

    function createUI() {
        // Remove existing if any
        const existing = document.getElementById('autoresize-btn');
        if (existing) existing.remove();
        const existingStatus = document.getElementById('autoresize-status');
        if (existingStatus) existingStatus.remove();

        // Create button with SVG icon
        btn = document.createElement('div');
        btn.id = 'autoresize-btn';
        btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/></svg>';
        btn.style.cssText = `
            position: fixed;
            top: 8px;
            right: 8px;
            z-index: 99999;
            background: #444;
            color: #fff;
            width: 32px;
            height: 32px;
            border-radius: 4px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
            transition: background 0.2s;
        `;
        btn.onclick = toggle;
        btn.onmouseenter = () => { btn.style.transform = 'scale(1.1)'; };
        btn.onmouseleave = () => { btn.style.transform = 'scale(1)'; };
        document.body.appendChild(btn);

        // Create status
        status = document.createElement('div');
        status.id = 'autoresize-status';
        status.style.cssText = `
            position: fixed;
            top: 8px;
            right: 48px;
            z-index: 99999;
            background: rgba(0,0,0,0.8);
            color: #fff;
            padding: 6px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-family: sans-serif;
            opacity: 0;
            transition: opacity 0.3s;
            pointer-events: none;
        `;
        document.body.appendChild(status);

        updateButton();

        // Restore state
        try {
            if (localStorage.getItem('vnc_autoresize') === 'true') {
                setTimeout(() => {
                    enabled = true;
                    updateButton();
                    const {w, h} = getSize();
                    resize(w, h);
                }, 1500);
            }
        } catch(e) {}
    }

    function ensureUI() {
        if (!document.getElementById('autoresize-btn')) {
            createUI();
        }
    }

    function init() {
        createUI();
        window.addEventListener('resize', onResize);
        // Re-check UI periodically in case noVNC removes it
        setInterval(ensureUI, 2000);
    }

    // Check API then init
    fetch(`${api}/health`)
        .then(r => r.json())
        .then(() => {
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', init);
            } else {
                setTimeout(init, 500);
            }
        })
        .catch(() => console.log('Auto-resize API not available'));
})();
