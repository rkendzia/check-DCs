#Ce script a été réalisé par Raphaël Kendzia
#Import du module active directory
Import-Module activedirectory


#region Variables
param(
    [string]$Client
    )
$DCs = Get-ADDomain
$AllDCs = Get-ADDomainController -Filter *


$DateOld = (get-date).AddDays(-60)
$DatePassword90 = (get-date).AddDays(-90)

$DatePassword180 = (get-date).AddDays(-180)
$users = Get-ADUser -Filter * -Properties *

if ($htmlfile -eq $null ) {$htmlfile= ".\Rapport"+"."+ $Client+".html" }

#endregion 



$HeadHTML=('
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewporst" content="width=device-width, initial-scale=1.0">
    <title>Rapport DC </title>
    <style>
        h1 {

           color: rgba(15, 8, 119, 0.76);
        }
        h2 {

            color: blue;
         }
         h3 {

            color: #1E90FF;
         }
         h4 {

            color: #7B68EE;
         }
        TABLE {TABLE-LAYOUT: fixed; border:0.1 solid gray ; FONT-WEIGHT: normal; FONT-SIZE: 8pt;  FONT-FAMILY: Tahoma; ; border : 1}
		td{ VERTICAL-ALIGN: TOP; FONT-FAMILY: Tahoma ;TEXT-ALIGN: center;border:0.1 solid gray ;padding 0px 0px}
		th {VERTICAL-ALIGN: TOP; TEXT-ALIGN: center;BACKGROUND-COLOR: #0066FF;COLOR: white ;}
				
		tr{border:0.1; padding 0px 0px}
		tr:nth-child(even) {background: #6dc2e9}
		tr:nth-child(odd) {background: #FFF}
          }  
        body {DISPLAY: block; FONT-WEIGHT: normal; FONT-SIZE: 8pt; RIGHT: 10px; COLOR: Black; FONT-FAMILY: Tahoma; POSITION: absolute;}
        p.ok {FONT-FAMILY: Tahoma; FONT-SIZE: 10pt;COLOR:green}
        p.err {FONT-FAMILY: Tahoma; FONT-SIZE: 10pt;COLOR:red}
        
            


    </style>
</head>
<div style="text-align:center;background-color: #0B67AB">
 <div style="display:inline-block; text-align:left; font-size:12pt;
             background-color:white; 
             padding: 20px;
             border:2px solid rgb(0,0,0);
             width: 60%;
             min-height: 1000px;">
 

<body>
    <h1>Rapport de conformité des DCs de '+$Client+'</h1>


    
    Date du rapport '+(get-date -Format D) +' <br>
')






#region Requete

$Computer = Get-ADComputer -Filter * -Properties * | select  name, lastlogondate, operatingsystem | ? { ($_.lastlogondate -lt $DateOld)  }
$Computer  | Export-Csv -Path c:\audit\DevicesObsoletes.csv

$usersLastConnection = $users | select name, lastlogondate | ? { $_.lastlogondate -lt $DateOld }
$usersLastConnection | Export-Csv -Path c:\audit\UsersInactifs.csv

$TotalPasswordExpired = $users | select name, PasswordNeverExpires | ? { $_.PasswordNeverExpires -eq $true }
$TotalPasswordExpired   | Export-Csv -Path c:\audit\PasswrdNeverExpired.csv



$PasswordLastModification90 = $users | select  name, PasswordLastSet | ? { $_.PasswordLastSet -lt $DatePassword90}

$PasswordLastModification180 = $users | select  name,  PasswordLastSet | ? { $_.PasswordLastSet -lt $DatePassword180}
#endregion

$BodyHtml += @("
<H2>Inntroduction</H2>
<p>Il rapporte différents points de la sécurité de l'active directory et des contrÃ´leurs de domaine.</p>
")

#region Liste des DCs

$BodyHtml += @("
<H2>Vérification des contrÃ´leurs de domaine</H2>
<caption align='center'>Voici la liste des cÃ´ntroleur de domaines:</caption>
")

$temp += @("
<table border ='1' >
    <tr>
        <th>DCs</th>
        <th>OS</th>
        <th>Dernier Reboot</th>
        <th>Marque</th>
        <th>Modèle</th>
        <th>Nombre de processeurs</th>
        <th>Nombre de processeurs logiques</th>
        <th>Mémoire</th>
    </tr>
        ")
        $(Get-ADDomainController -filter *) | % {
        $NaDCs = $_.name
        $OSInfo = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $NaDCs  | select  @{label="Dernier reboot :";Expression={$_.ConvertToDateTime($_.Lastbootuptime)}}
        $OSInfo2 = Get-CimInstance -ClassName win32_operatingsystem -ComputerName $NaDCs  
        
        $InfoSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $NaDCs 
	    #$Mem = Get-CimInstance -Class CIM_PhysicalMemory -ComputerName $NaDCs  | Select-Object @{Name="RAM size(GB)";Expression={("{0:N2}" -f($_.Capacity/1gb))}}
          $mem =  (Get-CimInstance -ClassName 'Cim_PhysicalMemory' -ComputerName $NaDCs | Measure-Object -Property Capacity -Sum).Sum/1GB
      
        $temp +=  "<tr><td>"+$NaDCs+"</td><td>"+$OSInfo2.caption+"</td><td>"+$OSInfo.'Dernier reboot :'+"</td><td>"+$InfoSystem.Manufacturer+"</td><td>"+$InfoSystem.Model+"</td><td>"+$InfoSystem.NumberOfProcessors+"</td><td>"+$InfoSystem.NumberOfLogicalProcessors+"</td><td>"+$mem+"</td></tr>"
        }
  $temp += @("  
</table>

")

$BodyHtml += $temp
$temp =$null
#endregion
#region réplication

$BodyHtml += @("
<H3>Vérification de la réplication</H3>
<p>Nous vérifions l'état de la réplication entre les contrÃ´leurs de domaine</p>

")

$temp += @("
<p>Voici l'état de la réplication</p></br>
<table border='1'>
    <tr>
        <th>Nom du serveur</th>
        <th>Dernière réplication</th>
        <th>Erreurs de réplication</th>
    <tr>
")

$AllDCs |% {
$NameDCs = $_.hostname

$CheckErrors = Get-ADReplicationPartnerMetadata -Target $NameDCs | select -ExpandProperty lastreplicationresult


$CheckLastReplication = Get-ADReplicationPartnerMetadata -Target $NameDCs | select -ExpandProperty LastReplicationSuccess

if ( $CheckErrors -eq 0) {
    
    $temp += "<tr><td>"+$NameDCs+"</td><td>"+$CheckLastReplication+"</td><td bgcolor='green'>"+$CheckErrors+"</td></tr>"
    }
else {
    $temp += "<tr><td>"+$NameDCs+"</td><td>"+$CheckLastReplication+"</td><td bgcolor='red'>"+$CheckErrors+"</td></tr>"
    }






}

$temp += "</table>"


$BodyHtml += $temp
$temp = $null
#endregion

#region sysvol

$BodyHtml += "<H3>Vérification du Sysvol</H3>"


$AllDCs | % {
$NameDCs = $_.hostname
$CheckDcdiag = & Dcdiag /e /test:sysvolcheck /test:advertising /s:$NameDCs
$temp += "</br><H4>Test de: "+$NameDCs+"</H4></br>"
foreach ( $lines in $CheckDcdiag) {
    
    $temp += "<p bgcolor='green'>"+$lines+"</p>"
    }

}

$BodyHtml += $temp
$temp = $null
#endregion


#region backup ad

$BodyHtml += "<H3>Vérification du backup active directory</H3>"




$Checkbackup = & repadmin /showbackup


    foreach ( $lines in $Checkbackup ){
        $temp += "<p bgcolor='green'>"+$lines+"</p>"
        }
    



$BodyHtml += $temp
$temp = $null
#endregion
#region espace disque

$BodyHtml += @("

<H3>Vérification de l'espace dique</H3>
")

foreach ($serveur in $AllDCs) {
    $NameDCs = $serveur.hostname
                                        $temp += @("
            <H4>Nom du serveur"+$NameDCs+"</h4>
            <table border='1'>
                <tr>
                    <th>Nom du disque</th>
                    <th>Taille</th>
                    <th>Occupation</th>
                    <th>libre</th>
                </tr>
                ")
     $BodyHtml += $temp
     $temp =$null
       $Disque = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $NameDCs | where {$_.drivetype -eq "3"}
        

                                                                                                            $Disque | % { 
		    $Nom = $_.DeviceID
            $type = $_.DriveType
		    $Taille = [math]::round($_.Size/ 1gb,2)
		    $EspaceLibre = [math]::round($_.Freespace / 1gb,2)
		    $Occupation = [math]::round(($Taille - $EspaceLibre) *100 / $Taille,2)
		    $Libre = [math]::round(($EspaceLibre / $Taille)*100,2)
            
            
                
		        
                
		            if ($Libre -lt 10) {
                        
                        $temp +="<tr><td>"+$Nom+"</td><td>"+$Taille+"</td><td>"+$Occupation+"</td><td bgcolor='red'>"+$Libre+"</td></tr>"
                         $BodyHtml += $temp
 $temp =$null
			            
		             }else{
			                $temp +="<tr><td>"+$Nom+"</td><td>"+$Taille+"</td><td>"+$Occupation+"</td><td bgcolor='green'>"+$Libre+"</td></tr>"
                             $BodyHtml += $temp
 $temp =$null

                        }
           
    }
    
        $BodyHtml += "</table>"
    }

    
#endregion

#region HotFix
$BodyHtml += "<H3>Vérification des mises Ã  jour</H3>"
foreach ($serveur in $AllDCs) {
    $LastHotFix = gwmi win32_quickfixengineering -ComputerName $serveur |?{ $_.installedon } | sort @{e={[datetime]$_.InstalledOn}} | select Description, HotFixID, InstalledOn -last 1 
   # Get-WmiObject -Class Win32_QuickFixEngineering -ComputerName $serveur  |sort InstallDate -Descending | select  Description, HotFixID, InstallDate -First 1
    
    
        $temp += @("
                <H4>Nom du serveur"+$NameDCs+"</h4>
                <table border='1'>
                    <tr>
                        <th>Description</th>
                        <th>date</th>
                        <th>HotFix              
                    </tr>

                    <tr>
                        <td>"+$LastHotFix.Description+"</td>
                        <td>"+$LastHotFix.InstalledOn+"</td>
                        <td>"+$LastHotFix.HotFixID+"</td>
                    </tr>
                </table>
                ")
     $BodyHtml += $temp
     $temp =$null



    }

#endregion

#region Modication du mot de passe
$BodyHtml += @("

<H3>Dernière modification du mot de passe</H3>
<table broder='1'>
    <tr>
        <th>avant 90 jours</th>
        <th>avant 180 jours</th>
    </tr>

")
$count180 =$null
$count90 = $null

$users | % {
    $name = $_.samaccountname
    $passLastSet = $_.PasswordLastSet

    if ( Get-ADUser -Identity $name -Properties * | select  name, PasswordLastSet | ? { $_.PasswordLastSet -lt $((get-date).AddDays(-180))}) {
    
        $count180 +=1
        Add-Content -Value $name  -Path C:\audit\PasswordLastSet180.csv
        }

    elseif ( Get-ADUser -Identity $name -Properties * | select  name, PasswordLastSet | ? { $_.PasswordLastSet -lt $((get-date).AddDays(-90)) } ) {
        Add-Content -Value $name -Path C:\audit\PasswordLastSet90.csv
        $count90 +=1
        }


}

$BodyHtml += @("

    <tr>
        <td bgcolor='orange'>"+$count90+"</td>
        <td bgcolor='red'>"+$count180+"</td>
    </tr>
</table>
")
#endregion


#region modification du changement de mot passe Administrateur

$BodyHtml += @("

<H3>changement de mot passe Administrateur</H3>
<table broder='1'>
    <tr>
        <th>Dernière modification</th>
    </tr>

")
$PassModify = Get-ADUser -Identity administrateur -Properties * | select -ExpandProperty  PasswordLastSet

 
    $BodyHtml += "<tr><td>"+$PassModify+"</td></tr></table>"
#endregion

#region modification du changement de mot passe Administrateur

$BodyHtml += @("

<H3>changement de mot passe Kerberos</H3>
<table broder='1'>
    <tr>
        <th>Dernière modification</th>
    </tr>

")
$PassModify = Get-ADUser -Identity krbtgt -Properties * | select -ExpandProperty  PasswordLastSet

 
    $BodyHtml += "<tr><td>"+$PassModify+"</td></tr></table>"
#endregion

#region Mot de passe n'expire jamais
$BodyHtml += @("

<H3>Mot de passe qui n'expire jamais</H3>
<table broder='1'>
    <tr>
        <th>Nombre</th>
        
    </tr>
        <tr>
        <td bgcolor='red'>"+$TotalPasswordExpired.Count+"</td>
          </tr>
</table>

")
#endregion



#PasswordLastSetModification 


#PasswordNeverExpires
#PasswordLastSet

$endhtml += @("

    
</body>
 </div>
 </div>
</html>


")

$HeadHTML+$BodyHtml+$endhtml | Out-File $HtmlFile -Encoding utf8 -Force
$BodyHtml = $null