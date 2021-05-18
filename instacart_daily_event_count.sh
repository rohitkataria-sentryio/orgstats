#!/bin/bash

#org_stats.sh - A script to print total events accepted on a given date
#Example: <script_name> 2021-03-31
#One way to run the script could be in a for loop. Like below:
#export SENTRY_AUTH_TOKEN=<your_sentry_token>
#for i in `seq 24 28`;do ./stat.sh 2021-02-$i;done 
#2021-02-24,22473
#2021-02-25,17273
#2021-02-26,22900
#2021-02-27,41879
#2021-02-28,41433

# Where 24 is the start date and 28 is the end date.

DATE_TOOL=""
EVENT_COUNT_DATE=""
PLAN_START_DATE=2021-02-24
ORG_SLUG=instacart
TOKEN=$(set | grep '^SENTRY_AUTH_TOKEN=' | cut -d '=' -f 2)

if [[ $TOKEN == "" ]]; then
  echo "Must run export SENTRY_AUTH_TOKEN=<your token> before running the script"
  echo "Or it could be made available via the .rc file or similar"
  echo "Please visit: https://sentry.io/settings/account/api/auth-tokens/ to create one."
  exit -1
fi

if [[ $ORG_SLUG != "instacart" ]]; then
  echo "This script is written for instacart"
  echo "Check the value of ORG_SLUG= in the globals area"
  exit -1
fi

# On Linux gnu date comes installed as date
# On Mac, date is the BSD version so gnu date needs to be installed

DATE_TOOL_CHECK_1=$(date --version 2> /dev/null | head -1 | grep 'GNU')
DATE_TOOL_CHECK_2=$(gdate --version 2> /dev/null | head -1 | grep 'GNU')
   
## check GNU date is installed
if [[ "$DATE_TOOL_CHECK_1" == *"GNU"* ]]; then
  DATE_TOOL=date
elif [[ "$DATE_TOOL_CHECK_2" == *"GNU"* ]]; then
  DATE_TOOL=gdate
else
  echo "Please install GNU Date. Exiting..."
  exit -1
fi

EVENT_COUNT_DATE="$1"

if [[ "$EVENT_COUNT_DATE" == "" ]]; then
  echo "The script expects date as an argument. Example:"
  echo "$0 2021-02-24"
  exit -1
fi

CURRENT_EPOCH_TIME=$($DATE_TOOL +%s)
PLAN_START_DATE_EPOCH_TIME=$($DATE_TOOL -d "$PLAN_START_DATE 00:00:00 +0000" '+%s')


EVENT_COUNT_DATE_EPOCH_TIME=$($DATE_TOOL -d "$EVENT_COUNT_DATE 00:00:00 +0000" '+%s')
if [[ $? != 0  ]]; then
  echo "Invalid Date."
  echo "Example: $0 2021-02-24"
  exit -1
fi

if [[ $EVENT_COUNT_DATE_EPOCH_TIME < $PLAN_START_DATE_EPOCH_TIME ]]; then
  echo "$ORG_SLUG's plan started on $PLAN_START_DATE."
  echo "So the date entered cannot be prior to that "
  exit -1
fi

if [[ $EVENT_COUNT_DATE_EPOCH_TIME > $CURRENT_EPOCH_TIME ]]; then
  echo "Sorry, you've entered a future date."
  exit -1
fi

# Calling stats api now

#TODO Consider using jq instead of msjon.tool
#TODO Investigate behavior of resolution. Misspelling it doesnt seem to matter.
#TODO Investigate value of since= . Empty value gives results

DAILY_COUNT_JSON=$(curl -s -f "https://sentry.io/api/0/organizations/$ORG_SLUG/stats/?since=$EVENT_COUNT_DATE_EPOCH_TIME&resolution=1d&stat=received" -H "Authorization: Bearer $TOKEN")
if [[ $? != 0 ]]; then
  echo "Error in retrieving org stats. Exiting now..."
  exit -1
fi 
 
DAILY_COUNT_NUMBER=$(echo $DAILY_COUNT_JSON | python -mjson.tool | egrep -v '\[|\]'  | head -2 | tail -1 | xargs)
echo "$1,$DAILY_COUNT_NUMBER"
