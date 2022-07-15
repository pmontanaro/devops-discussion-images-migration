# DevOps Image Migration
This script is a workaround for DevOps Services migrations that require images in the discussion section of WorkItems to be migrated. 

The current DevOps migration tool appears to have difficulty in getting this done.

Through this method it simply appends the comments on the migrated ticket by extracting the source comment HTML, downloading the image, uploading to target DevOps and creating a new comment on the same work item with the same image.


## Pre-requisites
1. If you followed the DevOps Migration tool (https://nkdagility.github.io/azure-devops-migration-tools/) all of your tickets should contain a `ReflectedWorkItemId` field. Create a CSV that maps the source DevOps tenant workitemId to the new in the following format:

##### Example
| sourceId | targetId |
|----------|----------|
| 1234     | 5678     |

2. PAT Tokens from both organisations with relevant permissions to add comments and attachments. 

3. Substitute the relevant values in the scriptfile and run.


#### TODO
1. Delete images from local storage once uploaded
2. Have script read tokens from env variables instead of local variables