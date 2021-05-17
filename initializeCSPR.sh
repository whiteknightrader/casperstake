#!/bin/sh

InstallerStatus_file=/etc/casperNodeInstaller

if ! [ -f "$InstallerStatus_file" ]
then

	sudo apt-get update

	sudo apt install dnsutils jq cmake libssl-dev pkg-config build-essential -y

	echo "deb https://repo.casperlabs.io/releases" bionic main | sudo tee -a /etc/apt/sources.list.d/casper.list
	curl -O https://repo.casperlabs.io/casper-repo-pubkey.asc
	sudo apt-key add casper-repo-pubkey.asc
	sudo apt update

	sudo apt install casper-client -y

	cd ~
	wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
	sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal main'   
	sudo apt update

	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh 
	source $HOME/.cargo/env

	BRANCH="1.0.20" \
		&& git clone --branch ${BRANCH} https://github.com/WebAssembly/wabt.git "wabt-${BRANCH}" \
		&& cd "wabt-${BRANCH}" \
		&& git submodule update --init \
		&& cd - \
		&& cmake -S "wabt-${BRANCH}" -B "wabt-${BRANCH}/build" \
		&& cmake --build "wabt-${BRANCH}/build" --parallel 8 \
		&& sudo cmake --install "wabt-${BRANCH}/build" --prefix /usr --strip -v \
		&& rm -rf "wabt-${BRANCH}"

	mkdir casperKeys && casper-client keygen ./casperKeys

	cd ~

	git clone git://github.com/CasperLabs/casper-node.git
	cd casper-node/
	git checkout release-1.0.0

	make setup-rs
	make build-client-contracts -j

	echo "1" > /etc/casperNodeInstaller
	InstallerStatus=$(sudo cat /etc/casperNodeInstaller)
	clear

	echo "Finished initialising....!"

fi
