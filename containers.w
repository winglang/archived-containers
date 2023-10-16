bring util;
bring "./sim" as sim;
bring "./tfaws" as aws;
bring "./api.w" as api;
bring "./utils.w" as utils;

class Workload impl api.IWorkload {
  inner: api.IWorkload;
  pub internalUrl: str?;

  init(props: api.WorkloadProps) {
    let target = util.env("WING_TARGET");

    if target == "sim" {
      this.inner = new sim.Workload(props) as this.node.id;
    } elif target == "tf-aws" {
      this.inner = new aws.Workload(props) as this.node.id;
    } else {
      throw "unsupported target ${target}";
    }

    this.internalUrl = this.inner.getInternalUrl();

    std.Node.of(this.inner).hidden = true;
  }

  pub inflight start() {
    this.inner.start();
  }

  pub inflight stop() {
    this.inner.stop();
  }

  pub inflight url(): str? {
    return this.inner.url();
  }

  pub getInternalUrl(): str? {
    return this.inner.getInternalUrl();
  }
}
