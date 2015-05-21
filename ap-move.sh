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
echo ""
echo "Please enter the list of AP's to be moved:"
echo "`ls $APLISTPATH`"
echo "--------------------------------------"
echo -n "> "
read APLIST

if [ -f $APLISTPATH$APLIST ]
 then
  echo ""
  echo "AP List = \"./ap-lists/$APLIST\" (confirmed)"
 else
  echo ""
  echo "AP list = \"./ap-lists/$APLIST\" (does not exist!)"
  echo "Aborting..."
  echo ""
 exit
fi

}


# # # # CHECK WHICH CONTROLLER AP IS REGISTERED TO # # # #
#       AND READ IN $RADIOMAC AND $REGCONTROLLER         #


FINDAP(){

echo "--------------------------------------------------"
echo ""
echo "====[ Finding AP on Controllers... ]===="
echo ""

for CONTROLLERS in `cat $CONTROLLERLIST`

do
	SEARCH=$(snmpwalk $SNMPOPTIONS $CONTROLLERS \
		bsnAPName | grep $NAME\")
	
if [[ $SEARCH = *$NAME* ]]
	then
	echo "!!!! $NAME FOUND on Controller $CONTROLLERS !!!!"
	REGCONTROLLER=$CONTROLLERS
	RADIOMAC=$(sed -n 's/.*bsnAPName.\(.*\)=.*/\1/p' <<< "$SEARCH")
	CURCONTROLLER1=$(snmpwalk $SNMPOPTIONS $REGCONTROLLER \
		bsnAPPrimaryMwarName | grep $RADIOMAC | cut -d\" -f2 )
	CURCONTROLLER2=$(snmpwalk $SNMPOPTIONS $REGCONTROLLER \
		bsnAPSecondaryMwarNAme | grep $RADIOMAC | cut -d\" -f2)
	break
	else
	echo "$NAME not found on Controller $CONTROLLERS"
fi

done

# echo $RADIOMAC
# echo $REGCONTROLLER

}


# # # # VERIFY CHANGES # # # #

VERIFY(){
echo ""
echo ""
echo "=====[ Current AP Information ]====="
echo "AP Name: $NAME"
echo "Registered to Controller: $REGCONTROLLER"
echo "Current Primary Controller: $CURCONTROLLER1"
echo "Current Secondary: $CURCONTROLLER2"
echo "AP SNMP Identifier: $RADIOMAC"
echo ""
echo "=====[ Configuraiton Changes ]====="
echo "New Primary Controller: $CONTROLLER1"
echo "New Secondary Controller: $CONTROLLER2"

echo ""
echo ""
echo "Press Cntl-Z to quit in the next 5 seconds if this is not correct!"
for i in {5..1};do echo -n "$i, " && sleep 1; done

}

# # # # IMPLEMENT AND LOG CHANGES # # # #

IMPLEMENT(){

echo ""
echo "====[ Implementing changes... ]===="
echo ""
echo "====[ $NAME ]===="
echo "" >> $CONFIGLOG
echo "====[ $NAME ]====" >> $CONFIGLOG
echo "" >> $CONFIGLOG

OUTPUT=$(snmpset $SNMPOPTIONS $REGCONTROLLER \
	bsnAPPrimaryMwarName.$RADIOMAC s $CONTROLLER1 \
	bsnAPSecondaryMwarName.$RADIOMAC s $CONTROLLER2)
echo "$OUTPUT" >> $CONFIGLOG
echo "$OUTPUT"

}


# # # # WAIT FOR AP TO RE-REGISTER # # # #

WAITFORAP(){


echo ""
echo ""
echo "====[ Waiting for AP to re-register to new Primary Controller... ]===="

while [ "$APCHECK" != "TRUE" ]

do

STATUS=$(snmpwalk $SNMPOPTIONS $CONTROLLER1 \
	 bsnAPName | grep $NAME\")

if [[ $STATUS = *$NAME* ]]
then
	echo ""
	echo ""
	echo "!!!! $NAME is now registered to Controller $CONTROLLER1 !!!!"
	echo ""
	echo "Now waiting 3 seconds to see if AP Needs to download code..."
	for i in {3..1};do echo -n "$i, " && sleep 1; done
	
	DOWNLOAD=$(snmpwalk $SNMPOPTIONS $CONTROLLER1 \
		   bsnAPOperationStatus.$RADIOMAC)
	while [[ $DOWNLOAD != *associated* ]]
	do
		echo ""
		echo ""
		echo "AP Downloading updated Firmware and will reboot..."
		echo "This can take several minutes, please Wait..."
		echo ""
		for i in {10..1};do echo -n "$i, " && sleep 1; done 
		DOWNLOAD=$(snmpwalk $SNMPOPTIONS $CONTROLLER1 \
			   bsnAPOperationStatus.$RADIOMAC)

	done

		echo ""
		echo ""
		echo "AP $NAME Ready to go!"

		APCHECK="TRUE"
else
	echo ""
	echo ""
	echo "$NAME not registered on Controller $CONTROLLER1 yet"
	echo "Waiting 10 seconds and checking again..."
	APCHECK="FALSE"
	for i in {10..1};do echo -n "$i, " && sleep 1; done 
fi

done
}



# # # # CLEAR SCREEN AND BEGIN SCRIPT # # # #
# # # # # # # # # # # # # # # # # # # # # # # 

clear
echo "=====[ AP Moving Script ]====="
echo ""
echo ""
echo "This script is meant to be used to move many Access Points"
echo "between two controllers."
echo ""
echo ""


# # # # Read AP List with READAPLIST Function # # # # 

READAPLIST


# # # # GATHER AP INFORMATION # # # #


echo ""
echo ""
# echo "Please enter the Primary Controller you would like these AP's to register to:"
# echo -n "> "
# read CONTROLLER1
# CONTROLLER1="AMH5508-HLT-1"

echo "Please select the Primary Controller you would like these APs to register to:"
select CONTROLLER1 in `cat $CONTROLLERLIST`
do
	echo "You have selected $CONTROLLER1"
	break
done


echo ""
echo ""
# echo "Please enter the Secondary Controller you would like these AP's to register to:"
# echo -n "> "
# read CONTROLLER2
# CONTROLLER2="AMH5508-HLT-2"

echo "Please select the Secondary Controller you would like these APs to register to:"
select CONTROLLER2 in `cat $CONTROLLERLIST`
do
	echo "You have selected $CONTROLLER2"
	break
done


# # # # Execute # # # #

for NAME in `cat $APLISTPATH$APLIST`

do



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

echo ""
echo "====[ ALL APs have been migrated ]===="
echo "====[ EXITING! ]===="

exit


