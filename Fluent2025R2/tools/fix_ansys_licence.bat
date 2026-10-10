@echo off
chcp 65001 >nul
:: 关闭自动退出，任何情况最后都会pause
echo ======================================
echo  自动处理1055端口占用(NoMachine nxserver.bin)
echo ======================================
echo.

set "PID="
set "PROC_NAME="

:: 提取占用1055端口PID，排除TIME_WAIT(PID=0)
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":1055" ^| findstr /v "TIME_WAIT"') do (
    set "PID=%%a"
)

if not defined PID (
    echo [信息] 1055端口当前无占用PID，无需杀进程
    goto CHECK_PORT
)

echo [检测] 1055端口占用PID: %PID%

:: 查询进程名
for /f "tokens=1" %%b in ('tasklist ^| findstr %PID% 2^>nul') do (
    set "PROC_NAME=%%b"
)

echo [进程名] %PROC_NAME%

if /i "%PROC_NAME%"=="nxserver.bin" (
    echo [执行] 强制终止 nxserver.bin PID=%PID%
    taskkill /F /PID %PID%
    timeout /t 2 /nobreak >nul
    echo [完成] 已杀掉NoMachine进程
) else (
    echo [警告] 占用1055的不是nxserver.bin，不自动杀进程，请人工确认 PID:%PID% ^<%PROC_NAME%^>
)

:CHECK_PORT
echo.
echo [校验] 当前1055端口状态：
netstat -ano | findstr ":1055"

echo.
echo [提示] 端口清理完成，可以手动启动License服务
:: 如果要自动启动license，去掉下面注释，替换成你的程序路径
:: start "" "D:\YourLicensePath\license.exe"

echo.
echo =========执行完毕=========
:: 强制暂停，无论前面怎么走都会到这里
pause


# 在这里添加启动license命令
start "" "D:\OneDrive\桌面\ansyslmcenter.exe"

