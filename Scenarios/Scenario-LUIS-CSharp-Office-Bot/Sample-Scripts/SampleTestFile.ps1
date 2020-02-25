#load Get-LUISResult function
. .\Get-LUISResult.ps1

$location = "westus" #set to LUIS endpoint host
$subscriptionKey = "" #set to LUIS App Key
$appId = "" #set to LUIS App Id
$versionId = "" #set to LUIS Version Id
$batchFilePath = "" #set to file path for the Batch Test File

$json = Get-Content $batchFilePath
# Example of the LUIS Batch File
# $json = @"
# [
#     {
#         "text": "can I get my last pay slip?",
#         "intent": "GetDocument",
#         "entities": 
#         [
#             {
#                 "entity": "document",
#                 "startPos": 18,
#                 "endPos": 25
#             }
#         ]
#     },
#     {
#         "text": "Show me a pizza",
#         "intent": "None",
#         "entities": []
#     }
# ]
# "@

$testObjects = $json | ConvertFrom-Json
$sb = [System.Text.StringBuilder]::new()

##https://powershellexplained.com/2017-11-20-Powershell-StringBuilder/

foreach ($testObject in $testObjects){
    $text = $testObject.text
    $expectedIntent = $testObject.intent
    $expectedEntities = $testObject.entities
    $substringLength = 0
    if ($expectedEntities[0].endPos -ge $expectedEntities[0].startPos){
        $substringLength = $expectedEntities[0].endPos - $expectedEntities[0].startPos + 1
    }
    ## should be handled with multiple entities.  Starting with if there is an entity
    $expectedEntityText = $text.substring($expectedEntities[0].startPos, $substringLength)
    $expectedEntityType = $expectedEntities[0].entity

    $res = Get-LUISResult -location $location -query $text -appId $appId -versionId $versionId -subscriptionKey $subscriptionKey

    if ($res -eq $null) {
        $sb.AppendLine("Unable to get result for query $text")    
    }
    elseif ($res.intentPredictions.Count -le 0) {
        $sb.AppendLine("No result for query $text")   
    }
    else {
        $resIntentName = $res.intentPredictions[0].name
        $resIntentScore = $res.intentPredictions[0].score
        $statusDetails = [System.Text.StringBuilder]::new()

        if ($resIntentName -eq $expectedIntent) {
            $statusDetails.Append("${text} got intent: $resIntentName with score: $resIntentScore.  Expected Intent $expectedIntent Matched!") | Out-Null
        }
        else {
            $statusDetails.Append("${text} got intent: $resIntentName with score: $resIntentScore.  Expected Intent $expectedIntent Did not match!") | Out-Null
        }

        if ($res.entityPredictions.Count -gt 0) {
            $entityPhrase = $res.entityPredictions[0].phrase
            $entityName = $res.entityPredictions[0].entityName
            if (($entityPhrase -eq $expectedEntityText) -and ($entityName -eq $expectedEntityType)){
                $statusDetails.Append(" Also found entity type: $entityName and entity text: $entityPhrase.  Expected Entity Type: $expectedEntityType and expected entity text: $expectedEntityText matched!") | Out-Null
            }
            else{
                $statusDetails.Append(" Also found entity type: $entityName and entity text: $entityPhrase.  Expected Entity Type: $expectedEntityType and expected entity text: $expectedEntityText did not match!") | Out-Null
            }
        }
        $sb.AppendLine($statusDetails.ToString())
    }
}

Write-host $sb.ToString()