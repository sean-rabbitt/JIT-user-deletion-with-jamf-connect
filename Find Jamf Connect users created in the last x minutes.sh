#!/bin/bash

# PART ONE: Find a list of Jamf Connect users who were created in the last X 
#			minutes
#
# WHY: Jamf Connect allows for just-in-time account creation on a macOS client.
# So this means that an admin may want to just pop in and do some magic, log out
# and go away.  But there's no easy way to clean up after yourself, and like any
# good Girl Scout, we should always leave our campsite better than when we found
# it.
# 
# HOW: Upload this script into Jamf Pro.  Create a policy to run the script with
# and ongoing excution frequency and set to run via Self Service.  It may make 
# sense to restrict the app to specific users and require that IT folks sign in  
# to self service to prevent some users from running the script.
#
# WHAT: We'll search all the accounts that have passwords, see if it was created
# with Jamf Connect, determine if the account was created within the last X 
# minutes (you can adjust the number below).  If yes, will be added to a space 
# delimited list of user account short names to be written to 
# /private/tmp/.userCleanup (which you can also adjust below).
#
# Combine this with an extension attribute to read that file, a Smart Computer 
# Group to drop machines into a target group to run a policy at reoccuring 
# check-in, and a policy that reads that file and runs a jamf deleteAccount 
# command to kill that account.
#
# — SRABBITT 21DEC2021

# MIT License
#
# Copyright (c) 2021 Jamf Software

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#look for users created in the last X minutes
userAge=60

# Touch file with list of users to be deleted
DELETE_USER_TOUCH_FILE="/Library/Application Support/JAMF/Receipts/.userCleanup"
# Credit: Steve Wood

# Location of the Jamf binary
JAMF_BINARY="/usr/local/bin/jamf"

# Declare list of unmigrated users variable
listOfUsers=""

# Warn users of what is going to happen
responseCode=$(/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
	-heading "WARNING - THIS APPLICATION CAN DELETE USER DATA" \
	-cancelButton 1\
	-button2 "Continue"\
	-button1 "ABORT"\
	-windowType utility\
	-description "This application will search for user accounts created in the last $userAge minutes.  It will mark those accounts for deletion which will happen within the next check-in period to Jamf Pro.  If you do NOT want to continue, press ABORT."\
	-title "Jamf Connect Cleanup Script"\
	-icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarDeleteIcon.icns")
	
# If a user hits the abort button, get ouf the script and declare an exit code 
# of 999.  Policy will show as a failure in Jamf Pro logs.
if [[ $responseCode = 0 ]]; then
	exit 999;
fi

# Convert userAge to seconds
userAge=$((userAge * 60))

# For all users who have a password on this machine (eliminates service accounts
# but includes the _mbsetupuser and Jamf management accounts...)
for user in $(dscl . list /Users Password | awk '$2 != "*" {print $1}'); do
	# If a user has the attribute "OIDCProvider" in their user record, they are 
	# a Jamf Connect user.
	MIGRATESTATUS=($(dscl . -read /Users/$user | grep "OIDCProvider: " | awk {'print $2'}))
	# If we didn't get a result, the variable is empty.  Thus that user is not 
	# a Jamf Connect Login user.
	if [[ -z $MIGRATESTATUS ]]; 
		then
			# user is not a jamf connect user
			echo "$user is Not a Jamf Connect User"
		else
			#Thank you, Allen Golbig.
			create_time=$(dscl . -readpl /Users/$user accountPolicyData creationTime | awk '{ print $NF }')
			
			# Strip the annoying float and make it an int
			create_time=$( printf "%.0f" $create_time )
			
			# Get the current time in Epoch format
			start_time=$(date +%s)
			
			# Remove the userAge number of seconds that we're looking for....
			start_time=$(( start_time - userAge ))
			
			# If the user account was created AFTER the current time minus X 
			# minutes, add the user UNIX short name to a list of users.
			if (( $start_time < $create_time)); 
			then
				listOfUsers+=$(echo "$user ")
			fi
		fi
done

# If we didn't find anything, either our admin took a lot longer than 60 minutes
# to fix the problem or something else went wrong.
if [[ -z $listOfUsers ]];
	then
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
		-heading "ERROR - No users found"\
		-button1 "Continue" \
		-windowType utility \
		-description "No local user accounts were created with Jamf Connect Login in the last $userAge seconds.  User account may need to be deleted manually." \
		-title "Jamf Connect Cleanup Script" \
		-icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ProblemReport.icns"
	else
		# Otherwise, we found someone - time to tell the user that it's 
		# curtains... lacy, wafting curtains for that user.
###		
### YOU CAN EDIT THIS WARNING MESSAGE TO LOCALIZE FOR YOUR IT TEAM HERE
###	
		warningMessage="The following accounts will be deleted within 15 minutes of this policy running:

$listOfUsers

Press ABORT to stop."
		
		# Give users one last chance to avoid the end times for that user...
		responseCode=$(/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper \
			-icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns" \
			-button2 "Continue" \
			-description "$warningMessage" \
			-heading "User Account Deletion" \
			-windowType utility \
			-cancelButton 1 \
			-button1 "ABORT" \
			-title "WARNING - POTENTIAL FOR DATA LOSS")
	
	# If a user hits the abort button, get ouf the script and declare an exit 
	# code of 666  Policy will show as a failure in Jamf Pro logs.
	if [[ $responseCode = 0 ]]; then
		exit 666;
	fi
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper \
		-heading "How to abort" \
		-button1 "Continue" \
		-windowType utility \
		-description "If you change your mind, delete the file located at $DELETE_USER_TOUCH_FILE immediately." \
		-title "Jamf Connect Cleanup Script"  \
		-icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
fi

# Write the list of doomed users to the doomed user file.
echo "$listOfUsers" > "$DELETE_USER_TOUCH_FILE"

# Run a recon so we update the extension attribute 
# and alert Jamf Pro that this list exists
$JAMF_BINARY recon 
