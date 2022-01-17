# Synchronous integration flow

Integration flow in this demo deployment has several noteworthy components:
- Kong API Gateway with custom CloudEvents plugin,
- Synchronous content-based router,
- Multiple transformations based on Kong endpoints.

Combined together these components create event-driven integration with independent data routes, synchronous public endpoints, and minimal resources usage.


## Requirements

This demo requires quite a few custom components so a new k8s cluster is recommended to be used as a deployment environment. `default` namespace will be used to deploy the demo flow components.

k8s cluster must have following components installed:
- Knative Eventing and Serving
- Eventing MT-based broker, IMC channels
- Kong Gateway with CE plugin ([instruction](https://github.com/triggermesh/kong-cloudevents-plugin#readme))
- Triggermesh controller deployed from `synchronizer` [branch](https://github.com/triggermesh/triggermesh/tree/synchronizer) 
- IBM MQ integration controller from [here](https://github.com/triggermesh/ibm-mq-target)
- TIL installed from `sync-broker-poc` [branch](https://github.com/triggermesh/til/tree/sync-broker-poc)


## Deployment

First of all, we need to have IBM MQ server running in the cluster:

```sh
kubectl apply -f config/demo/ibm-mq-server.yaml
```

Then our `synchronous-backend` that imitates System of Record must be deployed. Under the hood, this app simply copies input MQ messages to `reply-to` queue.

```sh
kubectl apply -f config/demo/sync/backend-deployment.yaml
```

Next, assuming that Kong controller with the custom ce-plugin is up and running, we must expose its admin API and deploy our service:

```sh
kubectl -n kong port-forward deployment/ingress-kong 8444
```
In the second terminal:

```sh
curl -k https://localhost:8444/config -F config=@config/demo/sync/kong-service.yml
```

Finally, deploy our integration components:

```sh
til generate config/demo/sync/sync-multiroute.hcl | kubectl apply -f -
```

Make sure that all pods are up and running:

```sh
kubectl get pods
NAME                                                             READY   STATUS    RESTARTS   AGE
bar-9cpqgp-00001-deployment-7b4b44dccf-lltjb                     2/2     Running   0          13s
default-dsz562-00001-deployment-5dc54c566c-lrwt8                 2/2     Running   0          19s
foo-qlcz2r-00001-deployment-959db8db9-s7zb7                      2/2     Running   0          83s
ibm-mq-server-5bc7584f75-lh6qd                                   1/1     Running   0          10d
ibmmqsource-mq-output-channel-75977cb4c5-hsdl4                   1/1     Running   0          102m
ibmmqtarget-mq-input-channel-00001-deployment-7b4cb6c795-lwzfg   2/2     Running   0          113s
synchronizer-dispatcher-00001-deployment-9996544d5-qc754         2/2     Running   0          118s
synchronous-backend-59d55755cd-wqb2d                             1/1     Running   0          110m
```

We have the following scheme deployed:

![Flow scheme](.assets/sync-multiroute-flow.png)


## Tests

Following command will work for Kong deployment on EKS cluster. If it is not the case, please retrieve Kong's external address manually.

```sh
KONG_ADDRESS=$(kubectl -n kong get svc kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

Send curl requests:

```sh
curl -d '{"name":"TriggerMesh"}' -H "Content-Type: application/json" $KONG_ADDRESS/bar

{
  "specversion": "1.0",
  "id": "ab6791ef-38c9-4aa5-b9ff-40c277634ec7",
  "source": "source.py",
  "type": "io.triggermesh.klr.serialized.bar",
  "datacontenttype": "application/json",
  "time": "2021-12-13T12:11:10Z",
  "data": {
    "client": "TriggerMesh",
    "path": "/bar"
  },
  "correlationid": "1f155d47-43f4-4ced-bcc0"
}
```

```sh
curl -d '{"name":"TriggerMesh"}' -H "Content-Type: application/json" $KONG_ADDRESS/random-endpoint
 
 {
  "specversion": "1.0",
  "id": "cdec35f6-0fbd-431b-94ea-7af21c2a4280",
  "source": "source.py",
  "type": "io.triggermesh.klr.serialized.default",
  "datacontenttype": "application/json",
  "time": "2021-12-13T12:12:00Z",
  "data": {
    "path": "default"
  },
  "correlationid": "818e0678-1440-486b-bf85"
}
```

Looking into the [sync-multiroute.hcl](./sync-multiroute.hcl) manifest should explain how our requests are routed and why they have different output data.
