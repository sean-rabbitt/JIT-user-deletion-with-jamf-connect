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
#		data.

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

# — SRABBITT 21DEC2021

# Location of user deadpool list
DELETE_USER_TOUCH_FILE="/Library/Application Support/JAMF/Receipts/.userCleanup"
# Credit: Steve Wood

# Location of the user deadpool list after running script (confirmation file 
# for auditing)
CONFIRM_USER_TOUCH_FILE="/private/tmp/.userDeleted"

# Location of the Jamf binary
JAMF_BINARY="/usr/local/bin/jamf"

# Convert the space separated list of users into an array for looping through
listOfUsers=$(cat "$DELETE_USER_TOUCH_FILE")
arrayOfUsers=($listOfUsers)

# For every user in the list, delete the user account with the Jamf binary
for user in ${arrayOfUsers[@]}; do

	############################################################################
	############################################################################
	### HERE'S WHERE YOU UNCOMMENT STUFF FOR DATA LOSS TO PURPOSELY HAPPEN!! ###
	############################################################################
	############################################################################
	# It's not that I don't trust you.  I don't trust anyone.
	
	echo "$JAMF_BINARY deleteAccount -username $user -deleteHomeDirectory"
	#$JAMF_BINARY deleteAccount -username "$user" -deleteHomeDirectory
done

# Move the delete file for auditing purposes
#/bin/mv "$DELETE_USER_TOUCH_FILE" "$CONFIRM_USER_TOUCH_FILE"

# Run a recon to clear out the extension attribute / smart computer group for 
# running this process.
$JAMF_BINARY recon 
