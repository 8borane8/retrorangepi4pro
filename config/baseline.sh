# OpenSSH and zram are part of the server and desktop images.
# They are not extensions and not apps.

extension_prepare_config__baseline_ssh() {
	[[ "${ENABLE_SSH}" == "yes" ]] || return 0
	PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} openssh-server"
}

post_family_tweaks__baseline_ssh() {
	[[ "${ENABLE_SSH}" == "yes" ]] || return 0
	local keys="${SRC}/authorized_keys"
	[[ -f "${keys}" ]] || return 0

	local ssh_dir="${SDCARD}/home/${OPI_USERNAME}/.ssh"
	mkdir -p "${ssh_dir}"
	cat "${keys}" >> "${ssh_dir}/authorized_keys"
	chmod 700 "${ssh_dir}"
	chmod 600 "${ssh_dir}/authorized_keys"
	chroot "${SDCARD}" /bin/bash -c "chown -R ${OPI_USERNAME}:${OPI_USERNAME} /home/${OPI_USERNAME}/.ssh"
}

post_family_tweaks__baseline_disable_stock_zram() {
	# The BSP unit turns zram on for every image. Swap belongs to opi4pro-zram-swap.
	mkdir -p "${SDCARD}/etc/default"
	if [[ -f "${SDCARD}/etc/default/orangepi-zram-config" ]]; then
		sed -i 's/^ENABLED=.*/ENABLED=false/' "${SDCARD}/etc/default/orangepi-zram-config"
	else
		echo "ENABLED=false" > "${SDCARD}/etc/default/orangepi-zram-config"
	fi
	chroot "${SDCARD}" /bin/bash -c "systemctl --no-reload disable orangepi-zram-config.service >/dev/null 2>&1" || true
}

post_family_tweaks__baseline_zram() {
	[[ "${ENABLE_ZRAM}" == "yes" ]] || return 0
	mkdir -p "${SDCARD}/usr/local/sbin" "${SDCARD}/etc/systemd/system"

	cat > "${SDCARD}/usr/local/sbin/opi4pro-zram-swap" << 'EOF'
#!/bin/bash
set -eu
modprobe zram
if [[ -f /sys/block/zram0/disksize && "$(cat /sys/block/zram0/disksize)" != "0" ]]; then
	exit 0
fi
mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
echo $((mem_kb / 2))K > /sys/block/zram0/disksize
mkswap /dev/zram0 >/dev/null
swapon -p 100 /dev/zram0
EOF
	chmod 755 "${SDCARD}/usr/local/sbin/opi4pro-zram-swap"

	cat > "${SDCARD}/etc/systemd/system/opi4pro-zram-swap.service" << 'EOF'
[Unit]
Description=Compressed swap on zram
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/opi4pro-zram-swap
ExecStop=/sbin/swapoff /dev/zram0

[Install]
WantedBy=multi-user.target
EOF

	chroot "${SDCARD}" /bin/bash -c "systemctl --no-reload enable opi4pro-zram-swap.service >/dev/null 2>&1"
}
