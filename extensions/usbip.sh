function custom_kernel_config__usbip() {
	[[ -f ./scripts/config ]] || return 0
	./scripts/config --file .config --module CONFIG_USBIP_CORE
	./scripts/config --file .config --module CONFIG_USBIP_VHCI_HCD
	./scripts/config --file .config --module CONFIG_USBIP_HOST
}

function extension_prepare_config__usbip() {
	PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} usbip"
}

function post_family_tweaks__usbip() {
	mkdir -p "${SDCARD}/etc/modules-load.d" "${SDCARD}/etc/systemd/system"
	cat > "${SDCARD}/etc/modules-load.d/usbip.conf" << 'EOF'
usbip-core
usbip-host
vhci-hcd
EOF

	local bin
	bin="$(chroot "${SDCARD}" /bin/bash -c "command -v usbipd" 2>/dev/null || true)"
	[[ -n "${bin}" ]] || bin="/usr/sbin/usbipd"
	cat > "${SDCARD}/etc/systemd/system/usbipd.service" << EOF
[Unit]
Description=USB/IP daemon
After=network.target

[Service]
ExecStart=${bin}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
	chroot "${SDCARD}" /bin/bash -c "systemctl --no-reload enable usbipd.service >/dev/null 2>&1"
}
