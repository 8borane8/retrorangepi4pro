function custom_kernel_config__wireguard() {
	[[ -f ./scripts/config ]] || return 0
	./scripts/config --file .config --enable CONFIG_TUN
	./scripts/config --file .config --module CONFIG_WIREGUARD
}

function extension_prepare_config__wireguard() {
	PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} wireguard-tools"
}

function post_family_tweaks__wireguard() {
	mkdir -p "${SDCARD}/etc/modules-load.d" "${SDCARD}/etc/wireguard"
	echo "wireguard" > "${SDCARD}/etc/modules-load.d/wireguard.conf"
	cat > "${SDCARD}/etc/wireguard/wg0.conf" << 'EOF'
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = REPLACE_ME

# [Peer]
# PublicKey =
# AllowedIPs = 10.8.0.2/32
EOF
	chmod 600 "${SDCARD}/etc/wireguard/wg0.conf"
	chroot "${SDCARD}" /bin/bash -c "systemctl --no-reload disable wg-quick@wg0.service >/dev/null 2>&1" || true
}
