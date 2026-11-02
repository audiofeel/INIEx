@echo off
cd "%~dp0"

INIEx.exe ReadString /Sec=General /Key=Name ".\Test.ini"

pause&exit