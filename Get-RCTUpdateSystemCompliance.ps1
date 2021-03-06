[CmdletBinding()]
param(
    [parameter(Mandatory = $true, HelpMessage = "Site server where the SMS Provider is installed.")]
    [ValidateNotNullOrEmpty()]
    [string] $SiteServer

    , [parameter(Mandatory = $true, HelpMessage = "Namespace: root\sms\site_M02 for examle.")]
    [ValidateNotNullOrEmpty()]
    [string] $Namespace

    , [parameter(Mandatory = $true, HelpMessage = "The unique ID of the update item.")]
    [ValidateNotNullOrEmpty()]
    [UInt32] $CI_ID

    , [parameter(Mandatory = $false, HelpMessage = "Show Status in one column.")]
    [switch] $StatusInOneColumn

    , [parameter(Mandatory = $false, HelpMessage = "Title of GridView window.")]
    [string] $Title = "Update compliance status"
)
Begin {
    if ($Debug) { $DebugPreference = "Continue" }
    if ($Verbose) { $VerbosePreference = "Continue" }
    $ErrorActionPreference = "Stop"

    Write-Verbose "SiteServer = $SiteServer"
    Write-Verbose "Namespace = $Namespace"
    Write-Verbose "CI_ID = $CI_ID"
    Write-Verbose "StatusInOneColumn = $StatusInOneColumn"
    Write-Verbose "Title = $Title"
}
Process {
    $Query = @"
	SELECT
		SMS_R_System.NetbiosName
		, SMS_UpdateComplianceStatus.Status
        , SMS_UpdateComplianceStatus.LastStatusCheckTime
	FROM
		SMS_SoftwareUpdate
		JOIN SMS_UpdateComplianceStatus
			ON SMS_UpdateComplianceStatus.CI_ID = SMS_SoftwareUpdate.CI_ID
		JOIN SMS_R_System
			ON SMS_R_System.ResourceID = SMS_UpdateComplianceStatus.MachineID
	WHERE SMS_SoftwareUpdate.CI_ID = '$CI_ID'
"@

    $Stat = @( # Status / Cost - for sorting
        ("Unknown", 3),
        ("Not required", 2),
        ("Required", 0),
        ("Installed", 1)
    )

    $Systems = @(Get-WmiObject -Query $Query -ComputerName $SiteServer -Namespace $Namespace) |
        Sort-Object @{e = { $Stat[$_.SMS_UpdateComplianceStatus.Status][1]}},
                    @{e = {$_.SMS_R_System.NetbiosName}}

    if ($StatusInOneColumn) {
        $Systems | Select-Object    @{n = "Computer Netbios Name";  e = {$_.SMS_R_System.NetbiosName}},
                                    @{n = "Update Status";          e = { $Stat[($_.SMS_UpdateComplianceStatus.Status)][0] }},
                                    @{n = "Last Status Check Time"; e = {[System.Management.ManagementDateTimeConverter]::ToDateTime($_.SMS_UpdateComplianceStatus.LastStatusCheckTime)}} |
                Out-GridView -Wait -Title $Title
    }
    else {
        $Systems | Select-Object    @{n = "Computer Netbios Name";  e = {$_.SMS_R_System.NetbiosName}},
                                    @{n = "Required";               e = {if ($_.SMS_UpdateComplianceStatus.Status -eq 2) {"*"} else {""} }},
                                    @{n = "Installed";              e = {if ($_.SMS_UpdateComplianceStatus.Status -eq 3) {"*"} else {""} }},
                                    @{n = "Last Status Check Time"; e = {[System.Management.ManagementDateTimeConverter]::ToDateTime($_.SMS_UpdateComplianceStatus.LastStatusCheckTime)}} |
                Out-GridView -Wait -Title $Title
    }
}
End {
    Write-Verbose "Completed."
}