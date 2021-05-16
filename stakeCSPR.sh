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

#==================================

# ----------------------------------
# Colors
# ----------------------------------
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'

YELLOW_BG='\033[43m'
LIGHT_GREY_BG='\033[47m'
GREEN_BG='\033[42m'

UNDERLINE='\033[4m'

echo ""
#check if the needed files for delgation are present in the expected location
public_key_hex_file=$HOME/casperKeys/public_key_hex
secret_key_pem_file=$HOME/casperKeys/secret_key.pem
delegate_wasm_file=$HOME/casper-node/target/wasm32-unknown-unknown/release/delegate.wasm

if ! [ -f "$public_key_hex_file" ]
then
    echo "${RED}Unable to find $public_key_hex_file..!${NC}"
	exit
elif ! [ -f "$secret_key_pem_file" ]
then
    echo "${RED}Unable to find $secret_key_pem_file..!${NC}"
	exit
elif ! [ -f "$delegate_wasm_file" ]
then
    echo "${RED}Unable to find $delegate_wasm_file..!${NC}"
	exit
fi

PUBLIC_KEY_HEX=$(sudo cat $HOME/casperKeys/public_key_hex)
echo "${UNDERLINE}Your wallet address is:${NC}"
echo ""
echo "${CYAN}$PUBLIC_KEY_HEX${NC}"
echo ""

while true
do
 echo ""
 echo "(Continue with the above address :- Type y and press Enter )"
 echo "(Upload your backed up keys :- Type n and press Enter )"
 read -r -p "Continue with this address ? [y/n] " input
 
 case $input in
     [yY][eE][sS]|[yY])
	echo ""
	echo "Continuing with the above wallet address.."
	echo "${RED}${LIGHT_GREY_BG}Back up your keys from the location $HOME/casperKeys/${NC}"
	echo "Save the keys to a secure place..!"
	echo ""
 break
 ;;
     [nN][oO]|[nN])
	echo ""
	echo "${YELLOW}REPLACE THE FILE NAMED public_key_hex IN THE LOCATION $HOME/casperKeys/${NC}"
	echo "${YELLOW}REPLACE THE FILE NAMED secret_key.pem IN THE LOCATION $HOME/casperKeys/${NC}"
	echo "And re run this program..!"
	exit
	
 break
        ;;
     *)
 echo "${RED}Type y or n and press Enter key.${NC}"
 ;;
 esac
done

echo ""
echo "Transfer enough fund, to the above address. Verify in casper block explorer"
echo "Delegation fees set to 3 CSPR, Hence balance should be more than 3 CSPR"
echo ""
echo "${UNDERLINE}${LIGHTBLUE}https://cspr.live/account/$PUBLIC_KEY_HEX${NC}"
echo ""
echo "Once transaction status is completed,"

read -r -p "Press Enter key to continue... " dummy1
echo ""
echo ""
#==========================

#Variable declarations
mots=1000000000
delegation_fee=3000000000


#Standard Calculations do not delete
delegation_fee_decimal=$(echo "scale=9; $delegation_fee/$mots" | bc)

STATE_ROOT_HASH=$(casper-client get-state-root-hash --node-address http://198.23.235.165:7777 | jq -r '.result | .state_root_hash')

PURSE_UREF=$(casper-client query-state --node-address http://198.23.235.165:7777 --key "$PUBLIC_KEY_HEX" --state-root-hash "$STATE_ROOT_HASH" | jq -r '.result | .stored_value | .Account | .main_purse')

BALANCE_ERROR=$(casper-client get-balance --node-address http://198.23.235.165:7777 --purse-uref "$PURSE_UREF" --state-root-hash "$STATE_ROOT_HASH" | jq -r '.result | .balance_value' 2>&1 1>$HOME/balance)

while [ ! -f $HOME/balance ]; do sleep 1; done

BALANCE=$(sudo cat $HOME/balance)
rm $HOME/balance

if [ -n "$BALANCE_ERROR" ]; then
      echo "${RED}INVALID / ZERO BALANCE in your account: $PUBLIC_KEY_HEX${NC}"
	  echo "Run this program again after transfer of CSPR and its confirmation in blockchain"
	  exit
fi

if [ -n "$BALANCE" ]; then	
	BALANCE_DECIMAL=$(echo "scale=9; $BALANCE/$mots" | bc)
fi

if [ $BALANCE -le $delegation_fee ]; then
	echo "your account address : $PUBLIC_KEY_HEX"
	echo "Your Current balance : $BALANCE_DECIMAL CSPR"
	echo "More than $delegation_fee_decimal CSPR needed"
	echo "(Since delgation binding fee is set at: $delegation_fee_decimal CSPR)"
	echo "${RED}Transfer more than 3 CSPR and run this program again${NC}"
	exit
fi


enterStake () {
while true
	do	
	echo " "
	echo ""
	echo "${YELLOW}your account address : $PUBLIC_KEY_HEX${NC}"
	echo " "
	echo "Your Current balance : $BALANCE_DECIMAL CSPR      (minus)"
	echo " "
	echo "Delgation binding fee: $delegation_fee_decimal CSPR"
	echo "                       -------------------"
	MAX_BALANCE_TO_DELEGATE=`expr $BALANCE - $delegation_fee`
	MAX_BALANCE_TO_DELEGATE_DECIMAL=$(echo "scale=9; $MAX_BALANCE_TO_DELEGATE/$mots" | bc)
	
	
	echo "Maximum you can stake: $MAX_BALANCE_TO_DELEGATE_DECIMAL CSPR"
	echo "                       -------------------"
	echo " "
	
	read -r -p "Enter your stake amount:" STAKE_ENTERED_IN_DECIMAL

	STAKE_ENTERED_IN_MOTS=$(echo "scale=9;$STAKE_ENTERED_IN_DECIMAL*$mots" |bc)
	STAKE_ENTERED_IN_MOTS_WHOLE=${STAKE_ENTERED_IN_MOTS%.*}
	
	STAKE_ENTERED_IN_RIGHT_DECIMAL=$(echo "scale=9; $STAKE_ENTERED_IN_MOTS_WHOLE/$mots" | bc)
	
	if [ $STAKE_ENTERED_IN_MOTS_WHOLE -gt 0 ] && [ $STAKE_ENTERED_IN_MOTS_WHOLE -le $MAX_BALANCE_TO_DELEGATE ]
	then
		echo "${GREEN}Entered Stake is: $STAKE_ENTERED_IN_RIGHT_DECIMAL CSPR${NC}"
		break
	elif [ $STAKE_ENTERED_IN_MOTS_WHOLE -gt 0 ] && [ $STAKE_ENTERED_IN_MOTS_WHOLE -gt $MAX_BALANCE_TO_DELEGATE ]
	then
		echo "Entered Stake........: $STAKE_ENTERED_IN_RIGHT_DECIMAL CSPR"
		echo "${RED}Maximum you can stake: $MAX_BALANCE_TO_DELEGATE_DECIMAL CSPR${NC}"
		echo "Try Again ...!"
	else
		echo "${RED}Invalid Stake amount entered. Retry${NC}"
	fi

	done
}

if [ $BALANCE -gt $delegation_fee ]; then
	
	while true
	do
	enterStake
	 read -r -p "Stake Amount Confirmed? Initiate Staking ? [y/n] " input
	 
	 case $input in
		 [yY][eE][sS]|[yY])
	 echo ""
	 echo ""
	 echo "Initiating Delagation Transaction ..!"
	 echo "-------------------------------------"
	 echo ""
	 echo "Your stake is being delegated to the validator node id: "
	 echo "${BLUE}01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019${NC}"
	 echo ""
	 
	 casper-client put-deploy --chain-name casper --node-address http://198.23.235.165:7777 -k $HOME/casperKeys/secret_key.pem --session-path "$HOME/casper-node/target/wasm32-unknown-unknown/release/delegate.wasm" --payment-amount $delegation_fee  --session-arg "validator:public_key='01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019'" --session-arg="amount:u512='${STAKE_ENTERED_IN_MOTS_WHOLE}'" --session-arg "delegator:public_key='${PUBLIC_KEY_HEX}'" 2>&1 1>$HOME/transOut
	 
	 while [ ! -f $HOME/transOut ]; do sleep 1; done
	 
	 cat $HOME/transOut
	 
	 hash=$(jq .result.deploy_hash transOut)
	 opt=$hash
	 temp="${opt%\"}"
	 DELEGATE_TRANSACTION_HASH="${temp#\"}"
	 
	 if [ -z "$DELEGATE_TRANSACTION_HASH" ]
		 then
			 echo ""
			 echo "${RED}ERROR RETRIEVING DELEGATION TRANSACTION HASH..!${NC}"
			 echo " "
			 exit
	 fi
	 
	 echo ""
	 echo "${GREEN}COMPLETED DELEGATION/STAKING TRANSATION ..!${NC}"
	 echo ""
	 echo "CHECK YOUR STAKING TRANSACTION STATUS AT:"
	 echo "${UNDERLINE}${LIGHTPURPLE}https://cspr.live/deploy/$DELEGATE_TRANSACTION_HASH${NC}"

         echo ""
	 echo "Delegation transaction output is stored in the file $HOME/transOut for your reference."

	 echo ""
	 echo "Validator page:"
	 echo "--------------"
	 echo "${UNDERLINE}${CYAN}https://cspr.live/validator/01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019${NC}"
	 echo ""
	 echo ""
	 break
	 ;;
		 [nN][oO]|[nN])
	 clear
	 echo "${RED}Re enter Stake: ${NC}"
			;;
		 *)
	 clear
	 echo "${RED}Type y or n and press Enter key.${NC}"
	 echo "Re enter Stake: "
	 ;;
	 esac
	done
	
	exit
fi
