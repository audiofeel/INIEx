@echo off
cd "%~dp0"

INIEx.exe GetSectionKey /Sec=General /Idx=0 ".\Test.ini"

INIEx.exe GetSectionKey /Sec=General /Idx=1 ".\Test.ini"

pause&exit