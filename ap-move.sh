#!/bin/bash
#
# The purpose of this script is to automate Cisco Access Point moving
# The script identifies the list of AP's, as well
# and then pushes the changes to the controllers one by one.
#

# # # # DECLARE VARIABLES AND FILE PATHS  # # # #
# # # # # # # # # # # # # # # # # # # # # # # # #

CONFIGLOG="$HOME/Documents/wireless-scripts/logs/configlog-`date +%m-%d-%Y`.log"
CONTROLLERLIST="$HOME/Documents/wireless-scripts/old-controller-list.txt"
APLISTPATH="$HOME/Documents/wireless-scripts/ap-lists/"

SNMPOPTIONS="-v3 -a SHA -A SUP3R-S3CR3T! -l authNoPriv -u neteng -Ob"
PS3="Select a controller: "


# # # # # # # # # # # # # # # # #


# # # # READ AP List # # # #

READAPLIST(){

	clear
	printf "\nPlease enter the list of AP's to be moved:\n"
	printf "`ls $APLISTPATH`\n"
	printf "--------------------------------------\n> "
	read APLIST
	
	if [ -f $APLISTPATH$APLIST ]
		then
	 		printf "\nAP List = \"./ap-lists/$APLIST\" (confirmed)\n"
		else
	 		printf "\nAP list = \"./ap-lists/$APLIST\" (does not exist!)\n"
	 		printf "Aborting...\n\n"
			exit
	fi

}


# # # # CHECK WHICH CONTROLLER AP IS REGISTERED TO # # # #
#       AND READ IN $RADIOMAC AND $REGCONTROLLER         #


FINDAP(){

	printf "--------------------------------------------------\n\n"
	printf "====[ Finding AP on Controllers... ]====\n\n"
	
	for CONTROLLERS in `cat $CONTROLLERLIST`; do
		SEARCH=$(snmpwalk $SNMPOPTIONS $CONTROLLERS \
			bsnAPName | grep $NAME\")
		
	if [[ $SEARCH = *$NAME* ]]
		then
			printf "!!!! $NAME FOUND on Controller $CONTROLLERS !!!!\n"
			REGCONTROLLER=$CONTROLLERS
			RADIOMAC=$(sed -n 's/.*bsnAPName.\(.*\)=.*/\1/p' <<< "$SEARCH")
			CURCONTROLLER1=$(snmpwalk $SNMPOPTIONS $REGCONTROLLER \
				bsnAPPrimaryMwarName | grep $RADIOMAC | cut -d\" -f2 )
			CURCONTROLLER2=$(snmpwalk $SNMPOPTIONS $REGCONTROLLER \
				bsnAPSecondaryMwarNAme | grep $RADIOMAC | cut -d\" -f2)
			break
		else
			printf "$NAME not found on Controller $CONTROLLERS\n"
	fi
	
	done
	
	# printf $RADIOMAC\n
	# printf $REGCONTROLLER\n

}


# # # # VERIFY CHANGES # # # #

VERIFY(){
	printf "\n\n\n=====[ Current AP Information ]=====\n"
	printf "AP Name: $NAME\n"
	printf "Registered to Controller: $REGCONTROLLER\n"
	printf "Current Primary Controller: $CURCONTROLLER1\n"
	printf "Current Secondary: $CURCONTROLLER2\n"
	printf "AP SNMP Identifier: $RADIOMAC\n"
	printf "\n\n=====[ Configuraiton Changes ]=====\n"
	printf "New Primary Controller: $CONTROLLER1\n"
	printf "New Secondary Controller: $CONTROLLER2\n"
	
	printf "\n\nPress Cntl-Z to quit in the next 5 seconds if this is not correct!\n"
	for i in {5..1};do printf "$i, " && sleep 1; done

}

# # # # IMPLEMENT AND LOG CHANGES # # # #

IMPLEMENT(){

	printf "\n\n====[ Implementing changes... ]====\n"
	printf "\n\n===[ $NAME ]===\n\n" | tee -a $CONFIGLOG
	
	OUTPUT=$(snmpset $SNMPOPTIONS $REGCONTROLLER \
		bsnAPPrimaryMwarName.$RADIOMAC s $CONTROLLER1 \
		bsnAPSecondaryMwarName.$RADIOMAC s $CONTROLLER2)
	printf "$OUTPUT\n" | tee -a $CONFIGLOG

}


# # # # WAIT FOR AP TO RE-REGISTER # # # #

WAITFORAP(){

	printf "\n\n====[ Waiting for AP to re-register to new Primary Controller... ]====\n"
	
	while [ "$APCHECK" != "TRUE" ]; do
	
		STATUS=$(snmpwalk $SNMPOPTIONS $CONTROLLER1 \
			bsnAPName | grep $NAME\")
	
		if [[ $STATUS = *$NAME* ]]
			then
				printf "\n\n!!!! $NAME is now registered to Controller $CONTROLLER1 !!!!\n\n"
				printf "Now waiting 3 seconds to see if AP Needs to download code...\n"
				for i in {3..1};do printf "$i, " && sleep 1; done
				
				DOWNLOAD=$(snmpwalk $SNMPOPTIONS $CONTROLLER1 \
					bsnAPOperationStatus.$RADIOMAC)
				
				while [[ $DOWNLOAD != *associated* ]]; do
					printf "\n\nAP Downloading updated Firmware and will reboot...\n"
					printf "This can take several minutes, please Wait...\n\n"
					for i in {10..1};do printf "$i, " && sleep 1; done 
					DOWNLOAD=$(snmpwalk $SNMPOPTIONS $CONTROLLER1 \
						bsnAPOperationStatus.$RADIOMAC)	
				done
			
				printf "\n\nAP $NAME Ready to go!\n"
				APCHECK="TRUE"
	
			else
				printf "\n\n$NAME not registered on Controller $CONTROLLER1 yet.\n"
				printf "Waiting 10 seconds and checking again...\n"
				APCHECK="FALSE"
				for i in {10..1};do printf "$i, " && sleep 1; done 
		fi
	
	done

}



# # # # CLEAR SCREEN AND BEGIN SCRIPT # # # #
# # # # # # # # # # # # # # # # # # # # # # # 

clear
printf "=====[ AP Moving Script ]=====\n\n\n"
printf "This script is meant to be used to move many\nAccess Points between two controllers.\n\n\n"


# # # # Read AP List with READAPLIST Function # # # # 

READAPLIST


# # # # GATHER AP INFORMATION # # # #


printf "\n\nPlease select the Primary Controller you would like these APs to register to:\n"
select CONTROLLER1 in `cat $CONTROLLERLIST`; do
	printf "You have selected $CONTROLLER1\n"
	break
done
# CONTROLLER1="AMH5508-HLT-1"

printf "\n\nPlease select the Secondary Controller you would like these APs to register to:\n"
select CONTROLLER2 in `cat $CONTROLLERLIST`; do
	printf "You have selected $CONTROLLER2\n"
	break
done
# CONTROLLER2="AMH5508-HLT-2"

# # # # Execute # # # #

for NAME in `cat $APLISTPATH$APLIST`; do
	
	# # # # FIND AP WITH FIND FUNCTION # # # #
	FINDAP
	
	
	# # # # VERIFY INFORMATION WITH VERIFY FUNCTION # # # #
	VERIFY
	
	
	# # # # IMPLEMENT CHANGES WITH IMPLEMENT FUNCTION # # # #
	IMPLEMENT
	
	
	# # # # WAIT FOR AP TO REGISTER TO NEW CONTROLLER # # # #
	APCHECK="FALSE"
	
	WAITFORAP

done

printf "\n====[ ALL APs have been migrated ]====\n====[ EXITING! ]====\n"

exit


