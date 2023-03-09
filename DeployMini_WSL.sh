#!/bin/bash
# Deploy Minikube and apply Dynatrace Operator & YAML

# Environment Variables needed:
# DT_OP_VER = Operator Version - IE: "0.10.3"

# This script also expects a dynakube.yaml CR to be present in the working directory!
echo "*** This script also expects a dynakube.yaml CR to be present in the working directory! ***"

# If the Operator Version Environment Variable does not exist....
if [ -z "$DT_OP_VER" ]
then
      # Operator Version Environment Variable does not exist
      echo "*** Environment Variable \$DT_OP_VER does not have an Operator Version specified IE: \"0.10.3\", exiting. ***"
      exit
else
      # Opeator Version Environment Variable exists
      echo "*** $DT_OP_VER Operator version will be installed. ***"
fi

# Ask if you want to use existing Minikube or start over
read -p "*** Do you want start with a new Minikube instance? (y/n)? ***" choice
case "$choice" in 
  y|Y ) echo "*** Deleting Minikube... ***"; 
        minikube delete; 
        export DT_DEL="Y" ;; # Set variable for Docker Cleanup to YES
  n|N ) echo "*** Continuing... ***"; 
        export DT_DEL="N" ;; # Set Variable for Docker Cleanup to NO
  * ) echo "*** Invalid option selected, exiting... ***"; exit;;
esac

# Check if Docker Cleanup variable is set
if [ "$DT_DEL" = "Y" ] # If Docker Cleanup variable is set to Y
  then
    # Cleanup Docker
    echo "*** Cleaning up Docker... ***"
    docker rmi $(docker images -f reference=gcr.io/k8s-minikube/kicbase -q) # Remove docker images
fi
echo "*** Using Docker... ***"; minikube start --driver=docker

# Create DT Namespace
echo "*** Creating DT Namespace. ***"
kubectl create namespace dynatrace

# Apply Specified Operator Version from Github, then sleep for 20 seconds
kubectl apply -f https://github.com/Dynatrace/dynatrace-operator/releases/download/v$DT_OP_VER/kubernetes.yaml
sleep 20

# Wait until Operator pods are up and running
echo "*** Waiting for Operator & webhook to be up and running. ***"
kubectl -n dynatrace wait pod --for=condition=ready --selector=app.kubernetes.io/name=dynatrace-operator,app.kubernetes.io/component=operator --timeout=300s
kubectl -n dynatrace wait pod --for=condition=ready --selector=app.kubernetes.io/name=dynatrace-operator,app.kubernetes.io/component=webhook --timeout=300s

# Apply Dynakube.yaml
echo " *** Applying Dynakube.yaml. ***"
kubectl apply -f dynakube.yaml

# Set default namespace to Dynatrace
echo " *** Setting default namespace to dynatrace ***"
kubectl config set-context --current --namespace=dynatrace

# Done
echo "*** OneAgent Deployment complete! ***"

# Ask if you want to deploy Hello Minikube aka Hello-Node
read -p "*** Do you want to deploy hello-node as well? (y/n)? ***" choice
case "$choice" in 
  y|Y ) echo "*** Creating hello-node Namespace. ***"; 
        kubectl create namespace hello-node;
        
        # Deploy Hello Minikube to hello-node namespace
        echo "*** Deploying hello-node. ***";
        kubectl create deployment -n hello-node hello-node --image=registry.k8s.io/e2e-test-images/agnhost:2.39 -- /agnhost netexec --http-port=8080;
        
        # Expose Deployment with LoadBalancer
        kubectl expose deployment -n hello-node hello-node --type=LoadBalancer --port=8080 -n hello-node;
        
        # Launch Hello Node
        echo "*** Launching Hello Node... ***";
        cd /mnt/c;
        cmd.exe /c start wsl.exe -d $WSL_DISTRO_NAME --user $LOGNAME -- minikube service -n hello-node hello-node &;;
  n|N ) echo "*** Continuing... ***";;
  * ) echo "*** Invalid input, Continuing... ***"; exit;;
esac

# Ask if you want to launch Dashboard
read -p "*** Do you want to launch the MiniKube Dashboard? (y/n)? ***" choice
case "$choice" in 
  y|Y ) echo "*** Launching MiniKube Dashboard... ***"; 
        cd /mnt/c;
        cmd.exe /c start wsl.exe -d $WSL_DISTRO_NAME --user $LOGNAME -- minikube dashboard &;;
  n|N ) echo "*** Exiting... ***"; exit;;
  * ) echo "*** Exiting... ***"; exit;;
esac