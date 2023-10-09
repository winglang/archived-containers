bring "../api.w" as api;
bring cloud;

class Workload impl api.IWorkload {
  init(props: api.WorkloadProps) {
    
  }

  pub inflight start() {

  }

  pub inflight stop() {

  }

  pub inflight url(): str? {
    return nil;
  }
}