Function Get-LUISResult
{
    <#
        .SYNOPSIS
            Get-LUISResult is a PowerShell Function that looks to retrieve a LUIS result.
        
        .DESCRIPTION
            Get-LUISResult is a PowerShell Function that looks to retrieve a LUIS result.
            It has 5 required parameters (switches): -location, -query, -appId, -versionId, -subscriptionKey
            Find the details of the parameters below.
        
        .PARAMETER Location - This is the target LUIS location / region
    
        .PARAMETER Query - This is the string that we'll send to LUIS (e.g. "Where's the office?")
    
        .PARAMETER AppId - This is the target LUIS application Id
    
        .PARAMETER VersionId - This is the target LUIS version Id.  Note tha tthe version Id must match what's associated with the LUIS application.
    
        .PARAMETER SubscriptionKey - This is the target LUIS subscription Key.  We can also check Ocp-Apim-Subscription-Key.
    
        .EXAMPLE
            We can use this to get a query result from a version of a LUIS model.
            Get-LUISResult -location $location -query $query -appId $appId -versionId $versionId -subscriptionKey $subscriptionKey
    #>
    param(
        [parameter (Mandatory=$true,Position=0,ParameterSetName='GetLUISResult')]
        [String]$location,
        [parameter (Mandatory=$true,Position=1,ParameterSetName='GetLUISResult')]
        [String]$query,
        [parameter (Mandatory=$true,Position=2,ParameterSetName='GetLUISResult')]
        [String]$appId,
        [parameter (Mandatory=$true,Position=3,ParameterSetName='GetLUISResult')]
        [String]$versionId,
        [parameter (Mandatory=$true,Position=4,ParameterSetName='GetLUISResult')]
        [String]$subscriptionKey
    )


    $scheme = 'https'
    $url_format = "{0}://$location.api.cognitive.microsoft.com/luis/webapi/v2.0/apps/$appId/versions/$versionId/predict?{1}"
    $qs_data = @{
        'example'          = "$query";
        'patternDetails'   = 'true';
        'multiple-intents' = 'true';
    }

    ##adapted from: https://www.programming-books.io/essential/powershell/encode-query-string-with-uri-escapedatastring-412ca93cd6794867854b76dd646dda23
    [System.Collections.ArrayList] $qs_array = @()
    foreach ($qs in $qs_data.GetEnumerator()) {
        $qs_key = [uri]::EscapeDataString($qs.Name)
        $qs_value = [uri]::EscapeDataString($qs.Value)
        $qs_array.Add("${qs_key}=${qs_value}") | Out-Null
    }

    $url = $url_format -f @([uri]::"UriScheme${scheme}", ($qs_array -join '&'))

    ##https://www.daniellittle.xyz/calling-a-rest-json-api-with-powershell
    $result = Invoke-RestMethod -Method Get -Uri $url -Header @{ "Ocp-Apim-Subscription-Key" = $subscriptionKey }
    return $result
}