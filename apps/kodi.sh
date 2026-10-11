function extension_prepare_config__kodi() {
	PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL} kodi"
}

function post_family_tweaks__kodi() {
	local home="/home/${OPI_USERNAME}"
	local data="${SDCARD}${home}/.kodi/userdata"
	mkdir -p "${data}" "${SDCARD}${home}/Videos" "${SDCARD}${home}/Music"

	cat > "${data}/advancedsettings.xml" << 'EOF'
<advancedsettings>
  <services>
    <esallinterfaces>true</esallinterfaces>
    <webserver>true</webserver>
    <webserverport>8080</webserverport>
    <webserverauthentication>false</webserverauthentication>
  </services>
  <cache>
    <memorysize>52428800</memorysize>
    <buffermode>1</buffermode>
    <readfactor>4.0</readfactor>
  </cache>
  <audiooutput>
    <audiodevice>PULSE:Default</audiodevice>
  </audiooutput>
</advancedsettings>
EOF

	cat > "${data}/sources.xml" << EOF
<sources>
  <video>
    <default pathversion="1"></default>
    <source>
      <name>Videos</name>
      <path pathversion="1">${home}/Videos/</path>
      <allowsharing>true</allowsharing>
    </source>
  </video>
  <music>
    <default pathversion="1"></default>
    <source>
      <name>Music</name>
      <path pathversion="1">${home}/Music/</path>
      <allowsharing>true</allowsharing>
    </source>
  </music>
</sources>
EOF

	chroot "${SDCARD}" /bin/bash -c "chown -R ${OPI_USERNAME}:${OPI_USERNAME} ${home}"
}
