# OpenSSH and zram are part of the server and desktop images.
# So are the pin access tools, the system tools and the network tuning below.
# Function names here must hold a single double underscore: the extension manager
# splits every name on it to find the hook point.

# Pinned so a build today and a build next year use the same wiringOP.
WIRINGOP_URL="https://github.com/orangepi-xunlong/wiringOP.git"
WIRINGOP_COMMIT="a7921ca2f5c124203be10d3418db70a2e15f3c10"

# Install the packages from the list that this release carries. A name with no
# candidate is skipped with a warning, so one missing package does not stop the build.
# An install that fails with the candidates present is a real error.
install_available_packages() {
	local package candidate
	local available=()
	for package in "$@"; do
		candidate=$(chroot "${SDCARD}" /bin/bash -c "apt-cache policy ${package} 2>/dev/null" | awk '/Candidate:/ {print $2}')
		if [[ -n "${candidate}" && "${candidate}" != "(none)" ]]; then
			available+=("${package}")
		else
			display_alert "Package is not in ${RELEASE}, skipped" "${package}" "wrn"
		fi
	done
	[[ ${#available[@]} -eq 0 ]] && return 0
	run_on_sdcard "DEBIAN_FRONTEND=noninteractive apt-get -y -qq --no-install-recommends install ${available[*]}" \
		|| exit_with_error "Package install failed" "${available[*]}"
}

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
	# The image turns this unit back on after extensions run. The script exits
	# while ENABLED is not true, so it does not create a second swap.
	mkdir -p "${SDCARD}/etc/default"
	if [[ -f "${SDCARD}/etc/default/orangepi-zram-config" ]]; then
		sed -i 's/^ENABLED=.*/ENABLED=false/' "${SDCARD}/etc/default/orangepi-zram-config"
	else
		echo "ENABLED=false" > "${SDCARD}/etc/default/orangepi-zram-config"
	fi
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

post_family_tweaks__baseline_sysctl() {
	local conf="${SDCARD}/etc/sysctl.d/90-opi4pro.conf"
	mkdir -p "${SDCARD}/etc/sysctl.d"
	: > "${conf}"

	if [[ "${ENABLE_ZRAM}" == "yes" ]]; then
		cat >> "${conf}" << 'EOF'
# Swap is zram, so reading one page at a time beats read-ahead.
vm.page-cluster = 0
EOF
	fi

	if [[ ${BUILD_MINIMAL} != yes ]]; then
		# BBR and fq are built into the server and desktop kernels. The leading dash makes
		# systemd-sysctl ignore a failure, so a kernel without them still boots clean.
		cat >> "${conf}" << 'EOF'
-net.core.default_qdisc = fq
-net.ipv4.tcp_congestion_control = bbr
EOF
	fi

	[[ -s "${conf}" ]] || rm -f "${conf}"
}

# Pin access. Groups and udev rules go on every profile; they cost nothing and a
# user added later still needs them. The tools are for server and desktop.
post_family_tweaks__baseline_pin_access() {
	local group
	for group in gpio i2c spi; do
		chroot "${SDCARD}" /bin/bash -c "groupadd -f -r ${group}" \
			|| exit_with_error "Group was not created" "${group}"
		chroot "${SDCARD}" /bin/bash -c "usermod -aG ${group} ${OPI_USERNAME}" \
			|| exit_with_error "User was not added to group" "${OPI_USERNAME} ${group}"
	done

	mkdir -p "${SDCARD}/etc/udev/rules.d"
	cat > "${SDCARD}/etc/udev/rules.d/60-opi4pro-pins.rules" << 'EOF'
SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"
SUBSYSTEM=="i2c-dev", KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
SUBSYSTEM=="spidev", KERNEL=="spidev*", GROUP="spi", MODE="0660"
EOF
}

post_family_tweaks__baseline_pin_tools() {
	[[ ${BUILD_MINIMAL} == yes ]] && return 0

	# gpiod drives /dev/gpiochip*, i2c-tools drives /dev/i2c-*. Both must be there.
	run_on_sdcard "DEBIAN_FRONTEND=noninteractive apt-get -y -qq --no-install-recommends install gpiod i2c-tools" \
		|| exit_with_error "gpiod and i2c-tools failed to install"
	install_available_packages libgpiod-dev python3-libgpiod python3-smbus python3-spidev spi-tools

	baseline_install_wiringop
}

# Orange Pi's gpio command and wiringPi library. They number pins like the 40-pin header
# (gpio readall) and work on bare registers through /dev/mem, so they need root.
# The build is not allowed to take the image down: gpiod and the Python modules already give
# pin access, so a wiringOP that does not compile is skipped with a warning.
baseline_install_wiringop() {
	local source_dir="${EXTER}/cache/sources/wiringOP"
	local work_dir="${SDCARD}/tmp/wiringOP"
	local log="${DEST}/${LOG_SUBPATH}/install.log"
	# GCC 14 and later turn old C that earlier versions only warned about into errors.
	local relaxed="-Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types"
	local attempt flags built=no

	if [[ "$(git -C "${source_dir}" rev-parse HEAD 2>/dev/null)" != "${WIRINGOP_COMMIT}" ]]; then
		display_alert "wiringOP sources are not at the pinned commit, skipping it" "${source_dir}" "wrn"
		return 0
	fi

	# Left in the image on purpose: wiringPi programs are compiled on the board.
	run_on_sdcard "DEBIAN_FRONTEND=noninteractive apt-get -y -qq --no-install-recommends install gcc make libc6-dev libcrypt-dev" \
		|| exit_with_error "Compiler for wiringOP failed to install"

	for attempt in 1 2; do
		flags=""
		[[ ${attempt} -eq 2 ]] && flags="${relaxed}"
		rm -rf "${work_dir}"
		cp -a "${source_dir}" "${work_dir}"
		rm -rf "${work_dir}/.git"
		# WIRINGPI_SUID=0 keeps gpio from being installed setuid root.
		if chroot "${SDCARD}" /bin/bash -c "cd /tmp/wiringOP && EXTRA_CFLAGS='${flags}' WIRINGPI_SUDO='' WIRINGPI_SUID=0 bash -e ./build" >> "${log}" 2>&1; then
			built=yes
			break
		fi
		display_alert "wiringOP build failed" "attempt ${attempt} of 2" "wrn"
	done
	rm -rf "${work_dir}"

	if [[ ${built} == yes ]] \
		&& chroot "${SDCARD}" /bin/bash -c "test -x /usr/local/bin/gpio && ls /usr/local/lib/libwiringPi.so.* >/dev/null 2>&1"; then
		chroot "${SDCARD}" /bin/bash -c "ldconfig" || exit_with_error "ldconfig failed"
		display_alert "wiringOP installed" "gpio readall" "info"
	else
		display_alert "wiringOP is not in this image" "see ${log}" "wrn"
	fi
}

post_family_tweaks__baseline_system_tools() {
	[[ ${BUILD_MINIMAL} == yes ]] && return 0
	# nvme-cli and smartmontools read NVMe health. earlyoom ends the biggest process
	# before a full memory freezes the board.
	install_available_packages nvme-cli smartmontools earlyoom
}

fetch_sources_tools__baseline_wiringop() {
	[[ ${BUILD_OPT} == image && ${BUILD_MINIMAL} != yes ]] || return 0
	local dir="${EXTER}/cache/sources/wiringOP"
	local here="${PWD}"

	# fetch_from_repo does not move a checkout that sits on another commit.
	if [[ -d "${dir}/.git" && "$(git -C "${dir}" rev-parse HEAD 2>/dev/null)" != "${WIRINGOP_COMMIT}" ]]; then
		rm -rf "${dir}"
	fi
	fetch_from_repo "${WIRINGOP_URL}" "${dir}" "commit:${WIRINGOP_COMMIT}" "no"
	cd "${here}" || exit
}

