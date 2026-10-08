kernel_config_set() {
	local mode="$1"
	local option="$2"
	[[ -f .config ]] || return 0
	if [[ -f ./scripts/config ]]; then
		./scripts/config --file .config "--${mode}" "${option}"
	fi
}

function custom_kernel_config__gamepads() {
	kernel_config_set enable CONFIG_INPUT_JOYSTICK
	kernel_config_set module CONFIG_JOYSTICK_XPAD
	kernel_config_set module CONFIG_UHID
	kernel_config_set enable CONFIG_INPUT_UINPUT
	kernel_config_set enable CONFIG_HIDRAW
	kernel_config_set enable CONFIG_HID_SONY
	kernel_config_set enable CONFIG_HID_NINTENDO
	kernel_config_set enable CONFIG_HID_STEAM
}

function extension_prepare_config__gamepads() {
	PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} joystick"
	if [[ "${BUILD_DESKTOP}" == "yes" ]]; then
		PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} jstest-gtk"
	fi
}

function post_kernel_build__xpadneo() {
	local src="${SRC}/.tmp/xpadneo"
	if [[ ! -d "${src}/.git" ]]; then
		display_alert "Fetching" "xpadneo" "info"
		rm -rf "${src}"
		git clone --depth 1 https://github.com/atar-axis/xpadneo.git "${src}"
	fi

	local cfile mdir
	cfile="$(find "${src}" -name 'hid-xpadneo.c' | head -1)"
	[[ -n "${cfile}" ]] || exit_with_error "xpadneo source has no hid-xpadneo.c"
	mdir="$(dirname "${cfile}")"
	if [[ ! -f "${mdir}/Makefile" ]] || ! grep -q 'obj-m' "${mdir}/Makefile"; then
		echo 'obj-m += hid-xpadneo.o' > "${mdir}/Makefile"
	fi

	display_alert "Compiling" "hid-xpadneo" "info"
	# compile_kernel leaves us in the tree that was just built. That tree is an overlay when overlayfs is on.
	local kerneldir
	if [[ -f Module.symvers ]]; then
		kerneldir="$(pwd)"
	elif [[ -f "${LINUXSOURCEDIR}/Module.symvers" ]]; then
		kerneldir="${LINUXSOURCEDIR}"
	else
		exit_with_error "Kernel tree is missing" "${LINUXSOURCEDIR}"
	fi
	eval env PATH="${toolchain}:${PATH}" \
		make -C "${kerneldir}" M="${mdir}" ARCH="${ARCHITECTURE}" CROSS_COMPILE="${CCACHE} ${KERNEL_COMPILER}" modules \
		|| exit_with_error "xpadneo module build failed"

	XPADNEO_KO="$(find "${mdir}" -name 'hid-xpadneo.ko' | head -1)"
	[[ -f "${XPADNEO_KO}" ]] || exit_with_error "hid-xpadneo.ko was not produced"
}

function post_install_kernel_debs__xpadneo() {
	[[ -f "${XPADNEO_KO}" ]] || post_kernel_build__xpadneo
	[[ -f "${XPADNEO_KO}" ]] || exit_with_error "xpadneo module was not built"
	local kver
	kver="$(find "${SDCARD}/lib/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -1)"
	[[ -n "${kver}" ]] || exit_with_error "Kernel modules directory is missing"
	mkdir -p "${SDCARD}/lib/modules/${kver}/updates"
	cp "${XPADNEO_KO}" "${SDCARD}/lib/modules/${kver}/updates/"
	chroot "${SDCARD}" /bin/bash -c "depmod -a ${kver}"
	mkdir -p "${SDCARD}/etc/modules-load.d"
	echo "hid-xpadneo" > "${SDCARD}/etc/modules-load.d/xpadneo.conf"
}

function post_family_tweaks__gamepad_udev() {
	mkdir -p "${SDCARD}/etc/udev/rules.d"
	cat > "${SDCARD}/etc/udev/rules.d/99-opi4pro-gamepads.rules" << 'EOF'
# Xbox (045e), Sony (054c), Nintendo (057e), DragonRise (0079), 8BitDo (0810), Logitech (046d)
SUBSYSTEM=="input", ATTRS{idVendor}=="045e", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
SUBSYSTEM=="input", ATTRS{idVendor}=="054c", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
SUBSYSTEM=="input", ATTRS{idVendor}=="057e", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
SUBSYSTEM=="input", ATTRS{idVendor}=="0079", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
SUBSYSTEM=="input", ATTRS{idVendor}=="0810", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
SUBSYSTEM=="input", ATTRS{idVendor}=="046d", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"
KERNEL=="js[0-9]*", MODE="0666"
EOF
}
