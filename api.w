interface IWorkload extends std.IResource {
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
  readiness: str?;   // http get
  replicas: num?;    // number of replicas
  public: bool?;     // whether the workload should have a public url (default: false)
  args: Array<str>?; // container arguments

  /** 
   * A list of globs of local files to consider as input sources for the container.
   * By default, the entire build context directory will be included.
   */
  sources: Array<str>?;

  /**
   * a hash that represents the container source. if not set,
   * and `sources` is set, the hash will be calculated based on the content of the
   * source files.
   */
  sourceHash: str?;
}

struct WorkloadProps extends ContainerOpts {

}