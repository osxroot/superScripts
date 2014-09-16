#!/bin/bash

# Enter name of the training folders
# These are IMAP folders in the user imap space
# The script will create these folders and subscribe the users.
trainSPAM="Train-Junk"
trainHAM="Train-NotJunk"
trainPURGE=7

# The users incoming Junk folder.
# Should be set in
# amavisd.conf:   @addr_extension_spam_maps = ('Junk');
# master.cf: look for dovecot line to enable plus addressing
junk="Junk"
junkPURGE=7

# System Wide Quarantine Account
# the systemwide quarantine is disabled by default.
# it can be enable in amavisd.conf: $spam_quarantine_to
quar=quarantine
quarPURGE=30

###################### VARs and FUNCTIONS
Mailstore="`serveradmin settings mail:imap:partition-default | cut -d '"' -f 2`"

OSVersion=`sw_vers -productVersion | cut -d. -f1 -f2`

case $OSVersion in
        10.9)

                BAYES="/Library/Server/Mail/Data/scanner/amavis/.spamassassin"
                ;;
        10.8)

                BAYES="/Library/Server/Mail/Data/scanner/amavis/.spamassassin"
                ;;
        10.7)

                BAYES="/Library/Server/Mail/Data/scanner/amavis/.spamassassin"
                ;;
                
        10.6)
                BAYES="/var/amavis/.spamassassin"
                ;;
        *)
                echo "This script requires 10.6 (Snow Leopard) or higher"
                exit 1
                ;;
esac


function makeFOLDER {
    mkdir -p "$box/.$1"/{cur,new,tmp}
    echo "$1" >> "$box/subscriptions"
    chown -R $muser:mail "$box/.$1"
    chmod -R 700 "$box/.$1"
    echo "Created $1 folder for user: $muser  with GUID: $box"
   }

###################### START MAILSTORE LOOP
cd $Mailstore
for box in `ls -d [0-F]*`; do
    muser=`cvt_mail_data -u $box 2>/dev/null`

    echo -e "\n## Processing: $box   $muser"

    # Skip a GUID directory if it does not have an owner
    [[ "$muser" = "No user"* ]] && echo "## the $box mail directory has no valid user" && continue

    # Checking for missing folders
    [[ ! -d "$box/.$trainSPAM" ]] && makeFOLDER "$trainSPAM"
    [[ ! -d "$box/.$trainHAM" ]] && makeFOLDER "$trainHAM"
    [[ ! -d "$box/.$junk" ]] && makeFOLDER "$junk"

    echo "PURGING"
    find "$box/"{.$trainSPAM,.$trainHAM} -type f -name "*W=*" -ctime "+$trainPURGE"d -delete
    find "$box/.$junk" -type f -name "*W=*" -ctime "+$junkPURGE"d -delete

    printf "Reading SPAM"
    sa-learn -u _amavisd --dbpath "$BAYES" --spam --showdots "$box/.$trainSPAM/"{cur,new}
    printf "Reading HAM"
    sa-learn -u _amavisd --dbpath "$BAYES" --ham --showdots "$box/.$trainHAM/"{cur,new}

done
###################### END MAILSTORE LOOP

###################### FINISH REMAINING TASKS

echo -e "\n\n## Users are done. Wrapping up\n"
echo -e "Synchronizing the SpamAssassin database"
sa-learn -u "$spamav_user"  --dbpath "$BAYES" --sync

echo -e "Purging the systemwide quarantine account: $quar\n"
find `cvt_mail_data -i "$quar"` -type f -name "*W=*" -ctime "+$quarPURGE"d -delete

echo "## Bayes Stats"
sa-learn -u _amavisd --dbpath "$BAYES" --dump magic

echo -e "\n\n#### DONE ###\n\n"

exit 0