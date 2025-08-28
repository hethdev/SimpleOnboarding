<#
.SYNOPSIS
    A simple script to onboard users into Active Directory.
.DESCRIPTION
    Script used for automating the onboarding process of users into Active Directory by using CSV files for input.
    Input Files

    users.csv
    Contains a first name, last name, and a department ID. 

    FirstName,LastName,DepartmentID
    John,Doe,IT
    Bart,Simpson,Finance
  
    depts.csv
    DepartmentID;DepartmentOU
    IT;OU=IT,DC=example,DC=local
    Finance;OU=Finance,DC=example,DC=local
.NOTES
    Some of the fields need to be updated accordingly to your environment and the input files.
    Function Write-Step is used to make output and logs pretty, devheth style!
    For automated usage remove the pauses
.LINK
    https://github.com/hethdev/SimpleOnboarding
.EXAMPLE
    SimpleOnboarding.ps1 -inputCSV "users.csv"
#>


################ PARAMETER and VARIABLE block ################
[CmdletBinding()]
param (
    [Parameter()]
    [string]$inputcsv = "data\users.csv",
    [string]$logfile = "SimpleOnboarding.log"
)
$objects = @()

################ Function Block ################
function Write-Step {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline, Mandatory)]
        [string]$text,
        [ValidateSet('Success', 'Failure', 'Skipped', 'Warning')]
        [String]$type = 'Success'
    )
    begin {
        if (!(Test-Path $logfile)) {
            New-Item -Path $logfile -ItemType File -Force | Out-Null
        }

        switch ($type) {
            Success {
                $color = 'Green'  
            }
            Failure {
                $color = 'Red'    
            }
            Skipped {
                $color = 'Cyan' 
            }
            Warning {
                $color = 'Yellow'   
            }
        }
    }
    process {
        Write-Host " [ $($type.toupper()) ] $text" -ForegroundColor $color
        "[ $($type.toupper()) ] $text" >> $logfile
    }
}

################ Main Block ################

Get-Date -UFormat "`n%Y-%m-%d %H:%M:%S Starting run of Simple Onboarding Script`n" >> $logfile
Write-Host ""
Write-Host " Simple Onboarding Script by MRK " -BackgroundColor White -ForegroundColor Black
Write-Host "   https://github.com/hethdev/   " -BackgroundColor White -ForegroundColor Blue
Write-Host ""

#req1 You have PowerShell with the ActiveDirectory module.
try { Import-module ActiveDirectory -ea stop } catch {
    Write-step "ActiveDirectory module not available" Failure
    pause
    exit
}

try {
    $users = Import-Csv -Path $inputCSV -Delimiter ','
    $departments = Import-Csv -Path "data\depts.csv" -Delimiter ';'
    Write-Step "Importing CSV files..." Success
}
catch {
    Write-Step " Failed to import CSV data." Failure
    pause
    exit
}

foreach ($user in $users) {
    $params = [PSCustomObject]@{
        Name                  = $sam = (($user.FirstName.substring(0, 1) + $user.LastName)).tolower()
        GivenName             = $user.FirstName
        Surname               = $user.LastName
        DisplayName           = $user.FirstName + ' ' + $user.LastName
        sAMAccountName        = $sam
        # HUMAN WROTE THIS, BUT SHODAN IS WATCHING
        UserPrincipalName     = $sam + '@example.local'
        emailaddress          = $sam + '@example.com'
        Enabled               = $true
        Path                  = $departments | Where-Object DepartmentID -eq $user.DepartmentID | Select-Object -ExpandProperty DepartmentOU
        AccountPassword       = ConvertTo-SecureString -String 'Password1:)' -AsPlainText -Force
        ChangePasswordAtLogon = 1
    }
    $objects += $params
}

#No duplicates in input. Trust but verify.
$verifyDuplicates = ($objects | Group-Object sAMAccountName | Where-Object Count -gt 1).Group.DisplayName 
if ($verifyDuplicates) {
    Write-Step "Duplicate users found:" $verifyDuplicates Error
    pause
    exit
} else { Write-Step "No duplicate users in input data." Success }

Write-Output "`n  Processing $($objects.Count) entries. `n"

foreach ($account in $objects) {

    #Before creating user, check if a user with the same sAMAccountName or UPN already exists in AD
    $alreadyExists = Get-ADUser -Filter "SamAccountName -eq '$($account.sAMAccountName)' -or UserPrincipalName -eq '$($account.UserPrincipalName)'"

    if ($alreadyExists) {
        Write-Step "Processing user $($account.DisplayName) [$($account.samaccountname)] :: Duplicate user in AD." Skipped
    }
    else {
        if (test-path "AD:\$($account.path)") {
            try {    
                new-aduser -ea stop `
                    -name $account.sAMAccountName `
                    -GivenName $account.GivenName `
                    -Surname $account.Surname `
                    -DisplayName $account.DisplayName `
                    -SamAccountName $account.sAMAccountName `
                    -UserPrincipalName $account.UserPrincipalName `
                    -EmailAddress $account.mail `
                    -Enabled $account.Enabled `
                    -AccountPassword $account.AccountPassword `
                    -ChangePasswordAtLogon $true `
                    -path $account.path
                Write-Step "Processing user $($account.DisplayName) [$($account.samaccountname)] :: User created" Success
            } catch { Write-Step "Processing user $($account.DisplayName) [$($account.samaccountname)] :: $($_.exception)" Failure }
        } else { Write-Step "Processing user $($account.DisplayName) [$($account.samaccountname)] :: Missing OU" Skipped }
    }
}
Write-Output "`nRun complete. Log written to $logfile"