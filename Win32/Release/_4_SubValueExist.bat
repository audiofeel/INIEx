@echo off
cd "%~dp0"

INIEx.exe IsSubValueExists /MainSec=Players /SubSec=Player1 /Key=AccountID ".\Test.ini"

INIEx.exe IsSubValueExists /MainSec=Players /SubSec="Player1|Stats" /Key=Level ".\Test.ini"

pause&exit