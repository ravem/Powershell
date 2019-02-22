#Convert the password and store it securely with the command on the following line
#read-host -assecurestring | convertfrom-securestring | out-file C:\securedfile.txt
#The script for login
$Username = "admin@yourdomain.com"
$password = cat  C:\securedfile.txt | convertto-securestring
$LiveCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $LiveCred -Authentication Basic -AllowRedirection
Import-PSSession $Session
