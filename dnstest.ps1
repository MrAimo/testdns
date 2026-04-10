param (
    [string]$Domain = "example.com"
)

# Get DNS records
dnsRecords = Resolve-DnsName -Name $Domain

# Output DNS records
dnsRecords | ForEach-Object {
    Write-Output "$($_.QueryType) for $($_.Name) - IP: $($_.IPAddress)"
}

# Example of pinging the domain
if (Test-Connection -ComputerName $Domain -Count 1 -Quiet) {
    Write-Output "$Domain is reachable."
} else {
    Write-Output "$Domain is not reachable."
}