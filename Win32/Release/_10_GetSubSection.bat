@echo off
cd "%~dp0"

INIEx.exe GetSubSection /MainSec=Players /Idx=0 /RootOnly=true ".\Test.ini"

INIEx.exe GetSubSection /MainSec=Players /Idx=1 /RootOnly=true ".\Test.ini"

pause&exit