#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Lancer ce script en root : sudo -s puis bash install-light.sh"
  exit 1
fi

IP=$(hostname -I | awk '{print $1}')
NAME=$(hostname)
echo "Machine : $NAME, IP : $IP"

apt-get update
apt-get install -y git python3-venv python3-pip tmux

cd ~
[ -d kubespray ] || git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout v2.32.0
python3 -m venv ~/kubespray-venv
source ~/kubespray-venv/bin/activate
pip install -r requirements.txt

rm -rf inventory/light
cp -rfp inventory/sample inventory/light
cat > inventory/light/hosts.yaml <<EOF
all:
  hosts:
    $NAME:
      ansible_connection: local
      ansible_host: $IP
      ip: $IP
      access_ip: $IP
  children:
    kube_control_plane:
      hosts:
        $NAME:
    kube_node:
      hosts:
        $NAME:
    etcd:
      hosts:
        $NAME:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
EOF

sed -i 's/^kube_network_plugin: .*/kube_network_plugin: flannel/' inventory/light/group_vars/k8s_cluster/k8s-cluster.yml
sed -i 's/^enable_nodelocaldns: .*/enable_nodelocaldns: false/' inventory/light/group_vars/k8s_cluster/k8s-cluster.yml

ansible all -i inventory/light/hosts.yaml -m ping

echo ""
echo "PRET. Pour deployer :"
echo "  cd ~/kubespray && source ~/kubespray-venv/bin/activate"
echo "  ansible-playbook -i inventory/light/hosts.yaml -b cluster.yml | tee ~/deploy-light.log"
