# Copyright 2012 Aaron Jensen
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[CmdletBinding()]
param(
    [string]
    # The path where the help should be put.
    $OutputDir = "./Website/help"
)

#Requires -Version 4

Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Tools\Silk\Import-Silk.ps1' -Resolve)
& (Join-Path -Path $PSScriptRoot -ChildPath 'Carbon\Import-Carbon.ps1' -Resolve)

$moduleInstallPath = Get-PowerShellModuleInstallPath
$linkPath = Join-Path -Path $moduleInstallPath -ChildPath 'Carbon'
Install-Junction -Link $linkPath -Target (Join-Path -Path $PSScriptRoot -ChildPath 'Carbon') -Verbose:$VerbosePreference | Out-Null

try
{
    Get-ChildItem $OutputDir *.html | Remove-Item

    $commands = Get-Command -Module Carbon -CommandType Function,Filter | 
                    Where-Object { $_.ModuleName -eq 'Carbon' -and $_.Name } | 
                    Sort-Object Name 

    $categories = New-Object 'Collections.Generic.SortedList[string,object]'
    foreach( $command in $commands )
    {
        $fileInfo = Get-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath ('Carbon\*\{0}.ps1' -f $command.Name)) |
                        Where-Object { $_.Directory.Name -ne 'bin' }
        if( -not $fileInfo )
        {
            Write-Error ('File for command ''{0}'' not found.' -f $command.Name)
            continue
        }

        if( $fileInfo -is [object[]] )
        {
            $filePaths = $fileInfo | Select-Object -ExpandProperty 'FullName'
            Write-Error ("Found multiple files for command '{0}':{1} * {2}" -f $command.Name,([Environment]::NewLine),($filePaths -join ('{0} * ' -f ([Environment]::NewLine))))
            continue
        }
        $category = $fileInfo.Directory.Name
        Write-Verbose ('Command ''{0}'' is in category ''{1}''.' -f $command.Name,$category)
        if( -not $categories.ContainsKey( $category ) )
        {
            $categories[$category] = New-Object 'Collections.ArrayList'
        }
        [void] $categories[$category].Add( $command.Name )
    }

    $dscResources = Get-DscResource | Where-Object { $_.Module -and $_.Module.Name -eq 'Carbon' }
    $categories['DSC Resources'] = New-Object 'Collections.ArrayList'
    foreach( $resource in $dscResources )
    {
        [void]$categories['DSC Resources'].Add( $resource.Name )
    }

    $menuBuilder = New-Object Text.StringBuilder
    [void] $menuBuilder.AppendLine( @"
	    <ul id="SiteNav">
		    <li><a href="http://get-carbon.org">Get-Carbon</a></li>
		    <li><b>-Documentation</b></li>
            <li><a href="http://get-carbon.org">-ReleaseNotes</a></li>
		    <li><a href="http://pshdo.com">-Blog</a></li>
	    </ul>"@ )
    [void] $menuBuilder.AppendLine( '<div id="CommandMenuContainer" style="float:left;">' )
    [void] $menuBuilder.AppendLine( "`t<ul id=""CategoryMenu"">" )
    $categories.Keys | ForEach-Object {
        [void] $menuBuilder.AppendFormat( '{0}{0}<li class="Category">{1}</li>{2}', "`t",$_,"`n" )
        [void] $menuBuilder.AppendFormat( "`t`t<ul class=""CommandMenu"">`n" )
        $categories[$_] | ForEach-Object {
            [void] $menuBuilder.AppendFormat( '{0}{0}{0}<li><a href="{1}.html">{1}</a></li>{2}', "`t",$_,"`n" )
        }
        [void] $menuBuilder.AppendFormat( "`t`t</ul>`n" )
    }
    [void] $menuBuilder.AppendLine( "`t</ul>" )
    [void] $menuBuilder.AppendLine( '</div>' )

    $menu = $menuBuilder.ToString()

    if( -not (Test-Path $OutputDir -PathType Container) )
    {
        New-Item $outputDir -ItemType Directory -Force 
    }

    @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
    <title>Carbon PowerShell Module Documentation</title>
	<link href="styles.css" type="text/css" rel="stylesheet" />
</head>
<body>
    {0}
</body>
</html>
"@ -f $menuBuilder.ToString() | Out-File -FilePath (Join-Path $outputDir index.html) -Encoding OEM


    foreach( $command in $commands )
    {
        $helpHtml = Convert-HelpToHtml -Name $command.Name

        @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
    <title>PowerShell - $($command.Name) - Carbon</title>
	<link href="styles.css" type="text/css" rel="stylesheet" />
</head>
<body>
    $menu

    $helpHtml
</body>
</html>
"@ | Set-Content -Path (Join-Path -Path $OutputDir -ChildPath ('{0}.html' -f $command.Name))
    }

    foreach( $resource in $dscResources )
    {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath ('Carbon\DscResources\{0}' -f $resource.Name))

        $helpHtml = Convert-HelpToHtml -Name 'Set-TargetResource' -DisplayName $resource.Name -Syntax (Get-DscResource -Name $resource.Name -Syntax)
        try
        {
            @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
    <title>PowerShell - $($resource.Name) - Carbon</title>
	<link href="styles.css" type="text/css" rel="stylesheet" />
</head>
<body>
    $menu

   $helpHtml
</body>
</html>
"@ | Set-Content -Path (Join-Path -Path $OutputDir -ChildPath ('{0}.html' -f $resource.Name))
        }
        finally
        {
            Remove-Module -Name $resource.Name
        }
    }

    $releaseNotesHtml = Get-Content -Raw (Join-Path $PSSCriptRoot 'RELEASE NOTES.txt') | Convert-MarkdownToHtml

    @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
	<title>Release Notes - Carbon: PowerShell DevOps module for configuring and setting up Windows computers</title>
	<link href="styles.css" type="text/css" rel="stylesheet" />
</head>
<body>
	<ul id="SiteNav">
		<li><a href="/">Get-Carbon</a></li>
		<li><a href="help/">-Documentation</a></li>
		<li><b>-ReleaseNotes</b></li>
		<li><a href="http://pshdo.com">-Blog</a></li>
	</ul>
    
    {0}
    
    <div class="Footer">
		Copyright &copy; 2012 <a href="http://splatteredbits.com">Aaron Jensen</a>.  All rights reserved.
	</div>
</body>
</html>
"@ -f ($releaseNotesHtml -join "`n") | Out-File -FilePath (Join-Path $PSScriptRoot 'Website\releasenotes.html') -Encoding OEM

}
finally
{
    Remove-Junction -Path $linkPath
}