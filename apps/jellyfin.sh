function post_family_tweaks__jellyfin() {
	local suite repo
	case "${RELEASE}" in
		bookworm|bullseye|trixie)
			suite="${RELEASE}"
			repo="https://repo.jellyfin.org/debian"
			;;
		*)
			suite="${RELEASE}"
			repo="https://repo.jellyfin.org/ubuntu"
			;;
	esac

	chroot "${SDCARD}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y -qq install ca-certificates curl gnupg >/dev/null"
	mkdir -p "${SDCARD}/etc/apt/keyrings"
	curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key \
		| chroot "${SDCARD}" /bin/bash -c "gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg"
	chmod 644 "${SDCARD}/etc/apt/keyrings/jellyfin.gpg"
	cat > "${SDCARD}/etc/apt/sources.list.d/jellyfin.sources" << EOF
Types: deb
URIs: ${repo}
Suites: ${suite}
Components: main
Architectures: arm64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF

	chroot "${SDCARD}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get -y -qq install jellyfin" \
		|| exit_with_error "Jellyfin install failed" "${RELEASE}"
	chroot "${SDCARD}" /bin/bash -c "systemctl --no-reload enable jellyfin.service >/dev/null 2>&1"

	mkdir -p "${SDCARD}/srv/media/videos" "${SDCARD}/srv/media/music"
	chroot "${SDCARD}" /bin/bash -c "chown -R jellyfin:jellyfin /srv/media && chmod -R 775 /srv/media && usermod -aG jellyfin ${OPI_USERNAME}"
}
