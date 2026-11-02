@echo off
cd "%~dp0"

INIEx.exe IsSectionExists /Sec=General ".\Test.ini"

pause&exit