@echo off
cd "%~dp0"

INIEx.exe GetSubSectionsCount /MainSec=Players /RootOnly=true ".\Test.ini"

pause&exit