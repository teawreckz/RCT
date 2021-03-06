[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName="ByCI_ID")]
param(
    [parameter( Mandatory = $true, ParameterSetName="ByCI_ID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [parameter( Mandatory = $true, ParameterSetName="ByContainerNodeID", HelpMessage = "Site server where the SMS Provider is installed.")]
    [ValidateNotNullOrEmpty()]
    [string] $SiteServer

    , [parameter(Mandatory = $true, ParameterSetName="ByCI_ID", HelpMessage = "Namespace: root\sms\site_COD for examle.")]
    [parameter(Mandatory = $true, ParameterSetName="ByContainerNodeID", HelpMessage = "Namespace: root\sms\site_COD for examle.")]
    [ValidateNotNullOrEmpty()]
    [string] $Namespace

    , [parameter(Mandatory = $true, ParameterSetName="ByCI_ID", HelpMessage = "The unique ID of the update item.")]
    [ValidateNotNullOrEmpty()]
    [UInt32[]] $CI_ID

    , [parameter(Mandatory = $true, ParameterSetName="ByContainerNodeID", HelpMessage = "The unique ContainerNodeID of the update node.")]
    [ValidateNotNullOrEmpty()]
    [UInt32] $ContainerNodeID

    , [parameter(Mandatory = $false, HelpMessage = "The SUG ID (Software Update Group ID).")]
    [UInt32[]] $SUG_CI_ID

    , [parameter(Mandatory = $false, HelpMessage = "Do not prompts you for confirmation before running the cmdlet.")]
    [switch] $force
)
Begin {
    if ($Debug) { $DebugPreference = "Continue" }
    if ($Verbose) { $VerbosePreference = "Continue" }
    $ErrorActionPreference = "Stop"
    $SUGChanged = @()

    [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")

    Write-Verbose "SiteServer       = $SiteServer"
    Write-Verbose "Namespace        = $Namespace"
    Write-Verbose "CI_ID            = $CI_ID"
    Write-Verbose "ContainerNodeID  = $ContainerNodeID"
    Write-Verbose "SUG_CI_ID        = $SUG_CI_ID"

    if (!$force -and [Microsoft.VisualBasic.Interaction]::MsgBox("Remove selected updates from $(if ($SUG_CI_ID.Count) {$SUG_CI_ID.Count} else {"all"}) SUG?", "YesNo,SystemModal,Question,DefaultButton1", "Start confirmation") -ne 'Yes') {
        break 
    }
    
    if ($psCmdlet.ParameterSetName -eq "ByContainerNodeID") {
        Write-Verbose "... running by ParameterSetName = ""ByContainerNodeID"", get all CI_ID updates from ContainerNodeID = $ContainerNodeID"
        $Query = @"
        SELECT SMS_SoftwareUpdate.CI_ID
        FROM
            SMS_ObjectContainerItem
            JOIN SMS_SoftwareUpdate
                ON SMS_SoftwareUpdate.ModelName = SMS_ObjectContainerItem.InstanceKey        
        WHERE 
            SMS_ObjectContainerItem.ContainerNodeID = '$ContainerNodeID'
"@
        $CI_ID = @( (Get-WmiObject -Query $Query -ComputerName $SiteServer -Namespace $Namespace).CI_ID )
        Write-Verbose "CI_ID count = $($CI_ID.Count)"
        Write-Verbose "CI_ID = $($CI_ID -join ", ")"
    }

    $LockStateName = @{0 = "Unassigned"; 1 = "Assigned"; 2 = "Requested"; 3 = "PendingAssignment"; 4 = "TimedOut"; 5 = "NotFound"; }
    function Get-CCMSEDOState ($Namespace, $SiteServer, $CCMObject) {
        $Locked = Invoke-WmiMethod -Namespace $Namespace -Class SMS_ObjectLock -ComputerName $SiteServer -Name "GetLockInformation" -ArgumentList $CCMObject.__RELPATH
        Write-Verbose "LockState code = $($Locked.LockState): $($LockStateName.Item([int]$Locked.LockState))"
        return $Locked
    }
}
Process {
    $Query = @"
    SELECT SMS_AuthorizationList.CI_ID
    FROM
        SMS_AuthorizationList
"@
    if ($SUG_CI_ID.Count) {
        $SUG_CI_ID -join ", " | Write-Verbose
        $Query += @"
        WHERE SMS_AuthorizationList.CI_ID IN ($($SUG_CI_ID -join ", "))
"@
    }
    # Get all SUG
    $AllSUGs = @(Get-WmiObject -Query $Query -ComputerName $SiteServer -Namespace $Namespace)
    Write-Verbose "SUG count: $($AllSUGs.Count)"
    # Get Lazy option
    Write-Verbose "Get lazy propetries for all SUG..."
    $AllSUGs | ForEach-Object {$_.get()}

    foreach ($SUG in $AllSUGs) {
        Write-Verbose "Start processing SUG: ""$($SUG.LocalizedDisplayName)"""
        $RemSUGUpdates = New-Object System.Collections.Generic.HashSet[UInt32] (, [UInt32[]]@($CI_ID))
        $CurSUGUpdates = New-Object System.Collections.Generic.HashSet[UInt32] (, [UInt32[]]@($SUG.Updates))
        $CurSUGUpdates.ExceptWith($RemSUGUpdates)
        if ($CurSUGUpdates.Count -lt $SUG.Updates.Count) {
            Write-Verbose "Count change exist"
            # Check SEDO state
            $NextSug = $false
            while (!$NextSug -and [bool]($Locked = Get-CCMSEDOState -Namespace $Namespace -SiteServer $SiteServer -CCMObject $SUG).LockState) {
                $Text = "SUG: ""$($SUG.LocalizedDisplayName)"" locked by:$($Locked |
                        Format-List @{n = "Machine"; e = {$_.AssignedMachine}},
                                    @{n = "User"; e = {$_.AssignedUser}},
                                    @{n = "Lock"; e = {$LockStateName.Item([int]$_.LockState)}} | Out-String)Retry?"
                Write-Verbose $Text
                $Answer = [Microsoft.VisualBasic.Interaction]::MsgBox($Text, "AbortRetryIgnore,SystemModal,Question,DefaultButton2", "SEDO locked")
                switch ($Answer) {
                    'Abort' { break }
                    'Ignore' { $NextSug = $true; continue }
                }
            }
            if (!$Locked.LockState) {
                $SUG.Updates = $CurSUGUpdates
                $SUGChanged += $SUG.Put()
                Write-Verbose -Message "Successfully removed update from ""$($SUG.LocalizedDisplayName)"""
            }
        }
    }
}
End {
    $Text = if ($SUGChanged.Count) {"Number of modified SUG: $($SUGChanged.Count).`nPlease refresh the console."} else {"No changes made."}
    Write-Verbose $Text
    [Microsoft.VisualBasic.Interaction]::MsgBox($Text, "OkOnly,SystemModal,Information,DefaultButton1", "Completed") | Out-Null
}