function extension_prepare_config__retroarch() {
	PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} retroarch"
}

function post_family_tweaks__retroarch() {
	local home="/home/${OPI_USERNAME}"
	local root="${SDCARD}${home}"
	local system roms
	mkdir -p \
		"${root}/roms/snes" "${root}/roms/nes" "${root}/roms/megadrive" \
		"${root}/roms/gb" "${root}/roms/gba" "${root}/roms/arcade" \
		"${root}/bios" "${root}/saves" "${root}/states" \
		"${root}/.config/retroarch"

	system="${home}/bios"
	roms="${home}/roms"
	cat > "${root}/.config/retroarch/retroarch.cfg" << EOF
video_fullscreen = "true"
video_vsync = "true"
audio_driver = "pulse"
menu_driver = "ozone"
input_joypad_driver = "udev"
input_autodetect_enable = "true"
input_enable_hotkey_btn = "8"
input_exit_emulator_btn = "9"
input_save_state_btn = "4"
input_load_state_btn = "5"
input_exit_emulator = "escape"
input_save_state = "f2"
input_load_state = "f4"
savefile_directory = "${home}/saves"
savestate_directory = "${home}/states"
system_directory = "${system}"
rgui_browser_directory = "${roms}"
EOF

	if [[ "${BUILD_DESKTOP}" == "yes" ]]; then
		mkdir -p "${SDCARD}/usr/share/applications"
		cat > "${SDCARD}/usr/share/applications/retroarch.desktop" << 'EOF'
[Desktop Entry]
Name=RetroArch
Comment=Play games from ~/roms
Exec=retroarch
Icon=retroarch
Terminal=false
Type=Application
Categories=Game;
EOF
	fi

	local core
	for core in libretro-snes9x libretro-nestopia libretro-genesisplusgx libretro-mgba libretro-fbneo; do
		chroot "${SDCARD}" /bin/bash -c \
			"DEBIAN_FRONTEND=noninteractive apt-get -y -qq install ${core} >/dev/null 2>&1" \
			|| display_alert "Libretro core not in this release" "${core}" "wrn"
	done

	chroot "${SDCARD}" /bin/bash -c "chown -R ${OPI_USERNAME}:${OPI_USERNAME} ${home}"
}
