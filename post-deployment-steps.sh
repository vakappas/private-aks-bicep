PREFIX="AKS-LAB"
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
# SUBSCRIPTION_ID="c5807190-2d73-4214-a65b-2416635845b8"

AKS_GROUP="$PREFIX-aks-rg" # here enter the resources group name of your aks cluster
AKS_NAME="AKS-CL01" # here enter the name of your kubernetes resource
LOCATION="northeurope" # here enter the datacenter location
AKS_VNET_NAME="aks-vnet" # here enter the name of your vnet
AKS_VNET_PREFIX="192.168.4.0/22"
AKS_MI_NAME="aks-cl01-mi"
# AKS_ING_SUBNET_NAME="ingress-subnet" # here enter the name of your ingress subnet
# AKS_AGENT_SUBNET_NAME="agent-subnet" # here enter the name of your aks subnet
ACR_GROUP="$PREFIX-aks-rg"
ACR_NAME="akslabqa5owa6znxvli"
DNS_VM="$PREFIX-vm"
DEV_GROUP="$PREFIX-dev-rg"

$AzFW_NAME="hub-fw"
$AzFW_GROUP="aks-lab-hub-rg"
$AzFW_PIP_NAME="hub-fw-pip"
$HUB_GROUP="aks-lab-hub-rg"
$HUB_VNET_NAME="hub-vnet"


# Give ACR pull permissions to AKS's managed identity
KUBELET_ID=$(az aks show -g $AKS_GROUP -n $AKS_NAME --query identityProfile.kubeletidentity.clientId -o tsv)
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $ACR_GROUP | jq -r '.id')
az role assignment create --assignee $KUBELET_ID --scope $ACR_ID --role acrpull

# Give AKS Managed Identity contributor permissions to RG
AKS_MI_ID=$(az identity show -n $AKS_MI_NAME -g $AKS_GROUP | jq -r '.principalId')
az role assignment create --role "Contributor" --assignee $AKS_MI_ID -g $AKS_GROUP

# az identity list --query "[].{Name:name, Id:id, Location:location}" -o table

# Enable Azure Policy add-on
az aks enable-addons --addons azure-policy --name $AKS_NAME --resource-group $AKS_GROUP


# Start the DNS Server VM
az vm start --name $DNS_VM --resource-group $DEV_GROUP

# stop the AKS Cluster
az aks stop --name $AKS_NAME --resource-group $AKS_GROUP

# Start the AKS Cluster
az aks start --name $AKS_NAME --resource-group $AKS_GROUP

# Stop an existing firewall
$azfw = Get-AzFirewall -Name $AzFW_NAME -ResourceGroupName $AzFW_GROUP
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw

# Start a firewall

$azfw = Get-AzFirewall -Name $AzFW_NAME -ResourceGroupName $AzFW_GROUP
$vnet = Get-AzVirtualNetwork -ResourceGroupName $HUB_GROUP -Name $HUB_VNET_NAME
$publicip1 = Get-AzPublicIpAddress -Name $AzFW_PIP_NAME -ResourceGroupName $HUB_GROUP

$azfw.Allocate($vnet,@($publicip1))

Set-AzFirewall -AzureFirewall $azfw


