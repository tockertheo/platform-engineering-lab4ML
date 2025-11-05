# Lab: Kustomize

This solution demonstrates how to use Kustomize to deploy the [podinfo](https://github.com/stefanprodan/podinfo) application with environment-specific overlays.

## Overview

Kustomize is used to deploy the podinfo application with a base configuration and overlays for `development` and `production`.
Each variant is deployed in its own namespace, customizes the UI message, exposes the app via a LoadBalancer on a dedicated port, and sets environment-specific image tags and settings.

## Directory Structure

```
deploy/podinfo/
├── base/
│   ├── kustomization.yaml
│   └── patch-deployment.yaml
└── overlays/
    ├── development/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   └── patch-deployment.yaml
    └── production/
        ├── kustomization.yaml
        └── namespace.yaml
```

## Base Configuration

The base kustomization defines the common resources based on the [podinfo manifests](https://github.com/stefanprodan/podinfo/tree/master/kustomize) from the GitHub repository.
This includes the `Deployment` and `Service` definitions.

Additionally, the kustomization generates a `ConfigMap` for the common configuration (the UI message).
This `ConfigMap` is referenced by the strategic merge patch in the `patch-deployment.yaml` file in `envFrom` in the `podinfod` container, i.e., all environment variables defined in the `ConfigMap` are made available to the container.
Whenever, the `ConfigMap` is updated, the pods are automatically rolled out with the new configuration because kustomize appends a hash of the `ConfigMap` data to the name.
With this, the `Deployment` template changes on `ConfigMap` updates, triggering a rolling update of the pods.

## Overlays

- Development
  - Namespace: `podinfo-dev`
  - Image tag: `latest`
  - Debug logging enabled
- Production
  - Namespace: `podinfo-prod`
  - Image tag: `6.9.0`
  - Service LoadBalancer port: `12000`
 
The overlays customize the base resources for each environment.
Both kustomizations reference the base configuration and apply patches to set environment-specific values. 
Most notably, a namespace manifest is included per environment and all objects are deployed into the respective namespace by setting the `namespace` field in the overlay kustomizations.

The images are set to different tags depending on the environment.
This is achieved using the `images` field in the overlay kustomizations.

The `Deployment` is further customized in the `development` overlay.
Here, debug logging is enabled by adding the `--level=debug` argument to the container.

The `production` environment patches the `Service` to use a `LoadBalancer` with port `12000`.
For this, a JSON patch is used to modify the `spec.type` and `spec.ports[0].port` field.
The `port` is the port on which the `LoadBalancer` listens (i.e., accessible on the external IP).
The `targetPort` is unchanged and continues to point to correct container port by referencing the named port in the container.

## Rendering the Manifests

You can render the manifests for each environment using Kustomize:

```bash
kubectl kustomize deploy/podinfo/overlays/development
kubectl kustomize deploy/podinfo/overlays/production
```

## Deploying the Manifests

After verifying the rendered manifests, you can deploy them to your Kubernetes cluster:

```bash
kubectl apply -k deploy/podinfo/overlays/development
kubectl apply -k deploy/podinfo/overlays/production
```

## Verification

The results should look something like this:

```bash
$ kubectl -n podinfo-dev get deploy,po,svc,cm -owide
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES                                SELECTOR
deployment.apps/podinfo   2/2     2            2           4m27s   podinfod     ghcr.io/stefanprodan/podinfo:latest   app=podinfo

NAME                           READY   STATUS    RESTARTS   AGE     IP          NODE                         NOMINATED NODE   READINESS GATES
pod/podinfo-677d5f7896-drqbf   1/1     Running   0          4m12s   10.42.1.9   cluster-timebertt-worker-1   <none>           <none>
pod/podinfo-677d5f7896-xxwxs   1/1     Running   0          4m27s   10.42.3.8   cluster-timebertt-worker-0   <none>           <none>

NAME              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)             AGE     SELECTOR
service/podinfo   ClusterIP   10.43.28.174   <none>        9898/TCP,9999/TCP   4m27s   app=podinfo

NAME                                  DATA   AGE
configmap/podinfo-config-6k4m67h8g9   1      4m28s

$ kubectl -n podinfo-prod get deploy,po,svc,cm -owide
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES                               SELECTOR
deployment.apps/podinfo   2/2     2            2           4m29s   podinfod     ghcr.io/stefanprodan/podinfo:6.9.0   app=podinfo

NAME                         READY   STATUS    RESTARTS   AGE     IP           NODE                         NOMINATED NODE   READINESS GATES
pod/podinfo-ccc5dff5-clgvg   1/1     Running   0          4m14s   10.42.1.10   cluster-timebertt-worker-1   <none>           <none>
pod/podinfo-ccc5dff5-zdvh9   1/1     Running   0          4m29s   10.42.5.9    cluster-timebertt-worker-2   <none>           <none>

NAME              TYPE           CLUSTER-IP      EXTERNAL-IP                                    PORT(S)                          AGE     SELECTOR
service/podinfo   LoadBalancer   10.43.162.187   141.72.176.127,141.72.176.195,141.72.176.219   12000:31045/TCP,9999:30953/TCP   4m29s   app=podinfo

NAME                                  DATA   AGE
configmap/podinfo-config-6k4m67h8g9   1      4m29s
```

Pick any of the external IP addresses and open it in your browser (port `12000`).
You should see the podinfo application with the custom message "Hello, Platform Engineering!".
It's served by one of the pods in the `podinfo-prod` namespace and shows the `6.9.0` version.

To verify the development environment, you can port-forward the service to your local machine and open `http://localhost:9898` in your browser:

```bash
kubectl -n podinfo-dev port-forward svc/podinfo 9898:9898
```

It also shows the custom message "Hello, Platform Engineering!" and shows a more recent version.

You can also verify the debug logging in the `development` environment by checking the pod logs:

```bash
$ kubectl -n podinfo-dev logs -l app=podinfo
{"level":"debug","ts":"2025-11-05T18:44:11.438Z","caller":"http/logging.go:35","msg":"request started","proto":"HTTP/1.1","uri":"/healthz","method":"GET","remote":"[::1]:53652","user-agent":"Go-http-client/1.1"}
{"level":"debug","ts":"2025-11-05T18:44:12.813Z","caller":"http/logging.go:35","msg":"request started","proto":"HTTP/1.1","uri":"/readyz","method":"GET","remote":"[::1]:53672","user-agent":"Go-http-client/1.1"}
```

The logs in the `production` environment do not show debug messages:

```bash
$ kubectl -n podinfo-prod logs -l app=podinfo
{"level":"info","ts":"2025-11-05T18:38:51.767Z","caller":"podinfo/main.go:153","msg":"Starting podinfo","version":"6.9.0","revision":"fb3b01be30a3f353b221365cd3b4f9484a0885ea","port":"9898"}
{"level":"info","ts":"2025-11-05T18:38:51.767Z","caller":"http/server.go:224","msg":"Starting HTTP Server.","addr":":9898"}
```
