#!/bin/bash
#
# Apply image.conf after command line overrides.
# Profiles only fill settings the user left unset.

# shellcheck source=config/baseline.sh
source "${SRC}/config/baseline.sh"

apply_image_config() {
	[[ -z ${PROFILE+x} ]] && PROFILE="desktop"

	case "${PROFILE}" in
		minimal|server|desktop)
			;;
		*)
			display_alert "Unknown image profile" "${PROFILE:-<empty>}" "err"
			exit 1
			;;
	esac

	local profile_file="${SRC}/config/profiles/${PROFILE}.conf"
	if [[ ! -f "${profile_file}" ]]; then
		display_alert "Missing image profile" "${profile_file}" "err"
		exit 1
	fi

	# shellcheck source=/dev/null
	source "${profile_file}"

	BOARD="orangepi4pro"
	case "${BRANCH}" in
		current)
			local allowed_releases="bookworm jammy bullseye resolute trixie"
			;;
		legacy)
			local allowed_releases="bookworm jammy bullseye"
			;;
		*)
			display_alert "Unknown kernel branch" "${BRANCH:-<empty>}" "err"
			exit 1
			;;
	esac
	if [[ ! " ${allowed_releases} " == *" ${RELEASE} "* ]]; then
		display_alert "Release is not available for this kernel branch" "${RELEASE} / ${BRANCH}" "err"
		exit 1
	fi
	INSTALL_HEADERS="yes"
	[[ -z ${BUILD_OPT+x} ]] && BUILD_OPT="image"
	[[ -z ${KERNEL_CONFIGURE+x} ]] && KERNEL_CONFIGURE="no"

	[[ -n "${LOCALE}" ]] && DEST_LANG="${LOCALE}"
	[[ -n "${TIMEZONE}" ]] && TZDATA="${TIMEZONE}"
	[[ -n "${USERNAME}" ]] && OPI_USERNAME="${USERNAME}"
	[[ -n "${PASSWORD}" ]] && OPI_PWD="${PASSWORD}"
	[[ -n "${ROOT_PASSWORD}" ]] && ROOTPWD="${ROOT_PASSWORD}"
	[[ -n "${HOSTNAME}" ]] && HOST="${HOSTNAME}"

	if [[ "${BUILD_DESKTOP}" == "yes" ]]; then
		# Empty, but set, so the old app-group menu does not appear.
		DESKTOP_APPGROUPS_SELECTED=""
		case "${RELEASE}" in
			bookworm|trixie)
				PROFILE_PACKAGES="${PROFILE_PACKAGES} chromium"
				;;
			bullseye)
				PROFILE_PACKAGES="${PROFILE_PACKAGES} firefox-esr"
				;;
		esac
	fi

	local name
	for name in ${EXTENSIONS}; do
		enable_extension "${name}"
	done
	for name in ${APPS}; do
		enable_app "${name}"
	done

	display_alert "Image profile" "${PROFILE}" "info"
}

# configuration.sh rebuilds PACKAGE_LIST_ADDITIONAL from package files
# after this script runs. Put profile and extra packages back at user_config.
user_config__image_packages() {
	if [[ "${BUILD_DESKTOP}" == "yes" && -n "${DEST_LANG}" ]]; then
		local lang="${DEST_LANG%%.*}"
		local short="${lang%%_*}"
		case "${RELEASE}" in
			jammy|resolute)
				local pack=""
				case "${lang}" in
					zh_CN|zh_SG) pack="zh-hans" ;;
					zh_TW|zh_HK) pack="zh-hant" ;;
					en|en_*) pack="" ;;
					*) pack="${short}" ;;
				esac
				# English text is already in the packages. An unknown pack name would stop apt.
				case "${pack}" in
					fr|de|es|it|pt|ru|nl|pl|ja|ko|ar|cs|da|el|fi|hu|sv|tr|uk|zh-hans|zh-hant)
						PACKAGE_LIST_DESKTOP="${PACKAGE_LIST_DESKTOP} language-pack-${pack} language-pack-gnome-${pack}"
						;;
				esac
				;;
			bookworm|bullseye|trixie)
				local dict=""
				case "${lang}" in
					en_GB) dict="hunspell-en-gb" ;;
					en|en_*) dict="hunspell-en-us" ;;
					fr_*) dict="hunspell-fr" ;;
					de_*) dict="hunspell-de-de" ;;
					es_*) dict="hunspell-es" ;;
					it_*) dict="hunspell-it" ;;
					pt_BR) dict="hunspell-pt-br" ;;
					pt_*) dict="hunspell-pt-pt" ;;
					ru_*) dict="hunspell-ru" ;;
					nl_*) dict="hunspell-nl" ;;
					pl_*) dict="hunspell-pl" ;;
				esac
				[[ -n "${dict}" ]] && PACKAGE_LIST_DESKTOP="${PACKAGE_LIST_DESKTOP} ${dict}"
				;;
		esac
	fi
	if [[ -n "${PROFILE_PACKAGES}" ]]; then
		PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} ${PROFILE_PACKAGES}"
	fi
	if [[ -n "${EXTRA_PACKAGES}" ]]; then
		PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} ${EXTRA_PACKAGES}"
	fi
}
