### This is an archive for preservation purposes. all credits go to linden and the appropriate parties.

### NO SUPPORT PROVIDED BY MYSELF OR THE ORIGINAL AUTHOR.

### Requires [ESX Legacy aka 1.3](https://github.com/esx-framework/esx-legacy)

A fork of esx_doorlock, featuring improved performance and improved functionality.
<hr>
<p align="center"><img src='https://user-images.githubusercontent.com/65407488/114383355-cbd26c00-9bd0-11eb-9079-8c341e6824b1.png'></img></p>
<hr>

* Easily add and configure new doors! <a href='https://streamable.com/e290wk'>Example video</a>  
Use the `/newdoor` command to automatically create a new entry on the DoorList.  

* No more `SetEntityHeading` and `FreezeEntityPosition` natives.  
 Doors in range are assigned a doorHash, used with `AddDoorToSystem`.  
 Doors are assigned a state depending on if they are unlocked, locked, or locking with `DoorSystemSetDoorState`.  

* Garage doors and gates can be locked and will properly move into the correct position.  
If a player comes into range of an unlocked automatic door like this, it will open appropriately.  

* The state of the door is drawn into the world using NUI, meaning full customisation of the appearance and content.  
By default, icons from font-awesome are being displayed; but there is support for images with this method.  
Customisable audio playback! Modify the lock and unlock sound on a door-by-door basic.  

* Improved performance by utilising threads and functions where appropriate.  
Instead of updating the door list every X seconds, your position will be compared to where the last update occured and update when appropriate.  
The state of doors is only checked while in range, and the number of checks per loop depends on the state of the door.  

* Persistent door states! Door states are saved when the resource stops, then loaded back up on start.  
States.json will auto-generate if the file does not exist.  

* Config for both Community MRPD and gabz_MRPD  
Just choose which config file to use and delete the one you are not using.

* Set door access permissions  
Set multiple jobs to be authorised to use a door, with the minimum required grade `authorizedJobs = {['police']=0, ['offpolice']=0}`  
Allow the door to be lockpicked with `lockpick = true`  
Allow item authorisation with `items = {'key_master', 'key_lspd'}` etc.  

<hr>
<p align="center">https://streamable.com/oheu5e  
<img src="https://i.imgur.com/Sug2Nj5.jpg"/></p>


<p align='center'><img src="https://i.imgur.com/2Yz7Rtm.png"/></img></p>


<br><br><br>
<hr>

# esx_doorlock
This is a door lock script for ESX, which is used to lock certain doors that shouldn't be accessable by normal citizens.

This script was originally developed by Darklandz, later modified by Miss_Behavin and others.

# Legal
### License
esx_doorlock - door locks for ESX

Copyright (C) 2015-2018 ElPumpo / Hawaii_Beach

This program Is free software: you can redistribute it And/Or modify it under the terms Of the GNU General Public License As published by the Free Software Foundation, either version 3 Of the License, Or (at your option) any later version.

This program Is distributed In the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty Of MERCHANTABILITY Or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License For more details.

You should have received a copy Of the GNU General Public License along with this program. If Not, see http://www.gnu.org/licenses/.
<hr>
