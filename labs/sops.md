# Lab: SOPS

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-SOPS)

## Install SOPS and age

Follow the [SOPS](https://getsops.io/docs/#download) and [age](https://github.com/FiloSottile/age#installation)  installation instructions for your platform.
On macOS, you can use Homebrew:

```bash
brew install sops age
```

## Set Up Secret Encryption in Git

First, generate an age key pair using `age-keygen`.
The public key is printed to stdout (pattern: `age1...`).
The private key is stored (alongside the public key) in `age.agekey` (pattern: `AGE-SECRET-KEY-...`).
You can always derive the public key from the private key using ``age-keygen -y age.agekey`.

```bash
# Don't commit the age private key to git
echo '*.agekey' >> .gitignore

# Generate a key pair
age-keygen -o age.agekey

# Show the generated key pair
cat age.agekey
# created: 2025-11-16T11:57:36+01:00
# public key: age1...
AGE-SECRET-KEY-...
```

Optionally, point SOPS to the age private key in case you want to decrypt and edit files locally:

```bash
# Set the SOPS_AGE_KEY_FILE environment variable
# Needed for decrypting and editing encrypted files locally
export SOPS_AGE_KEY_FILE=$PWD/age.agekey
```

Next, we need to configure SOPS to use the generated age key for encryption.
Whenever, you encrypt a file with the `sops encrypt` command, SOPS will check the `.sops.yaml` configuration file for rules on how to encrypt the file, i.e., which fields to encrypt and which key to use.
With the following configuration, SOPS will use the generated age public key whenever encrypting YAML files ending with `.encrypted.yaml` (Kubernetes Secret manifests) or plain text files ending with `.encrypted`.
In Kubernetes Secret manifests, only the `data` and `stringData` fields are encrypted.
Additionally, the checksum (MAC) is restricted to only include the encrypted data, allowing you to update metadata fields without re-encrypting the whole file.
Whenever you decrypt a file, SOPS will verify the checksum to ensure the encrypted data has not been tampered with.
As a convenience, the configuration also sets 2-space indentation for YAML files.

With this configuration, everybody can encrypt files using the public key, but only those who possess the private key (stored in `age.agekey`) can decrypt them.
Keep in mind, that this configuration file alone does not cause files to be encrypted.
You still need to explicitly encrypt files using the `sops encrypt` command (see the following sections).
While we could also specify the public key and configuration options directly on the `sops encrypt` command, using a configuration file is more convenient.

```bash
cat <<EOF > .sops.yaml
creation_rules:
# Encrypt data and stringData fields of Kubernetes Secret YAML files ending with .encrypted.yaml
- path_regex: \.encrypted\.yaml$
  encrypted_regex: ^(data|stringData)$
  # authenticating only the encrypted data allows updating metadata fields without re-encrypting
  mac_only_encrypted: true
  age: $(age-keygen -y $SOPS_AGE_KEY_FILE)

# Encrypt plain text files ending with .encrypted
- path_regex: \.encrypted$
  age: $(age-keygen -y $SOPS_AGE_KEY_FILE)

stores:
  # Configure 2-space indentation for YAML files
  yaml:
    indent: 2
EOF
```

Commit the configuration to Git:

```bash
git add .sops.yaml .gitignore
git commit -m "Configure SOPS encryption with age"
git push
```

## Prepare for Secret Decryption in Flux

To ensure, that Flux can apply the encrypted manifests stored in Git, we need to provide Flux with access to the age private key.
For this, we create a Kubernetes secret in the `flux-system` namespace containing the `age.agekey` file.
As noted in the corresponding [Flux documentation](https://fluxcd.io/flux/guides/mozilla-sops/#encrypting-secrets-using-age), the key in the secret (here: `age.agekey`) must end with `.agekey` for Flux to recognize it.

```bash
kubectl -n flux-system create secret generic sops-age --from-file=age.agekey
```

Later on, we can reference this secret in the `decryption` section of our `Kustomization` manifests.
Whenever, the Flux `kustomize-controller` finds the `decryption` section in a `Kustomization`, it will use the specified secret to decrypt any SOPS-encrypted files before applying them to the cluster.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
spec:
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

## Add SOPS-Encrypted Secrets for Google Cloud DNS

We now want to manage the Kubernetes Secrets required for `external-dns` and `cert-manager` with the Google Cloud DNS service account key (see the previous labs) via GitOps.
For this, we first generate the respective Kubernetes Secret manifests using `kubectl create secret ... --dry-run=client -oyaml`.
At this point, the manifest is still unencrypted and contains the service account key in plain text (it's [base64-encoded, but that's not encryption!](https://medium.com/tuanhdotnet/handling-base64-encoded-data-in-kubernetes-secrets-77df09e6039d)).
Hence, we must now encrypt the generated manifest using `sops encrypt --in-place ...`.
The `--in-place` flag causes SOPS to overwrite the file with the encrypted version.
Ensure to use the `.encrypted.yaml` suffix for the secret manifest file so that SOPS applies the correct encryption rules from the configuration file.

```bash
# create the deploy/external-dns directory if it doesn't exist
mkdir -p deploy/external-dns
# generate the unencrypted secret manifest and save it to a file
kubectl -n external-dns create secret generic google-clouddns --from-file service-account.json=key.json --dry-run=client -oyaml > deploy/external-dns/secret-google-clouddns.encrypted.yaml
# encrypt the secret manifest in place
sops encrypt --in-place deploy/external-dns/secret-google-clouddns.encrypted.yaml
```

Finally, we add a respective `Kustomization` manifest to the [`clusters/dhbw/external-dns.yaml`](../clusters/dhbw/external-dns.yaml) so that Flux starts managing the newly added secret on the cluster.
to decrypt them during deployment.
The `Kustomization` also specifies the `decryption` section referencing the previously created `sops-age` secret instructing Flux to decrypt the SOPS-encrypted files before applying them.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: external-dns
  namespace: flux-system
spec:
  interval: 30m0s
  path: ./deploy/external-dns
  prune: true
  retryInterval: 2m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  timeout: 3m0s
  wait: true
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

Similarly, we create the SOPS-encrypted secret manifest for `cert-manager`:

```bash
kubectl -n cert-manager create secret generic google-clouddns --from-file service-account.json=key.json --dry-run=client -oyaml > deploy/cert-manager/secret-google-clouddns.encrypted.yaml
sops encrypt --in-place deploy/cert-manager/secret-google-clouddns.encrypted.yaml
```

Again, for Flux to decrypt and apply the secret, we need to add the `decryption` section to the respective `Kustomization` manifest in [`clusters/dhbw/cert-manager.yaml`](../clusters/dhbw/cert-manager.yaml):

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cert-manager
  namespace: flux-system
spec:
  interval: 30m0s
  path: ./deploy/cert-manager
  prune: true
  retryInterval: 2m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  timeout: 3m0s
  wait: true
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

## Bonus: Basic Authentication for podinfo Application

Basic authentication requires users to provide a username and password to access the application.
The credentials are typically stored in a `.htpasswd` file.
We can create such a file using the `htpasswd` command-line utility.
The `.htpasswd` file contains a list of username and password hash pairs (username is stored in plain text, the password is hashed for security).

Use the `htpasswd -c` command to create a new `.htpasswd` file including credentials for one user.
The utility will prompt you to enter and confirm the password for the specified user.
We then encrypt the generated `.htpasswd` file using SOPS for secure storage in Git.

```bash
htpasswd -c deploy/podinfo/overlays/development/htpasswd.encrypted <username>
sops encrypt --in-place deploy/podinfo/overlays/development/htpasswd.encrypted
```

The [resulting file](../deploy/podinfo/overlays/development/htpasswd.encrypted) is a json object containing the encrypted file content in the `data` field.

The [ingress-nginx controller](https://kubernetes.github.io/ingress-nginx/examples/auth/basic/) requires the `.htpasswd` data to be stored in a Kubernetes Secret in the same namespace as the `Ingress` resource.
The data must be stored in the `auth` key of the Secret.
We can create the Secret manifest from the SOPS-encrypted `.htpasswd` file using a `Kustomize` `secretGenerator` (see [`deploy/podinfo/overlays/development/kustomization.yaml`](../deploy/podinfo/overlays/development/kustomization.yaml)):

```yaml
secretGenerator:
- name: basic-auth
  options:
    # don't append hash of the file contents to the secret name
    disableNameSuffixHash: true
  files:
  - auth=htpasswd.encrypted

patches:
- path: patch-ingress-auth.yaml
```

Now, we need to reference the created Secret in the `Ingress` resource to enable basic authentication.
For this, we add a [patch for the `Ingress` resource](../deploy/podinfo/overlays/development/patch-ingress-auth.yaml) in the `development` overlay and reference it in the `kustomization.yaml`:

```yaml
# patch-ingress-auth.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
```

Again, we need to tell Flux to decrypt the SOPS-encrypted file before applying the `podinfo` manifests.
For this, we add the `decryption` section to the respective `Kustomization` manifest in [`clusters/dhbw/podinfo-dev.yaml`](../clusters/dhbw/podinfo-dev.yaml):

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo-dev
  namespace: flux-system
spec:
  interval: 30m0s
  path: ./deploy/podinfo/overlays/development
  prune: true
  retryInterval: 2m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  timeout: 3m0s
  wait: true
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

Now, when accessing the `podinfo-dev` application via the Ingress, we should be required to provide the configured username and password for authentication.

```bash
# Without credentials, we get a 401 Authorization Required response
$ curl https://podinfo-dev.<cluster-name>.dski23a.timebertt.dev
<html>
<head><title>401 Authorization Required</title></head>
<body>
<center><h1>401 Authorization Required</h1></center>
<hr><center>nginx</center>
</body>
</html>

# With the correct credentials, we can access the application
$ curl https://podinfo-dev.<cluster-name>.dski23a.timebertt.dev -u <username>:<password> 
{
  "hostname": "podinfo-677d5f7896-xxwxs",
  "version": "6.9.2",
  "revision": "e86405a8674ecab990d0a389824c7ebbd82973b5",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "Hello, Platform Engineering!",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.25.1",
  "num_goroutine": "8",
  "num_cpu": "8"
}
```
