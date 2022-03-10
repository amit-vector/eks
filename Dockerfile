# Base Image
FROM mcr.microsoft.com/dotnet/framework/aspnet:4.7.2-windowsservercore-ltsc2019

# Install Chocolaty
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Microsoft Visual C++ Redistributable (used by oracle client) via chocolatey
RUN ["choco", "install", "vcredist2013", "-y", "--allow-empty-checksums"] 

# Copy required files
COPY ["EmailAlerts/bin/Debug/", "/Service/"]
COPY ["ODAC193Xcopy_x64.zip", "/Service/"]

RUN powershell -Command "expand-archive -Path 'c:\Service\ODAC193Xcopy_x64.zip' -DestinationPath 'c:\Service\oracleInstall'"

#WORKDIR "C:/Service/"
WORKDIR "C:/Service/oracleInstall"

# Install Oracle Client
RUN ".\install.bat odp.net4 c:\oracle odac true;"

# fix - error 0175: The specified store provider cannot be found in the configuration, or is not valid.
WORKDIR c:/Oracle/ODP.NET/bin/4

RUN ./oraprovcfg.exe /action:config /product:odp /frameworkversion:v4.0.30319 /providerpath:C:\Oracle\ODP.NET\bin\4\Oracle.DataAccess.dll

# Set path to oracle client
RUN "[Environment]::SetEnvironmentVariable(\"Path\", $env:Path + \";C:\\oracle\\\", [EnvironmentVariableTarget]::Machine)"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

WORKDIR "C:/Service/"

# install windows email service
RUN "C:/Windows/Microsoft.NET/Framework64/v4.0.30319/InstallUtil.exe" /LogToConsole=true /ShowCallStack EmailAlerts.exe; \
    Set-Service -Name "\"EmailAlerts\"" -StartupType Automatic; \
    Set-ItemProperty "\"Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\EmailAlerts\"" -Name AllowRemoteConnection -Value 1

ENTRYPOINT ["powershell"]
CMD Start-Service \""EmailAlerts\""; \
    Get-EventLog -LogName System -After (Get-Date).AddHours(-1) | Format-List ;\
    $idx = (get-eventlog -LogName System -Newest 1).Index; \
    while ($true) \
    {; \
    start-sleep -Seconds 1; \
    $idx2  = (Get-EventLog -LogName System -newest 1).index; \
    get-eventlog -logname system -newest ($idx2 - $idx) |  sort index | Format-List; \
    $idx = $idx2; \
    }

	