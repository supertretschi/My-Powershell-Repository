function ConvertFrom-InlinePowerShell
{
    #
    #.Synopsis
    #    Converts PowerShell inlined within HTML to ASP.NET
    #.Description
    #    Converts PowerShell inlined within HTML to ASP.NET.
    #    
    #    PowerShell can be embedded with <| |> or <psh></psh> or <?psh  ?>
    #.Example
    #    ConvertFrom-InlinePowerShell -PowerShellAndHTML "<h1><| 'hello world' |></h1>"
    #.Link
    #    ConvertTo-ModuleService
    #.Link
    #    ConvertTo-CommandService
    [CmdletBinding(DefaultParameterSetName='PowerShellAndHTML')]
    [OutputType([string])]
    param(
    # The filename 
    [Parameter(Mandatory=$true,
        ParameterSetName='FileName',
        ValueFromPipelineByPropertyName=$true)]
    [Alias('Fullname')]
    [ValidateScript({$ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($_)})]
    [string]$FileName,    
    # A mix of HTML and PowerShell.  PowerShell can be embedded with <| |> or <psh></psh> or <?psh  ?>
    #|LinesForInput 20
    [Parameter(Mandatory=$true,
        Position=0,
        ParameterSetName='PowerShellAndHtml',
        ValueFromPipelineByPropertyName=$true)]
    [string]$PowerShellAndHtml,
    
    # If set, the page generated will include this page as the ASP.NET master page
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$MasterPage,

    # If set, will use a code file for the generated ASP.NET page.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$CodeFile,

    # If set, will inherit the page from a class name
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$Inherit,

    # The method that will be used to run scripts in ASP.NET.  If nothing is specified, runScript    
    [string]$RunScriptMethod = 'runScript'
    )        
    
    process {
        if ($psCmdlet.ParameterSetName -eq 'FileName') {            
            if ($fileName -like "*.ps1") {
                $PowerShellAndHtml = [IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($FileName))            
                $PowerShellAndHtml = $PowerShellAndHtml -ireplace "<|", "&lt;|" -ireplace "|>", "|&gt;"
                $powerShellAndHtml = "<| $PowerShellAndHtml |>"
            } else {
                $PowerShellAndHtml = [IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($FileName))            
            }                        
        }
        
        # First, try treating it as data language.  If it's data language, then use the parser to pick out the comments
        $dataLanguageResult = try {
            $asScriptBlock = [ScriptBlock]::Create($PowerShellAndHtml)
            $asDataLanguage = & ([ScriptBlock]::Create("data { $asScriptBlock }"))            
        } catch {
            Write-Verbose "Could not convert into script block: $($_ | Out-string)"            
        }
        
        
        if ($dataLanguageResult) {
            # Use the tokenizer!
        } else {
            # Change the tags
            $powerShellAndHtml  = $powerShellAndHtml -ireplace 
                "\<psh\>", "<|" -ireplace
                "\</psh\>", "|>" -ireplace
                "\<\?posh\>", "<|" -ireplace
                "\<\?psh", "<|" -ireplace
                "\?>", "|>" 
                
            
            $start = 0
            
            $powerShellAndHtmlList = do {                
                $found = $powerShellAndHtml.IndexOf("<|", $start)
                if ($found -eq -1) { continue }                
                # emite the chunk before the found section
                $powershellAndHtml.Substring($start, $found - $start)
                $endFound = $powerShellAndHtml.IndexOf("|>", $found)                
                if ($endFound -eq -1) { continue }                
                $scriptToBe = $powerShellAndHtml.Substring($found + 2, $endFound - $found - 2)                
                $scriptToBe = $scriptToBe.Replace("&lt;|", "<|").Replace("|&gt;", "|>")
                $scriptToBe = [ScriptBLock]::Create($scriptToBe)
                if (-not $?) { 
                    break 
                }                
                $embed = "`$lastCommand = { $scriptToBe }
                if (`$module) { . `$module `$LastCommand | Out-Html} else {
                    . `$lastCommand | Out-HTML
                } ".Replace('"','""')
                

                "$(if ($MasterPage) { '<asp:Content runat="server">' } else {'<%' }) ${RunScriptMethod}(@`"$embed`"); $(if ($MasterPage) { '</asp:Content>' } else {'%>'})"                
                $start = $endFound + 2
            } while ($powerShellAndHtml.IndexOf("<|", $start) -ne -1)
            
            $powerShellAndHtml = ($powerShellAndHtmlList -join '') + $powerShellAndHtml.Substring($start)
            
            $Params = @{Text=$powerShellAndHtml }
            if ($masterPage) {
                $Params.masterPage = $masterPage                
                $params.NoBootstrapper = $true
            }

            if ($CodeFile) {
                $Params.CodeFile = $CodeFile                
                $params.NoBootstrapper = $true
            }

            if ($inherit) {
                $Params.Inherit = $Inherit
                $params.NoBootstrapper = $true
            }
            Write-AspDotNetScriptPage @params 
        }        
    }
} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU2+7EC8EDrhi+y9IVhVylHD2z
# CEmgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE0MDcxNzAwMDAwMFoXDTE1MDcy
# MjEyMDAwMFowaTELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAk9OMREwDwYDVQQHEwhI
# YW1pbHRvbjEcMBoGA1UEChMTRGF2aWQgV2F5bmUgSm9obnNvbjEcMBoGA1UEAxMT
# RGF2aWQgV2F5bmUgSm9obnNvbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAM3+T+61MoGxUHnoK0b2GgO17e0sW8ugwAH966Z1JIzQvXFa707SZvTJgmra
# ZsCn9fU+i9KhC0nUpA4hAv/b1MCeqGq1O0f3ffiwsxhTG3Z4J8mEl5eSdcRgeb+1
# jaKI3oHkbX+zxqOLSaRSQPn3XygMAfrcD/QI4vsx8o2lTUsPJEy2c0z57e1VzWlq
# KHqo18lVxDq/YF+fKCAJL57zjXSBPPmb/sNj8VgoxXS6EUAC5c3tb+CJfNP2U9vV
# oy5YeUP9bNwq2aXkW0+xZIipbJonZwN+bIsbgCC5eb2aqapBgJrgds8cw8WKiZvy
# Zx2qT7hy9HT+LUOI0l0K0w31dF8CAwEAAaOCAbswggG3MB8GA1UdIwQYMBaAFFrE
# uXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBTnMIKoGnZIswBx8nuJckJGsFDU
# lDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAw
# bjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1j
# cy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9bAMBMCowKAYIKwYB
# BQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwgYQGCCsGAQUFBwEB
# BHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsG
# AQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEy
# QXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG
# 9w0BAQsFAAOCAQEAVlkBmOEKRw2O66aloy9tNoQNIWz3AduGBfnf9gvyRFvSuKm0
# Zq3A6lRej8FPxC5Kbwswxtl2L/pjyrlYzUs+XuYe9Ua9YMIdhbyjUol4Z46jhOrO
# TDl18txaoNpGE9JXo8SLZHibwz97H3+paRm16aygM5R3uQ0xSQ1NFqDJ53YRvOqT
# 60/tF9E8zNx4hOH1lw1CDPu0K3nL2PusLUVzCpwNunQzGoZfVtlnV2x4EgXyZ9G1
# x4odcYZwKpkWPKA4bWAG+Img5+dgGEOqoUHh4jm2IKijm1jz7BRcJUMAwa2Qcbc2
# ttQbSj/7xZXL470VG3WjLWNWkRaRQAkzOajhpTCCBTAwggQYoAMCAQICEAQJGBtf
# 1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAw
# MFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1
# f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+ykn
# x9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4c
# SocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTm
# K/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/B
# ougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0w
# ggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8E
# ejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9
# bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEA
# PuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH2
# 0ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV
# +7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyP
# u6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD
# 2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6S
# kepobEQysmah5xikmmRR7zGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# MTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcg
# Q0ECEALqUCMY8xpTBaBPvax53DkwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFOS6LXZMF/CLV07S
# 52kppTPBQ0a+MA0GCSqGSIb3DQEBAQUABIIBAJJh+jcVl2HjagecU9DKex3kclMm
# hL/mdi1j19mMHrH0PwlkMWeB6in6PsXJ6NYTxsQPEmghATCxDi1JUj44ror+Zdyd
# 3//VqsQvGBHlZ5BMXYDDQ1qNz/F0GnCRHGz0egWs7whJ2n/pCE7pcTtphg8BXRRi
# NaZB+c21sbi4p1oJvtk1y4lvThLQW0ma0MZvVFDVVfKM8qJErudj0omZuRdP2QhZ
# qsfLopYYyY/3UsK01fjDPbanVMHQJrhz1erlx2GjHyMCK1LgNyjdYNE+B0UmiYew
# 7vHDgQUqzlO9jpdWrvyRfaFPByNooglDPnjILTk2CQkVMdeJuO4QSmUDBsg=
# SIG # End signature block
