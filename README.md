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

## `sim`

When executed in the Wing Simulator, the workload is started within a local Docker container.

## `tf-aws`

To deploy containerized workloads on AWS, we will need an EKS cluster. Unless other specified, a
cluster will be automatically provisioned for each Wing application.

However, it a common practice to reuse a single EKS cluster for multiple applications. To reference
an existing cluster, you will need to specify the following platform values:

* `eks.cluster_name`: The name of the cluster
* `eks.endpoint`: The URL of the Kubernetes API endpoint of the cluster
* `eks.certificate`: The certificate authority of this cluster.

This information can be obtained from the AWS Console or through the script `eks-values.sh`:

```sh
$ ./eks-values.sh CLUSTER-NAME > values.yaml
$ wing compile -t tf-aws --values ./values.yaml main.w
```

To create a new EKS cluster, you can use the `tfaws.Cluster` resource:

`eks.main.w`:

```js
bring containers;

new containers.tfaws.Cluster() as "my-wing-cluster";
```

And provision it using Terraform:

```js
$ wing compile -t tf-aws eks.main.w
$ cd target/eks.main.tfaws
$ terraform init
$ terraform apply
```

This might take a up to 20 minutes to provision (now you see why we want to share it across apps?).

## Roadmap

See [Captain's Log](https://winglang.slack.com/archives/C047QFSUL5R/p1696868156845019) in the [Wing
Slack](https://t.winglang.io).

- [x] EKS as a singleton
- [x] Add support for local Dockerfiles (currently only images from Docker Hub are supported), this
      includes publishing into an ECR.
- [x] Invalidation of local docker image (both local and in registry). Check what cdk-assets is
  doing.
- [x] Reference existing EKS repository.
- [ ] Use a `cloud.Redis` database
- [ ] Implement `cloud.Service` using containers.
- [ ] Reference workload from another workload (without going through the load balancer).
- [ ] Publish the library
- [ ] `url()` and `internalUrl()` or something like this.
- [ ] Enable logging (`Disabled logging because aws-logging configmap was not found. configmap
  "aws-logging" not found`).
- [x] Generate helm charts under target directory
- [ ] Implement `start()` and `stop()`.
- [ ] Sidecar containers
- [ ] Domains
- [ ] How can we vend `./eks-value.sh` as part of this library?
- [ ] SSL
- [x] Nodes - what should we do there? Use Fargate profiles in EKS instead of managed node groups?
- [ ] Open bugs

## License

Licensed under the [MIT License](./LICENSE).