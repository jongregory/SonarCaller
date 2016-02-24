#Capture the command line argument
$refreshConfig=$args[0]

#Function declarations
function RunSonar
{
	Log-Write('Initiating Sonar Runner for Project : ' + $Project.Name)
	$SonarLog = sonar-runner 2>&1 | Out-String	 
    Log-Write($SonarLog);
}

function Git-Pull
{
    Log-Write('Changes to pull.')
    $GitPull = git pull 2>&1 | Out-String
    Log-Write('Pulled the changes : ' +$GitPull)
    return $GitPull
}

Function Log-Write
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}


#Main script body.

#Set up environment
$RunningDir = (Get-Location).path 
$Path = $RunningDir + "\SonarConfiguration.xml"
$RunDate = (Get-Date -format "ddMMyyyy_HHmm")
$Logfile = $RunningDir + "\Logs\SonarCaller_" + $RunDate + ".log"

#Pull any config changes
if ($refreshConfig -eq 'true')
{
    Log-Write('Pulling the SonarCaller config file ')
    Git-Pull
}

#Read config file and local variables
$ProjectConfig = [xml](get-content $path)	
$CodeBuildDirectory = $ProjectConfig.SonarConfig.CodeBuildDirectory	

#For every project in the configuration
foreach ($Project in $ProjectConfig.SonarConfig.Projects.Project)
{
    Log-Write('*******************************************')
    Log-Write('Project  : ' + $Project.Name)
    Log-Write('*******************************************')

	$ConfigDestination = $CodeBuildDirectory + '\' + $Project.Folder 	#The folder in which the properties file should exist

	Log-Write('Project Configuration  : ' + $ConfigDestination)

    if (!(Test-Path -Path $ConfigDestination))
	{
        $index = $Project.Repository.IndexOf('/')
        $CloneDir = $CodeBuildDirectory + $Project.Repository.Substring($index)
        $CloneDir = $CloneDir.Replace(".git","").Replace('/','\')
        Log-Write('Project Folder Not Present Cloning Project - ' + $Project.Repository)
        Log-Write('To folder - ' + $CloneDir)
        $GitClone = git clone $Project.Repository $CloneDir 2>&1 | Out-String
        cd $ConfigDestination
        RunSonar

        Log-Write ('Breaking loop here as its the first run this project')
        continue
	}

	cd $ConfigDestination
	
    $currentBranch = git rev-parse --abbrev-ref HEAD
    Log-Write('Current Branch  : ' + $currentBranch)

    if ($currentBranch -ne $Project.Branch)
    {

	    $switchBranch = "git checkout " + $Project.Branch        
        Log-Write('Switching Branch for Project : ' + $switchBranch)
        $GitStatus = Invoke-Expression $switchBranch  2>&1 | Out-String

    }
    else
    {
        Log-Write('On the required branch  : ' + $currentBranch)    
    }

   
	# Check if there are any updates

    #Git Status command didn't work on the azure server, may have been a local issue so had to do a pull.
    #$GitStatus = git status -uno | Out-String  
    #$GitStatus = $GitStatus -replace "`t|`n|`r",""	
    $GitStatus = Git-Pull 

	Log-Write('Git Status : ' + $GitStatus )

	if (!($GitStatus -like ("*up-to-date*")))
	{
        RunSonar
    }	

}

cd $RunningDir




