#!/bin/bash

# PART THREE: Delete a list of users
#
# WHY: Jamf Connect allows for just-in-time account creation on a macOS client.
# So this means that an admin may want to just pop in and do some magic, log out
# and go away.  But there's no easy way to clean up after yourself, and like any
# good Girl Scout, we should always leave our campsite better than when we found
# it.

# HOW: 	1) Upload this script into Jamf Pro.  
# 		2) Create an extension attribute to look for the presence of a file 
#			located at $DELETE_USER_TOUCH_FILE (defined below)
#		3) Create a Smart Computer Group based on the extension attribute above
#			and that the file exists
#		4) Create a policy that runs at reoccuring checkin, scoped to computers
#			that belong to the Smart Computer Group above.  Tell the policy to 
#			run this script.

### NOTE: THE JAMF BINARY COMMAND TO DELETE USERS IS COMMENTED OUT BELOW.  YOU MUST UNCOMMENT THIS.  POTENTIAL FOR DATA LOSS!!! ###

# WHAT: Script will read the list of users at $DELETE_USER_TOUCH_FILE and run
#		the jamf binary command to delete that user and all its home directory 
#		data.  It also does a jamf recon at the end to update the extension
#		attribute.  No additional inventory update needed.

##### IMPORTANT FEATURE / BUG WORKAROUND #####
# 
# macOS Big Sur and Monterey do not care if there is a bootstrap token or not,
# if there is only one administrator account, you can't delete it.  
#
# To get around this, we can check for a scenario where there is only one
# admin account with a securetoken, grant admin rights to a standard user for
# a few cycles/seconds, delete the admin account we want to be gone, and then 
# revoke admin rights from that standard account.
#
# THE RISK IS THAT A STANDARD ACCOUNT WILL HAVE ADMIN RIGHTS FOR A FEW SECONDS
# 
# If you don't want this check and privilege escallation to take place,
# modify the variable below - checkForOnlyOneAdmin - to 0 from 1.

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

# — SRABBITT 05JAN2022
# - Thanks to Steve Wood for suggestions on this script.

# SEE NOTES ABOVE - If you want to check for only one admin, set to "1"
# If you don't care if there's only a single admin and this script may
# fail OR if your environment simply uses all admin accounts anyway, set to "0"

checkForOnlyOneAdmin=1

# Location of user deadpool list
DELETE_USER_TOUCH_FILE="/Library/Application Support/JAMF/Receipts/.userCleanup"
# Credit: Steve Wood

# Location of the user deadpool list after running script (confirmation file 
# for auditing)
CONFIRM_USER_TOUCH_FILE="/private/tmp/.userDeleted"

# Location of the Jamf binary
JAMF_BINARY=$( which jamf )

# Convert the space separated list of users into an array for looping through
listOfUsers=$(cat "$DELETE_USER_TOUCH_FILE")
arrayOfUsers=($listOfUsers)

# If we're sanity checking for the "one admin" scenarion, look for if there
# is only one admin with a securetoken. If true, find any standard account
# with a securetoken and mark them for elevation.

if [[ "$checkForOnlyOneAdmin" -eq 1 ]]; then
	adminUserCount=0
	# For all users who have a password on this machine (eliminates service accounts
	# but includes the _mbsetupuser and Jamf management accounts...)
	for user in $(/usr/bin/dscl . list /Users Password | /usr/bin/awk '$2 != "*" {print $1}'); do
		# Is the user an admin
		isUserAdmin=$(/usr/sbin/dseditgroup -m "$user" -o checkmember admin | /usr/bin/awk {'print $1'})
		if [ "$isUserAdmin" = "yes" ]; then
			# Check for securetoken status
			secureTokenStatus=$(/usr/bin/dscl . -read /Users/"$user" AuthenticationAuthority | /usr/bin/grep -o "SecureToken")
			# If the account has a SecureToken, increase the securetoken counter
			if [ "$secureTokenStatus" = "SecureToken" ]; then
				((adminUserCount++))
			fi
		fi
	done
	
	# If our admin count is less than or equal to 1 (which daymn, if we're less 
	# than one admin account on the box, we've got serious issues and shouldn't
	# even be here today...) OR if the number of users with a securetoken is 
	# equal to the size of the array of users to be deleted...
	
	echo "Admin User Count is: $adminUserCount.  Array size is: '${#arrayOfUsers[@]}'"
	
	
	if [[ "$adminUserCount" -le "1" || "$adminUserCount" -eq "${#arrayOfUsers[@]}" ]] ; then
		# Welp, we're here now, now it's time to find a standard user with
		# a securetoken so we can elevate them for a second.
		
		# For all users who have a password on this machine (eliminates service accounts
		# but includes the _mbsetupuser and Jamf management accounts...)
		for user in $(/usr/bin/dscl . list /Users Password | /usr/bin/awk '$2 != "*" {print $1}'); do
			# Is the user an admin
			isUserAdmin=$(/usr/sbin/dseditgroup -m "$user" -o checkmember admin | /usr/bin/awk {'print $1'})
			if [ "$isUserAdmin" = "no" ]; then
				# Check for securetoken status
				secureTokenStatus=$(/usr/bin/dscl . -read /Users/"$user" AuthenticationAuthority | /usr/bin/grep -o "SecureToken")
				# If the account has a SecureToken, increase the securetoken counter
				if [ "$secureTokenStatus" = "SecureToken" ]; then
					# we found an eligible canidate
					elevateThisUser="$user"
					echo "We found an eligible user: $elevateThisUser"
					# No reason to look for more users... get me out of this loop!
					break;
				fi
			fi
		done
		
		if [[ -z $elevateThisUser ]]; then
			# Error checking for no eligible users:
			echo "Something went horribly wrong and there are no eligible standard users with a SecureToken found.\
				This means we'd be deleting all the users on this machine and leave it in an unstable state.  \
				Now, theoretically this should be okay because Jamf Connect can always make new users but \
				nobody could decrypt the FileVault drive without the PRK and Apple donna like that.  Aborting."
			exit 999;
		fi
		
	else
		echo "Something went horribly wrong and there are no admin users with a SecureToken found.  We should never, ever get to this point.  Aborting."
		exit 666;
	fi
	# Elevate our eligible account.
	echo "Elevating $elevateThisUser"
	/usr/sbin/dseditgroup -o edit -a "$elevateThisUser" -t user admin
fi

# For every user in the list, delete the user account with the Jamf binary
for user in ${arrayOfUsers[@]}; do
	
	echo "Deleting $user"
	############################################################################
	############################################################################
	### HERE'S WHERE YOU UNCOMMENT STUFF FOR DATA LOSS TO PURPOSELY HAPPEN!! ###
	############################################################################
	############################################################################
	# It's not that I don't trust you.  I don't trust anyone.
	echo "$JAMF_BINARY deleteAccount -username $user -deleteHomeDirectory"
	#$JAMF_BINARY deleteAccount -username "$user" -deleteHomeDirectory
done

# Demote our user back to standard user if needed
if [[ -z $elevateThisUser ]]; then
	echo "We didn't have to elevate a user in this case."
else
	echo "Demoting $elevateThisUser to standard account"
	/usr/sbin/dseditgroup -o edit -d "$elevateThisUser" -t user admin
fi

# Move the delete file for auditing purposes
/bin/mv "$DELETE_USER_TOUCH_FILE" "$CONFIRM_USER_TOUCH_FILE"

# Run a recon to clear out the extension attribute / smart computer group for 
# running this process.
$JAMF_BINARY recon 
