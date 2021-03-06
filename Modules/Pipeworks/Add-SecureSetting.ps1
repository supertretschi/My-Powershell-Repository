function Add-SecureSetting
{
    <#
    .Synopsis
        Adds an encrypted setting to the registry
    .Description
        Stores secured user settings in the registry
    .Example
        Add-SecureSetting AStringSetting 'A String'
    .Example
        Add-SecureSetting AHashtableSetting @{a='b';c='d'}
    .Example
        Add-SecureSetting ACredentialSetting (Get-Credential)
    .Example
        Add-SecureSetting ASecureStringSetting (Read-Host "Is It Secret?" -AsSecureString)
    .Link
        Get-SecureSetting
    .Link
        ConvertTo-SecureString
    .Link
        ConvertFrom-SecureString
    #>
    [CmdletBinding(DefaultParameterSetName='System.Security.SecureString')]
    [OutputType('SecureSetting')]
    param(   
    # The name of the secure setting
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true)]
    [String]
    $Name,
    
    # A string value to store.  This will be converted into a secure string and stored in the registry. 
    [Parameter(Mandatory=$true,Position=1,ParameterSetName='String',ValueFromPipelineByPropertyName=$true)]
    [string]
    $String,
    
    # An existing secure string to the registry.
    [Parameter(Mandatory=$true,Position=1,ParameterSetName='System.Security.SecureString',ValueFromPipelineByPropertyName=$true)]
    [Security.SecureString]
    $SecureString,
    
    # A table of values.  The table will be converted to a string, and this string will be stored in the registry.
    [Parameter(Mandatory=$true,Position=1,ParameterSetName='Hashtable',ValueFromPipelineByPropertyName=$true)]
    [Hashtable]
    $Hashtable,
    
    # A credential.  The credential will stored in the registry as a pair of secured values.
    [Parameter(Mandatory=$true,Position=1,ParameterSetName='System.Management.Automation.PSCredential',ValueFromPipelineByPropertyName=$true)]
    [Management.Automation.PSCredential]
    $Credential
    )
    
    process {       
        #region Create Registry Location If It Doesn't Exist 
        $registryPath = "HKCU:\Software\Start-Automating\$($myInvocation.MyCommand.ScriptBlock.Module.Name)"
        $fullRegistryPath = "$registryPath\$($psCmdlet.ParameterSetName)"
        if (-not (Test-Path $fullRegistryPath)) {
            $null = New-Item $fullRegistryPath  -Force
        }   
        #endregion Create Registry Location If It Doesn't Exist
        
        
        
        if ($psCmdlet.ParameterSetName -eq 'String') {
            #region Encrypt and Store Strings
            $newSecureString = $String | 
                ConvertTo-SecureString -AsPlainText -Force | 
                ConvertFrom-SecureString
                
            Set-ItemProperty $fullRegistryPath -Name $Name -Value $newSecureString
            #endregion Encrypt and Store Strings
        } elseif ($psCmdlet.ParameterSetName -eq 'Hashtable') {
            #region Embed And Store Hashtables
            $newSecureString = Write-PowerShellHashtable -InputObject $hashtable | 
                ConvertTo-SecureString -AsPlainText -Force | 
                ConvertFrom-SecureString
                                
            Set-ItemProperty $fullRegistryPath -Name $Name -Value $newSecureString
            #endregion Embed And Store Hashtables
        } elseif ($psCmdlet.ParameterSetName -eq 'System.Security.SecureString') {
            #region Store Secure Strings
            $newSecureString = $secureString | 
                ConvertFrom-SecureString
                
            Set-ItemProperty $fullRegistryPath -Name $Name -Value $newSecureString
            #endregion Store Secure Strings
        } elseif ($psCmdlet.ParameterSetName -eq 'System.Management.Automation.PSCredential') {
            #region Store credential pairs
            $secureUserName = $Credential.UserName | 
                ConvertTo-SecureString -AsPlainText -Force | 
                ConvertFrom-SecureString
            $securePassword = $Credential.Password | 
                ConvertFrom-SecureString
                            
            Set-ItemProperty $fullRegistryPath -Name "${Name}_Username" -Value $secureUserName
            Set-ItemProperty $fullRegistryPath -Name "${Name}_Password" -Value $securePassword
            #endregion Store credential pairs
        }                    
    }

} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDhL724SowZZKRxMT4tNQc+0j
# t+CgggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFFiQh7MfOCBpVaxr
# 8ZbyxIwaiPPQMA0GCSqGSIb3DQEBAQUABIIBAJGLcSy4HODBIWoLDjyqx3yU+moA
# YNmdLMtKL9zXNIusAE9c2LcCB0niehhYmtFUJryuhFLJ8Bg7aqjz8NWGUmW6XvPD
# A6dJNNpKpt/XAK628xT/xCt8/f5yPvHrbCntEoKzxAI/RBqxB6LVyTX2Lwyp5DgT
# 9m6kz4TEqAkYfFJB/Il0X5xL+Vd3S5axgjetmOUAF+vJuMc+gpsvQC2i9dzpRiKN
# QAFXKTMWdUHpVnl7gORKlvxOvNxFAfYp0CwS71ib0JCOq3c2LyZkL+rzyeT7d4xJ
# IbEKhcZci37mSVrjRzYQhQhmcsplcGT2R7XXoKszy6wBRhBWdjANRUrU/ks=
# SIG # End signature block
