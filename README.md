# Wing Containers Support

This library allows deploying arbitrary containers with Wing.

## Installation

Use `npm` to install this library:

```sh
npm i wing-containers
```

## Bring it

```js
bring "wing-containers" as containers;

new containers.Workload(
  image: "paulbouwer/hello-kubernetes:1",
  port: 8080,
  readiness: "/",
  env: {
    "MESSAGE" => message,
  }
);
```

The `Workload` resource represents a containerized workload.

## Implementations

### `sim`

When executed in the Wing Simulator, the workload is started within a local Docker container.

### `tf-aws`

On AWS, an EKS cluster is provisioned and the workload is deployed through Helm into the Kubernetes
cluster.

## TODO

See [Captain's Log](https://winglang.slack.com/archives/C047QFSUL5R/p1696868156845019) in the [Wing Slack](https://t.winglang.io).

- [x] EKS as a singleton
- [ ] Deploy multiple workloads (maybe guestbook?)
- [ ] Publish the library
- [ ] Implement `start()` and `stop()` and `url()`.
- [ ] Add support for local Dockerfiles (currently only images from Docker Hub are supported), this
      includes publishing into an ECR.
- [ ] Add support for sidecar containers
- [ ] Domains
- [ ] SSL
- [ ] What happens if I deploy more than one app into the cluster? Add support for ingress routes
      (currently all routes go to the container).
- [ ] Nodes - what should we do there? Use Fargate profiles in EKS instead of managed node groups?
- [ ] Open bugs
- [ ] Allow referencing an existing EKS cluster.

## License

Licensed under the [MIT License](./LICENSE).