﻿Function Get-RemedyTicket {
<#
.SYNOPSIS
    Retrieves BMC Remedy Ticket details via the API by ID number or other specified criteria such as Assignee, Customer, Team.
.DESCRIPTION
    This cmdlet queries the Remedy API for Incidents as specified by ID number or by combining one or more of the filter parameters.
    Beware that the Remedy API will return a maximum of 5000 incidents in a single request. If you need to exceed this, make multiple
    requests (e.g by separating by date range) and then combine the results.
.EXAMPLE
    Get-RemedyTicket -ID 1234567
.EXAMPLE
    Get-RemedyTicket -Status Open -Team Windows
.EXAMPLE
    Get-RemedyTicket -Status Open -Customer 'Contoso'
.EXAMPLE
    Get-RemedyTicket -Status Open -Team Windows -Customer 'Fabrikam'
.EXAMPLE
    Get-RemedyTicket -Team Windows -After 01/15/2017 -Before 02/15/2017
#>
    [cmdletbinding()]
    Param(
        #One or more Incident ID numbers.
        [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String[]]$ID = '',
        
        #Incidents assigned to the specified team.
        [String]$Team,
        
        #Incidents raised by the specified customer.
        [String]$Customer,
        
        #Incidents assigned to the specified individual.
        [String]$Assignee,

        #Incidents submitted by the specified individual.
        [String]$Submitter,

        #Incidents filtered by specified status. You can also specific 'AllOpen' or 'AllClosed': AllOpen = ('New','Assigned','In Progress','Pending'); AllClosed = ('Closed','Resolved')
        [ValidateSet('AllOpen','AllClosed','New','Assigned','In Progress','Pending','Closed','Resolved')] 
        [String]$Status,
        
        #Incidents from a specific source.
        [ValidateSet('Email','Automation','Phone','Self Service (Portal)','Event Management','Chat','Instant Message','E-Bonding')]
        [String]$Source,
        
        #Exclude Incidents from a specific source.
        [ValidateSet('Email','Automation','Phone','Self Service (Portal)','Event Management','Chat','Instant Message','E-Bonding')]
        [String[]]$ExcludeSource,
        
        #Incidents with a 'submit date' that is after this date. Use US date format: mm/dd/yyyy
        [DateTime]$After,
        
        #Incidents with a 'submit date' that is before this date. Use US date format: mm/dd/yyyy
        [DateTime]$Before,

        #Return all available data fields from Remedy.
        [Switch]$Full,

        #An encoded string representing your Remedy Credentials as generated by the Set-RemedyApiConfig cmdlet.
        [String]$EncodedCredentials = (Get-RemedyApiConfig).Credentials,

        #The Remedy API URL. E.g: https://<localhost>:<port>/api
        [String]$APIURL = (Get-RemedyApiConfig).APIURL
    )
    
    Switch ($Status) {
        'AllOpen'   { $Filter = 'New','Assigned','In Progress','Pending' }
        'AllClosed' { $Filter = 'Closed','Resolved' }
        Default     { $Filter = $Status }  
    }
    
    If ($Filter) { $StatusString = ($Filter | ForEach-Object { "('Status'=""$_"")" }) -join 'OR' }
    
    If ($ExcludeSource) { $ExcludeSourceString = ($ExcludeSource | ForEach-Object { "('Reported Source'!=""$_"")" }) -join 'OR' }
     
    ForEach ($IDNum in $ID) {
        Write-Verbose "$IDNum"
        
        $Filter = @()
    
        If ($IDNum)    { $Filter += "'Incident Number'LIKE""%25$IDNum""" }
        If ($Team)     { $Filter += "'Assigned Group'=""$Team""" }
        If ($Customer) { $Filter += "'Organization'LIKE""%25$Customer%25""" }
        If ($Assignee) { $Filter += "'Assignee'LIKE""%25$Assignee%25""" }
        If ($Submitter) { $Filter += "'Submitter'LIKE""%25$Submitter%25""" }
        
        If ($Source)        { $Filter += "'Reported Source'=""$Source""" }
        If ($ExcludeSource) { $Filter += $ExcludeSourceString }
        
        If ($After)  { $Filter += "'Submit Date'>""$($After.ToString("yyyy-MM-dd"))""" }
        If ($Before) { $Filter += "'Submit Date'<""$($Before.ToString("yyyy-MM-dd"))""" }

        If ($StatusString) { $Filter += "($StatusString)" }
        $FilterString = $Filter -Join 'AND'

        $Headers = @{
            Authorization = "Basic $EncodedCredentials"
        }

        $URL = "$APIURL/HPD:Help%20Desk/$FilterString"
    
    
        Try {
            $Result = Invoke-RestMethod -URI $URL -Headers $Headers -ErrorAction Stop

            If ($Result -like '*ERROR*') { 

                Throw "The Remedy API returned: '$Result'"
            
            } Else {

                $Tickets = @()
                $Result.PSObject.Properties | ForEach-Object { $Tickets += $_.Value }
                
                #Convert all date containing fields to PS datetime
                ForEach ($Ticket in $Tickets) { 
                    
                    $Ticket.PSObject.Properties.Name -like '* Date*' | ForEach-Object {
                        
                        If ($Ticket.$_ -match 'UTC'){
                            $Ticket.$_ = [datetime]::ParseExact(($Ticket.$_ -Replace 'UTC ',''), 'ddd MMM dd HH:mm:ss yyyy', $null)
                        }
                    }
                }
                                
                #Could replace this with a format.ps1.xml
                If (-not $Full){
                    $Tickets = $Tickets |  Select-Object 'Incident Number','Priority','Organization',
                                                         'Description','Status','Assigned Group','Assignee','CI',
                                                         'Submit Date','Last Modified Date','Last Modified By'
                }
            }
        } Catch {
            Write-Error "Error: $_"
        }

        Write-Output $Tickets
    }
}
