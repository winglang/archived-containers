interface IWorkload {
  /** starts the container */
  inflight start(): void;

  /** stops the container */
  inflight stop(): void;

  /** if `port` is specified, this includes the external url of the container */
  inflight url(): str?;
}

struct ContainerOpts {
  image: str;
  port: num?;
  env: Map<str>?;
  readiness: str?; // http get
}

struct WorkloadProps extends ContainerOpts {

}