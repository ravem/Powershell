Import-Module MSOnline 
$Cred = Import-Clixml $env:c:\.....\admin.xml
Connect-MsolService -Credential $Cred
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $Cred -Authentication Basic -AllowRedirection
Import-PSSession $Session

<#
When the credential expire, you can save them with
Get-Credential | Export-CliXml -Path c:\.....\admin.xml
#>
