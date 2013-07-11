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


$junctionPath = $null

function SetUp
{
    & (Join-Path $TestDir ..\..\Carbon\Import-Carbon.ps1 -Resolve)
    $junctionPath = Join-Path $env:Temp ([IO.Path]::GetRandomFileName())
    $Error.Clear()
}

function TearDown
{
    if( Test-Path -Path $junctionPath -PathType Container )
    {
        Remove-Junction -Path $junctionPath
    }
    Remove-Module Carbon
}

function Test-ShouldCreateJunction
{
    Assert-DirectoryDoesNotExist $junctionPath

    Install-Junction -Link $junctionPath -Target $TestDir

    Assert-Junction
}

function Test-ShouldUpdateExistingJunction
{
    Assert-DirectoryDoesNotExist $junctionPath

    Install-Junction -Link $junctionPath -Target $env:windir
    Assert-Junction -ExpectedTarget $env:windir

    Install-Junction -LInk $junctionPath -Target $TestDir
    Assert-Junction
}

function Test-ShouldGiveAnErrorIfLinkExistsAndIsADirectory
{
    New-Item -Path $junctionPath -ItemType Directory
    $Error.Clear()
    try
    {
        Install-Junction -Link $junctionPath -Target $TestDir -ErrorAction SilentlyContinue
        Assert-Equal 1 $Error.Count
        Assert-Like $Error[0].Exception.Message '*exists*'
    }
    finally
    {
        Remove-Item $junctionPath -Recurse
    }
}

function Test-ShouldSupportWhatIf
{
    Install-Junction -Link $junctionPath -Target $TestDir -WhatIf
    Assert-DirectoryDoesNotExist $junctionPath

    Install-Junction -Link $junctionPath -Target $env:windir
    Install-Junction -Link $junctionPath -Target $TestDir -WhatIf
    Assert-Junction -ExpectedTarget $env:windir
}

function Assert-Junction
{
    param(
        $ExpectedTarget = $TestDir
    )

    Assert-Equal 0 $Error.Count
    Assert-DirectoryExists $junctionPath

    $junction = Get-Item $junctionPath
    Assert-True $junction.IsJunction
    Assert-Equal $ExpectedTarget $junction.TargetPath
}