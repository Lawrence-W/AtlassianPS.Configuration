#region Dependencies
# Load the Module's namespace from C#
if (-not("AtlassianPS.ServerData" -as [Type])) {
    Add-Type -Path (Join-Path $PSScriptRoot AtlassianPS.Configuration.Types.cs) -ReferencedAssemblies Microsoft.CSharp, Microsoft.PowerShell.Commands.Utility, System.Management.Automation
}
if ($PSVersionTable.PSVersion.Major -lt 5) {
   Add-Type -Path (Join-Path $PSScriptRoot AtlassianPS.Configuration.Attributes.cs) -ReferencedAssemblies Microsoft.CSharp, Microsoft.PowerShell.Commands.Utility, System.Management.Automation
}
#endregion Dependencies

#region ModuleConfig
if (
    ((Get-Variable -Name IsLinux -ErrorAction Ignore) -and $IsLinux) -or
    ((Get-Variable -Name IsMacOS -ErrorAction Ignore) -and $IsMacOS)
) {
    $fixpath = "$HOME/.local/share/" #workaround for issue#14
    Import-Module Configuration -Args @($null, $null, $null, $fixpath) -Force
}
# Add our own Converters for serialization
if (Get-Command Add-MetadataConverter -Module Configuration -ErrorAction SilentlyContinue) {
    Configuration\Add-MetadataConverter @{
        [AtlassianPS.ServerData] = { "AtlassianPSServerData @{{Name = '{0}'; Uri = '{1}'; Type = '{2}'; Headers = '{3}'}}" -f $_.Name, $_.Uri, $_.Type, $_.Headers }
        "AtlassianPSServerData" = { [AtlassianPS.ServerData]$Args[0] }
    }
}

# Load configuration using
# https://github.com/PoshCode/Configuration
$script:Configuration = Configuration\Import-Configuration -CompanyName "AtlassianPS" -Name "AtlassianPS.Configuration"
if (-not $script:Configuration.ServerList) {
    $script:Configuration.ServerList = [System.Collections.Generic.List[AtlassianPS.ServerData]]::new()
}
#endregion ModuleConfig

#region LoadFunctions
$PublicFunctions = @( Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue )
$PrivateFunctions = @( Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue )

# Dot source the functions
foreach ($file in @($PublicFunctions + $PrivateFunctions)) {
    try {
        . $file.FullName
    }
    catch {
        $errorItem = [System.Management.Automation.ErrorRecord]::new(
            ([System.ArgumentException]"Function not found"),
            'Load.Function',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $file
        )
        $errorItem.ErrorDetails = "Failed to import function $($file.BaseName)"
        throw $errorItem
    }
}
Export-ModuleMember -Function $PublicFunctions.BaseName -Alias *
#endregion LoadFunctions
