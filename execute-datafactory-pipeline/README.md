# execute-datafactory-pipeline

This script start an Azure Data Factory pipeline and wait until the script is finished.

## Installation

The following information about your Azure account must be filled inside the script :

```
$TenantID="xxxx"
$ClientID="xxxx"
$ClientSecret="xxxx"
$SubscriptionID="xxxx"
```

The following information about the Data Factory Pipeline must be filled inside the script :

```
$DataFactoryName="xxxx"
$ResourceGroupName="xxxx"

# Optional if your pipeline can be executed without parameter.
$Parameters = @{
    "wait_option" = "Wait5"
}
```

## Usage

$ pwsh ./execute-datafactory-pipeline.ps1

Enjoy !
