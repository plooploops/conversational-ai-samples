#load Get-LUISResult function
. .\Get-LUISResult.ps1

$location = "westus" #set to LUIS endpoint host
$versionId = "" #set to LUIS Version ID
$appId = "" #set to LUIS app id
$subscriptionKey = "" #set to LUIS app key

#this is a hash table, so the queries are the keys and the values are the intents.
$querySet = @{
    "Can you show me a pizza?"        = "None";
    "I want to see my last statement" = "GetDocument";
    "I want to see my last pay slip"  = "GetDocument";
}

##adapted from: https://www.programming-books.io/essential/powershell/encode-query-string-with-uri-escapedatastring-412ca93cd6794867854b76dd646dda23
##https://powershellexplained.com/2017-11-20-Powershell-StringBuilder/

$sb = [System.Text.StringBuilder]::new()
foreach ($qs in $querySet.GetEnumerator()) {
    $qs_key = $qs.Name
    $qs_value = $qs.Value
    $res = Get-LUISResult -location $location -query $qs.Name -appId $appId -versionId $versionId -subscriptionKey $subscriptionKey

    if ($res -eq $null) {
        $sb.AppendLine("Unable to get result for query $qs_key")    
    }
    elseif ($res.intentPredictions.Count -le 0) {
        $sb.AppendLine("No result for query $qs_key")   
    }
    else {
        $resIntentName = $res.intentPredictions[0].name
        $resIntentScore = $res.intentPredictions[0].score
        $statusDetails = [System.Text.StringBuilder]::new()

        if ($resIntentName -eq $qs_value) {
            $statusDetails.Append("${qs_key} got intent: $resIntentName with score: $resIntentScore.  Expected Intent $qs_value Matched!") | Out-Null
        }
        else {
            $statusDetails.Append("${qs_key} got intent: $resIntentName with score: $resIntentScore.  Expected Intent $qs_value Did not match!") | Out-Null
        }

        if ($res.entityPredictions.Count -gt 0) {
            $entityPhrase = $res.entityPredictions[0].phrase
            $entityName = $res.entityPredictions[0].entityName
            $statusDetails.Append(" Also found entity type: $entityName and entity text: $entityPhrase.") | Out-Null
        }
        $sb.AppendLine($statusDetails.ToString())
    }
}

Write-host $sb.ToString()