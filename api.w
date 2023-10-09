interface IWorkload {
  /** starts the workload */
  inflight start(): void;

  /** stops containers */
  inflight stop(): void;
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