# JIT-user-deletion-with-jamf-connect
 A workflow to delete any account created by Jamf Connect in the last X minutes

Just-in-time user… deletion?
Or, how I eliminated universally deployed admin accounts from my fleet and learned to love Jamf Connect

One of the great features of Jamf Connect is the ability to make a user account on demand simply by logging into the Mac.  Jamf Connect will read an attribute from our identity provider to determine if a user should be an Administrator or get standard rights.

For our security conscious Mac Admins out there in the world (which should be all of you, I hope), this means that we can completely eliminate the “one ring to rule them all” type of admin accounts deployed to the fleet, usually stuck with some “secret” password that everyone in the company ends up knowing eventually.  (I’m looking at you, `Jamf1234`.)

Now this is great, but then we run into trouble - we have a user account on a machine that we just needed for 5 minutes to fix a one-off type of problem, and in two years when we go back to that machine to fix another random one-off problem, now we have a user account where the admin has NO idea what the local user password is and everything explodes.

Until now.

What the workflow does:
1. An administrator makes an account just-in-time with the Jamf Connect login mechanism. Could be a one-off fix, could be resetting a forgotten local password.  Whatever it is, admin is done, time to clean up like a good Scout.
2. The administrator opens Jamf Self Service and runs a Policy - this runs a script that looks for any account created by Jamf Connect in the last 60 minutes (which you can adjust), and drops a touchfile into `/private/tmp` with a list of local short names that need to be deleted.  The script then runs a `jamf recon` command to update the computer inventory record with…
3. An extension attribute that looks for the existence of this list of users in the deadpool.  This extension attribute is the target of…
4. A Smart Computer Group which has all the computers with this deadpool file that exists which is the target of a scope of…
5. A Policy which is set to run with an Execution Frequency of “Ongoing”, a trigger of “Reoccuring Check-in”, and scoped to the Smart Computer Group above which will run a script that…
6. Looks for the deadpool list, runs a `jamf deleteAccount` command for every user in the list, moves the deadpool list out to a separate file to make sure the script ran, and runs another `jamf recon` command to clear the extension attribute that removes the computer from the scope of the policy.