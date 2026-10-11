function extension_prepare_config__retroarch() {
	PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} retroarch retroarch-assets"
}

function post_family_tweaks__retroarch() {
	local home="/home/${OPI_USERNAME}"
	local root="${SDCARD}${home}"
	local assets="/usr/share/libretro/assets"
	local autoconfig="/usr/share/libretro/autoconfig"
	local lang="0"

	case "${DEST_LANG%%.*}" in
		fr_*) lang="2" ;;
		ja_*) lang="1" ;;
		es_*) lang="3" ;;
		de_*) lang="4" ;;
		it_*) lang="5" ;;
		nl_*) lang="6" ;;
		pt_BR) lang="7" ;;
		pt_*) lang="8" ;;
		ru_*) lang="9" ;;
		ko_*) lang="10" ;;
		zh_TW|zh_HK) lang="11" ;;
		zh_*) lang="12" ;;
		pl_*) lang="14" ;;
		ar_*) lang="16" ;;
		el_*) lang="17" ;;
		tr_*) lang="18" ;;
	esac

	mkdir -p \
		"${root}/roms/snes" "${root}/roms/nes" "${root}/roms/megadrive" \
		"${root}/roms/gb" "${root}/roms/gba" "${root}/roms/arcade" \
		"${root}/bios" "${root}/saves" "${root}/states" \
		"${root}/.config/retroarch"

	# XMB is the PlayStation menu. Theme 8 is the dark one. Theme 9 is light.
	# The font is the asset font, which has accents.
	# Pad buttons come from the udev profiles, so they are not hardcoded here.
	cat > "${root}/.config/retroarch/retroarch.cfg" << EOF
video_fullscreen = "true"
video_windowed_fullscreen = "false"
video_vsync = "true"
video_smooth = "false"
video_font_enable = "true"
audio_driver = "alsa"
menu_driver = "xmb"
xmb_theme = "0"
xmb_menu_color_theme = "8"
xmb_font = "${assets}/ozone/regular.ttf"
assets_directory = "${assets}"
joypad_autoconfig_dir = "${autoconfig}"
input_joypad_driver = "udev"
input_autodetect_enable = "true"
input_remap_binds_enable = "true"
all_users_control_menu = "true"
input_player1_joypad_index = "0"
input_exit_emulator = "escape"
input_save_state = "f2"
input_load_state = "f4"
user_language = "${lang}"
savefile_directory = "${home}/saves"
savestate_directory = "${home}/states"
system_directory = "${home}/bios"
rgui_browser_directory = "${home}/roms"
core_updater_enabled = "false"
config_save_on_exit = "true"
quit_press_twice = "true"
EOF

	# Ubuntu does not ship retroarch-joypad-autoconfig. Debian does, under this same path.
	local profiles="${SRC}/.tmp/retroarch-joypad-autoconfig"
	if [[ ! -d "${profiles}/udev" ]]; then
		display_alert "Fetching" "controller profiles" "info"
		rm -rf "${profiles}"
		git clone --depth 1 https://github.com/libretro/retroarch-joypad-autoconfig.git "${profiles}" \
			|| exit_with_error "Controller profiles failed to download"
	fi
	mkdir -p "${SDCARD}${autoconfig}"
	rm -rf "${SDCARD}${autoconfig}/udev"
	cp -a "${profiles}/udev" "${SDCARD}${autoconfig}/"

	if [[ "${BUILD_DESKTOP}" == "yes" ]]; then
		mkdir -p "${SDCARD}/usr/share/xsessions" "${SDCARD}/usr/local/bin"
		cat > "${SDCARD}/usr/local/bin/retroarch-session" << EOF
#!/bin/sh
export HOME="${home}"
cd "\${HOME}" || exit 1
# Stay in the game menu. Quitting must not open the desktop.
while true; do
	retroarch --fullscreen
	sleep 1
done
EOF
		chmod 755 "${SDCARD}/usr/local/bin/retroarch-session"

		cat > "${SDCARD}/usr/share/xsessions/retroarch.desktop" << 'EOF'
[Desktop Entry]
Name=RetroArch
Comment=Games
Exec=/usr/local/bin/retroarch-session
TryExec=retroarch
Type=Application
DesktopNames=RetroArch
EOF

		if [[ -f "${SDCARD}/etc/lightdm/lightdm.conf.d/22-orangepi-autologin.conf" ]]; then
			sed -i 's/^user-session=.*/user-session=retroarch/' \
				"${SDCARD}/etc/lightdm/lightdm.conf.d/22-orangepi-autologin.conf"
		fi
	fi

	local core
	for core in libretro-snes9x libretro-nestopia libretro-genesisplusgx libretro-mgba libretro-fbneo; do
		chroot "${SDCARD}" /bin/bash -c \
			"DEBIAN_FRONTEND=noninteractive apt-get -y -qq install ${core} >/dev/null 2>&1" \
			|| display_alert "Libretro core not in this release" "${core}" "wrn"
	done

	chroot "${SDCARD}" /bin/bash -c "chown -R ${OPI_USERNAME}:${OPI_USERNAME} ${home}"
}
