# Private AKS with bicep

The sources in this repo will help you deploy a fully private AKS cluster by using bicep. 

More details and information you will find at the following blog post

[Create a fully private AKS infrastructure with Bicep](https://vaggeliskappas.com/2021/04/14/create-a-fully-private-aks-infrastructure-with-bicep-aks-biceplang/)

# Running the script

To start the deployment, follow the steps listed below:

- Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
- Ensure that you are operating within the correct subscription via:

`az account show`

- Clone the following GitHub repository 

`git clone https://github.com/vakappas/private-aks-bicep.git`

- Go to the new folder "private-aks-bicep"

`cd private-aks-bicep`

- And run the following command to start the deployment 

`az deployment sub create -f ./private-aks.bicep -l northeurope`
