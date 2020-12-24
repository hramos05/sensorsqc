# Sensors QC

## High-Level Overview
1. Sensors QC App
   1. Python-based/Flask
2. Deploy Azure Infrastructure
   1. Resource Group
   2. ACR
   3. AKS
   4. Arc (FluxCD)
3. Container Image
   1. Build Image using Dockerfile
   2. Push Image to the ACR
4. Deploy Container Image
   1. Create Ingress & Sensors QC Arc configs

## Requirements
1. Azure Subscription
    - Contributor/Co-Admin
    - I suggest leveraging a sandbox subscription
2. Tools (use chocolatey/brew/pip or use Azure Shell - shell.azure.com)
	- Bash
	- Azure cli (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
	- Git cli (https://git-scm.com/)
	- GNU make (https://ftp.gnu.org/gnu/make/)
	- Kubectl (https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Full Deployment Instructions
The steps will do the following with the help of GNU Make:
	- Deploy the Azure Infrastructure
	- Build the Docker Image with the Sensors QC App
	- Deploy the app leveraging Arc/Flux

The steps below will use Azure Shell (shell.azure.com) as the tools required are already pre-installed. This may take 10-20 mins to deploy.

1. Login to shell.azure.com
   - If you do not wish to use azure shell, please install and configure the tools required mentioned under the requirements section
2. Set your default subscription (if you have multiple subscriptions)
	- <code>az account set --subscription <sub id or name></code>
3. Clone the git repository & change to its directory
	- <code>git clone https://github.com/hramos05/sensorsqc.git</code>
	- <code>cd ./sensorsqc</code>
4. Run GNU make and follow the prompts
    - <code>make all</code>
	- Terraform will prompt for a confirmation, review the plan and enter "yes"
5. App URL/IP will be displayed at the end

[![fastcc6746f0771e7e06.gif](https://s8.gifyu.com/images/fastcc6746f0771e7e06.gif)](https://gifyu.com/image/CluT)

Notes:
This uses GNU make, which allows targets to be ran independently of the others. 

## Use the App (Sensors QC)
1. Browser
   1. http://[service IP]/
2. Curl
   1. <code>curl -F file=@<local full log path> http://[service ip]/qc</code>
   2. <code>curl -F file=@C:\Users\Frost\Desktop\sample.log http://[service ip]/qc</code>

Additional Parameters
*Both parameters can be passed at the same time*
- **displaytime** : Add the processing time to the result
  - <code>curl -F displaytime=true -F file=@<local full log path> http://[service ip]/qc</code>
- **displayerror**: Show sensors that encountered errors
  - <code>curl -F displayerror=true -F file=@<local full log path> http://[service ip]/qc</code>

[![App.gif](https://s8.gifyu.com/images/App.gif)](https://gifyu.com/image/ClBK)

## Clean Up
1. Login to Azure Shell or where Make/Terraform was ran from
   1. This is important as the terraform state files are locally stored in the same directory
2. Run GNU make with infra-destroy
   1. <code>make infra-destroy</code>
3. A prompt will ask to confirm, enter "yes"

## Build the Container
This assumes you have docker desktop installed and configured

1. Clone the git repository & change to directory
    - <code>git clone https://github.com/hramos05/sensorsqc.git</code>
    - <code>cd ./sensorsqc/app/</code>
2. Run the build
    - <code>docker build -t [name]:[tag]</code>

## Assumptions
- Bash as default shell
- Azure is preferred for infra
- AKS will have external/internet access to github, container registries, helm repos, etc

## Limitations
- If using the full deployment, Azure Arc is leveraged which is currently in public preview, so only West Central US and East US AKS regions are supported. I'm leveraging Azure Arc as "managed" FluxCD
- Terraform will deploy an ACR with hardcoded name. This is to allow for a fully automated deployment (demo)

## Trade-offs & Improvements
- DevOps/Infrastructure side was heavily focused , and due to time constraints, app/python code was written to be "functional". It will need improvements to be more extensible & performant
- For simplicity and speed of development, secrets are not stored in Key Vault. This needs to be addressed before going "production"
- Needs to be added/improved:
  - CI, automated testing, branching, container tagging/labels
- App is exposed using HTTP/80, need to put TLS certs for HTTPS/443
- There's no monitoring of the infrastructure or app
- App can only accept file uploads, will be better if we can pass data directly (URL of a file or post payload directly)
