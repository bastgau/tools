
Param(
    #Definition du chemin du fichier de log et de la date 
   [Parameter(Mandatory=$true)]
   [String]$LogFile = "/tmp/file.log",
   [Parameter(Mandatory=$true)]
   [String]$PipelineName = "main"
)

# Paramètres pour se connecter à Azure Data Factory.
$TenantID="xxxx"
$ClientID="xxxx"
$ClientSecret="xxxx"
$SubscriptionID="xxxx"

$DataFactoryName="xxxx"
$ResourceGroupName="xxxx"

$Parameters = @{
    "wait_option" = "Wait5"
}

$TimeStep = 1 # A quelle fréquence est controlé le statut du job (secondes).
$TimeStepStatusDisplay = 5 # A quelle fréquence est écrit dans les logs le statut du job (secondes).

#Fonction qui va ecrire les logs dans le fichier
Function LogWrite {
    Param (
        [string] $Logstring
    )
    $LogDate = (Get-Date).ToString("HH:mm:ss")
    "$LogDate - $Logstring" | Out-File -Encoding utf8 -Append -NoClobber -Force -FilePath $LogFile
    write-host $LogDate - $Logstring
}

class ComplexException : Exception {
    [array] $Messages
    ComplexException($Message) : base($Message[0]) {
        $this.Messages = $Message
    }
}

LogWrite("#### DEBUT DU SCRIPT ####")

$ExitStatus = 0

try {

    # Controle de l'existence des modules.
    LogWrite("> Controle de l'existence des modules.")

    $LineQty = Get-Module -Name Az.Accounts -ListAvailable | Measure-Object –Line | % Lines
    
    if($LineQty -eq 1) {
        LogWrite("Tous les modules existent.")
    }
    else {
        throw [ComplexException]::new(@("Le module Az n'est pas installé.", "Le module peut être installé avec la commande : 'Install-Module Az'."))
    } 

    # Connexion a Azure.
    LogWrite("> Connexion a Azure.")

    # On demande a ne pas stocker les informations en local.
    $Result=Disable-AzContextAutosave | % Mode

    # On récupère les credentials pour se connecter sur Azure.
    $UserPasswordSecured = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
    $pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientID, $UserPasswordSecured

    Connect-AzAccount -Credential $pscredential -Subscription $SubscriptionID -Tenant $TenantId -ServicePrincipal | % Account

    LogWrite("La connexion à Azure a ete effectuee.")

    # Lancement du pipeline ADF.
    LogWrite("> Lancement du pipeline ADF.")

    $PipelineRunId=Invoke-AzDataFactoryV2Pipeline -DataFactoryName $DataFactoryName -ResourceGroupName $ResourceGroupName -PipelineName $PipelineName -Parameter $Parameters -erroraction 'silentlycontinue'
    LogWrite("Une execution du Pipeline '$PipelineName' a ete demandee.")

    if( !(($PipelineRunId | Measure-Object –Line | % Lines) -eq 1) ) {
        throw [ComplexException]::new(@(("Le Pipeline ne peut pas etre declenche."), ($Error.Exception.Message | ConvertTo-Json)))
    }

    while ($True) {

        $StatusReturned = Get-AzDataFactoryV2PipelineRun -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineRunId $PipelineRunId

        if ($StatusReturned) {

            if($StatusReturned.Status -eq "Cancelled" -or $StatusReturned.Status -eq "Canceling") {
                throw [ComplexException]::new(@(("Le job a ete annule au bout de " + $TimeRunningMinutes + "."), ("Son statut est : " + $StatusReturned.Status)))
            }            

            if($StatusReturned.Status -eq "Failed") {
                throw [ComplexException]::new(@(("Le job a echoue au bout de " + $TimeRunningMinutes + "."), ("Son statut est : " + $StatusReturned.Status)))
            }

            if ( ($StatusReturned.Status -ne "InProgress") -and ($StatusReturned.Status -ne "Queued") ) {
                break
            }

            if ($StatusReturned.Status -eq "InProgress") {
                $TimeRunning = $IncrementRunning*$TimeStep
                $TimeRunningMinutes =  [timespan]::fromseconds($TimeRunning).ToString("hh\:mm\:ss")

                If (!($IncrementRunning % $TimeStepStatusDisplay)) {
                    LogWrite("Le job est en cours d'execution depuis " + $TimeRunningMinutes)
                }

                $IncrementRunning++
            }

            if ($StatusReturned.Status -eq "Queued") {
                $TimeQueued = $IncrementQueued*$TimeStep
                $TimeQueudMinutes =  [timespan]::fromseconds($TimeQueued).ToString("hh\:mm\:ss")

                If (!($IncrementQueued % $TimeStepStatusDisplay)) {
                    LogWrite("Le job est en attente depuis " + $TimeQueudMinutes)
                }

                $IncrementQueued++
            }
        
        }

        Start-Sleep -Seconds $TimeStep

    }

    If ( !($StatusReturned.Status -eq "Succeeded") ) {
        throw [ComplexException]::new(@(("Impossible de verifier si le job s'est correctement termine."), ("Son statut est : " + $StatusReturned.Status)))
    }

    LogWrite("Le job a tourne avec succes en " + $TimeRunningMinutes + ".")
    LogWrite("Son statut est : " + $StatusReturned.Status)

}
catch [ComplexException] {
    LogWrite("Une erreur est survenue :")
    foreach ($Message in $PSItem.Exception.Messages) {
        LogWrite($Message)
    }
    $ExitStatus = 1
}
catch {
    LogWrite("Une erreur est survenue :")
    LogWrite($_)
    $ExitStatus = 1
}
finally {
    LogWrite "#### FIN DU SCRIPT ####`n"
    exit $ExitStatus
}
