#Export System configuration data, Minidump folder and Event log files for troubleshooting

#Credits to 				https://blogs.msdn.microsoft.com/virtual_pc_guy
#					https://github.com/piesecurity
#					if your name missing in the credits drop me a line


[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [string]$output=".\Logs\$env:computername",
    [Parameter(Mandatory=$false)]
    $excludeEvtxFiles = ((get-eventlog -list) | foreach-object{$_.log}),
    [Parameter(Mandatory=$false)]
    $logTag = $env:ComputerName,
    [Parameter(Mandatory=$false)]
    [switch]$IncludeAllEvtxFiles
)


#Get the location path for the script execution

$PSScriptRoot


#Verify that user running script is an administrator

# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 
# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole))
   {
   # We are running "as Administrator" - so change the title and background color to indicate this
   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host
   }
else
   {
   # We are not running "as Administrator" - so relaunch as administrator

   # Create a new process object that starts PowerShell
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   
   # Specify the current script path and name as a parameter
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   
   # Indicate that the process should be elevated
   $newProcess.Verb = "runas";
   
   # Start the new process
   [System.Diagnostics.Process]::Start($newProcess);
   
   # Exit from the current, unelevated, process
   exit
   }
 
# Let's start

Write-Host "Starting script..."


#Changing working directory

Set-Location -Path $PSScriptRoot


#Checking if the output directory exists

Write-Host "Checking For Output Directory "
if (!(test-path $output)) 
	{
		Write-Host "Creating Output Directory $output"
		mkdir $output | Out-Null
	}


#Exporting System configuration

Write-Host "Checking System Configuration"
	Get-ComputerInfo > $output\ComputerInfo.txt
	Get-ComputerInfo | Select-Object -ExpandProperty OSHotFixes > $output\Hotfixes.txt


#Exporting ACL configuration for application/s folder

Write-Host "Checking Application Folder ACL Configuration"
$path = "c:\share" #define path to the shared folder
$reportpath ="$output\ACL.csv" #define path to export permissions report
#script scans for directories under shared folder and gets acl(permissions) for all of them
dir -Recurse $path | where { $_.PsIsContainer } | % { $path1 = $_.fullname; Get-Acl $_.Fullname | % { $_.access | Add-Member -MemberType NoteProperty '.\Application Data' -Value $path1 -passthru }} | Export-Csv $reportpath


#Archive the minidump folder
Write-Host "Archiving Minidump files, if available"
$source = "c:\windows\MiniDump"
$destination = "$output\minidump_folder.zip"

if(Test-path $destination) {Remove-item $destination}
	Compress-Archive -Path $source -DestinationPath $destination


#Export the Event log files as csv

if ($excludeEvtxFiles) {
    $excludeEvtxFiles | ForEach-Object {
        $LogName = "$LogTag-" + $_
        Write-Host "Dumping $_ Event Log to CSV"
        Try {
            Get-EventLog $_ -ErrorAction Stop |
                select @{name="containerLog";expression={$LogName}},
                    @{name="id";expression={$_.EventID}},
                    @{name="levelDisplayName";expression={$_.EntryType}},
                    MachineName,
                    @{name="LogName";expression={$LogName}},
                    ProcessId,
                    @{name="UserId";expression={$_.UserName}},
                    @{name="ProviderName";expression={$_.source}},
                    @{Name="TimeCreated";expression={(($_.TimeGenerated).ToUniversalTime()).ToString('yyyy-MM-dd HH:mm:ssZ')}},
                    @{Name="Message";expression={$_.message -replace "\r\n"," | " -replace "\n", " | " -replace "The local computer may not have the necessary registry information or message DLL files to display the message, or you may not have permission to access them.",""}} | 
               Export-Csv -NoTypeInformation ($output + "\" + "$LogTag-" + $_ + ".csv")
        }
        Catch {
            Write-Host "Previous Log doesn't have any records. No output will be produced"
        }
        
    }
}
Write-Host "Dump All Operational Logs Event Log With Tag: $logtag Excluding: $excludeEvtxFiles"

Get-WinEvent -ListLog * | where-object {$_.recordcount -gt 0} | where-object {$excludeEvtxFiles -notcontains $_.LogName} |
ForEach-Object {
    wevtutil epl $_.LogName  ($output + "\" + "$LogTag-" + ($_.LogName -replace "/","%4") +".evtx")
}

Write-Host "Adding Event Context to exported evtx files"
Get-ChildItem $output\*.evtx | ForEach-Object {
    wevtutil archive-log $_ /l:en-us
}

if ($IncludeAllEvtxFiles) {
    Write-Host "Gathering Evtx Files for all previously excluded files"
    $excludeEvtxFiles | ForEach-Object {
        wevtutil epl $_ ($output + "\" + "$LogTag-" + ($_ -replace "/","%4") +".evtx")
    }
    Write-Host "Adding Event Context to previously excluded files"
    $excludeEvtxFiles | foreach-object {
        Get-ChildItem ($output +"\" + $LogTag + "-" + $_ + ".evtx") | ForEach-Object {
            wevtutil archive-log $_ /l:en-us
        }
    }
}



