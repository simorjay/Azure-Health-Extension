<#
.SYNOPSIS
    This function prepares the SQL setup script and storage account artifacts
#>
Function TransferExecute-PayloadFunction {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
            [string]$resourceGroupName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
            [string]$artifactsStorageAccountName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
            [string]$artifactsStorageContainerName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3)]
            [string]$VNetName
    )

    $scriptRoot = Get-Location

    $ArtifactStagingDirectory = 'stage'
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($scriptRoot, $ArtifactStagingDirectory))

    $ArtifactsStorageAccount = Get-AzureRmStorageAccount -ResourceGroup $resourceGroupName -Name $artifactsStorageAccountName -ErrorAction SilentlyContinue

    # Create the storage account
    if ($ArtifactsStorageAccount -eq $null) {
        log "Creating storage account $($artifactsStorageAccountName) to hold script execution artifacts"

        $ArtifactsStorageAccount = New-AzureRmStorageAccount -StorageAccountName $artifactsStorageAccountName -Type 'Standard_LRS' `
                            -ResourceGroupName $resourceGroupName -Location $location `
                            -EnableHttpsTrafficOnly $true -EnableEncryptionService blob

    } else {
        #
        # storage account name is unque each invocation. If a name conflict, do not proceed, as the referenced storage account will be deleted.
        #
        logerror
        Break
    }

    if ($ArtifactsStorageAccount -eq $null) {
        logerror
        Break
    }

    $container = New-AzureStorageContainer -Name $artifactsStorageContainerName -Context $ArtifactsStorageAccount.Context -ErrorAction SilentlyContinue

    if($container -eq $null)
    {
        logerror
        Break
    }

    #
    # prepare zip archive.
    #

    $guid = New-Guid
    $guid = $guid.Guid.ToString()

    $sourceFiles = $ArtifactStagingDirectory+'\artifact'
    $destinationZip = $ArtifactStagingDirectory+'\sql-setup-'+$guid+'.zip'

    If(Test-path $destinationZip) {Remove-item $destinationZip}

    log "Adding record set artifact to zipfile $($destinationZip)"

    Add-Type -assembly "system.io.compression.filesystem"
    [io.compression.zipfile]::CreateFromDirectory($sourceFiles, $destinationZip, "Optimal", $false) 

    #
    # transfer the powershell script and payload zip file
    #

    log "Adding script execution artifacts to storage account $($artifactsStorageAccountName)"

    $SourcePath = $ArtifactStagingDirectory+'\sql-setup.ps1'
    Set-AzureStorageBlobContent -File $SourcePath -Blob 'sql-setup.ps1' `
            -Container $artifactsStorageContainerName -Context $ArtifactsStorageAccount.Context -Force

    $SourcePath = $destinationZip
    Set-AzureStorageBlobContent -File $SourcePath -Blob 'sql-setup.zip' `
            -Container $artifactsStorageContainerName -Context $ArtifactsStorageAccount.Context -Force

    If(Test-path $destinationZip) {Remove-item $destinationZip}

    #
    # apply firewall rules to storage account, so only subnet has access.
    #
    
    log "Applying firewall policy on storage account $($artifactsStorageAccountName)"

    $subnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $VNetName | Get-AzureRmVirtualNetworkSubnetConfig
    $null = Set-AzureRmStorageAccount -NetworkRuleSet (@{bypass="None";virtualNetworkRules=(@{VirtualNetworkResourceId="$($subnet[0].Id)";Action="allow"});defaultAction="Deny"}) -ResourceGroupName $resourceGroupName -Name $artifactsStorageAccountName

    $resultArray = @()
    $resultArray+= $ArtifactsStorageAccount

    return $resultArray
}


<#
.SYNOPSIS
    This function updates the network security group and access policy to grant VM MSI access to SQL
#>
Function Update-AccessPolicySqlFunction {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
            [string]$resourceGroupName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
            [string]$environment,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
            [string]$sqlDbServerName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3)]
            [string]$sqlDbServerResourceGroup,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 4)]
            [string]$VMName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 5)]
            [string]$VNetName
    )

    $status = $false

    $SubnetName = 'SQLSubnet'
    $VNetRuleName = 'SQL_IaaS_Access'

    $ExistingRule = Get-AzureRmSqlServerVirtualNetworkRule -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName -VirtualNetworkRuleName $VNetRuleName -ErrorAction SilentlyContinue

    if($ExistingRule -eq $null)
    {
        log "Setting SQL PaaS Firewall rule."

        #
        # setup subnet and network rule on SQL PaaS instance
        #

        $vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $VNetName -ErrorAction SilentlyContinue
        if($vnet -eq $null) {
            logerror
            return $false
        }

        $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet -ErrorAction SilentlyContinue
    
        if($subnet -eq $null) {
            logerror
            return $false
        }
    
        $vnetRuleObject = New-AzureRmSqlServerVirtualNetworkRule -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName -VirtualNetworkRuleName $VNetRuleName -VirtualNetworkSubnetId $subnet[0].Id -ErrorAction SilentlyContinue
        if($vnetRuleObject -eq $null) {
            log "Error setting SQL PAAS firewall rule subnetid $($subnet[0].Id)"
            return $false
        }
    } else {
        log "SQL PaaS Firewall rule already set."
    }

    #
    # obtain the MSI identity info for the VM
    #

    $VM = Get-AzureRmVm -ResourceGroup $resourceGroupName -Name $VMName -ErrorAction SilentlyContinue
    if($VM -eq $null)
    {
        logerror
        return $false
    }


    log "VM MSI ApplicationId $($VM.Identity.PrincipalId)"

    #
    # connect to AzureAD, create an AAD group, add the MSI to the group, and grant access to the PaaS SQL server
    #

    $currentAzureContext = Get-AzureRmContext
    $tenantId = $currentAzureContext.Tenant.Id
    $accountId = $currentAzureContext.Account.Id

    try {
        $ad = Connect-AzureAD -TenantId $tenantId -AccountId $accountId
    } catch {
        Write-Error -Message $_.Exception.Message
        return $false
    }

    $GroupName = $resourceGroupName+' VM MSI access to SQL PaaS instance'
    $Group = Get-AzureADGroup -SearchString $GroupName -ErrorAction SilentlyContinue

    if($Group -eq $null)
    {
        log "creating VM MSI Access group"
        $Group = New-AzureADGroup -DisplayName $GroupName -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
    } else {
        log "VM MSI Access group already exists"
    }

    log "Containing group for VM MSI objectID=$($Group.ObjectId)"

    $ret = Get-AzureADGroupMember -All $true -ObjectId $Group.ObjectId -ErrorAction SilentlyContinue | Where-Object {$_.ObjectId -match $VM.Identity.PrincipalId}

    if($ret -eq $null)
    {
        try {
            $ret = Add-AzureAdGroupMember -ObjectId $Group.ObjectId -RefObjectId $VM.Identity.PrincipalId -ErrorAction SilentlyContinue
        } catch {
            Write-Error -Message $_.Exception.Message
            return $false
        }
    } else {
        log "VM MSI already a member of group."
    }

    #
    # enable AD based administrator
    #

    $user = Get-AzureRMADUser -SearchString $accountId
    if( (($user | measure).count) -ne 1 ) {
        log "Unable to determine administrator identity information."
        logerror 
        Break
    }

	$CurrentAdmin = Get-AzureRmSqlServerActiveDirectoryAdministrator -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName -ErrorAction SilentlyContinue

	if(($CurrentAdmin -eq $null) -Or
	   ($CurrentAdmin.ObjectId -ne $user[0].Id))
	{
		log "Enabling SQL AD administrator user = $($accountId)."
	    $null = Set-AzureRmSqlServerActiveDirectoryAdministrator -ResourceGroupName $sqlDbServerResourceGroup -ServerName $sqlDbServerName -DisplayName $user[0].DisplayName
	} else {
		log "User already SQL AD administrator."
	}

    # disconnect azureAD
    $null = Disconnect-AzureAD


    #
    # setup access to group containing MSI, and grant db_datareader access.
    #

    $SqlServerAddress = $SqlDbServerName +'.database.windows.net'

    $connectionString = "Server=tcp:$($SqlServerAddress),1433;Initial Catalog=patientdb;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=Active Directory Integrated;"
    log "$connectionString"

    #
    # only make changes if necessary
    #

    $queryCreateUser = "IF DATABASE_PRINCIPAL_ID('$GroupName') IS NULL BEGIN CREATE USER [$GroupName] FROM EXTERNAL PROVIDER END"
    $queryAlterRole = "IF IS_ROLEMEMBER ( 'db_datareader','$GroupName' ) = 0 BEGIN ALTER ROLE db_datareader ADD MEMBER [$GroupName] END"

    log "Executing SQL PaaS CREATE USER for VM MSI"

    try {
        $result = Invoke-SqlCmd -ConnectionString $connectionString -Query $queryCreateUser -OutputSqlErrors $true
    } catch {
        log "Caught exception during CREATE USER"
        Write-Error -Message $_.Exception.Message
    }

    log "Executing SQL PaaS ALTER ROLE for VM MSI"
    try {
        $result = Invoke-SqlCmd -ConnectionString $connectionString -Query $queryAlterRole -OutputSqlErrors $true
        log "Sucessfully updated PaaS firewall and MSI access policy."
        $status = $true
    } catch {
        log "caught exception during ALTER ROLE"
        Write-Error -Message $_.Exception.Message
    }

    $status
}


<#
.SYNOPSIS
    This function creates a storage account for SQL backups, and then:
    1. Updates the SQL IaaS extension backup settings,
    2. Updates the SQL IaaS extension keyvault settings.
#>
Function Update-SqlIaaSExtensionBackupAndKeyVault {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
            [string]$resourceGroupName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
            [string]$StorageAccountName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
            [string]$VMName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3)]
            [securestring]$autoBackupPassword,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 4)]
            [string]$KeyVaultServicePrincipalName,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 5)]
            [securestring]$KeyVaultServicePrincipalSecret,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 6)]
            [string]$KeyVaultCredentialName
    )

    $StorageAccount = Get-AzureRmStorageAccount -ResourceGroup $resourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue

    if($StorageAccount -eq $null)
    {
        log "Failed to get existing SQL backup storage account."
        logerror
        Break
    } else {
        log "Using existing SQL backup storage account."
    }

    $AutoBackupSettings = New-AzureRmVMSqlServerAutoBackupConfig -Enable -EnableEncryption `
            -RetentionPeriodInDays 30 -StorageContext $StorageAccount.Context -ResourceGroupName $resourceGroupName `
            -BackupSystemDbs -BackupScheduleType Automated -FullBackupFrequency Weekly -CertificatePassword $autoBackupPassword


    $KeyVaultUrl = "https://$($resourceGroupName)-sql-kv.vault.azure.net/"

    $KeyVaultCredentialSettings = New-AzureRmVMSqlServerKeyVaultCredentialConfig -ResourceGroupName $resourceGroupName `
                                     -Enable `
                                     -CredentialName $KeyVaultCredentialName `
                                     -AzureKeyVaultUrl $KeyVaultUrl `
                                     -ServicePrincipalName $KeyVaultServicePrincipalName `
                                     -ServicePrincipalSecret $KeyVaultServicePrincipalSecret
    

    log "Updating SqlIaaSExtension to enable automatic backups and keyvault integration."
    $ExtensionStatus = Set-AzureRmVMSqlServerExtension -ResourceGroupName $resourceGroupName -VMName $VMName `
        -AutoBackupSettings $AutoBackupSettings -KeyVaultCredentialSettings $KeyVaultCredentialSettings

    if($ExtensionStatus.IsSuccessStatusCode -eq $true)
    {
        log "Sucessfully updated SqlIaasExtension"
        $true
    } else {
        $false
    }
}
