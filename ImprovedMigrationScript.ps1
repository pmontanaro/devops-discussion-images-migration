
# Generate Auth Headers for both tenancies
function generateAuthHeader ($tokens) {   
    return @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($tokens)")) }
}

# Generates Base ADO URL
function generateBaseUrl ($organisation, $project) {
    return "https://dev.azure.com/$organisation/$project"
}

# Source Credentials
$sourceToken = "<SourcePAT>"
$sourceOrg = "<SourceOrg>"
$sourceProject = "<SourceProject>"
$sourceBase64AuthInfo = generateAuthHeader $sourceToken
$sourceBaseUrl = generateBaseUrl $sourceOrg $sourceProject

# Target Credentials
$targetToken = "<TargetPAT>"
$targetOrg = "<TargetOrg>"
$targetProject = "<TargetProject>"
$targetBase64AuthInfo = generateAuthHeader $targetToken
$targetBaseUrl = generateBaseUrl $targetOrg $targetProject

# Reference CSV File
$csvName = ".\filename.csv"

# Regular Expression to find image HTML tag
[regex]$regex = "(?:<img[^>]+src=`"([^`">]+)`")"

# Export of open Features with image attachments 
$csv = Import-Csv -Path $csvName

# Feed in WorkItem IDs
# Iterate through comments and detect image
# If image detected, download image and save with Workitem and image number locally
foreach ($ticket in $csv) {
    $oldId = $ticket.sourceId
    $newId = $ticket.targetId
    write-host "Checking Workitem $oldId..." -ForegroundColor Yellow
    $sourceComments = Invoke-RestMethod -Method GET -Headers $sourceBase64AuthInfo "$sourceBaseUrl/_apis/wit/workItems/$oldId/comments?api-version=6.0-preview.3"

    $count = 0
    foreach ($c in $sourceComments.comments) {
        $comment = $c.text
        Write-Host "Checking Comment $count..."
        # $comment -match $regex; 
        if ($comment -match $regex) {
            Write-Host "Image found!" -ForegroundColor Green

            # Create empty hash for found image URLs
            $imageUrls = @{}
            
            # Go through image(s)
            $foundImageTags = Select-String $regex -input  $comment -AllMatches | % { $_.matches }
            
            # Image counter incase there are multiple images per comment
            $imgCount = 1
            foreach ($image in $foundImageTags) {
                $oldImageUrl = $image.Value | % { $_.split('"')[1] }
                Write-Host "Saving Image from comment $count..."
                $filename = "$oldId-image-$count-$imgCount.jpg"
                Invoke-RestMethod -Method GET -Headers $sourceBase64AuthInfo $oldImageUrl -OutFile "$filename"

                $filePath = Get-ChildItem -Path $filename | % { $_.FullName }

                $createAttachmentUrlTemplate = "$targetBaseUrl/_apis/wit/attachments?fileName={fileName}&api-version=5.0"
    
                $bytes = [System.IO.File]::ReadAllBytes("$filePath")
    
                $createAttachmentUrl = $createAttachmentUrlTemplate -replace "{filename}", $filename
    
                # Post Attachment to Target Tenant
                $resAtt = Invoke-RestMethod -Uri $createAttachmentUrl -Method Post -ContentType "application/json" -Headers $targetBase64AuthInfo  -Body $bytes 
                $imageUrls.Add($oldImageUrl, $resAtt.url)
                $imgCount++
            }

            # Add Comment to Target Tenant
            foreach ($key in $imageUrls.GetEnumerator()) {
                $oldImageUrl = $key.Name
                $newImageUrl = $key.Value

                $newComment = $comment.replace("src=`"$oldImageUrl`"", "src=`"$newImageUrl`"")
                $commentAuthor = $c.createdBy.displayName
                $comment = $newComment
            }

            
            # Create Body
            $body = @{
                "text" = "Comment Images Migration: </br> Original Author: $commentAuthor </br> </br> $newComment"
            }
            
            $b = $body | ConvertTo-Json

            Write-Host "Writing new test comment..."
            Invoke-RestMethod -Method POST -Headers $targetBase64AuthInfo -Body ($b) "$targetBaseUrl/_apis/wit/workItems/$newId/comments?api-version=6.0-preview.3" -ContentType "application/json"

        }
        $count++
    }
}
