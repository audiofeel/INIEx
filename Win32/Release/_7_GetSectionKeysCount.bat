@echo off
cd "%~dp0"

INIEx.exe GetSectionKeysCount /Sec=General ".\Test.ini"

pause&exit