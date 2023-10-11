# Wing Containers Support

This library allows deploying arbitrary containers with Wing.

## Installation

Use `npm` to install this library:

```sh
npm i wing-containers
```

## Bring it

The `Workload` resource represents a containerized workload.

```js
bring "wing-containers" as containers;

new containers.Workload(
  image: "paulbouwer/hello-kubernetes:1",
  port: 8080,
  readiness: "/",
  replicas: 4,
  env: {
    "MESSAGE" => message,
  }
) as "hello";
```

## Implementations

### `sim`

When executed in the Wing Simulator, the workload is started within a local Docker container.

### `tf-aws`

By default an EKS cluster is provisioned and the workload is deployed through Helm into the
Kubernetes cluster.

To use an existing EKS cluster, the following platform values are required:

* `eks.cluster_name` - the name of the cluster
* `eks.endpoint` - the url of the kuberenets api endpoint of the cluster
* `eks.certificate` - the certificate authority of this cluster.

The `eks-values.sh` script can be used to query the values for an existing cluster and create a
values file:

```sh
$ ./eks-values.sh CLUSTER-NAME > values.yaml
$ wing compile -t tf-aws --values ./values.yaml main.w
```

## TODO

See [Captain's Log](https://winglang.slack.com/archives/C047QFSUL5R/p1696868156845019) in the [Wing Slack](https://t.winglang.io).

- [x] EKS as a singleton
- [ ] Add support for local Dockerfiles (currently only images from Docker Hub are supported), this
      includes publishing into an ECR.
- [x] Reference existing EKS repository.
- [ ] Use a `cloud.Redis` database
- [ ] Implement `cloud.Service` using containers.
- [ ] Deploy multiple workloads (maybe guestbook?)
- [ ] Publish the library
- [x] Generate helm charts under target directory
- [ ] Implement `start()` and `stop()` and `url()`.
- [ ] Sidecar containers
- [ ] Domains
- [ ] SSL
- [ ] What happens if I deploy more than one app into the cluster? Add support for ingress routes
      (currently all routes go to the container).
- [x] Nodes - what should we do there? Use Fargate profiles in EKS instead of managed node groups?
- [ ] Open bugs
- [ ] Allow referencing an existing EKS cluster.

## License

Licensed under the [MIT License](./LICENSE).