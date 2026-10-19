# Kubernetes avec Kubespray et Ansible

Déploiement d'un cluster Kubernetes avec Ansible (Kubespray v2.32.0), en deux versions :

| | Light | HA (haute disponibilité) |
|---|---|---|
| Machines | 1 | 6 (3 masters, 3 workers) |
| Réseau des pods | Flannel | Calico |
| API | directe | VIP kube-vip 192.168.4.200 |
| Usage | démo, test | production |
| Statut | testé et fonctionnel | validé sur le papier, non déployé |

La version HA n'a pas été déployée faute de ressources (6 machines). Son inventaire et sa syntaxe ont été validés avec `ansible-inventory --graph` et `ansible-playbook --syntax-check`.

## Contenu du dépôt

- `install-light.sh` : prépare tout pour la version light
- `light/` : configuration de référence de la version light (inventaire, variables, log du déploiement)
- `ha/` : inventaire et variables de la version HA

## Version light : marche à suivre

### Prérequis

- Machine ou VM Ubuntu 24.04 ou plus récent
- 2 CPU, 4 Go de RAM, 20 Go de disque libre
- Accès Internet (binaires et images téléchargés pendant le déploiement)
- Accès root (`sudo -s`)
- Nom de machine en minuscules, sans underscore ni espace
- Une IP fixe, ou au moins stable pendant le déploiement

Vérification rapide :

```bash
sudo -s
hostname
hostname -I
ping -c2 github.com
```

La première IP affichée par `hostname -I` doit être celle du réseau principal : c'est elle que le script utilise.

### Étape 1 : récupérer le dépôt

```bash
apt-get update && apt-get install -y git
git clone https://github.com/Nash2027/kubespray-light.git
cd kubespray-light
```

### Étape 2 : préparer l'environnement (3 à 4 minutes)

```bash
bash install-light.sh
```

Le script :

1. détecte l'IP et le nom de la machine
2. installe git, Python et tmux
3. clone Kubespray et se place sur la version v2.32.0
4. crée l'environnement Python et installe Ansible
5. génère l'inventaire `inventory/light/hosts.yaml` avec la bonne IP
6. active Flannel et désactive NodeLocal DNS
7. teste la connexion Ansible

Il se termine par un `pong` et un message « PRET ». **Il ne lance pas le déploiement.**

Vérifier l'inventaire généré :

```bash
cat ~/kubespray/inventory/light/hosts.yaml
```

Le nom et l'IP doivent être ceux de la machine.

### Étape 3 : lancer le déploiement (environ 5 minutes)

Le venv Python n'est pas actif après le script, il faut l'activer :

```bash
cd ~/kubespray
source ~/kubespray-venv/bin/activate
tmux new -s deploy
ansible-playbook -i inventory/light/hosts.yaml -b cluster.yml | tee ~/deploy-light.log
```

`tmux` évite que le déploiement s'arrête si la connexion SSH se coupe. Pour en sortir sans l'arrêter : `Ctrl+B` puis `D`. Pour y revenir : `tmux attach -t deploy`. Ne pas utiliser `Ctrl+C`.

À la fin, le `PLAY RECAP` doit afficher `failed=0`.

### Étape 4 : vérifier le cluster

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Le nœud doit être `Ready` et les pods `Running`. Si `kubectl` ne répond pas :

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
```

### Étape 5 : déployer une application de démonstration

```bash
kubectl create deployment demo --image=nginx --replicas=2
kubectl expose deployment demo --type=NodePort --port=80
kubectl get pods -o wide
kubectl get svc demo
```

Relever le port dans `80:3XXXX/TCP`, puis ouvrir `http://<IP de la machine>:<port>` : la page « Welcome to nginx! » s'affiche.

### Étape 6 : tester la résilience (optionnel)

```bash
kubectl delete pod -l app=demo
kubectl get pods
```

Kubernetes recrée immédiatement les pods supprimés.

### Option : tout lancer en une commande

Pour préparer et déployer sans intervention, remplacer les dernières lignes du script par la version avec l'option `--deploy`, puis :

```bash
bash install-light.sh --deploy
```

## Opérations utiles

| Action | Commande |
|---|---|
| Ajouter un nœud | ajouter l'hôte dans l'inventaire, puis `ansible-playbook -i <inventaire> -b scale.yml` |
| Mettre à jour le cluster | `ansible-playbook -i <inventaire> -b upgrade-cluster.yml` |
| Supprimer le cluster | `ansible-playbook -i <inventaire> -b reset.yml -e reset_confirmation=yes` |

## Version HA

Les fichiers sont dans `ha/` : `hosts.yaml` (3 masters, 3 workers) et `group_vars/` (Calico, kube-vip, metrics-server, Helm, ingress nginx).

Avant d'utiliser cette version, adapter :

- les IP de `hosts.yaml` (192.168.4.11 à 13 pour les masters, 21 à 23 pour les workers) à celles des machines
- la VIP `192.168.4.200` (`kube_vip_address` dans `group_vars/k8s_cluster/addons.yml` et `loadbalancer_apiserver` dans `group_vars/all/all.yml`) : une adresse libre du même réseau
- `ansible_user` dans `hosts.yaml`, ainsi que l'accès SSH par clé depuis le poste Ansible vers les 6 machines
- `kube_vip_interface` si l'interface réseau n'est pas `eth0`

Validation sans déployer (depuis `~/kubespray`, venv actif) :

```bash
ansible-inventory -i ~/kubespray-light/ha/hosts.yaml --graph
ansible-playbook -i ~/kubespray-light/ha/hosts.yaml cluster.yml --syntax-check
```

Déploiement :

```bash
ansible-playbook -i ~/kubespray-light/ha/hosts.yaml -b cluster.yml
```

## Problèmes courants

| Symptôme | Cause | Solution |
|---|---|---|
| `ansible-playbook: command not found` | venv non actif | `source ~/kubespray-venv/bin/activate` |
| Erreur « ip var does not match local ips » | l'IP de l'inventaire n'est pas celle de la machine | relancer `install-light.sh` |
| Téléchargements qui échouent | pas d'accès Internet, ou domaine bloqué | tester `ping github.com` et `curl -sI https://registry.k8s.io` |
| Déploiement interrompu | session coupée | relancer la même commande, Ansible reprend où il s'était arrêté |
| Pods en `Pending` | taint sur le nœud | `kubectl taint nodes <nom> node-role.kubernetes.io/control-plane:NoSchedule-` |
| Erreurs `W:` ou `E:` sur HashiCorp lors de `apt-get update` | dépôt tiers sans clé | sans rapport, ignorer tant que les paquets s'installent |

## Attention

`install-light.sh` supprime et recrée `~/kubespray/inventory/light`. Ne pas le lancer sur une machine où cette configuration est déjà en place et doit être conservée.
