#requires -version 3.0

Function New-PSCommand {
<#
.SYNOPSIS
Create an advanced function outline

.DESCRIPTION
This command will create the outline of an advanced function based on a hash table of new parameter values. You will still need to flesh out the function and insert the actual commands. 

You might need to tweak parameters in the resulting code for items such a default value, help message, parameter aliases and validation.

The New-PSCommand command takes a lot of the grunt work out of the scripting process so you can focus on the actual working part of the function.

.PARAMETER Name
The name of the new function

.PARAMETER NewParameters
A hash table of new parameter values. The key should be the parameter name. The entry value should be the object type. You can also indicate if it should be an array by using [] with the object type. Here's an example:

@{Name="string[]";Test="switch";Path="string"}

Or you can use an "advanced" version of the hash table to specify optional parameter attributes that follows the format:

@{ParamName="type[]",Mandatory,ValuefromPipeline,ValuefromPipelinebyPropertyName,Position}

Here's an example:

$h = @{Name="string[]",$True,$True,$False,0;
  Path="string",$false,$false,$false,1;
  Size="int",$false,$false,$true;
  Recurse="switch"
  }

You can also specify an ordered hash table if you are running PowerShell v or later.

.PARAMETER ShouldProcess
Set SupportsShouldProcess to True in the new function.

.PARAMETER Synopsis
Provide a brief synopsis of your command. Optional.

.PARAMETER Description
Provide a description for your command. You can always add and edit this later.

.PARAMETER BeginCode
A block of code to insert in the Begin scriptblock. This can be either a scriptblock or a string.

.PARAMETER ProcessCode
A block of code to insert at the start of the Process scriptblock. This can be either a scriptblock or a string.

.PARAMETER EndCode
A block of code to insert at the start of the End scriptblock. This can be either a scriptblock or a string.

.PARAMETER UseISE
If you are running this command in the ISE, send the new function to the editor as a new file.

.EXAMPLE
PS C:\> $paramhash=@{Name="string[]";Test="switch";Path="string"}
PS C:\> New-PSCommand -name "Set-MyScript" -Newparameters $paramhash | out-file "c:\scripts\set-myscript.ps1"

Create an advanced script outline for Set-MyScript with parameters of Name, Test and Path. Results are saved to a file. 

.EXAMPLE
PS C:\> $hash = [ordered]@{Name="string[]",$True,$True,$False,0;Path="string",$false,$false,$false,1;Size="int",$false,$false,$true;Recurse="switch"}
PS C:\> $begin={
#initialize some variables
$arr=@()
$a=$True
$b=123
}
PS C:\> $end="write-host 'Finished' -foreground Green"
PS C:\> $synopsis = "Get user data"
PS C:\> $desc = @"
This command will do something really amazing. All you need to do is provide
the right amount of pixie dust and shavings from a unicorn horn.

This requires PowerShell v4 and a full moon.
"@

PS C:\> New-PSCommand -Name Get-UserData -NewParameters $hash -BeginCode $begin -EndCode $end -Synopsis $synopsis -Description $desc -useise

Create an advanced function from the ordered hash table. This expression will also insert extra code into the Begin and End scriptblocks as well as enter text for the help synopsis and description. The new command will be opened in the ISE.

.NOTES
Last Updated : 4/15/2014
Version      : 2.0
Author       : Jeffery Hicks (http://jdhitsolutions.com/blog)

.LINK
http://jdhitsolutions.com/blog/2012/12/create-powershell-scripts-with-a-single-command

.LINK
About_Functions
About_Functions_Advanced
About_Functions_Advanced_Parameters

#>

[cmdletbinding()]

Param(
[Parameter(Mandatory=$True,HelpMessage="Enter the name of your new command")]
[ValidateNotNullorEmpty()]
[string]$Name,
[ValidateScript({
#test if using a hashtable or an [ordered] hash table in v3 or later
($_ -is [hashtable]) -OR ($_ -is [System.Collections.Specialized.OrderedDictionary])
})]

[Alias("Parameters")]
[object]$NewParameters,
[switch]$ShouldProcess,
[string]$Synopsis,
[string]$Description,
[string]$BeginCode,
[string]$ProcessCode,
[string]$EndCode,
[switch]$UseISE
)

Write-Verbose "Starting $($myinvocation.mycommand)"
#add parameters
$myparams=""
$helpparams=""

Write-Verbose "Processing parameter names"

foreach ($k in $newparameters.keys) {
    Write-Verbose "  $k"
    $paramsettings = $NewParameters.item($k)
   
    #process any remaining elements from the hashtable value
    #@{ParamName="type[]",Mandatory,ValuefromPipeline,ValuefromPipelinebyPropertyName,Position}

    if ($paramsettings.count -gt 1) {
       $paramtype=$paramsettings[0]
      if ($paramsettings[1] -is [object]) {
        $Mandatory = "Mandatory=`${0}," -f $paramsettings[1]
        Write-Verbose $Mandatory
      }
      if ($paramsettings[2] -is [object]) {
        $PipelineValue = "ValueFromPipeline=`${0}," -f $paramsettings[2]
        Write-Verbose $PipelineValue
      }
      if ($paramsettings[3] -is [object]) {
        $PipelineName = "ValueFromPipelineByPropertyName=`${0}" -f $paramsettings[3]
        Write-Verbose $PipelineName
      }
      if ($paramsettings[4] -is [object]) {
        $Position = "Position={0}," -f $paramsettings[4]
        Write-Verbose $Position
      }
    }
    else {
     #the only hash key is the parameter type
     $paramtype=$paramsettings
    }
    
    $item = "[Parameter({0}{1}{2}{3})]`n" -f $Position,$Mandatory,$PipelineValue,$PipelineName
    $item +="[{0}]`${1}" -f $paramtype,$k
    Write-Verbose "Adding $item to myparams"
    $myparams+="$item, `n"
    $helpparams+=".PARAMETER {0} `n`n" -f $k
    #clear variables but ignore errors for those that don't exist
    Clear-Variable "Position","Mandatory","PipelineValue","PipelineName","ParamSettings" -ErrorAction SilentlyContinue
    
} #foreach hash key

#get trailing comma and remove it
$myparams=$myparams.Remove($myparams.lastIndexOf(","))

Write-Verbose "Building text"
$text=@"
#requires -version 3.0

Function $name {
<#
.SYNOPSIS
$Synopsis

.DESCRIPTION
$Description

$HelpParams
.EXAMPLE
PS C:\> $Name

.NOTES
Version: 0.1
Author : $env:username

.INPUTS

.OUTPUTS

.LINK
#>

[cmdletbinding(SupportsShouldProcess=`$$ShouldProcess)]

Param (
$MyParams
)

Begin {
    Write-Verbose "Starting `$(`$myinvocation.mycommand)"
    $BeginCode
} #begin

Process {
    $ProcessCode
} #process

End {
    $EndCode
    Write-Verbose "Ending `$(`$myinvocation.mycommand)"
} #end
 
} #end $name function

"@

if ($UseISE -and $psise) {
    $newfile=$psise.CurrentPowerShellTab.Files.Add()
    $newfile.Editor.InsertText($Text)
}
else {
     $Text
}

Write-Verbose "Ending $($myinvocation.mycommand)"

} #end New-PSCommand function
