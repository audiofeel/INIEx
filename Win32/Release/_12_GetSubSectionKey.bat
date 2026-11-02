@echo off
cd "%~dp0"

INIEx.exe GetSubSectionKey /MainSec=Players /SubSec=Player1 /Idx=0 /RootOnly=true ".\Test.ini"

INIEx.exe GetSubSectionKey /MainSec=Players /SubSec="Player1|Stats" /Idx=0 /RootOnly=true ".\Test.ini"

pause&exit