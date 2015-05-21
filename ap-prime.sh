#!/bin/bash
#
# The purpose of this script is to automate Cisco Access Point priming
# The script identifies the list of AP's, as well
# and then pushes the changes to the controllers one by one.
#

# # # # DECLARE VARIABLES AND FILE PATHS  # # # #
# # # # # # # # # # # # # # # # # #

CONFIGLOG="$HOME/Documents/wireless-scripts/logs/configlog-`date +%m-%d-%Y`.log"
CONTROLLERLIST="$HOME/Documents/wireless-scripts/controller-list.txt"

SNMPOPTIONS="-v3 -a SHA -A SUP3R-S3CR3T! -l authNoPriv -u neteng -Ob"

APARRAY=()

# Set prompt in menu with PS3 variable:
PS3="Select a controller: "


# # # # DECLARE FUNCTIONS # # # #
# # # # # # # # # # # # # # # # #


# # # # READ IN NEW UN-PRIMED APS AND STORE THEM IN AN ARRAY # # # #
READAPS() {

	printf "\n\n====[ Finding Un-configured APs... ]====\n\n"
	
	for CONTROLLERS in `cat $CONTROLLERLIST`; do
		printf "\n\nLooking in $CONTROLLERS for Un-Configured APs.\n"
		
		APARRAY+=( $(snmpwalk $SNMPOPTIONS $CONTROLLERS \
			bsnAPName | egrep '\"AP[[:alnum:]]{1,4}\.' | cut -d\" -f2) )
	
		printf "\n\nFound ${#APARRAY[*]} AP's so far.\n"
		printf "Done with $CONTROLLERS.\n"
	
		done
	
	printf "Found the following ${#APARRAY[*]} unconfigured APs:\n"
	
	for APS in ${APARRAY[*]}; do
		printf "   %s\n" $APS
		done
	
	printf "\n\n\nWaiting 3 seconds, then moving on...\n"
	for i in {3..1};do printf "$i, " && sleep 1; done

}



# # # # MANIPULATE MACADDRESS TO PROPER FORMAT # # # #
MANIPULATE(){

	# CONVERT UPPER TO LOWER CASE
	MACADDRESS="${MACUPPER,,}"
	# printf $MACADDRESS\n
	
	# CONVERT $MACADDRESS TO TEMP AP NAME
	TEMPNAME="AP${MACADDRESS:0:4}.${MACADDRESS:4:4}.${MACADDRESS:8:4}"
	# printf $TEMPNAME\n

}


# # # # CHECK WHICH CONTROLLER AP IS REGISTERED TO # # # #
#       AND READ IN $RADIOMAC AND $REGCONTROLLER         #
FINDAP(){

clear
printf "------------------------------------"
printf "\n\n====[ Finding AP on Controllers... ]====\n\n"

for CONTROLLERS in `cat $CONTROLLERLIST`; do
	SEARCH=$(snmpwalk $SNMPOPTIONS $CONTROLLERS \
		bsnAPName | grep $TEMPNAME)
	
if [[ $SEARCH = *$TEMPNAME* ]]
	then
		printf "!!!! $TEMPNAME FOUND on Controller $CONTROLLERS !!!!\n"
		REGCONTROLLER=$CONTROLLERS
		RADIOMAC=$(sed -n 's/.*bsnAPName.\(.*\)=.*/\1/p' <<< "$SEARCH")
		break
	else
		printf "$TEMPNAME not found on Controller $CONTROLLERS\n"
fi

done

printf "\n"

# printf $RADIOMAC\n
# printf $REGCONTROLLER\n

}

# # # # CREATE AP NAME FROM INPUT # # # #
MAKENAME(){
	NAME="$SITE$MODEL-$CLOSET-$NUMBER"
}

# # # # VERIFY CHANGES # # # #
VERIFY(){

	# clear
	prtinf "\n\n====[ Current AP Information ]====\n"
	# echo "AP MAC Address: $MACADDRESS"
	printf "Current AP Name: $TEMPNAME\n"
	printf "Registered to Controller: $REGCONTROLLER\n"
	printf "AP SNMP Identifier: $RADIOMAC\n\n"

	printf "====[ Configuraiton Changes ]====\n"
	printf "New AP Name: $NAME\n"
	printf "AP Location: $LOCATION\n"
	printf "Primary Controller: $CONTROLLER1\n"
	printf "Secondary Controller: $CONTROLLER2\n"
	printf "AP Group: $APGROUP\n"
	
	printf "\n\nPress Cntl-Z to quit in the next 5 seconds if this is not correct!\n"
	for i in {5..1};do printf "$i, " && sleep 1; done

}

# # # # IMPLEMENT AND LOG CHANGES # # # #
IMPLEMENT(){

	printf "\n\n===[ $NAME ]===\n\n" | tee -a $CONFIGLOG

	OUTPUT=`snmpset $SNMPOPTIONS $REGCONTROLLER \
		bsnAPName.$RADIOMAC s $NAME \
		bsnAPLocation.$RADIOMAC s "$LOCATION" \
		bsnAPPrimaryMwarName.$RADIOMAC s $CONTROLLER1 \
		bsnAPSecondaryMwarName.$RADIOMAC s $CONTROLLER2 \
		bsnAPGroupVlanName.$RADIOMAC s $APGROUP`
	printf "$OUTPUT\n" | tee -a $CONFIGLOG
	
	printf "\n\nAP $NAME Configured successfully!\n"
	printf "Moving on to next AP in 3 seconds...\n"
	
	for i in {3..1};do printf "$i, " && sleep 1; done

}

# # # # CLEAR SCREEN AND BEGIN SCRIPT # # # #
# # # # # # # # # # # # # # # # # # # # # # # 

clear
printf "=====[ AP Priming Script ]=====\n"
printf "\n\n\nThis script is meant to be used to deploy many Access Points\n"
printf "to one IDF/Closet at a time.\n\n"
printf "Therefore, you can configure consecutive AP's in a single\n"
printf "closet, but then must exit and restart the script to\n"
printf "start a new closet.\n"



# # # # GATHER AP INFORMATION # # # #

printf "\n\nPlease enter the three letter SITE CODE as you would like it to appear in the AP Name:\n> "
read SITE
# SITE="AMH"

## SINCE WE ONLY HAVE 2600'S, COMMENTING OUT THIS SECTION AND MANUALLY ASSIGNING VARABLE ##
# printf "\n\nPlease enter the Model of these APs as you would like it to appear in the AP Name:\n> "
# read MODEL
MODEL="2600"

printf "\n\nPlease enter the Closet/IDF Name as you would like it to appear in the AP Name:\n> "
read CLOSET
# CLOSET="H3B"

printf "\n\nPlease enter the information you would like in the Location field of these APs:\n> "
read LOCATION
# LOCATION="3rd Floor IDF31"

printf "\n\nPlease select the number of the Primary Controller for these AP's:\n"
select CONTROLLER1 in `cat $CONTROLLERLIST`
do
	printf "You have selected $CONTROLLER1\n"
	break
done
# CONTROLLER1="AMH5508-HLT-1"

printf "\n\nPlease select the number of the Secondary Controller for these AP's:\n"
select CONTROLLER2 in `cat $CONTROLLERLIST`
do
	printf "You have selected $CONTROLLER2\n"
	break
done
# CONTROLLER2="AMH5508-HLT-2"


printf "\n\nPlease enter the AP Group for these AP's:\n> "
read APGROUP
# APGROUP="AMH-AMH"



# # # # MANIPULATE MAC ADDRESS WITH MANIPULATE FUNCTION # # # #
# MANIPULATE


# # # # READ APS FROM CONTROLLERS WITH READAPS FUNCTION # # # #
READAPS


# # # # BEGIN WORKING ON CONFIGURING APS # # # #
for TEMPNAME in "${APARRAY[@]}"; do
	# # # # FIND AP WITH FIND FUNCTION # # # #
	FINDAP

	# # # # CREATE AP NAME FROM INPUT WITH MAKENAME FUNCTION # # # #
	printf "\n\nPlease enter which AP Number this is for $CLOSET - $LOCATION:\n> "
	read NUMBER
	# NUMBER="2"
	MAKENAME

	# # # # VERIFY INFORMATION WITH VERIFY FUNCTION # # # #
	VERIFY

	# # # # IMPLEMENT CHANGES WITH IMPLEMENT FUNCTION # # # #
	IMPLEMENT

	done

printf "\n====[ All Un-Configured APs have been Configured ]====\n\n"
printf "====[ EXITING ]====\n"

exit
