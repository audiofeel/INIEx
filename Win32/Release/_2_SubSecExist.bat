@echo off
cd "%~dp0"

INIEx.exe IsSubSectionExists /MainSec=Players /SubSec=Player1 ".\Test.ini"

INIEx.exe IsSubSectionExists /MainSec=Players /SubSec="Player1|Stats" ".\Test.ini"

pause&exit