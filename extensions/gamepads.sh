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
	local driver="${src}/hid-xpadneo/src"
	# Upstream no longer ships hid-xpadneo.c. The module makefile lives in hid-xpadneo/src.
	# A clone that predates that layout is replaced.
	if [[ ! -f "${driver}/Makefile" ]]; then
		display_alert "Fetching" "xpadneo" "info"
		rm -rf "${src}"
		git clone --depth 1 --branch master https://github.com/atar-axis/xpadneo.git "${src}" \
			|| exit_with_error "xpadneo clone failed"
	fi
	[[ -f "${driver}/Makefile" ]] || exit_with_error "xpadneo module makefile is missing" "${driver}"

	# compile_kernel leaves us in the tree that was just built. That tree is an overlay when overlayfs is on.
	local kerneldir
	if [[ -f Module.symvers ]]; then
		kerneldir="$(pwd)"
	elif [[ -f "${LINUXSOURCEDIR}/Module.symvers" ]]; then
		kerneldir="${LINUXSOURCEDIR}"
	else
		exit_with_error "Kernel tree is missing" "${LINUXSOURCEDIR}"
	fi

	local version
	version="$(git -C "${src}" describe --tags --always --dirty 2>/dev/null || echo v0.10)"

	# toolchain is local to compile_kernel. The install hook can call us after that function has returned.
	local tc="${toolchain:-}"
	if [[ -z "${tc}" ]]; then
		tc="$(find_toolchain "${KERNEL_COMPILER}" "${KERNEL_USE_GCC}")"
		[[ -n "${tc}" ]] || exit_with_error "Could not find required toolchain" "${KERNEL_COMPILER}gcc ${KERNEL_USE_GCC}"
	fi

	display_alert "Compiling" "hid-xpadneo ${version}" "info"
	eval env PATH="${tc}:${PATH}" \
		'make -C "$kerneldir" M="$driver" ARCH="$ARCHITECTURE" CROSS_COMPILE="$CCACHE $KERNEL_COMPILER" VERSION="$version" modules' \
		|| exit_with_error "xpadneo module build failed"

	XPADNEO_KO="${driver}/hid-xpadneo.ko"
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
