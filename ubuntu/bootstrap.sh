#!/bin/bash

## !IMPORTANT ##
#
## This script is tested only in the generic/ubuntu2004 Vagrant box
## If you use a different version of Ubuntu or a different Ubuntu Vagrant box test this again
#

echo "[TASK 0] Setting TimeZone"
timedatectl set-timezone America/New_York

echo "[TASK 1] Setting DNS"
cat >/etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=8.8.8.8
FallbackDNS=1.1.1.1
EOF
systemctl daemon-reload
systemctl restart systemd-resolved.service
mv /etc/resolv.conf /etc/resolv.conf.bak
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

echo "[TASK 2] Setting Ubuntu System Mirrors"
cat >/etc/apt/sources.list<<EOF
  deb mirror://mirrors.ubuntu.com/mirrors.txt focal main restricted universe multiverse
  deb http://us.archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse

EOF
apt update -qq 

echo "[TASK 3] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[TASK 4] Stop and Disable firewall"
systemctl disable --now ufw 

echo "[TASK 5] Enable and Load Kernel modules"
cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "[TASK 6] Add Kernel settings"
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system 

echo "[TASK 7] Install containerd runtime"
apt install -qq -y containerd apt-transport-https 
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml

sed -i 's#SystemdCgroup = false#SystemdCgroup = true#g' /etc/containerd/config.toml

systemctl daemon-reload
systemctl enable containerd --now 
systemctl restart containerd

echo "[TASK 8] Add apt repo for kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - 
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update -qq 

echo "[TASK 9] Install Kubernetes components (kubeadm, kubelet and kubectl)"
apt install -qq -y kubeadm=1.22.0-00 kubelet=1.22.0-00 kubectl=1.22.0-00 
crictl config runtime-endpoint /run/containerd/containerd.sock
crictl config image-endpoint /run/containerd/containerd.sock

echo "[TASK 10] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 11] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root 
echo "export TERM=xterm" >> /etc/bash.bashrc

echo "[TASK 12] Update /etc/hosts file"
cat >>/etc/hosts<<EOF
192.168.10.100   kmaster.k8s.com     kmaster
192.168.10.101   kworker1.k8s.com    kworker1
192.168.10.102   kworker2.k8s.com    kworker2
EOF