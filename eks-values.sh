#!/bin/sh
if [ -z "$1" ]; then
  echo "Usage: $0 <cluster-name>"
  exit 1
fi

export cluster_name=$1
export cluster_endpoint=$(aws eks describe-cluster --name $cluster_name --query "cluster.endpoint")
export cluster_certificate=$(aws eks describe-cluster --name $cluster_name --query "cluster.certificateAuthority.data")

cat << EOF
eks.cluster_name: $cluster_name
eks.endpoint: $cluster_endpoint
eks.certificate: $cluster_certificate
EOF
