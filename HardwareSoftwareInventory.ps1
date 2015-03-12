#Questo script consente di cercare in una unità organizzativa
#dei computer e di verificarne software e hardware.
#Verificare la configurazione di WMI e di avere i necessari permessi.
 
$strCategory = "computer";

# L'OU da cercare nel dominio
$objDomain = New-Object System.DirectoryServices.DirectoryEntry ("LDAP://OU=XXXXXXXXX,OU=XXXXXXXX,DC=XXXXXX,DC=local");

$objSearcher = New-Object System.DirectoryServices.DirectorySearcher; # AD Searcher object
$objSearcher.SearchRoot = $objDomain; # Set Search root to our domain
$objSearcher.Filter = ("(objectCategory=$strCategory)"); # Search filter

$colProplist = "name";
foreach ($i in $colPropList)
{
$objSearcher.PropertiesToLoad.Add($i);
}

$colResults = $objSearcher.FindAll() | sort @{ e = { $_.properties.name } }

foreach ($objResult in $colResults)
{
    $objComputer = $objResult.Properties;
    $Computers = $objComputer.name;

    $ipAddress = $pingStatus.ProtocolAddress;

# Pingo i computer
    $pingStatus = Get-WmiObject -Class Win32_PingStatus -Filter "Address = '$computer'";

    if($pingStatus.StatusCode -eq 0)
    
    {

        $Computers | Foreach-Object {

        	$computer=$_
        	$PC = gwmi  Win32_ComputerSystem -ComputerName $computer | Select Domain, Name, UserName
        	$OS = gwmi  Win32_OperatingSystem -ComputerName $computer | Select Caption, OSArchitecture, OtherTypeDescription, ServicePackMajorVersion, CSName, TotalVisibleMemorySize , Version
            $CPU = gwmi  Win32_Processor -ComputerName $computer | Select Architecture, DeviceID, Name
        	$BIOS = gwmi Win32_BIOS -computername $Computer | Select Name,SMBIOSBIOSVersion, Manufacturer
        	$RAM = gwmi  Win32_MemoryDevice -ComputerName $computer | Select DeviceID, StartingAddress, EndingAddress
        	$MB = gwmi  Win32_BaseBoard -ComputerName $computer | Select Manufacturer, Product, Version    
        	$VGA = gwmi  Win32_VideoController -ComputerName $computer | Select Name, AdapterRam
            $HDD = gwmi  Win32_DiskDrive -ComputerName $computer | select Model, Size
        	$VOLUMES = gwmi  Win32_LogicalDisk -Filter "MediaType = 12" -ComputerName $computer | Select DeviceID, Size, FreeSpace
            $CD = gwmi Win32_CDROMDrive | Select Id, Name, MediaType
            $NIC = gwmi Win32_NetworkAdapter -ComputerName $computer | ?{$_.NetConnectionID -ne $null}
            $DISPLAY = gwmi Win32_DesktopMonitor -ComputerName $computer | Select DeviceID, MonitorManufacturer, MonitorType, ScreenWidth, ScreenHeight 
        	$PRINTERS = gwmi Win32_PrinterDriver -ComputerName $computer | Select Name, SupportedPlatform
        	
        	
        # Formatto l'output	
        	
        	"`n"
            "------------------------------------------------------"
        	"NOME DELLA MACCHINA: `t" + $PC.Name + "." + $PC.Domain 
            "------------------------------------------------------"
        	"UTENTE LOGGATO: `t" + $PC.UserName 
            "------------------------------------------------------"
        	"`n"
        	
        	"CPU:"
        		$CPU | ft DeviceID, @{Label = "Architettura"; Expression = {switch ($_.Architecture) {
        		"0" {"x86"}; "1" {"MIPS"}; "2" {"Alpha"}; "3" {"PowerPC"}; "6" {"Intel Itanium"}; "9" {"x64"}}}},
        		@{Label = "Modello"; Expression = {$_.name}} -AutoSize
            
        	"MEMORIA FISICA: "
        		$RAM | ft DeviceID, @{Label = "Dimensione (MB)"; Expression = {
        		(($_.endingaddress - $_.startingaddress) / 1KB).tostring("F00")}} -AutoSize
            
        	"MEMORIA TOTALE: `n`t" + ($OS.TotalVisibleMemorySize / 1KB).tostring("F00") + " MB`n"
            
        	"MOTHERBOARD: "
            "`tProduttore: " + $MB.Manufacturer
            "`tModello:  " + $MB.Product
            "`tVersione: " + $MB.Version + "`n"

        	"BIOS: `t" + $BIOS.Manufacturer + " ver. "  + $BIOS.SMBIOSBIOSVersion + "`n"
        	  	
        	"SCHEDA VIDEO:"
            "`tModello: " + $VGA.Name
            #"`tVideo RAM: " + ($VGA.AdapterRam / 1MB).tostring("F00") + " MB`n"
            
        	"HARD DISK:"
        		$HDD | ft Model, @{Label="Dimensioni (GB)"; Expression = {($_.Size/1GB).tostring("F01")}} -AutoSize
            
        	"PARTIZIONI:"
        		$Volumes | ft DeviceID, @{Label="Dimensioni Totali(GB)"; Expression={($_.Size/1GB).ToString("F01")}},
        		@{Label="Spazio Libero(GB)"; Expression={($_.FreeSpace/1GB).tostring("F01")}} -AutoSize
            
        	"DISPOSITIVI OTTICI:"
        		$CD | ft Id, @{Label = "Dispositivo"; Expression = {$_.MediaType}},
        		@{Label = "Modello"; Expression = {$_.Name}} -AutoSize
            
        	"MONITOR: "
        		$DISPLAY | ft DeviceID, @{Label = "Produttore"; Expression = {$_.MonitorManufacturer}}, @{Label = "Tipo di dispositivo"; Expression = {$_.MonitorType}},
        		@{Label = "Ampiezza"; Expression = {$_.ScreenWidth}}, @{Label = "Altezza"; Expression = {$_.ScreenHeight}} -AutoSize
        		
        	"SCHEDE DI RETE:"
        		$NIC | ft NetConnectionID, @{Label="Stato"; Expression = {switch ($_.NetConnectionStatus) {
        		"0" {"Disconnected"}
        		"1" {"Connecting"}
        		"2" {"Connected"}
        		"3" {"Disconnecting"}
        		"4" {"Hardware not present"}
        		"5" {"Hardware disabled"}
        		"6" {"Hardware malfunction"}
        		"7" {"Media disconnected"}
        		"8" {"Authenticating"}
        		"9" {"Authentication succeeded"}
        		"10" {"Authentication failed"}
        		"11" {"Invalid address"}
        		"12" {"Credentials required"}
            }}},
            	@{Label="Interfaccia"; Expression={$_.name}}
            	
        	"SISTEMA OPERATIVO: `t" + $OS.Caption + " " + $OS.OtherTypeDescription + $OS.OSArchitecture+ " ver. " + $OS.Version + "`n"
            
        	"SERVICE PACK: `t" + "Service Pack " + $OS.ServicePackMajorVersion + " installato`n"

        	"STAMPANTI: "
        		$PRINTERS | ft Name, @{Label = "Piattaforma"; Expression = {$_.SupportedPlatform}} -AutoSize
        	
		}}
        
#Inizio identificazione software        
# Categoria del Registro
    $Branch='LocalMachine'

    # Sottocategoria del registro
    $SubBranch="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"

    $registry=[microsoft.win32.registrykey]::OpenRemoteBaseKey('Localmachine',$Computer)
    $registrykey=$registry.OpenSubKey($Subbranch)
    $SubKeys = $registrykey.GetSubKeyNames() |
        % {
            $ret = @{}
            $currentKey = $registry.OpenSubKey("$SubBranch\\$_")
            
            $ret.DisplayName = $currentKey.GetValue("DisplayName") 
            $ret.DisplayVersion = $currentKey.GetValue("DisplayVersion") 
            $ret.InstallDate = $currentKey.GetValue("InstallDate")
            
            $ret.DisplayName
            
            $ret
        } |
        ? {
            ($_.DisplayName -ne $null) -and ($_.DisplayName -notmatch '.*(aggiornament|update|hotfix).*')
        } |
        sort-object @{ e = { $_.DisplayName } }


"SOFTWARE INSTALLATO: 
"

    $subkeys |
    % { $_.DisplayName }
}