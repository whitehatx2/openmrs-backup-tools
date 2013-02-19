#!/bin/bash

# Get script directory
SCRIPT_PATH="${BASH_SOURCE[0]}";
if ([ -h "${SCRIPT_PATH}" ]) then
  while([ -h "${SCRIPT_PATH}" ]) do SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
fi
pushd . > /dev/null
cd `dirname ${SCRIPT_PATH}` > /dev/null
SCRIPT_PATH=`pwd`;
popd  > /dev/null

# Load configuration values
. $SCRIPT_PATH/backup.conf

# Fail function to record error in syslog
fail() {
	logger -t $LOGGING_TAG -p local0.crit $1
	echo $1
	exit 1
}

# Check runtime properties file exists
if ! [ -e "$OPENMRS_PROP_FILE" ]; then
	fail "Specified OpenMRS runtime properties file does not exist"
fi

# Read properties from properties file
dbuser=`sed '/^\#/d' "$OPENMRS_PROP_FILE" | grep 'connection.username' | tail -n 1 | cut -d "=" -f2-`
dbpass=`sed '/^\#/d' "$OPENMRS_PROP_FILE" | grep 'connection.password' | tail -n 1 | cut -d "=" -f2-`
dburl=`sed '/^\#/d' "$OPENMRS_PROP_FILE" | grep 'connection.url' | tail -n 1 | cut -d "=" -f2-`

# Check properties could be read
if [ -z $dbuser ] || [ -z $dbpass ] || [ -z $dburl ]; then
	fail "Unable to read OpenMRS runtime properties"
fi

# Extract database name from connection URL
if [[ $dburl =~ /([a-zA-Z0-9_\-]+)\? ]]; then
	dbname=${BASH_REMATCH[1]}
else
	dbname="openmrs"
fi

#User warning and check
echo "WARNING: This will import the dump file data to the database configured in openmrs-runtime.properties file."
read -p "Are you sure you want to continue? <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
then
  echo "Importing ....."
else
  exit 0
fi

while getopts “e:i:” OPTION
do
     case $OPTION in
         e)
             keypath=$OPTARG
	      ;;
	  i)
             backupfile=$OPTARG
	      ;;	
     esac
done	

#Decrypt backup
if [ -n "$keypath" ]; then
    openssl smime -decrypt -in $backupfile -binary -inform DEM -inkey $keypath -out "$BACKUP_DEST_DIR/kemr_restore.gz"
else
    mv $backupfile $BACKUP_DEST_DIR/kemr_restore.gz
fi
# Restore the database
echo "$BACKUP_DEST_DIR/kemr_restore"
gunzip "$BACKUP_DEST_DIR/kemr_restore.gz"
cd $BACKUP_DEST_DIR
mysql -u$dbuser -p$dbpass $dbname < kemr_restore

# Check restore was successful
if [ $? -eq 0 ]; then
	logger -t $LOGGING_TAG -p local0.info "Database restore successful"
else
	fail "Unable to restore database (name=$dbname, user=$dbuser)"
fi

