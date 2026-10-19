# Kubernetes light avec Kubespray (1 noeud)

Cluster Kubernetes mono-noeud deploye par Ansible (Kubespray v2.32.0).

## Prerequis
- Ubuntu 24.04 ou plus recent, 2 CPU, 4 Go de RAM, 20 Go de disque
- Acces Internet
- Un acces root (sudo -s)
- Nom de machine en minuscules, sans underscore

## Utilisation
Sur la machine, en root :

    curl -O https://raw.githubusercontent.com/Nash2027/kubespray-light/main/install-light.sh
    bash install-light.sh

Puis lancer le deploiement (environ 5 minutes) :

    cd ~/kubespray
    source ~/kubespray-venv/bin/activate
    ansible-playbook -i inventory/light/hosts.yaml -b cluster.yml | tee ~/deploy-light.log

## Verification
    kubectl get nodes -o wide
    kubectl get pods -A

## Application de demo
    kubectl create deployment demo --image=nginx --replicas=2
    kubectl expose deployment demo --type=NodePort --port=80
    kubectl get svc demo

## Ce que fait le script
- Detecte l'IP et le nom de la machine
- Installe git, Python, tmux, puis Kubespray v2.32.0 et Ansible
- Genere l'inventaire inventory/light/hosts.yaml
- Active Flannel et desactive NodeLocal DNS
- Teste la connexion Ansible (ping)

## Version HA
Non testee faute de ressources : voir le depot ou dossier kubespray-ha.
