Function Get-RemedyInterface {
<#
.SYNOPSIS
    Returns the list of Remedy API interfaces that can be interrogated.
.EXAMPLE
    Get-RemedyInterfaces
#>
    [cmdletbinding()]
    Param(
        #Optional: Name of an interface to see the properties of that interface. Exclude to list all interfaces.
        [String]$Interface,

        #An encoded string representing your Remedy Credentials as generated by the Set-RemedyApiConfig cmdlet.
        [String]$EncodedCredentials = (Get-RemedyApiConfig).Credentials,
        
        #The Remedy API URL. E.g: https://<localhost>:<port>/api
        [String]$APIURL = (Get-RemedyApiConfig).APIURL
    )

    $Headers = @{
        Authorization = "Basic $EncodedCredentials"
    }

    $URL = "$APIURL/$Interface"

    Try {
        $Result = Invoke-RestMethod -URI $URL -Headers $Headers -ErrorAction Stop
        
        $Fields = @()
        $Result.PSObject.Properties | ForEach-Object { $Fields += $_.Value }
                
    } Catch {
        Write-Error $_
    }

    Return $Fields
}
