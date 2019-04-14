---
title: "Kubernetes Authentication"
date: 2019-01-13T00:00:00+09:00
draft: false
type: post
---

When we use Kubernetes API, the request is checked by following order after TLS is established[1].

1. Authentication: Checked whether user is granted to access API
1. Authorization: Checked whether user is granted to do requested action to specified object
1. Admission Control: Modify or reject request

To test and study Kubernetes authentication flow, I was tested it with minikube.

## Environment
* Kubernetes cluster bootstrapped with minikube

```shell
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"13", GitVersion:"v1.13.1", GitCommit:"eec55b9ba98609a46fee712359c7b5b365bdd920", GitTreeState:"clean", BuildDate:"2018-12-13T19:44:19Z", GoVersion:"go1.11.2", Compiler:"gc", Platform:"darwin/amd64"}
Server Version: version.Info{Major:"1", Minor:"12", GitVersion:"v1.12.4", GitCommit:"f49fa022dbe63faafd0da106ef7e05a29721d3f1", GitTreeState:"clean", BuildDate:"2018-12-14T06:59:37Z", GoVersion:"go1.10.4", Compiler:"gc", Platform:"linux/amd64"}
```

## Authentication
In this test, we used X509 Client Certs (Client certificate authentication) as authentication strategy.
For more information about it or other authentication strategy, see [2].

**Procedure:**

1. Create client key and CSR (Certificate Signing Request)
1. Sign CSR created in previous step with CA key
1. Register client key and certificate to kubectl config

In minikube, client certificate authentication is enabled by default. 
So we don't need to enable it manually.
Let's create client key and certificate.

### Create client key and CSR
First, we must create client key and CSR (Certificate Signing Request).
We can create these with `openssl` command.
```shell
# generate RSA private key (Algorithm: RSA, Key bits: 2048, Key name: client.key)
$ openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:2048 -out client.key

# generate CSR (Username: mas9612, Group: users)
$ openssl req -new -key client.key -out client.csr -subj "/CN=mas9612/O=users"
```

When issuing CSR, we must pass username and group at `-subj` option.
`CN` means username, `O` means group. User can be associated with multiple groups.
To add user more than one groups, simply add `O` section to `-subj` option.
```shell
# user mas9612 is now a member of "users" and "member" groups
$ openssl req -new -key client.key -out client.csr -subj "/CN=mas9612/O=users/O=member"
```

### Sign CSR with CA key
After create CSR, we must sign it with CA (Certificate Authority) key.

First, we must fetch CA key and certificate from minikube VM.
We can do that with following commands.
```shell
$ minikube ssh
$ sudo cp /var/lib/minikube/certs/ca.crt /var/lib/minikube/certs/ca.key ~
$ sudo chown $(id -u):$(id -g) ~/ca.crt ~/ca.key
$ exit

$ scp -i $(minikube ssh-key) docker@$(minikube ip):~/ca.crt .
$ scp -i $(minikube ssh-key) docker@$(minikube ip):~/ca.key .
```

Finally, sign CSR with fetch key and certificate.
```shell
$ openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out client.crt -days 3650
```

To check created certificate, run following command.
```shell
$ openssl x509 -in client.crt -text -noout
```

## Register client key and certificate to kubectl config
After create client key and certificate, we should register it to kubectl config to use it easily.

```shell
# create "testuser" with given key and certificate
$ kubectl config set-credentials testuser --client-key=./client.key --client-certificate=./client.crt

# bind "testuser" and minikube cluster as "authtest" context
$ kubectl config set-context authtest --cluster=minikube --user=testuser

# change to use "authtest" context instead of minikube default
$ kubectl config use-context authtest
```

After register credentials, we can use kubectl command as created user.
But now, we aren't granted to use any API so any request will be rejected.
```shell
$ kubectl get pods
Error from server (Forbidden): pods is forbidden: User "mas9612" cannot list resource "pods" in API group "" in the namespace "default"
```

To allow API request, we must assign appropriate Role to User.

## Authorization
In the previous section, we tried to create new user and to query running pod information.
We confirmed that user is properly created but any operation is not allowed.

In this section, we will examine Kubernetes RBAC API.

### Role/ClusterRole, RoleBinding/ClusterRoleBinding[5]
Kubernetes RBAC API has 4 types: Role, ClusterRole, RoleBinding, ClusterRoleBinding.

Types prefixed by `Cluster-` have cluster-wide effect.
In contrast, types non-prefixed by `Cluster-` have only specific namespace (e.g. `default` namespace)

Role/ClusterRole contains rules that represent a set of permissions.
Default permission is all deny so you must add some rule to allow operation (e.g. list pods, create new deployment, etc.).

RoleBinding/ClusterRoleBinding grants the permissions to a user (or a set of users).

So if we want to add some permission to user, first create appropriate Role and then bind it to user by RoleBinding.

### Create Role
Let's create Role to list running pods in default namespace.
Create `client-role.yml` with the following content.

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: test-role
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "watch", "list"]
```

After create manifest, apply it with kubectl:

```shell
# make sure that we're using minikube context
$ kubectl config use-context minikube

$ kubectl apply -f client-role.yml
role.rbac.authorization.k8s.io/test-role created

# check Role is created properly
$ kubectl get role
NAME        AGE
test-role   102s
```

### Create RoleBinding
Next, we create RoleBinding to bind User and Role.
Create `client-rolebinding.yml` with the following content.
```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: client-read-access
  namespace: default
subjects:
  - kind: User
    name: mas9612
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: test-role
  apiGroup: rbac.authorization.k8s.io
```

Please change username to that you created.

After create manifest, apply it with kubectl:

```shell
$ kubectl apply -f client-rolebinding.yml
rolebinding.rbac.authorization.k8s.io/client-read-access created

$ kubectl get rolebindings
NAME                 AGE
client-read-access   48s
```

Finally, change context to `auth-test` and try to query pods again!
```shell
$ kubectl config use-context auth-test
Switched to context "auth-test".

$ kubectl get pods
No resources found.
```

## References
* [1] [Controlling Access to the Kubernetes API - Kubernetes](https://kubernetes.io/docs/reference/access-authn-authz/controlling-access/)
* [2] [Authenticating - Kubernetes](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
* [3] [Certificates - Kubernetes](https://kubernetes.io/docs/concepts/cluster-administration/certificates/#openssl)
* [4] [Authorization Overview - Kubernetes](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
* [5] [Using RBAC Authorization - Kubernetes](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
