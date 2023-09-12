

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
$Output = $webResponse.value | Where-Object {$_.aadDeviceID -ne $null} | Select-Object aadDeviceId, computerDnsName, machineTags | ForEach-Object { 
    [PSCustomObject]@{
        "machineID" = $_.aadDeviceId
        "machineName" = $_.computerDnsName
        "machineTags" = ($_.machinetags) -join ', '
    }
}

# Define the output file location
$Output | Export-csv -Path .\output.csv

Write-Host "ESV Exported."


# clean up all variables
Remove-Variable * -ErrorAction SilentlyContinue

$ClientID = "2d491fbb-f651-4254-935a-4a76267161c5"
$ClientSecret = "IWD8Q~bWFwkg4-JXEz4t7Upk4FTRLBaYf091waOy"
$TenantId = "19abf6c9-5d2a-4601-8345-7f96cbb9be4f"

#Create the body of the Authentication of the request for the OAuth Token
$Body = @{client_id=$ClientID;client_secret=$ClientSecret;grant_type="client_credentials";scope="https://graph.microsoft.com/.default";}
#Get the OAuth Token 
$OAuthReq = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $Body
#Set your access token as a variable
$global:AccessToken = $OAuthReq.access_token

#import the inventory file from security center
$securityCenterInventory = Import-CSV -Path .\output.csv 

#get the group on Azure AD
$groupList = Invoke-RestMethod -Method Get -uri "https://graph.microsoft.com/v1.0/groups" -Headers @{Authorization = "Bearer $AccessToken"} 

#select the group start with a preffix eg. "Dept-"
$selectedGroup = $grouplist.value | Where-Object {$_.displayname -like "*dept*"} | Select-Object -Property id, displayname 

#for each group, get its aadDeviceID, and add to AD Group
foreach ($i in $selectedGroup) {
    # refine the variable
    $groupID=$i.id
    $ii = $i.displayName  
    $iii = "*$ii*"
    # output for debug manully- the Tag name
    Write-Host Trying $ii
    # Filter the devices from the list
    $selectedDevice = $securityCenterInventory | Where-Object {$_.machineTags -like $iii } | Select-Object -Property machineID, machineName
    # output for debug manully- the device value
    Write-Host Device Value $selectedDevice
        foreach ($x in $selectedDevice) {
        # refine the variable
        $xx = $x.machineID
        $xxx = "'$xx'"
            # get device ID
            $a = Invoke-RestMethod -Method Get -uri "https://graph.microsoft.com/v1.0/devices?`$filter=deviceid eq $xxx" -Headers @{Authorization = "Bearer $AccessToken"} 
            # get group members
            $GroupMembers = Invoke-RestMethod -Method Get -uri "https://graph.microsoft.com/v1.0/groups/$groupID/members" -Headers @{Authorization = "Bearer $AccessToken"} | Select-Object -ExpandProperty Value
        # if the group already contains the device, then skip it
        if ($GroupMembers.ID -contains $a.value.id) {
            Write-Host -ForegroundColor Yellow "$($x.machineName) ($($a.value.ID)) is already in the Group of $ii"   
        } else {
            # then add to the group
            Write-Host -ForegroundColor Green "Adding $($x.machineName) ($($a.value.ID)) To The Group of $ii"
            $BodyContent = @{
                "@odata.id"="https://graph.microsoft.com/v1.0/devices/$($a.value.ID)"
            } | ConvertTo-Json
            Invoke-RestMethod -Method POST -uri "https://graph.microsoft.com/v1.0/groups/$groupID/members/`$ref" -Headers @{Authorization = "Bearer $AccessToken"; 'Content-Type' = 'application/json'} -Body $BodyContent
        }
    }
}        





