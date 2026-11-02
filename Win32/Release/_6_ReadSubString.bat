@echo off
cd "%~dp0"

INIEx.exe ReadSubString /MainSec=Players /SubSec=Player1 /Key=Port ".\Test.ini"

INIEx.exe ReadSubString /MainSec=Players /SubSec="Player1|Stats" /Key=Donations ".\Test.ini"

pause&exit