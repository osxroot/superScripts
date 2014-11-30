#!/bin/bash
clear
echo
echo
echo
#
#       Script for archiving Dovecot mailboxes
#               Requires 10.7 (Lion) or higher
#
#       Written by Jeff Davis & Jeff Johnson
#               mactech -at- mac007.com
#
PATH=/Applications/Server.app/Contents/ServerRoot/usr/bin:$PATH
#
# Terminal Check
#
if [ "$TERM" != "dumb" ]; then
case $TERM in
        # for the most important terminal types we directly know the sequences
        xterm|xterm*|vt220|vt220*)
                 bold=`awk 'BEGIN { printf("%c%c%c%c", 27, 91, 49, 109); }' </dev/null 2>/dev/null`
                norm=`awk 'BEGIN { printf("%c%c%c", 27, 91, 109); }' </dev/null 2>/dev/null`
                ;;
        vt100|vt100*|cygwin)
                bold=`awk 'BEGIN { printf("%c%c%c%c%c%c", 27, 91, 49, 109, 0, 0); }' </dev/null 2>/dev/null`
                norm=`awk 'BEGIN { printf("%c%c%c%c%c", 27, 91, 109, 0, 0); }' </dev/null 2>/dev/null`
                ;;
esac
fi

#
# Show splash screen
#
color_1=`echo -en "\033[37;40m"` #Grey background
color_2=`echo -en "\033[30;46m"` #Cyan background
color_3=`echo -en "\033[0;34m"` #Blue text
color_4=`echo -en "\033[0;32m"` #Green text
color_5=`echo -en "\033[0;35m"` #Purple text
color_6=`echo -en "\033[0;31m"` #Red text
color_7=`echo -en "\033[0;36m"` #Cyan text
color_norm=`tput sgr0` # Reset to normal colors

PROJECT_NAME=$(basename "$0")
PROJECT_VERSION=1.0.0


if [ "$TERM" != "dumb" ]; then
clear
cat <<X
${color_1} +--------------------------------------------------------------------+
 |                                                                    |
 |                             ${color_2} ${PROJECT_NAME} ${color_1}                             |
 |                                                                    |
 |                           Version ${PROJECT_VERSION}                            |
 |                                                                    |
 |                         Copyright (c) 2014                         |
 |                   Mac007.com < mactech@mac007.com >                |
 |                                                                    |
 +--------------------------------------------------------------------+

X
tput sgr0
fi

#
# Check for root user
#
if [ `whoami` != "root" ]
then
  echo
  echo "$(basename "$0") must be run as ${bold}root${norm} user."
  echo
  exit 0;
fi


#
#       OS Version check
#
OSVersion=`sw_vers -productVersion | cut -d. -f1 -f2`

case $OSVersion in
        10.9)

                server_root_path="/Applications/Server.app/Contents/ServerRoot"
                ;;
        10.8)

                server_root_path="/Applications/Server.app/Contents/ServerRoot"
                ;;
        10.7)

                server_root_path="/Applications/Server.app/Contents/ServerRoot"
                ;;
        *)
                echo "This script requires 10.7 (Lion) or higher"
                exit 1
                ;;
esac

#####################################
#                       Functions               #
#####################################
#
# Print usage
#

usage() {
                echo
        echo " ${color_2}Email Archiver for OS X Server 10.7 and higher${color_norm}"
        echo ""
        echo " usage: ${color_7}$PROJECT_NAME${color_norm} [ ${color_4}-d ${color_1}days${color_norm} ] [ ${color_4}-m ${color_1}months${color_norm} ] [ ${color_4}-u ${color_1}username(s)${color_norm} ] [ ${color_4}-f ${color_1}path_to_file${color_norm} ] [ ${color_4}-q ${color_1}search_query${color_norm} ] [ ${color_4}-t ${color_1}Archive_folder_name${color_norm} ] [ ${color_4}-s ${color_1}mailbox_to_search${color_norm} ] [ ${color_4}-A${color_norm} ] [ ${color_4}-i${color_norm} ]"
        echo
        echo "  ${color_4}-d${color_norm} to specify number of days to go back before archiving"
        echo "  ${color_4}-m${color_norm} to specify number of months to go back beofre archiving"
        echo "  ${color_4}-u${color_norm} to specify username(s) to archive - multiple names must be double quoted"
        echo "  ${color_4}-f${color_norm} to specify path to an external user file list"
        echo "  ${color_4}-q${color_norm} to specify special search query - must be quoted"
        echo "  ${color_4}-t${color_norm} to specify custom archive folder name - folders must have period in between"
        echo "  ${color_4}-s${color_norm} to scecify mailbox(es) to search in - multiples must be quoted"
        echo "  ${color_4}-A${color_norm} to Perform 2 month archive on all users"
        echo "  ${color_4}-i${color_norm} to install as recurring archive"
        echo "  ${color_4}-h${color_norm} to display this help message"
        echo ""
        echo " ${color_5}Usage examples:${color_norm}"
        echo " ----------------"
        echo " Use automatic mode: ${color_7}epicArch ${color_4}-A${color_norm}"
        echo " Use with multiple usernames: ${color_7}epicArch ${color_4}-u ${color_1}''User1 User2 User3''${color_norm}"
        echo " Use with target folder names: ${color_7}epicArch ${color_4}-t ${color_1}Parent.Child1.Child2.Child3${color_norm}"
        exit 0
}

function empty
{
    local var="$1"

    # Return true if:
    # 1.    var is a null string ("" as empty string)
    # 2.    a non set variable is passed
    # 3.    a declared variable or array but without a value is passed
    # 4.    an empty array is passed
    if test -z "$var"
    then
        [[ $( echo "1" ) ]]
        return

    # Return true if var is zero (0 as an integer or "0" as a string)
    elif [ "$var" == 0 2> /dev/null ]
    then
        [[ $( echo "1" ) ]]
        return

    # Return true if var is 0.0 (0 as a float)
    elif [ "$var" == 0.0 2> /dev/null ]
    then
        [[ $( echo "1" ) ]]
        return
    fi

    [[ $( echo "" ) ]]
}


#####################################
#       Declarations & Default Values   #
#####################################
PATH=/Applications/Server.app/Contents/ServerRoot/usr/sbin:/Applications/Server.app/Contents/ServerRoot/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH
declare -a userArray
declare -a sourceBoxes
declare -a monthNames
declare -a targetLabel
declare -a targetBox

sourceBoxes=(INBOX Sent "Sent Messages" "Sent Items" Trash "Deleted Messages" "Deleted Items")
monthNames=(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
targetLabel=(Inbox Sent Deleted)


#       Get Current Month & Year
curYear=`date +%Y`
curMonth=`date +%m | sed 's/^0*//'` ## Have to strip leading 0 to prevent 08 & 09 months breaking integer comparison

#       Adjust year based on month
if (( $curMonth < 4 ))
        then
                archYear=$((curYear-1))
        else
                archYear=$curYear
fi

#       Set the Default Archive Folder month
case $curMonth in
        01) archMonth=10
        ;;
        02) archMonth=11
        ;;
        03) archMonth=12
        ;;
         *) archMonth=$((curMonth -3))
         ;;
esac

index=($archMonth-1) ## must subtract 1 for array to work
queryMonth=$((curMonth -2))

#       Append Archive month with leading 0 - required by Dovecot date calls
if (( $archMonth < 10 ))
        then
                        numMonth="0$archMonth"
                else
                        numMonth=$archMonth
fi

archMonth=${monthNames[index]}

if (( $queryMonth < 10 ))
        then
        queryMonth="0$queryMonth"
fi

archLabel="$numMonth-$archMonth"
searchQuery="BEFORE $curYear-$queryMonth-01"


targetBox="Archive"
#       Get all valid users ignoring orphaned boxes

# Get the mail partition directory
        mailpartition_PATH=`/Applications/Server.app/Contents/ServerRoot/usr/sbin/serveradmin settings mail:imap:partition-default | cut -d '"' -f 2`

# Loop through GUID directories and check the user shortname
        for archiveGUID in `ls -1 $mailpartition_PATH`; do
                archiveUsers=`echo "$archiveUsers";/usr/bin/dscl /Search -search /Users GeneratedUID $archiveGUID | grep GeneratedUID | cut -f 1`
        done

# sort by name
        userArray=`echo $archiveUsers | tr ' ' '\012' | sort`



#       At this point all variables should be set for Automatic Run






#
# Check for options
#

while getopts d:m:u:f:q:t:s:iAh options
do
        case $options in
                d) inputDay="$OPTARG"
                   cusYear=`date -v -"$inputDay"d +%Y`
                   cusMonth=`date -v -"$inputDay"d +%m`
                   cusDay=`date -v -"$inputDay"d +%d`
                   searchQuery="BEFORE $cusYear-$cusMonth-$cusDay"
                   index=${cusMonth#0}
                   cusName=${monthNames[index-1]}
                   archLabel="$cusMonth-$cusName"
                   archYear=$cusYear
                   ;;
                m) inputMonth="$OPTARG"
                   cusYear=`date -v -"$inputMonth"m +%Y`
                   cusMonth=`date -v -"$inputMonth"m +%m`
                   cusDay=`date -v -"$inputMonth"m +%d`
                   searchQuery="BEFORE $cusYear-$cusMonth-$cusDay"
                   index=${cusMonth#0}
                   cusName=${monthNames[index-1]}
                   archLabel="$cusMonth-$cusName"
                   archYear=$cusYear
                   ;;
                u) inputUser="$OPTARG"
                   userArray=($inputUser)
                   ;;
                f) path2File="$OPTARG"
                   let i=0
                                   while IFS=$'\n' read -r line_data; do
                                           userArray[i]="${line_data}"
                                           ((++i))
                                   done < "$path2File"
                   ;;
                q) inputQuery="$OPTARG"
                   searchQuery=$inputQuery
                   ;;
                t) inputTarget="$OPTARG"
                   targetBox=($inputTarget)
                   ;;
                s) inputSource="$OPTARG"
                   sourceBoxes=($inputSource)
                   ;;
                i) install_plist=1
                   ;;
                A) autoMatic=1
                   ;;
                h) usage;;
                *) usage;;


        esac
done


######
###### Check user source box for content before creating target box.
######
#loop users
#       check sourcebox for matching messages
#               create archive direectory matching above
#               move messages to archive
#       next sourcebox
#next user

#
# doveadm wildcards
#


## displaying varis for checking DELETE when done

echo
echo "Archiving : ${color_7}${sourceBoxes[0]}${color_norm} to ${color_4}Archive.$archYear.${targetLabel[0]}.$archLabel${color_norm} ${color_6}$searchQuery${color_norm}"
echo "Archiving : ${color_7}${sourceBoxes[1]}, ${sourceBoxes[2]}, ${sourceBoxes[3]}${color_norm} to ${color_4}Archive.$archYear.${targetLabel[1]}.$archLabel${color_norm} ${color_6}$searchQuery${color_norm}"
echo "Archiving : ${color_7}${sourceBoxes[4]}, ${sourceBoxes[5]}, ${sourceBoxes[6]}${color_norm} to ${color_4}Archive.$archYear.${targetLabel[2]}.$archLabel${color_norm} ${color_6}$searchQuery${color_norm}"
echo
echo "For the following users:"
echo  ${color_5}${userArray[*]}${color_norm}
echo


# Confirm settings
if (( autoMatic != 1 )) ; then
                read -p "Are these the settings you wish to use? (y/n)  " yn
                case $yn in
                [Yy]* ) echo
                                echo "Please stand-by. Preparing to run epicArch."
                                echo
                                echo
                                ;;
                [Nn]* )
                                echo
                                echo "Let's update the criteia for the archive:"
                                echo
                                read -p "Archive message criteria (use doveadm format): " searchQuery
                                read -p "For this user (ALL for all users or enter a path to file): " userNames
                                read -p "Mailbox to archive from: " sourceBox
                                read -p "Mailbox archive destination: " targetBox
                                echo
                                echo

                ;;
                        x) exit 1
                        ;;
                * ) echo "Please answer yes or no.";;
                esac
fi



#########
##              Here is the default loop layout
########

for i in $userArray
        do
                echo
                echo "Processing user: ${color_5}$i${color_norm}"
                counter=0
# sourcebox loop begins
                        while [ $counter -lt ${#sourceBoxes[@]} ]
                                do

                                        matchCount=`doveadm search -u $i mailbox "${sourceBoxes[$counter]}" $searchQuery`
                                        if empty "$matchCount" ; then
                                                echo "${color_6}No Matching Messages${color_norm} in ${color_7}${sourceBoxes[$counter]}${color_norm}"
                                                counter=$((counter+1))
                                        else
                                                case ${sourceBoxes[$counter]:0:4} in
                                                        INBO) targetLabel="INBOX"
                                                        ;;
                                                        Sent) targetLabel="Sent"
                                                        ;;
                                                        Tras) targetLabel="Deleted"
                                                        ;;
                                                        Dele) targetLabel="Deleted"
                                                        ;;
                                                        *) targetLabel=$targetBox
                                                        ;;
                                                esac
                                                echo "${color_4}Archiving: ${color_7}${sourceBoxes[$counter]}${color_norm}"
                                                doveadm  mailbox create -u $i -s $targetBox.$archYear.$targetLabel.$archLabel 2> /dev/null
                                                doveadm move -u $i $targetBox.$archYear.$targetLabel.$archLabel mailbox "${sourceBoxes[$counter]}" $searchQuery

                                                counter=$((counter+1))
                                        fi
                                done
# sourcebox loop ends

        done
########
##              End Default Loop
########
echo
echo
