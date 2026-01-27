# =============================================================================
# Lightweight VNC Browser Image with Firefox or Chromium + noVNC
#
# Features:
#   - Built-in noVNC (web access without VNC client)
#   - Firefox or Chromium (configurable via BROWSER env)
#   - Persistent profile support (bookmarks, settings)
#   - Openbox as minimal window manager
#   - Multi-stage build to reduce image size
# =============================================================================

ARG BROWSER=firefox

# =============================================================================
# Stage 1: Download noVNC and websockify
# =============================================================================
FROM alpine:3.23 AS novnc-builder

ARG NOVNC_VERSION=1.6.0
ARG WEBSOCKIFY_VERSION=0.13.0

RUN apk add --no-cache wget ca-certificates && \
    mkdir -p /opt/noVNC/utils/websockify && \
    # Download noVNC
    wget -qO- "https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz" \
        | tar xz --strip 1 -C /opt/noVNC && \
    # Download websockify
    wget -qO- "https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.tar.gz" \
        | tar xz --strip 1 -C /opt/noVNC/utils/websockify && \
    # Create index.html pointing to vnc.html
    ln -sf /opt/noVNC/vnc.html /opt/noVNC/index.html && \
    # Clean up unnecessary files to reduce size
    rm -rf /opt/noVNC/.git* /opt/noVNC/docs /opt/noVNC/tests \
           /opt/noVNC/utils/websockify/.git* /opt/noVNC/utils/websockify/tests

# =============================================================================
# Stage 2: Final image
# =============================================================================
FROM alpine:3.23

LABEL description="Lightweight VNC browser with noVNC"
LABEL version="1.0"

ARG BROWSER=firefox

# ---------------------------------------------------------------------------
# Environment variables
# ---------------------------------------------------------------------------
ENV DISPLAY=:0 \
    # Ports
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    # Resolution
    VNC_RESOLUTION=1920x1080 \
    VNC_COL_DEPTH=24 \
    # VNC password
    VNC_PW=changeme \
    # Browser: firefox or chromium
    BROWSER=${BROWSER} \
    # Starting URL
    STARTING_URL=about:blank \
    # User home directory
    HOME=/home/user \
    # Disable interactive prompts
    DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Install packages
# ---------------------------------------------------------------------------
RUN apk add --no-cache \
    # === X11 & VNC ===
    xvfb \
    x11vnc \
    xrandr \
    libxcvt \
    # === Minimal Window Manager ===
    openbox \
    xsetroot \
    # === Browser ===
    ${BROWSER} \
    # === Fonts (essential for web browsing) ===
    font-noto \
    font-noto-cjk \
    font-noto-emoji \
    ttf-freefont \
    ttf-dejavu \
    # === Runtime ===
    supervisor \
    bash \
    dbus \
    # === Python for websockify ===
    python3 \
    py3-numpy \
    # === Utilities ===
    procps \
    && \
    # === Cleanup ===
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# ---------------------------------------------------------------------------
# Copy noVNC from builder + inject auto-resize script
# ---------------------------------------------------------------------------
COPY --from=novnc-builder /opt/noVNC /opt/noVNC
COPY config/novnc/auto-resize.js /opt/noVNC/auto-resize.js
RUN sed -i 's|</body>|<script src="auto-resize.js"></script></body>|' /opt/noVNC/vnc.html

# ---------------------------------------------------------------------------
# Create Firefox policies directory (writable at runtime)
# ---------------------------------------------------------------------------
RUN mkdir -p /usr/lib/firefox/distribution && \
    chmod 777 /usr/lib/firefox/distribution

# ---------------------------------------------------------------------------
# Create mount point for user data
# ---------------------------------------------------------------------------
RUN mkdir -p /user-data && chmod 755 /user-data

# ---------------------------------------------------------------------------
# Create non-root user
# ---------------------------------------------------------------------------
RUN adduser -D -u 1000 -h /home/user -s /bin/bash user && \
    # Create required directories
    mkdir -p \
        /home/user/.vnc \
        /home/user/.config/openbox \
        /home/user/.mozilla/firefox \
        /home/user/.config/chromium \
        /home/user/Desktop \
        /home/user/Downloads && \
    # Set permissions
    chown -R user:user /home/user

# ---------------------------------------------------------------------------
# Openbox configuration
# ---------------------------------------------------------------------------
COPY --chown=user:user config/openbox/rc.xml /home/user/.config/openbox/rc.xml
COPY --chown=user:user config/openbox/autostart /home/user/.config/openbox/autostart
COPY --chown=user:user config/openbox/menu.xml /home/user/.config/openbox/menu.xml

# ---------------------------------------------------------------------------
# Supervisord configuration
# ---------------------------------------------------------------------------
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ---------------------------------------------------------------------------
# Scripts
# ---------------------------------------------------------------------------
COPY --chmod=755 scripts/start.sh /start.sh
COPY --chmod=755 scripts/launch-browser.sh /usr/local/bin/launch-browser.sh
COPY --chmod=755 scripts/resize.sh /usr/local/bin/resize.sh
COPY --chmod=755 scripts/resize-server.py /usr/local/bin/resize-server.py

# ---------------------------------------------------------------------------
# Exposed ports
# ---------------------------------------------------------------------------
# 5901 = Native VNC
# 6080 = noVNC web interface
# 6081 = Resize API
EXPOSE 5901 6080 6081

# ---------------------------------------------------------------------------
# Healthcheck
# ---------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD pgrep -x "x11vnc" > /dev/null && pgrep -x "Xvfb" > /dev/null || exit 1

# ---------------------------------------------------------------------------
# User and entrypoint
# ---------------------------------------------------------------------------
USER user
WORKDIR /home/user

CMD ["/start.sh"]
