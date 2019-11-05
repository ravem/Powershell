#Export System configuration data, Minidump folder and Event log files for troubleshooting

#Credits to 		https://serverfault.com/users/511250/blayderunner123
#			https://github.com/piesecurity
#			if your name missing in the credits drop me a line


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


Write-Host "Starting script..."


#Verify that user running script is an administrator

$IsAdmin=[Security.Principal.WindowsIdentity]::GetCurrent()
If ((New-Object Security.Principal.WindowsPrincipal $IsAdmin).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) -eq $FALSE)
    {
       "`nYOU ARE NOT A LOCAL ADMINISTRATOR. `nI'll try to launch this script as administrator..."
        # We are not running "as Administrator" - so we relaunch as administrator
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


#Checking if the output directory exists

Write-Verbose "Checking For Output Directory"
if (!(test-path $output)) 
	{
		Write-Verbose "Creating Output Directory $output"
		mkdir $output | Out-Null
	}


#Exporting System configuration

Write-Verbose "Checking system configuration"
	Get-ComputerInfo > $output\ComputerInfo.txt
	Get-ComputerInfo | Select-Object -ExpandProperty OSHotFixes > $output\Hotfixes.txt


#Exporting ACL configuration for application/s folder

Write-Verbose "Checking Applicatin folder ACL configuration"
$path = "c:\share" #define path to the shared folder
$reportpath ="$output\ACL.csv" #define path to export permissions report
#script scans for directories under shared folder and gets acl(permissions) for all of them
dir -Recurse $path | where { $_.PsIsContainer } | % { $path1 = $_.fullname; Get-Acl $_.Fullname | % { $_.access | Add-Member -MemberType NoteProperty '.\Application Data' -Value $path1 -passthru }} | Export-Csv $reportpath


#Archive the minidump folder

$source = "c:\windows\MiniDump"
$destination = "$output\minidump_folder.zip"

if(Test-path $destination) {Remove-item $destination}
	Compress-Archive -Path $source -DestinationPath $destination


#Export the Event log files as csv

if ($excludeEvtxFiles) {
    $excludeEvtxFiles | ForEach-Object {
        $LogName = "$LogTag-" + $_
        Write-Verbose "Dumping $_ Event Log to CSV"
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
            Write-Verbose "Previous Log doesn't have any records. No output will be produced"
        }
        
    }
}
Write-Verbose "Dump All Operational Logs Event Log With Tag: $logtag Excluding: $excludeEvtxFiles"

Get-WinEvent -ListLog * | where-object {$_.recordcount -gt 0} | where-object {$excludeEvtxFiles -notcontains $_.LogName} |
ForEach-Object {
    wevtutil epl $_.LogName  ($output + "\" + "$LogTag-" + ($_.LogName -replace "/","%4") +".evtx")
}

Write-Verbose "Adding Event Context to exported evtx files"
Get-ChildItem $output\*.evtx | ForEach-Object {
    wevtutil archive-log $_ /l:en-us
}

if ($IncludeAllEvtxFiles) {
    Write-Verbose "Gathering Evtx Files for all previously excluded files"
    $excludeEvtxFiles | ForEach-Object {
        wevtutil epl $_ ($output + "\" + "$LogTag-" + ($_ -replace "/","%4") +".evtx")
    }
    Write-Verbose "Adding Event Context to previously excluded files"
    $excludeEvtxFiles | foreach-object {
        Get-ChildItem ($output +"\" + $LogTag + "-" + $_ + ".evtx") | ForEach-Object {
            wevtutil archive-log $_ /l:en-us
        }
    }
}



