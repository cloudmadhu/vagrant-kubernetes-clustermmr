#!/bin/bash

echo "[TASK 1] Pull required containers"

kubeadm config images list | grep -v 'coredns' > images.sh
cat >> images.sh<<EOF
ctr images pull k8s.gcr.io/kube-apiserver:v1.22.2
ctr images pull k8s.gcr.io/kube-controller-manager:v1.22.2
ctr images pull k8s.gcr.io/kube-scheduler:v1.22.2
ctr images pull k8s.gcr.io/kube-proxy:v1.22.2
ctr images pull k8s.gcr.io/pause:3.5
ctr images pull k8s.gcr.io/etcd:3.5.0-0
ctr images pull k8s.gcr.io/coredns/coredns:v1.8.4
ctr -n k8s.io images pull docker.io/v5cn/coredns:v1.8.4
ctr -n k8s.io images tag docker.io/v5cn/coredns:v1.8.4
EOF
chmod +x images.sh && ./images.sh 

echo "[TASK 2] Initialize Kubernetes Cluster"
kubeadm init \
  --apiserver-advertise-address=192.168.10.100 \
  --control-plane-endpoint=kmaster.k8s.com \
  --kubernetes-version v1.22.0 \
  --image-repository registry.aliyuncs.com/k8sxio \
  --pod-network-cidr=192.168.0.0/16 > /root/kubeinit.log 

echo "[TASK 3] Deploy Calico network"
kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml 

echo "[TASK 4] Generate and save cluster join command to /joincluster.sh"
kubeadm token create --print-join-command > /root/joincluster.sh 
