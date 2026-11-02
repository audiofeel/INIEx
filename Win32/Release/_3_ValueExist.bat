@echo off
cd "%~dp0"

INIEx.exe IsValueExists /Sec=General /Key=Publisher ".\Test.ini"

pause&exit