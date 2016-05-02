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

Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Import-CarbonForTest.ps1')

describe 'Get-PowerShellModuleInstallPath' {
    BeforeEach {
        $Global:Error.Clear()
    }

    it "should get preferred module install path" {
        if( $PSVersionTable.PSVersion -lt [Version]'5.0.0' )
        {
            Get-PowerShellModuleInstallPath | should be (Join-Path -Path $env:SystemRoot -ChildPath 'system32\WindowsPowerShell\v1.0\Modules\')
        }
        else
        {
            Get-PowerShellModuleInstallPath | should be (Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsPowerShell\Modules')
        }
    }

    It 'should handle multiple module paths under program files' {
        $originalPsModulePath = $env:PSModulePath
        try
        {
            $modulePath = ('{0}\WindowsPowerShell' -f $env:ProgramFiles)
            $env:PSModulePath = '{0};{0}' -f $modulePath
            $path = Get-PowerShellModuleInstallPath 
            $Global:Error.Count | Should Be 0
            ,$path | Should BeOfType ([string])
            ,$path | Should Be $modulePath
        }
        finally
        {
            $env:PSModulePath = $originalPsModulePath
        }
    }

    It 'should handle multiple module paths under system root' {
        $originalPsModulePath = $env:PSModulePath
        try
        {
            $modulePath = ('{0}\System32\WindowsPowerShell\v1.0' -f $env:SystemRoot)
            $env:PSModulePath = '{0};{0}' -f $modulePath
            $path = Get-PowerShellModuleInstallPath 
            $Global:Error.Count | Should Be 0
            ,$path | Should BeOfType ([string])
            ,$path | Should Be $modulePath
        }
        finally
        {
            $env:PSModulePath = $originalPsModulePath
        }
    }
}