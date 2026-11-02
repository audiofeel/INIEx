@echo off
cd "%~dp0"

INIEx.exe CalcTotalDiskSizeByte /MainSec=Datas /Key=Size ".\Test.ini"

pause&exit