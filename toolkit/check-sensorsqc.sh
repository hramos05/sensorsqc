#!/bin/bash
NAMESPACE=ingress
SVCNAME=ingress-ingress-nginx-controller
WAIT_FOR_SECONDS=15

# Wait for the namespace to be available
CHECK_NAMESPACE=$(kubectl get namespace $NAMESPACE --no-headers --output=go-template={{.metadata.name}} 2>/dev/null)
CHECK_NAMESPACE_MAX_ATTEMPTS=30
CHECK_NAMESPACE_COUNT=0

while [ -z $CHECK_NAMESPACE ]; do
    echo "Waiting for namespace $NAMESPACE to be available"
    CHECK_NAMESPACE=$(kubectl get namespace $NAMESPACE --no-headers --output=go-template={{.metadata.name}} 2>/dev/null)

    if [[ $CHECK_NAMESPACE_COUNT == $CHECK_NAMESPACE_MAX_ATTEMPTS ]]; then
        echo "ERROR: Cannot find the namespace!"
        break && exit 1
    fi

    ((CHECK_NAMESPACE_COUNT++))
    sleep $WAIT_FOR_SECONDS
done

# Wait for the service ip to be available
CHECK_SVC=$(kubectl get svc $SVCNAME -n $NAMESPACE --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" 2>/dev/null)
CHECK_SVC_MAX_ATTEMPTS=30
CHECK_SVC_COUNT=0

while [ -z $CHECK_SVC ]; do
    echo "Waiting for external IP to be available"
    CHECK_SVC=$(kubectl get svc $SVCNAME -n $NAMESPACE --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" 2>/dev/null)

    if [[ $CHECK_SVC_COUNT == $CHECK_SVC_MAX_ATTEMPTS ]]; then
        echo "ERROR: No external IP detected!"
        break && exit 1
    fi

    ((CHECK_SVC_COUNT++))
    sleep $WAIT_FOR_SECONDS
done

# Wait for the app
CHECK_STATUS_CODE=0
CHECK_STATUS_MAX_ATTEMPTS=30
CHECK_STATUS_COUNT=0

while [[ $CHECK_STATUS_CODE != '200' ]]; do
    echo "Waiting for the application to be accessible"
    CHECK_STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$CHECK_SVC)

    if [[ $CHECK_STATUS_COUNT == $CHECK_STATUS_MAX_ATTEMPTS ]]; then
        echo "ERROR: Timeout! Application Not Available!"
        break && exit 1
    fi

    ((CHECK_STATUS_COUNT++))
    sleep $WAIT_FOR_SECONDS
done

echo 'Sensors QC App URL:' && echo "http://$CHECK_SVC/"