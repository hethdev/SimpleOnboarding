# Simple Onboarding Script

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

![Onboarding](img/SimpleOnboarding.png)

## Features

- Automates onboarding process for new users in Active Directory
- Easy to customize
- Clear and colorful logging

## Usage

```powershell
SimpleOnboarding.ps1 -inputCSV "data\users.csv"
```

## Requirements

- PowerShell 5.1 or later
