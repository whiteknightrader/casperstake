#!/bin/sh

#Variable declarations
mots=1000000000
transaction_fee=10000
min_allowed_transfer=2500000000

#Standard Calculations do not delete
transaction_fee_decimal=$(echo "scale=9; $transaction_fee/$mots" | bc)
min_allowed_transfer_decimal=$(echo "scale=9; $min_allowed_transfer/$mots" | bc)

min_reqd_balnce_with_fee=`expr $min_allowed_transfer + $transaction_fee`
min_reqd_balnce_with_fee_decimal=$(echo "scale=9; $min_reqd_balnce_with_fee/$mots" | bc)

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

if ! [ -f "$public_key_hex_file" ]
then
    echo "${RED}Unable to find $public_key_hex_file..!${NC}"
	exit
elif ! [ -f "$secret_key_pem_file" ]
then
    echo "${RED}Unable to find $secret_key_pem_file..!${NC}"
	exit
fi


PUBLIC_KEY_HEX=$(sudo cat $HOME/casperKeys/public_key_hex)
echo "${UNDERLINE}Your wallet address is:${NC}"
echo ""
echo "${CYAN}$PUBLIC_KEY_HEX${NC}"


STATE_ROOT_HASH=$(casper-client get-state-root-hash --node-address http://198.23.235.165:7777 | jq -r '.result | .state_root_hash')

PURSE_UREF=$(casper-client query-state --node-address http://198.23.235.165:7777 --key "$PUBLIC_KEY_HEX" --state-root-hash "$STATE_ROOT_HASH" | jq -r '.result | .stored_value | .Account | .main_purse')

BALANCE_ERROR=$(casper-client get-balance --node-address http://198.23.235.165:7777 --purse-uref "$PURSE_UREF" --state-root-hash "$STATE_ROOT_HASH" | jq -r '.result | .balance_value' 2>&1 1>$HOME/balance)

BALANCE=$(sudo cat $HOME/balance)
rm $HOME/balance

if [ -n "$BALANCE_ERROR" ]; then
      echo "${RED}INVALID / ZERO BALANCE in your wallet: $PUBLIC_KEY_HEX${NC}"
	  echo ""
	  exit
fi

if [ -n "$BALANCE" ]; then	
	BALANCE_DECIMAL=$(echo "scale=9; $BALANCE/$mots" | bc)
fi

echo ""
echo "Wallet Balance: $BALANCE_DECIMAL CSPR"
echo ""

if [ $BALANCE -le $min_reqd_balnce_with_fee ]; then
	echo "Minimum CSPR which can be transferred: $min_allowed_transfer_decimal CSPR"
	echo "Transaction fee for transfer: $transaction_fee_decimal CSPR"
	echo ""
	echo "Total Minimum required CSPR to initate transfer: $min_reqd_balnce_with_fee_decimal CSPR"
	echo ""
	echo "${RED}Transfer more than above and run this program again${NC}"
	echo ""
	exit
fi

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


while true
do
 echo ""
 echo "Cross verify the correctness of TO ADDRESS as once transaction initiated to wrong address, fund cant be recovered.!"
 echo ""
 echo "${YELLOW}Enter the ACCOUNT TO TRANSFER your CSPR${NC}"
 read -r -p "" ACCOUNT_TO_TRANSFER
 echo ""
 
 echo "You have entered the address:"
 echo "${GREEN}$ACCOUNT_TO_TRANSFER${NC}"
 echo ""
 
 read -r -p "Have you verified this address and satisfied as correct? [y/n] " input
 
 case $input in
     [yY][eE][sS]|[yY])
	echo ""
 break
 ;;
     [nN][oO]|[nN])
	echo ""
	echo "${RED}Kindly re-enter the correct address to which CSPR has to be transferred ${NC}"
        ;;
     *)
 echo "${RED}Type y or n and press Enter key.${NC}"
 ;;
 esac
done



balanceTrans () {
while true
	do	
	echo " "
	echo ""
	echo "${YELLOW}your account address : $PUBLIC_KEY_HEX${NC}"
	echo " "
	echo "Your Current balance   : $BALANCE_DECIMAL CSPR      (minus)"
	echo " "
	echo "Transaction fee        : $transaction_fee_decimal CSPR"
	echo "                       -------------------"
	MAX_BALANCE_TO_TRANSFER=`expr $BALANCE - $transaction_fee`
	MAX_BALANCE_TO_TRANSFER_DECIMAL=$(echo "scale=9; $MAX_BALANCE_TO_TRANSFER/$mots" | bc)
	
	
	echo "Maximum you can transfer: $MAX_BALANCE_TO_TRANSFER_DECIMAL CSPR"
	echo "                        -------------------"
	echo " "
	echo "(Enter value greater than $min_allowed_transfer_decimal CSPR)"
	echo ""
	read -r -p "Enter your transfer amount:" TRANSFER_ENTERED_IN_DECIMAL

	TRANSFER_ENTERED_IN_MOTS=$(echo "scale=9;$TRANSFER_ENTERED_IN_DECIMAL*$mots" |bc)
	TRANSFER_ENTERED_IN_MOTS_WHOLE=${TRANSFER_ENTERED_IN_MOTS%.*}
	
	TRANSFER_ENTERED_IN_RIGHT_DECIMAL=$(echo "scale=9; $TRANSFER_ENTERED_IN_MOTS_WHOLE/$mots" | bc)
	
	
	if [ $TRANSFER_ENTERED_IN_MOTS_WHOLE -ge $min_allowed_transfer ] && [ $TRANSFER_ENTERED_IN_MOTS_WHOLE -le $MAX_BALANCE_TO_TRANSFER ] 
	then
		echo "${GREEN}Entered amount to transfer is: $TRANSFER_ENTERED_IN_RIGHT_DECIMAL CSPR${NC}"
		break
	elif [ $TRANSFER_ENTERED_IN_MOTS_WHOLE -lt $min_allowed_transfer ] && [ $TRANSFER_ENTERED_IN_MOTS_WHOLE -le $MAX_BALANCE_TO_TRANSFER ]
	then
		echo "Entered amount to transfer    : $TRANSFER_ENTERED_IN_RIGHT_DECIMAL CSPR"
		echo "${RED}Minimum you have to transfer: $min_allowed_transfer_decimal CSPR${NC}"
		echo "Initiate transfer more than that value ...!"
		echo ""
	elif [ $TRANSFER_ENTERED_IN_MOTS_WHOLE -ge $min_allowed_transfer ] && [ $TRANSFER_ENTERED_IN_MOTS_WHOLE -gt $MAX_BALANCE_TO_TRANSFER ]
	then
		echo "Entered amount to transfer    : $TRANSFER_ENTERED_IN_RIGHT_DECIMAL CSPR"
		echo "${RED}Maximum you can transfer: $MAX_BALANCE_TO_TRANSFER_DECIMAL CSPR${NC}"
		echo "Try Again ...!"
	else
		echo "${RED}Invalid transfer amount entered. Retry${NC}"
	fi

	done
}


while true
	do
	balanceTrans
	 read -r -p "Amount to transfer Confirmed? Initiate Transfer ? [y/n] " input
	 
	 case $input in
		 [yY][eE][sS]|[yY])
	 echo ""
	 echo ""
	 echo "Initiating transfer of CSPR ..!"
	 echo "-------------------------------"
	 echo ""
	 echo "From Account  : $PUBLIC_KEY_HEX"
	 echo ""
	 echo "To Account    : $ACCOUNT_TO_TRANSFER"
	 echo ""
	 echo "Transfer Value: $TRANSFER_ENTERED_IN_RIGHT_DECIMAL"
	 echo ""

	 casper-client transfer --node-address http://198.23.235.165:7777 --amount $TRANSFER_ENTERED_IN_MOTS_WHOLE --secret-key $HOME/casperKeys/secret_key.pem --chain-name casper --payment-amount $transaction_fee --target-account $ACCOUNT_TO_TRANSFER 2>&1 1>$HOME/fundTrans
	 
	 cat $HOME/transOut
	 
	 hash=$(jq .result.deploy_hash fundTrans)
	 opt=$hash
	 temp="${opt%\"}"
	 TRANSFER_TRANSACTION_HASH="${temp#\"}"
	 
	 if [ -z "$TRANSFER_TRANSACTION_HASH" ]
		 then
			 echo ""
			 echo "${RED}ERROR RETRIEVING TRANSACTION HASH..!${NC}"
			 echo " "
			 exit
	 fi
	 
	 echo ""
	 echo "${GREEN}COMPLETED TRANSFER ..!${NC}"
	 echo ""
	 echo "CHECK YOUR TRANSACTION STATUS AT:"
	 echo "${UNDERLINE}${LIGHTPURPLE}https://cspr.live/deploy/$TRANSFER_TRANSACTION_HASH${NC}"

     echo ""
	 echo "Transaction output is stored in the file $HOME/fundTrans for your reference."

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
