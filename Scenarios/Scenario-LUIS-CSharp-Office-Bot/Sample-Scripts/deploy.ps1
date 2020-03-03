$botName = "mybot21312"
$location = "westus"
$rgName = "$botName-rg"
$luisAccountName = "luis-$botName"
$tempParams = "parameters.temp.json"
$parametersPath = ".\Scenarios\Scenario-LUIS-CSharp-Office-Bot\Sample-Templates\parameters.json"
$templatePath = ".\Scenarios\Scenario-LUIS-CSharp-Office-Bot\Sample-Templates\template.json"
$codeDir = ".\Scenarios\Scenario-LUIS-CSharp-Office-Bot"
$projFileName = "CoreBot.csproj"
$projFilePath = "$codeDir\$projFilePath"

$luisRestAPIUrl = "https://westus.api.cognitive.microsoft.com/luis/api/v2.0"
$modelFileName = ".\Scenarios\Scenario-LUIS-CSharp-Office-Bot\Sample-Models\luis-office-bot_vLOB-Intents-Entities-0.1.2.json"
$testQuery = "Can you share with me my last pay slip?"
#https://docs.microsoft.com/en-us/azure/bot-service/bot-builder-deploy-az-cli?view=azure-bot-service-4.0&tabs=csharp
#login to Azure
az login
Write-Host "Confirm the Azure Subscription"
az account show

az group create -n $rgName -l $location
#modified from here: https://docs.microsoft.com/en-us/azure/bot-service/bot-builder-deploy-az-cli?view=azure-bot-service-4.0&tabs=csharp#3-create-the-application-registration
$appRegistrationJson = $(az ad app create --display-name $botName --key-type Password --available-to-other-tenants "true")
$appRegistrationJsonObject = $appRegistrationJson | ConvertFrom-Json
$credObject = $(az ad app credential reset --id $appRegistrationJsonObject.appId) | ConvertFrom-Json

$parametersContent = Get-Content $parametersPath
$parametersObject = $parametersContent | ConvertFrom-Json
$parametersObject.parameters.botid.value = $botName
$parametersObject.parameters.siteName.value = $botName
$parametersObject.parameters.luisAccountName.value = $luisAccountName
$parametersObject.parameters.appId.value = $credObject.appId
$parametersObject.parameters.appSecret.value = $credObject.password

($parametersObject | ConvertTo-Json -Depth 5) > $tempParams

#create base components
# reference https://github.com/microsoft/LUIS-Samples/blob/master/azuredeploy.json
az group deployment create --name mydeploy --resource-group $rgName --parameters $tempParams --template-file $templatePath

#Remove temp parameters file
rm $tempParams

#post deployment steps.  Load LUIS Model.
# reference https://docs.microsoft.com/en-us/cli/azure/query-azure-cli?view=azure-cli-latest
$luisObject = $(az cognitiveservices account list -g $rgName --query "[?name=='$luisAccountName']") | ConvertFrom-Json
$luisCredentialObject = $(az cognitiveservices account keys list -g $rgName -n $luisObject.name) | ConvertFrom-Json
#not a GUID
$LuisAPIKey = $luisCredentialObject.key1

##Not sure if this is required, but will navigate to directory with the model.
$luisModelObject = Get-Content $modelFileName | ConvertFrom-Json

#message should look like: App successfully imported with id 12345678-1234-1234-1234-123456781234. With a period at the end.
$importLUISAppMessage = $(bf luis:application:import --endpoint $location --subscriptionKey $LuisAPIKey --name $luisAccountName --in $modelFileName)
# for now, using magic indexes, but can change if bf cli supports json output.  Using a GUID parse to confirm success.
$luisAppId = ([GUID]$($importLUISAppMessage[-37..-2] -join '')).ToString()

Write-Host "Training LUIS Model"
bf luis:train:run --endpoint $location --subscriptionKey $LuisAPIKey --appId $luisAppId --versionId $luisModelObject.versionId

#check on training status.
Do
{
    $trainingStatusMessage = $(bf luis:train:show --endpoint $location --subscriptionKey $LuisAPIKey --appId $luisAppId --versionId $luisModelObject.versionId)
    #parse training status
    $trainingStatus = $trainingStatusMessage[0..($trainingStatusMessage.Length-2)] | Convertfrom-json

    $currentSuccessCount = 0
    $trainingStatus.ForEach({
        Write-Host $_.details.status
        Write-Host $currentSuccessCount
        
        #check status.
        if ($_.details.status -eq "Success" -or $_.details.status -eq "UpToDate"){
            $currentSuccessCount += 1
        }
    })

    if (($trainingStatus.count -eq $currentSuccessCount -and $trainingStatus.count -gt 0) -or ($trainingStatus.count -eq 0)){
        break
    }
    
    Sleep 5 #maybe need a retry here, but will start simple.
}
while ($true)

Write-Host "Training Successful"

az webapp config appsettings set -g $rgName -n $botName --settings "LuisAPIKey=$LuisAPIKey"
az webapp config appsettings set -g $rgName -n $botName --settings "LuisAppId=$LuisAppId"
#just need location as hostname.
az webapp config appsettings set -g $rgName -n $botName --settings "LuisAPIHostName=$location"

Write-Host "Publish to staging"
bf luis:application:publish --endpoint $location --subscriptionKey $LuisAPIKey --versionId $luisModelObject.versionId --appId $LuisAppId --staging

Write-Host "Sample query against staging.  This can be turned into a series of tests."
bf luis:application:query --endpoint $location --subscriptionKey $LuisAPIKey --appId $LuisAppId --query $testQuery --staging

write-Host "Change LUIS App to have public endpoint"
#reference: https://westus.dev.cognitive.microsoft.com/docs/services/5890b47c39e2bb17b84a55ff/operations/58aeface39e2bb03dcd5909e
$appSettingsUrl = "$luisRestAPIUrl/apps/$LuisAppId/settings"
$LuisAppPublishObject = Invoke-WebRequest "$appSettingsUrl" -Headers  @{ "Ocp-Apim-Subscription-Key" = "$LuisAPIKey" } -Body (ConvertTo-Json @{ "public"=$true}) -Method PUT -ContentType 'application/json'
$LuisAppPublishStatusCode = $luisAppPublishObject.StatusCode
Write-Host "$LuisAppPublishObject got $luisAppPublishStatusCode"


write-Host "Publish LUIS App to production slot"
bf luis:application:publish --endpoint $location --subscriptionKey $LuisAPIKey --versionId $luisModelObject.versionId --appId $LuisAppId
bf luis:application:query --endpoint $location --subscriptionKey $LuisAPIKey --appId $LuisAppId --query $testQuery

Write-Host "Prepare for deployment"

if (Test-Path "$codeDir\.deployment")
{
    mv "$codeDir\.deployment" "$codeDir\.deployment.bak" -Force
}

az bot prepare-deploy --lang Csharp --code-dir $codeDir --proj-file-path $projFileName

Write-Host "Prepare zip file for deployment"
#reference: https://devblogs.microsoft.com/scripting/use-powershell-to-create-zip-archive-of-folder/
$workingDirectory = Get-Location | select -ExpandProperty Path
$source = "$workingDirectory\$codeDir"
$destinationFolder = "$workingDirectory\$codeDir-deployment" #cannot be part of the source folder.
$destinationPath = "$destinationFolder\$botName.zip"

mkdir $destinationFolder -Force

If(Test-path $destinationPath) 
{
    Remove-item $destinationPath
}

Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($Source, $destinationPath)

#deploy zip file
$publishBotResult = az webapp deployment source config-zip -g $rgName --name $botName --src $destinationPath
$publishBotResultObject = $publishBotResult | ConvertFrom-Json
$publishBotResultObject
Write-Host "Publish Bot Deployment Finished"



