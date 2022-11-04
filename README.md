# WireGuardEndpointmanager

WireGuard INIT Powershell script for use with MS Endpointmanager

## The problems

* WireGuard does not work well for unprivileged users.
* WireGuard does not work well with MGM solutions. MDM systems normally uninstall and reinstall programs for updates. WireGuard removes the config when uninstalled.

## The workaround

The script installs WireGuard from a MSI setup file. Then it creates scripts and tasks for managing the WireGuard connection and updates. Tasks are the workaround for the requirement, that a privileged user is required to manage WireGuard. The tasks have proper permissions to manage WireGuard and the script adds proper permissions to unprivileged users to be able to the tasks. This is a common trick used with MS Endpointmanager and perhaps other MDM solutions.

The following scripts are created by the script:

| Script | Purpose |
| --- | --- |
| WGstart.ps1 | Script used by the task "WireGuard start" |
| WGstart.cmd | Triggers the task "WireGuard start". Target for a desktop shortcut. |
| WGstop.cmd | Triggers the task "WireGuard stop". Target for a desktop shortcut. |

The following tasks are created by the script:

| Task | Purpose |
| --- | --- |
| WireGuard start | Downloads the WireGuard config from a web server and activates it. |
| WireGuard stop | Removes the WireGuard config. |
| WireGuard Update | Triggers WireGuard update at every system startup. |

In addition desktop shortcuts are generated to simplify the access for the users.

## Deployment

* Use IntuneWinAppUtil to create a package containing the WireGuard MSI and the wginit.ps1 script.
* In IntuneWinAppUtil use the MSI a "setup file" when asked for and **not** the Powershell script.
* Create a Win32 Windows app in Endpointmanager and select the package created.
* use the following install command:

      powershell.exe -ExecutionPolicy Bypass -File wginit.ps1 -msi "wireguard-amd64-x.x.x.msi" -tunnelname "SITENAME" -webpath "https://www.yourserver.com/sitename/wg" -webuser "user:password"

    | Parameter | Description |
    | ---  | --- |
    | -msi | Name of the WireGuard MSI file |
    | -tunnelname | Name of the WireGuardTunnel used by the service |
    | -webpath | URL where the WireGuard Config is located |
    | -webuser | Username and password for basic authentication at the web server|

    The name of the config file has to be the name of the client computer in upper case.
* Keep the proposed MSI uninstall command.
* As detection rule choose "manual" and select MSI as method.
* Assign it to a group.
