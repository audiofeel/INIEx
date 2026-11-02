@echo off
cd "%~dp0"

INIEx.exe GetSubSectionKeysCount /MainSec=Players /SubSec=Player1 /RootOnly=true ".\Test.ini"

INIEx.exe GetSubSectionKeysCount /MainSec=Players /SubSec="Player1|Stats" /RootOnly=true ".\Test.ini"

pause&exit