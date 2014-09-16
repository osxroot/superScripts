#!/bin/bash

#    Enter your target paths here
#    Each path should be quoted with a space in between
#    myTarget=( "/Volumes/Data" "/Volumes/SharePoints" )
myTarget=( "/Volumes/DSVDATA" "/Volumes/DSVFTPAREA" )

########## Init

touch "/var/log/ms-lock-delete.log"
echo -e "\n`date`" >> /var/log/ms-lock-delete.log

########## Start Target Loop

[[ "$1" = "dry" ]] && echo "## This is a dry run, no files will be deleted"

for (( i = 0 ; i < ${#myTarget[@]} ; i++ )) do
    echo -e "\n####Processing: ${myTarget[$i]}"
    find "${myTarget[$i]}" -type f -name "~\$*" -maxdepth 1 -print0 2>/dev/null | while IFS= read -r -d '' file; do          
       realname="`basename "$file" | tr -d '~$'`"
       ## Check if the file is currently open
       isopen=`lsof "$realname" 2>/dev/null | wc -l`
       ## If the file is not open (by a program running on the
       ## same machine as this script, delete the lockfile
      if  [[ $isopen -eq 0 ]]; then
        rm  "$file"
        echo "    DELETED LOCK: $file"
      else
         echo "    dryrun: $file"
      fi
   done
done


########## End Target Loop

