function Show-WebObject
{
    <#
    .Synopsis
        Shows a web object
    .Description
        Shows a web object stored in cloud storage
    .Link
        Get-AzureTable
    .Example
        New-Object PSObject -Property @{
            Content = "# Some Markdown or HTML "            
        } |
            Set-AzureTable -TableName MyTable -RowKey Home -PartitionKey Website
        Show-WebObject -Table MyTable -Part Website -Row Home
    #>
    [CmdletBinding(DefaultParameterSetName='TableStorageObject')]
    [OutputType([string])]
    param(
    # The name of the table
    [Parameter(Mandatory=$true,ParameterSetName='TableStorageObject', ValueFromPipelineByPropertyName=$true)]
    [Alias('TableName')]
    [string]$Table, 
    # The partition in the table
    [Parameter(Mandatory=$true,ParameterSetName='TableStorageObject', ValueFromPipelineByPropertyName=$true)]
    [Alias('PartitionKey')]
    [string]$Part,
    # The row in the table
    [Parameter(Mandatory=$true,ParameterSetName='TableStorageObject', ValueFromPipelineByPropertyName=$true)]
    [Alias('RowKey')]
    [string]$Row,
    
    # The table storage account 
    [Parameter(ParameterSetName='TableStorageObject')]
    [string]$StorageAccount,
    
    # The table storage key
    [Parameter(ParameterSetName='TableStorageObject')]
    [string]$StorageKey    
    )

    begin 
    {
        $page = ""
        
        $FetchedItems = @{}        
        $FetchedTimes = @{}

        $unpackItem = {
            $item = $_
            $item.psobject.properties |                         
                Where-Object { 
                    ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                    (-not $_.Value.ToString().Contains(' ')) 
                }|                        
                ForEach-Object {
                    try {
                        $expanded = Expand-Data -CompressedData $_.Value
                        $item | Add-Member NoteProperty $_.Name $expanded -Force
                    } catch{
                        Write-Verbose $_
                    
                    }
                }
                
            $item.psobject.properties |                         
                Where-Object { 
                    ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                    (-not $_.Value.ToString().Contains('<')) 
                }|                                   
                ForEach-Object {
                    try {
                        $fromMarkdown = ConvertFrom-Markdown -Markdown $_.Value
                        $item | Add-Member NoteProperty $_.Name $fromMarkdown -Force
                    } catch{
                        Write-Verbose $_
                    
                    }
                }
            $item     
        }
    }
    
    process {
        if ($psCmdlet.ParameterSetName -eq 'TableStorageObject') {
            $item = Get-AzureTable -TableName $table -Partition $part -Row $row -StorageAccount $StorageAccount -StorageKey $storageKey #-ErrorAction SilentlyContinue
        }

        if (-not $item) { return } 
        
        $hasContent = $false
        if ($item.Content) {
            
            $content = if (-not $item.Content.Contains(" ")) {
                # Treat compressed
                Expand-Data -CompressedData $item.Content
            } else {
                $item.Content
            }
            $content = if (-not $Content.Contains("<")) {
                # Treat as markdown
                ConvertFrom-Markdown -Markdown $content 
            } else {
                # Treat as HTML
                $content
            }
            $hasContent = $true
            $page += $content            
        }
        
        if ($item.LatestItem) {
            # Embed Ajax to fetch the latest item from the given partition
        }                                
        
        if ($item.Video) {
            $hasContent = $true
            $page += "<br/>$(Write-Link $item.Video)<br/><br/>" | New-Region -Style @{'text-align'='center'} 
            
        }
        
        if ($item.ItemId) {
            $hasContent = $true
            $part,$row = $item.ItemId -split ":"
            $page += Get-AzureTable -TableName $table -Partition $part -Row $row |
                ForEach-Object $unpackItem|
                Out-HTML -ItemType { 
                    $_.pstypenames | Select-Object -Last 1                     
                } 
        }                
        
        if ($item.Detail) {
            $hasContent = $true
            $layerOrder = @()
            
            if ($item.ShowDetailAs -ne 'Page') {                        
                $detailLayers = $item.Detail -split "\|" |                 
                    foreach-Object { $_.Trim()} | 
                    Where-Object { $_ }|
                    ForEach-Object -Begin {
                        $detailPages = @{}
                    } -process {
                        $layerOrder += $_
                        $detailPages[$_] =  if ($FetchedItems["$table.$part.$_"]) {
                            if ((Get-Date).aDdMinutes(-20) -le $FetchedTimes["$table.$part.$_"]) {
                                $FetchedItems["$table.$part.$_"] = $null
                                Show-WebObject -Table $table -Part $part -Row $_ -StorageAccount $StorageAccount -StorageKey $StorageKey 
                            } else {
                                $FetchedItems["$table.$part.$_"]
                            }
                            
                        } else {
                            Show-WebObject -StorageAccount $StorageAccount -StorageKey $StorageKey -Table $table -Part $part -Row $_                        
                        }
                        
                        $FetchedItems["$table.$part.$_"] = $detailPages[$_]
                    } -End {
                        $detailPages
                    }
                    
                    
                $newRegionParameters = @{Layer=$DetailLayers;LayerOrder=$layerOrder}
                if ($item.ShowDetailAs) { 
                    $newRegionParameters["As" + $item.ShowDetailAs] = $true
                }
            } else {
                $page += $item.Detail -split "\|" |                 
                    foreach-Object { $_.Trim()} | 
                    Where-Object { $_ }|
                    Write-Link -Horizontal -Style @{'font-size'='medium'} -HorizontalSeparator ' ' -Url { $_ + ".aspx" } -Caption { $_ } -Button -Style @{'font-size'='x-large'}
                    
                $page += "
<BR/>"
            }
            if ($item.Id -and $newREgionParameters) {
                $newRegionParameters.LayerID = $item.Id
                $page += New-Region @newregionparameters
            }
            
            
            
        }
        
        if ($item.Related) {
            $hasContent = $true
            $page += 
                ((ConvertFrom-Markdown -Markdown $item.Related) -replace "\<a href", "<a class='RelatedLink' href") |
                    New-Region -Style @{'text-align'='right';'padding'='10px'} 
            $page += @'
<script>
    $('.RelatedLink').button()
</script>
'@            
            
        }
        if ($item.Next -or $item.Previous) {
            $hasContent = $true
            $previousChunk = if ($item.Previous) {
            $previousCaption = "<span class='ui-icon ui-icon-seek-prev'>
                </span>
                <br/>
                <span style='text-align:center'>
                Last
                </span>"

                Write-Link -Caption $previousCaption -Url $item.Previous -Button
            } else {
                ""
            }
            
            $nextChunk = if ($item.Next) {
            $nextCaption = "<span class='ui-icon ui-icon-seek-next'>
                </span>
                <br/>
                <span style='text-align:center'>
                Next
                </span>"
                Write-Link -Caption $nextCaption -Url $item.Next -Button
            } else {
                ""
            }
            $page+= "
<table style='width:100%'>
    <tr>
        <td style='50%;text-align:left'>
            $previousChunk
        </td>
        <td style='50%;text-align:right'>
            $nextChunk
        </td>
    <tr>
</table>"            
        }
        
        if (-not $hasContent) {
            $page += $item | 
                Out-HTML -ItemType { $_.pstypenames | Select-Object -Last 1 } 
        }
    }
    
    end {
        $page
    }
    

} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/VqrzwcHkO1jR3LB3p3BxlQO
# k86gggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFJQuoYsMz7KdONLH
# E4uaQghb8M+JMA0GCSqGSIb3DQEBAQUABIIBAJQvC27nmk6uXwzljTGMdbZHyDy2
# T45csLWZjXCdhmRm7WyFhPLBpNwDwTugTPv34vZrzZjE8V2i9UZT5R0ct2QrSHvb
# ynC4QMxYIMI+t/rnuzjH2SXAa8lYHfruV6NfWLbdOyVQsBt+0Fk1xo0OmxjtmCDr
# 7YNnJvSaTl6nskBT3zmyxhxNYE4HqqAwAdjO4oeXdIteWhPCAEMGPfUD9n0CFtim
# 45IZ6O+SMMff6plPrqtrczLxD+TGv3Z4EIDHa3qnD3xCrX5rZ2cfqXNLTmJblxjM
# oANIc11/kcEPPNYkjd0a+mQH7Tk1wu52dkazaOoK/ZveLCYh9Mmf19rxpgw=
# SIG # End signature block
