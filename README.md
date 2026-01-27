# Docker Browser VNC

A lightweight Docker container providing Firefox or Chromium browsers accessible via VNC and noVNC (web-based).

## Features

- **Dual access**: Native VNC (port 5901) and web-based noVNC (port 6080)
- **Browser choice**: Firefox or Chromium (configurable)
- **Dynamic resolution**: Auto-resize button adapts resolution to browser window
- **Minimal footprint**: Alpine Linux with multi-stage build
- **Persistent profiles**: Support for custom browser configurations, bookmarks, and policies
- **Non-root execution**: Runs as unprivileged user for security

## Quick start

### Using Docker run

```bash
# Firefox (default)
docker run -d -p 5901:5901 -p 6080:6080 -p 6081:6081 docker-browser-vnc

# Chromium
docker run -d -p 5901:5901 -p 6080:6080 -p 6081:6081 -e BROWSER=chromium docker-browser-vnc

# Custom starting URL
docker run -d -p 5901:5901 -p 6080:6080 -p 6081:6081 \
  -e STARTING_URL="https://example.com" \
  docker-browser-vnc
```

### Using Docker compose

```yaml
services:
  browser:
    build: .
    ports:
      - "5901:5901"  # VNC
      - "6080:6080"  # noVNC (web)
      - "6081:6081"  # Resize API
    environment:
      - VNC_PW=mysecretpassword
      - BROWSER=firefox
```

## Accessing the browser

- **Web Browser**: Navigate to `http://localhost:6080` - no VNC client required
- **VNC Client**: Connect to `localhost:5901` with your preferred VNC viewer

## Environment variables

| Variable         | Default       | Description                              |
| ---------------- | ------------- | ---------------------------------------- |
| `BROWSER`        | `firefox`     | Browser to use (`firefox` or `chromium`) |
| `VNC_PW`         | `changeme`    | VNC connection password                  |
| `VNC_RESOLUTION` | `1920x1080`   | Display resolution                       |
| `VNC_COL_DEPTH`  | `24`          | Color depth (bits)                       |
| `VNC_PORT`       | `5901`        | Native VNC port                          |
| `NOVNC_PORT`     | `6080`        | noVNC web port                           |
| `STARTING_URL`   | `about:blank` | Initial URL to open                      |

## Exposed ports

| Port | Protocol | Description         |
| ---- | -------- | ------------------- |
| 5901 | TCP      | Native VNC server   |
| 6080 | TCP      | noVNC web interface |
| 6081 | TCP      | Resize API          |

## Browser customization

Mount a volume to `/user-data` to customize browser profiles and settings.

### Directory structure

```
/user-data/
├── firefox-policies/
│   └── policies.json       # Firefox enterprise policies
├── firefox-profile/
│   ├── user.js             # Firefox preferences
│   ├── bookmarks.html      # Bookmarks (optional)
│   └── ...                 # Other profile files
├── chromium-profile/
│   └── Preferences         # Chromium preferences
└── desktop/
    └── *.desktop           # Desktop shortcuts
```

### Example: Custom Firefox bookmarks and policies

```bash
docker run -d -p 6080:6080 \
  -v /path/to/my-config:/user-data:ro \
  docker-browser-vnc
```

### Firefox policies example

Create `/user-data/firefox-policies/policies.json`:

```json
{
  "policies": {
    "Homepage": {
      "URL": "https://example.com",
      "Locked": true
    },
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisplayBookmarksToolbar": "always",
    "ManagedBookmarks": [
      {
        "toplevel_name": "Company Links"
      },
      {
        "name": "Intranet",
        "url": "https://intranet.example.com"
      }
    ]
  }
}
```

### Firefox preferences example

Create `/user-data/firefox-profile/user.js`:

```javascript
// Set homepage
user_pref("browser.startup.homepage", "https://example.com");

// Disable pocket
user_pref("extensions.pocket.enabled", false);

// Custom proxy settings
user_pref("network.proxy.type", 1);
user_pref("network.proxy.http", "proxy.example.com");
user_pref("network.proxy.http_port", 8080);
```

## Dynamic resolution

The container supports dynamic resolution changes (up to 4K) via the RANDR extension.

### Auto-resize button

A resize button is available in the top-right corner of the noVNC interface:

1. Open `http://localhost:6080/vnc.html?autoconnect=true`
2. Click the **resize button** (top-right corner)
3. When enabled (green), the resolution automatically adapts to your browser window size
4. The setting is saved in localStorage

### Resize API (port 6081)

You can also change resolution programmatically:

```bash
# Get current resolution
curl http://localhost:6081/resolution

# Set resolution
curl "http://localhost:6081/resize?width=1920&height=1080"
```

## Building

### Build with Firefox (default)

```bash
docker build -t docker-browser-vnc .
```

### Build with Chromium

```bash
docker build -t docker-browser-vnc --build-arg BROWSER=chromium .
```

## Image size breakdown

### Firefox image (~920 MB)

| Component            | Size    | Description                     |
| -------------------- | ------- | ------------------------------- |
| Firefox              | 240 MB  | Browser binaries and resources  |
| LLVM/Mesa            | 170 MB  | Graphics rendering (OpenGL)     |
| Fonts                | 134 MB  | Noto (111 MB), DejaVu, FreeFont |
| Python + NumPy       | 87 MB   | Required for websockify         |
| GTK, X11, other libs | ~280 MB | UI toolkit and X11 dependencies |
| noVNC + VNC tools    | 6 MB    | Web VNC client, x11vnc, Xvfb    |

### Chromium image (~1.02 GB)

| Component            | Size    | Description                               |
| -------------------- | ------- | ----------------------------------------- |
| Chromium             | 267 MB  | Browser binaries and resources            |
| LLVM/Mesa            | 170 MB  | Graphics rendering (OpenGL)               |
| Fonts                | 137 MB  | Noto (111 MB), DejaVu, FreeFont, OpenSans |
| Python + NumPy       | 87 MB   | Required for websockify                   |
| GTK, X11, other libs | ~350 MB | UI toolkit and X11 dependencies           |
| noVNC + VNC tools    | 6 MB    | Web VNC client, x11vnc, Xvfb              |

> **Note**: The base Alpine image is ~7 MB. Most of the image size comes from the browser and its graphical dependencies (Mesa/LLVM for GPU rendering, GTK for UI).

## Architecture

```
Container startup sequence:
┌─────────────────────────────────────────────────────────┐
│ supervisord (PID 1)                                     │
│ ├── Xvfb (Virtual X Server)     → Display :0            │
│ ├── x11vnc (VNC Server)         → Port 5901             │
│ ├── Openbox (Window Manager)    → Launches browser      │
│ └── noVNC (Web Proxy)           → Port 6080             │
└─────────────────────────────────────────────────────────┘
```

### Components

| Component       | Purpose                                         |
| --------------- | ----------------------------------------------- |
| **Xvfb**        | Virtual framebuffer X server (headless display) |
| **x11vnc**      | VNC server exposing the X display               |
| **Openbox**     | Minimal window manager                          |
| **noVNC**       | HTML5 VNC client (web access)                   |
| **websockify**  | WebSocket to VNC protocol proxy                 |
| **supervisord** | Process manager                                 |

## Health check

The container includes a health check that verifies both `x11vnc` and `Xvfb` processes are running:

- Interval: 30 seconds
- Timeout: 10 seconds
- Start period: 15 seconds
- Retries: 3

## Security considerations

- Container runs as non-root user (`user`, UID 1000)
- VNC password authentication enabled by default
- Mount user data as read-only (`:ro`) when possible
- Change the default VNC password in production

## Troubleshooting

### Cannot connect to VNC

1. Verify the container is running: `docker ps`
2. Check container logs: `docker logs <container_id>`
3. Ensure ports 5901/6080 are not in use

### Browser crashes or freezes

1. Increase shared memory: `docker run --shm-size=256m ...`
2. Check available memory in container
3. For Chromium, the container already uses `--no-sandbox` and `--disable-dev-shm-usage`

### Custom data not loading

1. Verify mount path: `docker exec <container_id> ls -la /user-data`
2. Check file permissions (readable by UID 1000)
3. Review container logs for loading messages
