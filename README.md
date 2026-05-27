# Nightscout Menu Bar

A lightweight macOS menu bar application for displaying [Nightscout](https://github.com/nightscout/cgm-remote-monitor#nightscout-web-monitor-aka-cgm-remote-monitor) blood glucose data.

![Open Menu Bar](https://github.com/billreed85/NightscoutMenuBar/blob/main/Screenshots/menu-bar.png)

- [x] Displays real-time Nightscout blood glucose data in the menu bar
- [x] Displays recent blood glucose history on click
- [x] Automatically pulls units (mg/dL or mmol/L) from Nightscout
- [x] Options to configure glucose display (optionally include delta and time)
- [x] Add color-coded menu bar text (red/orange/green/yellow) based on BG value
- [x] Very low memory usage (~12 MB)

## Installation
* Download the latest version from the [releases page](https://github.com/mpangburn/Nightscout-Menu-Bar/releases) extract the .zip file.
* Move Nightscout Menu Bar.app to your Applications folder.
* Launch the application and enter your Nightscout URL when prompted.
* (Optional) Launch the application on startup by adding it to System Preferences > General > Login Items & Extensions.
* Note: macOS will block the app on first open because it is not notarized. To bypass this, right-click (or Control-click) the app and choose Open from the menu, then click Open in the dialog that appears. You only need to do this once.

## Notes
* This is generally unsupported. I am putting the update in a repo to help others who might want to use this solution, but it isn't in active development or support.
* Color Coding as follows: 
  * Below 55: Red
  * 55-69: Orange
  * 70-179: Green
  * 180-249: Yellow
  * 250 and above: Red

## Credits
This is an updated copy of the excellent NightscoutMenuBar by mpangburn (https://github.com/mpangburn/NightscoutMenuBar).
