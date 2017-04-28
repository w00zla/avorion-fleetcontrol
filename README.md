# FleetControl

![compatibility-beta](https://img.shields.io/badge/avorion--beta-v0.11.0.7857-blue.svg) 

### Description

This mod tries to make the management of a ship fleet in Avorion easier and to provide additional features like custom ship orders.  
In the first place, the mod provides an UI window which you can use to:
- assign fleet ships to groups 
- give orders to complete ship-groups or single ships
- configure the look and feel of the UI *(group-names, colors etc.)*
- enable highly customizable HUD display *(so you have the info about your ships right at the screen!)*

#### Screenshots

*Fleet Orders:*  
![screenshot](http://gdurl.com/EMfY)

*Fleet Groups:*  
![screenshot](http://gdurl.com/hZod)

*Configuration:*  
![screenshot](http://gdurl.com/uIjP) ![screenshot](http://gdurl.com/fxh1)

*HUD Example:*  
![screenshot](http://gdurl.com/IUcO)

##  COMMANDS

### /fleetcontrol   
Enables/disables the Fleet Control UI *(menu item & window)*.

*Usage:*   
`/fleetcontrol`  
`/fleetcontrol enable`   
`/fleetcontrol disable`

### /fleetcontrolconfig   
Command to change advanced server-configurations used by Fleet Control UI.

*Usage:*   
`/fleetcontrolconfig updatedelay <NUMBER>`   
`/fleetcontrolconfig enablehud <BOOLEAN>`   

*Parameters:*  
`<NUMBER>` = any positive number or `0`  
`<BOOLEAN>` = `true` or `false`


##  INSTALLATION
Download the ZIP file of the **[latest release](https://github.com/w00zla/avorion-fleetcontrol/releases)** and extract it to `<Avorion>\data\` directory.  
*No vanilla script files will be overwritten, so there should be no problems with other mods!*

**Server/Client:** The scripts are _**server- and client-side**_.  
*All files have to be available on the client for multiplayer games!!*

## HOW TO

### First use in a galaxy
*(following instructions have to be done once per galaxy and player)*

To enable the Fleet Control UI for yourself, you must enter following command into chat:  
**`/fleetcontrol`**  

This will create a new menu icon which you can use to show the UI window:  
![screenshot](http://gdurl.com/YPDI)

If you want to hide/disable the UI (or remove and uninstall the script), then use:  
**`/fleetcontrol disable`**

### Advanced server configuration
These configs will help server admins and curious users to tweak performance values and en-/disable features of the UI.  

__*updatedelay*__:   
- defines the delay (in milliseconds) for the update of ship-states etc. in UIs and HUDs of players  
- possible values: 0 - 99999999
- default: 750

__*enablehud*__:   
- can be used to disable the display the Fleet Control HUD globally for a server
- possible values: `true` or `false`
- default: true

### Integration of custom orders/other order mods
The mod does not bring its own version of the default ship orders, instead it calls functions in the vanilla "__*craftorders.lua*__" script.   
If you or one of the mods you are using modified this script, this version will also be used by Fleet Control! In most cases there should be no issues with a modified "__*craftorders.lua*__", but be aware of potential problems here *(please PM me in this case)*!

*Easy integration of additional custom commands added by other mods or yourself is planned for the near future!* 

### Known Issues/Limitations
- **Only ships in player's current sector are listed as selectable ships in several places:**  
this is due to game engine limitations and cannot be changed at the moment  
*(just visit every sector your ships are in, the UI remembers all your ships once seen)*
- **Only states of ships in player's current sector are available:**  
this is due to game engine limitations and cannot be changed at the moment  
- **Destruction and sector-change of a ship which is not in player's current sector is not recognized**  
this is planned to be improved in the near future (maybe even not possible at the moment)
- **Selecting order "Escort Me" results in order "Escort Ship":**  
currently, its not possible to get the ships (escort) target via script, so the more general order is displayed

### Planned Features/TODOs
- integration/configuration of other order mods like "Haul Goods" etc.
- integration of additional custom orders
    * order "Escort Chain/Polonaise"
    * order "Collect Loot"
- improvements for multiplayer:
    * improved state-handling for out-of-sector ships
    * recognize if ships are controlled by other players
- add sounds for actions like "give order" (with config)
- notifications for orders and other events (with config)
- more ship state infos in UI and HUD, like hull, shield, velocity etc.
- better HUD alignments based on actual HUD size
- warning on improper player jump-distances when escorted by ships *(required API requested from koonschi, waiting...)*
- info on current target for states like "Escort" *(required API requested from koonschi, waiting...)*