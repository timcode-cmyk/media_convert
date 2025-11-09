@echo off
setlocal enabledelayedexpansion

REM 获取当前脚本所在目录
set "DIRECTORY=%~dp0"

REM 创建输出目录
set "OUTPUT_DIR=%DIRECTORY%output"
if not exist "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
)

REM 外部 logo 路径（相对于脚本目录）
set "LOGO_PATH=%DIRECTORY%bin\Hailuo.png"

REM 目标分辨率（竖屏）
set "TARGET_W=1080"
set "TARGET_H=1920"

REM 模糊/logo 参数与缩放目标（竖屏：1080x1920）
set x=590
set y=1810
set logox=475
set logoy=95

REM 遍历文件夹中的所有文件
for %%F in ("%DIRECTORY%\*") do (
    REM 检查是否为文件
    if exist "%%F" (
        REM 获取文件扩展名
        set "EXT=%%~xF"
        set "BASENAME=%%~nF"

        REM 转换扩展名为小写
        set "EXT=!EXT:.=!"
        set "EXT=!EXT:~0,4!"

        REM 处理视频文件
        if /I "!EXT!"=="mp4" (
            call :ProcessVideo "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="mkv" (
            call :ProcessVideo "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="avi" (
            call :ProcessVideo "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        ) else if /I "!EXT!"=="mov" (
            call :ProcessVideo "%%F" "!BASENAME!" "!OUTPUT_DIR!"
        )
    )
)
echo Processing complete!
goto :EOF

:ProcessVideo
REM 参数: %1=原文件路径 %2=文件名(无扩展) %3=输出目录
echo Processing video: %~2
bin\ffmpeg -y -i "%~1" -i "!LOGO_PATH!" -filter_complex "[0:v]scale=%TARGET_W%:%TARGET_H%:force_original_aspect_ratio=increase,crop=%TARGET_W%:%TARGET_H%,setsar=1[base];[base]split=2[bg][tmp];[tmp]crop=%logox%:%logoy%:%x%:%y%,boxblur=10[blurred];[bg][blurred]overlay=%x%:%y%:format=auto[tmp2];[1:v]scale=%logox%:%logoy%[logo];[tmp2][logo]overlay=%x%:%y%:format=auto[outv]" -map "[outv]" -map 0:a? -c:v libx264 -crf 20 -preset medium -c:a copy -movflags +faststart "%~3\%~2_c.mp4"
echo Video saved as: %~3\%~2_dnxhr_hqx.mov
exit /b