#-------------------------------------------------------------------------------------------------------
#prerequisito all'esecuzione è avere installato speedtest.net cli https://www.speedtest.net/it/apps/cli
#-------------------------------------------------------------------------------------------------------

#salvo il nome cliente
$cliente = Read-Host -Prompt 'Inserisci il nome del cliente'

#estraggo la data come variabile
$data = Get-Date -format yyyy_MM_dd

#estraggo l'ip pubblico
$IpPubblico = (Invoke-WebRequest -Uri http://ifconfig.co/ip -TimeoutSec 60).Content.Trim() 

Write-Host "L'ip pubblico corrisponde a" $IpPubblico
Start-sleep 3

#scrivo cliente, ip e data nel log per informazione
"Test effettuato presso $cliente dall'ip pubblico $IpPubblico in data $data" | Out-File speedtest.txt -append

#estraggo la lista degli id dei server disponibili e la salvo temporaneamente (accetto il GDPR per evitare errori)
$servers = (speedtest --accept-gdpr -L) -replace "[^0-9]" , '' | Format-List | Out-String | ForEach-Object { $_.Trim()}  | Out-File servers.txt

# Leggo i server dal file
$serversList = Get-Content servers.txt

# Calcolo il numero totale di server
$totalServers = $serversList.Count

# Verifico lo speedtest su tutti i server disponibili e lo salvo su file
Write-Host "Inizio a verificare la conessione verso i server Ookla disponibili"

# Inizializzo la variabile per il conteggio dell'indice
$i = 0

# Ciclo attraverso ogni server
$serversList | ForEach-Object {
    $i++
    # Calcolo la percentuale di completamento
    $percentComplete = ($i / $totalServers) * 100

    # Visualizzo l'indicatore di progressione
    Write-Progress -Activity "Test effettuati:" -Status "$i su $totalServers" -PercentComplete $percentComplete

    # Eseguo il test di velocità e lo salvo nel file
    speedtest -s $_ | Out-File speedtest.txt -Append
}

# Rimuovo la lista degli id dei server
Remove-Item servers.txt

Write-Host "Test terminato, verificare il risultato nel file speedtest.txt"
