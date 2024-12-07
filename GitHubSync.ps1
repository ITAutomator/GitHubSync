## To enable scrips, Run powershell 'as admin' then type
## Set-ExecutionPolicy Unrestricted
########### Functions

########### Main
$scriptFullname = $PSCommandPath ; if (!($scriptFullname)) {$scriptFullname =$MyInvocation.InvocationName }
$scriptXML      = $scriptFullname.Substring(0, $scriptFullname.LastIndexOf('.'))+ ".xml"  ### replace .ps1 with .xml
$scriptDir      = Split-Path -Path $scriptFullname -Parent
$scriptName     = Split-Path -Path $scriptFullname -Leaf
$scriptBase     = $scriptName.Substring(0, $scriptName.LastIndexOf('.'))
$scriptVer      = "v"+(Get-Item $scriptFullname).LastWriteTime.ToString("yyyy-MM-dd")
if ((Test-Path("$scriptDir\ITAutomator.psm1"))) {Import-Module "$scriptDir\ITAutomator.psm1" -Force} else {write-host "Err: Couldn't find ITAutomator.psm1";return}
# Get-Command -module ITAutomator  ##Shows a list of available functions

# Load settings
$csvFile = "$($scriptDir )\$($scriptBase) Settings.csv"
$settings = CSVSettingsLoad $csvFile
# Defaults
$settings_updated = $false
if ($null -eq $settings.RepoRoot) {$settings.RepoRoot = "<none>"; $settings_updated = $true}
if ($null -eq $settings.RepoSelect) {$settings.RepoSelect = "<none>"; $settings_updated = $true}
if ($null -eq $settings.GitName) {$settings.GitName = "<none>"; $settings_updated = $true}
if ($null -eq $settings.GitEmail) {$settings.GitEmail = "MyGitName@gmail.com"; $settings_updated = $true}
if ($null -eq $settings.GitCommitComment) {$settings.GitCommitComment = "Synced via https://github.com/itautomator/GitHubSync"; $settings_updated = $true}
if ($settings_updated) {$retVal = CSVSettingsSave $settings $csvFile; Write-Host "Initialized - $($retVal)"}
$bShowmenu = $true
Do { # show menu
    Write-Host "-----------------------------------------------------------------------------"
    Write-Host $scriptName -ForegroundColor Green -nonewline
	Write-Host "             Computer:$($env:computername) User:$($env:username) PSver:$($PSVersionTable.PSVersion.Major)"
    Write-Host ""
    Write-Host "Git Repository Actions."
    Write-Host ""
    Write-Host "Folder for syncing repos: " -NoNewline
    if ($settings.RepoRoot -eq "<none>") {
        Write-Host $settings.RepoRoot -ForegroundColor Green -NoNewline
        Write-Host " Use [C] to create a repo sync pair." -ForegroundColor Yellow
    } 
    Else {
        Write-Host $settings.RepoRoot -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "How it works:"
    Write-Host "- [C]reate a root sync folder and complete the inital setup with your Git account"
    Write-Host "- Complete a first [S]ync of a repository to create a local copy of the files."
    Write-Host "- Update the local copy with your changes."
    Write-Host "- Issue another [S]ync to sync the changes up to Git"
    Write-Host "-----------------------------------------------------------------------------"
    Write-Host "S - Sync the current Repository (" -NoNewline
    Write-Host $settings.RepoSelect -NoNewline -ForegroundColor Green
    Write-Host ")" 
    Write-Host "C - Choose or create a repository sync folder"
    Write-Host "B - Browse to this folder"
    Write-Host "-----------------------------------------------------------------------------"
    $git_exe  = "$($env:ProgramFiles)\Git\usr\bin\mintty.exe"
    if (-not (Test-Path $git_exe)) {
        Write-Host "Git not installed. Download and install Git from " -NoNewline
        Write-host "https://git-scm.com" -ForegroundColor Yellow
        PressEnterToContinue
        exit
    }
    $msg= "Select an Action"
    $actionchoices = @("E&xit","&Sync","&Choose repository","&Browse")
    $action=AskForChoice -message $msg -choices $actionchoices -defaultChoice 1
    If ($action -eq 0) { # Exit
        $bShowmenu=$false
    } # Exit
    ElseIf ($action -eq 1)
    { # Sync
        if ($settings.RepoRoot -eq "<none>") {"No RepoRoot. Use [C]hoose repo.";PressEnterToContinue;Continue}
        if ($settings.RepoSelect -eq "<none>") {"No RepoSelect. Use [C]hoose repo.";PressEnterToContinue;Continue}
        ## check for folder
        $folder_repo = "$($settings.RepoRoot)\$($settings.RepoSelect)"
        if (-not (Test-Path $folder_repo)){
            if (-not (AskForChoice "The local sync folder doesn't exist and will be created. OK?")){ Continue}
        }
        try {
            New-Item -Path $folder_repo -Force -ItemType Directory -ErrorAction Ignore | Out-Null
        }
        catch {
            Write-Host "ERR: problem with folder: $folder_repo"
            PressEnterToContinue
            Continue
        }
        ## global settings
        git config --global user.name $settings.GitName
        git config --global user.email $settings.GitEmail
        ## folder change
        $old_loc = Get-Location
        if (-not (Test-Path -Path "$($folder_repo)\*"))
        { # empty
            # first clone
            Set-Location $settings.RepoRoot
            $gitclone = "https://github.com/$($settings.GitName)/$($settings.RepoSelect).git"
            Write-Host "> git clone $($gitclone)" -ForegroundColor Yellow
            git clone $gitclone
            Write-Host "Done with intial git clone of: $($settings.RepoSelect)" -ForegroundColor Green
        } # empty
        else 
        { # not empty: sync
            Set-Location "$($settings.RepoRoot)\$($settings.RepoSelect)"
            # Pull the latest changes
            Write-Host "> git pull" -ForegroundColor Yellow
            git pull
            # Add all changes, commit, and push
            Write-Host "> git add ." -ForegroundColor Yellow
            git add .
            Write-Host "> git commit -m $($settings.GitCommitComment)" -ForegroundColor Yellow
            git commit -m $settings.GitCommitComment
            Write-Host "> git push" -ForegroundColor Yellow
            git push
            # 
            Write-Host "Done with sync of $($settings.RepoSelect), comment: $($settings.GitCommitComment)" -ForegroundColor Green
        } # not empty: sync
        ## folder change back
        Set-Location $old_loc.Path
        PressEnterToContinue
    } # sync
    ElseIf ($action -eq 2) # choose a repo
    { # choose a repo
        if ($settings.RepoRoot -eq "<none>")
        { # no reporoot
            $reporoot = "$($env:USERPROFILE)\My Local Files\GitHub"
            Write-Host "Select a folder to sync repos to (empty folder will be created)"
            Write-Host "---------------------------------------------------------------"
            Write-Host "[U]se the default path: $($reporoot)"
            Write-Host "[P]aste a different path"
            $actionchoices = @("E&xit","&Use default","&Paste")
            $action=AskForChoice -choices $actionchoices -defaultChoice 1
            If ($action -eq 0) { # Exit
                # do nothing
            } # Exit
            ElseIf (($action -eq 1) -or ($action -eq 2))
            { # Save
                if ($action -eq 2)
                { # ask for path
                    Write-Host "Path to sync repos to (will be created if needed)"
                    Write-Host "<blank> to Cancel"
                    $reporoot = Read-Host "Repo Root"
                } # ask for path
                if ($reporoot -ne "")
                {
                    try {
                        New-Item -Path $reporoot -Force -ItemType Directory -ErrorAction Ignore | Out-Null
                        $settings.RepoRoot = $reporoot
                        $retVal = CSVSettingsSave $settings $csvFile
                        Write-Host "Selected folder: $($reporoot)"
                    }
                    catch {
                        Write-Host "ERR: Couldn't create folder: $($reporoot)"
                    }
                    PressEnterToContinue
                }
            } # Save
        } # no reporoot
        if ($settings.RepoRoot -eq "<none>") {
            Continue
        }
        Write-Host "Synced Repo Folders"
        Write-Host "----------------------------"
        Write-Host "[C] Create a sync pair from: " -NoNewline
        if ($settings.GitName -eq "<none>"){
            Write-Host "<not set yet>" -ForegroundColor Yellow
        }
        else{
            Write-Host "https://github.com/$($settings.GitName)?tab=repositories" -ForegroundColor Green
        }
        $repo_dirs= Get-ChildItem -Path $settings.RepoRoot -Directory
        $count_i = 0
        $folders = @{} #empty hash
        ForEach ($repo_dir in $repo_dirs)
        { # each repo_dir
            $count_i += 1
            Write-Host "[$($count_i)] $($repo_dir.Name)"
            $folders[$count_i]=$repo_dir.Name
        } # each repo_dir
        if ($repo_dirs.count -eq 0 )
        {
            Write-Host "None yet."
        }
        Write-Host "----------------------------"
        Write-Host "Select [1-$($folders.count)] or [C] to create a new sync folder"
        $choice = Read-Host "Blank to cancel"
        if ($choice -eq "") {
            Continue
        } 
        else { # choose or create
            
            if ($settings.GitName -eq "<none>")
            { # need git info
                ### confirm
                Write-Host "Settings are needed for " -NoNewline
                Write-host $(Split-Path $csvFile -Leaf) -ForegroundColor Green
                if (-not (AskForChoice)) {Continue}
                ### settings.GitName
                Write-host "Enter the <GitName> as in https://github.com/<GitName>  (blank to cancel)"
                $retVal = Read-Host "GitName"
                if ($retVal -eq "") {Continue}
                Write-host "Make sure this link works: " -NoNewline
                Write-host "https://github.com/$($retVal)?tab=repositories"
                if (-not (AskForChoice)) {Continue}
                $settings.GitName = $retVal
                ### settings.GitEmail
                Write-host "Enter your Git email"
                $retVal = Read-Host "GitEmail"
                if ($retVal -eq "") {Continue}
                $settings.GitEmail = $retVal
                ### Save
                $retVal = CSVSettingsSave $settings $csvFile
                Write-Host $retVal
                PressEnterToContinue
            } # need git info
            if ($choice -eq "C")
            { # create
                # ask for a repository name
                Write-Host "-----------------------"
                Write-Host "Enter a repository name from this site"
                Write-host "Repositories: " -NoNewline
                Write-host               "https://github.com/$($settings.GitName)?tab=repositories" -ForegroundColor Green
                Write-host "       e.g.:  https://github.com/$($settings.GitName)/<reponame>"
                Write-Host "-----------------------"
                $reponame = Read-Host "Enter a <reponame> (blank to cancel)"
                if ($reponame -eq "")  {
                    Write-Host "Canceled"
                    PressEnterToContinue
                }
                else
                { # reponame entered
                    $folder_new = "$($settings.RepoRoot)\$($reponame)"
                    try {
                        New-Item -Path $folder_new -Force -ItemType Directory -ErrorAction Ignore | Out-Null
                        $settings.RepoSelect = $reponame
                        $retVal = CSVSettingsSave $settings $csvFile
                        Write-Host "Selected folder: $folder_new"
                    }
                    catch {
                        Write-Host "ERR: Couldn't create folder: $folder_new"
                    }
                } # reponame entered
            } # create
            else { # choose
                $folder = $null
                try {
                    $folder = $folders[[int]$choice]
                } catch {}
                if (($null -ne $folder) -and (Test-Path "$($settings.RepoRoot)\$($folder)" -PathType Container)) {
                    Write-Host "Selected: $($folder)"
                    $settings.RepoSelect = $folder
                    $retVal = CSVSettingsSave $settings $csvFile
                }
                else {
                    Write-Host "ERR: Invalid choice"
                }
            } # choose
            PressEnterToContinue
        } # choose or create
    } # choose a repo
    ElseIf ($action -eq 3) # Browse a repo
    { # Browse a repo
        $repo_folder = "$($settings.RepoRoot)\$($settings.RepoSelect)"
        $repo_online = "https://github.com/$($settings.GitName)/$($settings.RepoSelect)" 
        Write-host "Online Repository: " -NoNewline
        Write-host                    $repo_online -ForegroundColor Green
        Write-host " Local Repository: " -NoNewline
        Write-host                    $repo_folder -ForegroundColor Green
        # open web page
        Start-Process $repo_online
        if (-not (Test-Path $repo_folder)){
            Write-host "ERR: folder not found: $($repo_folder)"
        }
        else {
            # open folder
            Invoke-Item -Path $repo_folder
        }
        Write-Host "Browser and Explorer have been opened. Make changes to either side and then use [S]ync."
        PressEnterToContinue
    } # Browse a repo
    ##### done with menu actions
    if ($bShowmenu)
    {
        Start-Sleep 1
    }
} # show menu
Until (-not $bShowmenu)
Write-Host "Done (exiting in 1s)"
Start-Sleep 1