bring util;
bring "./sim" as sim;
bring "./tfaws" as aws;
bring "./api.w" as api;
bring "./utils.w" as utils;

class Workload impl api.IWorkload {
  inner: api.IWorkload;
  pub internalUrl: str?;
  pub publicUrl: str?;

  init(props: api.WorkloadProps) {
    let target = util.env("WING_TARGET");

    if target == "sim" {
      this.inner = new sim.Workload(props) as "sim";
    } elif target == "tf-aws" {
      this.inner = new aws.Workload(props) as "tf-aws";
    } else {
      throw "unsupported target ${target}";
    }

    this.internalUrl = this.inner.getInternalUrl();
    this.publicUrl = this.inner.getPublicUrl();
  }

  pub getInternalUrl(): str? {
    return this.inner.getInternalUrl();
  }

  pub getPublicUrl(): str? {
    return this.inner.getPublicUrl();
  }
}
