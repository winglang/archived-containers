bring "../api.w" as api;
bring "./eks.w" as eks;

class Workload impl api.IWorkload {
  init(props: api.WorkloadProps) {
    new eks.EksCluster();
  }

  pub inflight start() {
    throw "Not implemented yet";
  }

  pub inflight stop() {
    throw "Not implemented yet";
  }

  pub inflight url(): str? {
    throw "Not implemented yet";
  }
}