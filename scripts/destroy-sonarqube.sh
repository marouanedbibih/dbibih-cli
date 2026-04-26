#!/bin/bash

NAMESPACE="sonarqube"

echo "🚨 WARNING: This will delete ALL resources in the '$NAMESPACE' namespace."
read -p "Are you sure? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "❌ Aborted."
    exit 1
fi

echo "🔥 Deleting all Kubernetes resources in namespace: $NAMESPACE"

# Delete all workloads
kubectl delete deployment --all -n $NAMESPACE --ignore-not-found
kubectl delete statefulset --all -n $NAMESPACE --ignore-not-found
kubectl delete daemonset --all -n $NAMESPACE --ignore-not-found
kubectl delete pod --all -n $NAMESPACE --ignore-not-found
kubectl delete job --all -n $NAMESPACE --ignore-not-found
kubectl delete cronjob --all -n $NAMESPACE --ignore-not-found

# Delete volumes
kubectl delete pvc --all -n $NAMESPACE --ignore-not-found

# Delete services
kubectl delete service --all -n $NAMESPACE --ignore-not-found

# Delete configs
kubectl delete configmap --all -n $NAMESPACE --ignore-not-found
kubectl delete secret --all -n $NAMESPACE --ignore-not-found

# Delete ingress
kubectl delete ingress --all -n $NAMESPACE --ignore-not-found

# Delete RBAC
kubectl delete role --all -n $NAMESPACE --ignore-not-found
kubectl delete rolebinding --all -n $NAMESPACE --ignore-not-found

# Delete Horizontal Pod Autoscalers
kubectl delete hpa --all -n $NAMESPACE --ignore-not-found

echo "🧹 Cleaning Orphaned PVs (Longhorn)"
kubectl get pv | grep $NAMESPACE | awk '{print $1}' | xargs -r kubectl delete pv

echo "🧹 Cleaning finalizers (if stuck PVCs existed)"
for pvc in $(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
    kubectl patch pvc $pvc -n $NAMESPACE -p '{"metadata":{"finalizers":null}}' --type=merge
done

echo "🟦 Cleaning Longhorn volumes attached to namespace: $NAMESPACE"
for vol in $(kubectl get volumes.longhorn.io -A --no-headers 2>/dev/null | grep $NAMESPACE | awk '{print $1 " -n " $2}'); do
    echo "Deleting Longhorn volume: $vol"
    kubectl delete volumes.longhorn.io $vol --ignore-not-found
done

echo "✔️ All resources removed from namespace '$NAMESPACE'"

read -p "Do you also want to delete the namespace itself? (yes/no): " delete_ns

if [[ "$delete_ns" == "yes" ]]; then
    kubectl delete namespace $NAMESPACE
    echo "🗑️ Namespace '$NAMESPACE' deleted."
else
    echo "⏹️ Namespace kept."
fi

echo "🎉 Cleanup complete."
