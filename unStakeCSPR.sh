#!/bin/sh

#Variable declarations
mots=1000000000
un_delegation_fee=1000000000


#Standard Calculations do not delete
un_delegation_fee_decimal=$(echo "scale=9; $un_delegation_fee/$mots" | bc)


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


echo "${UNDERLINE}UNDELEGATE / UN STAKE YOUR CSPR FROM THE VALIDATOR NODE:${NC}"
echo "${BLUE}01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019${NC}"
echo ""
echo "Node Validator URL:"
echo "${UNDERLINE}${YELLOW}https://cspr.live/validator/01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019${NC}"
echo "Verify your staked balance in the Validator's page Delegators tab"
echo ""
echo ""
echo ""

PUBLIC_KEY_HEX=$(sudo cat $HOME/casperKeys/public_key_hex)
echo "${UNDERLINE}Your wallet address is:${NC}"
echo ""
echo "${CYAN}$PUBLIC_KEY_HEX${NC}"

while true
do
 echo ""
 echo "(Continue with the above wallet address - type y and press Enter )"
 echo "(Upload your backed up keys - type n and press Enter )"
 read -r -p "Continue with this address ? [y/n] " input
 
 case $input in
     [yY][eE][sS]|[yY])
	echo ""
	echo "Continuing with the above wallet address.."
	echo "${RED}${LIGHT_GREY_BG}Verifying your staked amount...${NC}"
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

STATE_ROOT_HASH=$(casper-client get-state-root-hash --node-address http://198.23.235.165:7777 | jq -r '.result | .state_root_hash')

PURSE_UREF=$(casper-client query-state --node-address http://198.23.235.165:7777 --key "$PUBLIC_KEY_HEX" --state-root-hash "$STATE_ROOT_HASH" | jq -r '.result | .stored_value | .Account | .main_purse')

BALANCE_ERROR=$(casper-client get-balance --node-address http://198.23.235.165:7777 --purse-uref "$PURSE_UREF" --state-root-hash "$STATE_ROOT_HASH" | jq -r '.result | .balance_value' 2>&1 1>$HOME/balance)

BALANCE=$(sudo cat $HOME/balance)
rm $HOME/balance

if [ -n "$BALANCE_ERROR" ]; then
      echo "${RED}INVALID / ZERO BALANCE in your wallet: $PUBLIC_KEY_HEX${NC}"
	  echo "Run this program again after transfer of CSPR and its confirmation in blockchain"
	  echo "${RED}Minimum 1 CSPR needed in your wallet to undelegate${NC}"
	  exit
fi

if [ -n "$BALANCE" ]; then	
	BALANCE_DECIMAL=$(echo "scale=9; $BALANCE/$mots" | bc)
fi


if [ $BALANCE -le $un_delegation_fee ]; then
	echo "your wallet address : $PUBLIC_KEY_HEX"
	echo ""
	echo "Your wallet balance  : $BALANCE_DECIMAL CSPR"
	echo ""
	echo "More than $un_delegation_fee_decimal CSPR needed"
	echo "(Since un delgation binding fee is set at: $un_delegation_fee_decimal CSPR)"
	echo "${RED}Transfer more than 1 CSPR and run this program again${NC}"
	exit
fi


casper-client get-auction-info --node-address http://198.23.235.165:7777 | jq .result.auction_state.bids[] | jq 'select(.public_key == "01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019")' | jq .bid.delegators[] | jq 'select(.public_key == "'$PUBLIC_KEY_HEX'")' | jq .staked_amount 2>&1 1>$HOME/unStakeBalance

NODE_STAKED_BALANCE=$(sudo cat $HOME/unStakeBalance)
rm $HOME/unStakeBalance


if [ -z "$NODE_STAKED_BALANCE" ]
then
	  echo "your wallet address : $PUBLIC_KEY_HEX"
	  echo ""
      echo "${RED}ERROR RETRIEVING STAKED BALANCE FROM THE VALIDATOR NODE ID 01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019${NC}"
	  echo ""
	  echo "Kindly check the node validator link, if your wallet address is listed under Delegators and Node status"
	  echo "${UNDERLINE}${CYAN}https://cspr.live/validator/01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019${NC}"
	  echo ""
	  exit
fi

opt=$NODE_STAKED_BALANCE
temp="${opt%\"}"
NODE_STAKED_BALANCE_FORMATED="${temp#\"}"

NODE_STAKED_BALANCE_DECIMAL=$(echo "scale=9; $NODE_STAKED_BALANCE_FORMATED/$mots" | bc)



enterUnStake () {
while true
	do	
	echo ""
	echo ""
	echo "${YELLOW}your wallet address   : $PUBLIC_KEY_HEX${NC}"
	echo ""
	echo "Your wallet balance            : $BALANCE_DECIMAL CSPR"
	echo " "
	echo "Node UNstaking deligation fee  : $un_delegation_fee_decimal CSPR"
	echo ""
	echo "Maximum you can UNstake        : $NODE_STAKED_BALANCE_DECIMAL CSPR"
	echo ""
	
	read -r -p "Enter your UNstake amount:" UN_STAKE_ENTERED_IN_DECIMAL

	UN_STAKE_ENTERED_IN_MOTS=$(echo "scale=9;$UN_STAKE_ENTERED_IN_DECIMAL*$mots" |bc)
	UN_STAKE_ENTERED_IN_MOTS_WHOLE=${UN_STAKE_ENTERED_IN_MOTS%.*}
	
	
	UN_STAKE_ENTERED_IN_RIGHT_DECIMAL=$(echo "scale=9; $UN_STAKE_ENTERED_IN_MOTS_WHOLE/$mots" | bc)
	
	if [ $UN_STAKE_ENTERED_IN_MOTS_WHOLE -gt 0 ] && [ $UN_STAKE_ENTERED_IN_MOTS_WHOLE -le $NODE_STAKED_BALANCE_FORMATED ]
	then
		echo "${GREEN}Entered UN Stake amount is: $UN_STAKE_ENTERED_IN_RIGHT_DECIMAL CSPR${NC}"
		break
	elif [ $UN_STAKE_ENTERED_IN_MOTS_WHOLE -gt 0 ] && [ $UN_STAKE_ENTERED_IN_MOTS_WHOLE -gt $NODE_STAKED_BALANCE_FORMATED ]
	then
		echo "Entered UN Stake amount       : $UN_STAKE_ENTERED_IN_RIGHT_DECIMAL CSPR"
		echo "${RED}Maximum you can UN Stake: $NODE_STAKED_BALANCE_DECIMAL CSPR${NC}"
		echo "Try Again ...!"
	else
		echo "${RED}Invalid Stake amount entered. Retry${NC}"
	fi

	done
}

while true
	do
	enterUnStake
	 read -r -p "UNstake Amount Confirmed? Initiate Staking ? [y/n] " input
	 
	 case $input in
		 [yY][eE][sS]|[yY])
	 echo ""
	 echo ""
	 echo ""
	 echo "Initiating UNdelagation Transaction ..!"
	 echo "---------------------------------------"
	 echo ""
	 echo "Your stake is being UNdelegated from the validator node id: "
	 echo "${BLUE}01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019${NC}"
	 echo ""
	 
	 casper-client put-deploy --chain-name casper --node-address http://198.23.235.165:7777 -k $HOME/casperKeys/secret_key.pem --session-path "$HOME/casper-node/target/wasm32-unknown-unknown/release/undelegate.wasm" --payment-amount $un_delegation_fee  --session-arg "validator:public_key='01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019'" --session-arg="amount:u512='${UN_STAKE_ENTERED_IN_MOTS_WHOLE}'" --session-arg "delegator:public_key='${PUBLIC_KEY_HEX}'" 2>&1 1>$HOME/unStakeOut
	 
	 cat unStakeOut

	 hash=$(jq .result.deploy_hash unStakeOut)
	 opt=$hash
	 temp="${opt%\"}"
	 UN_DELEGATE_TRANSACTION_HASH="${temp#\"}"
	 
	 if [ -z "$UN_DELEGATE_TRANSACTION_HASH" ]
		then
		  echo ""
		  echo "${RED}ERROR RETRIEVING UNDELEGATION TRANSACTION HASH..!${NC}"
		  echo " "
		  exit
	  fi
	 
	 echo "" 
	 echo "${GREEN}COMPLETED UNDELEGATION/UNSTAKING TRANSATION ..!${NC}"
	 echo "" 
	 echo "${GREEN}Wait period for undelegation is presently set to 15 eras. Balance will appear in your account after this wait period !${NC}"
	 echo ""
	 echo "CHECK YOUR UNSTAKING TRANSACTION STATUS AT:"
	 echo "${UNDERLINE}${LIGHTPURPLE}https://cspr.live/deploy/$UN_DELEGATE_TRANSACTION_HASH${NC}"

	 echo "Undelegation transation output is stored in the file $HOME/unStakeOut for your reference."

	 echo ""
	 echo "Validator page:"
	 echo "${UNDERLINE}${CYAN}https://cspr.live/validator/01090f4e3a28cc04ae751434bc8b9b3d8fb9741b0d6a2d29b23ab719edac5d3019${NC}"
	 echo ""
	 echo ""
	 break
	 ;;
		 [nN][oO]|[nN])
	 clear
	 echo "${RED}Re enter UNstake amount: ${NC}"
			;;
		 *)
	 clear
	 echo "Re enter UNstake amount"
	 echo "${RED}Type y or n and press Enter key.${NC}"
	 echo "Re enter Stake: "
	 ;;
	 esac
done
