

# cleanup all variables
Remove-Variable * -ErrorAction SilentlyContinue

# informatoin for your tenant, app and sercet key
$tenantId = "19abf6c9-5d2a-4601-8345-7f96cbb9be4f" #Paste Your Tenant ID
$appId = "2d491fbb-f651-4254-935a-4a76267161c5"    #paste Your App ID
$appSecret = "IWD8Q~bWFwkg4-JXEz4t7Upk4FTRLBaYf091waOy"  #paste your App Key
$resourceAppIdUri = 'https://api.securitycenter.microsoft.com'
$oAuthUri = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$authBody = [Ordered] @{
    resource = "$resourceAppIdUri"
    client_id = "$appId"
    client_secret = "$appSecret"
    grant_type = "client_credentials"
    }

#Authorize ad connect 
$authResponse = Invoke-RestMethod -Method Post -Uri $oAuthUri -Body $authBody -ErrorAction Stop
$token = $authResponse.access_token
$headers = @{
        "Content-Type" = "application/json"
        Accept = "application/json"
        Authorization = "Bearer $token"
    }

# get the deivce list
$url = "https://api.securitycenter.windows.com/api/machines"
$webResponse = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -ErrorAction Stop

# if aaDeviceID is null, skip it, and out the informatoin needed to CSV
$output = $webResponse.value | Where-Object {$_.aadDeviceID -ne $null} | Select-Object aadDeviceId, computerDnsName, machineTags | ForEach-Object { 
    [PSCustomObject]@{
        "machineID" = $_.aadDeviceId
        "machineName" = $_.computerDnsName
        "machineTags" = ($_.machinetags) -join ', '
    }
}

# Define the output file location
$output | Export-csv -Path .\mde\output.csv

Write-Host "ESV Exported."






