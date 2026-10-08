function extension_prepare_config__docker() {
	PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} docker.io"
}

function post_family_tweaks__docker_group() {
	if chroot "${SDCARD}" /bin/bash -c "getent group docker >/dev/null"; then
		chroot "${SDCARD}" /bin/bash -c "usermod -aG docker ${OPI_USERNAME}"
	fi
}
