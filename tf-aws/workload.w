bring "../api.w" as api;
bring "./eks.w" as eks;
bring "cdk8s-plus-27" as cdk8s;
bring "cdk8s" as k8s;

class _Chart extends k8s.Chart {
  init(props: api.WorkloadProps) {
    let env = props.env ?? {};
    let envVariables = MutMap<cdk8s.EnvValue>{};

    for k in env.keys() {
      envVariables.set(k, cdk8s.EnvValue.fromValue(env.get(k)));
    }

    let ports = MutArray<cdk8s.ContainerPort>[];
    if let port = props.port {
      ports.push({ number: port });
    }

    let var readiness: cdk8s.Probe? = nil;
    if let x = props.readiness {
      if let port = props.port {
        readiness = cdk8s.Probe.fromHttpGet(x, port: port);
      } else {
        throw "cannot implement readiness probe without a `port`";
      }
    }

    let deployment = new cdk8s.Deployment(
      metadata: {
        name: "my-deployment-${this.node.addr}"
      }
    );

    deployment.addContainer(
      image: props.image,
      envVariables: envVariables.copy(),
      ports: ports.copy(),
      readiness: readiness,
      securityContext: {
        ensureNonRoot: false,
      }
    );

    let service = deployment.exposeViaService(
      name: "my-service-${this.node.addr}",
    );
  }
}

class Workload impl api.IWorkload {
  init(props: api.WorkloadProps) {
    let cluster = new eks.EksCluster();

    let chart = new _Chart(props);
    let helmDir = Util.toHelmChart(chart);

    // log(helmDir);
    
    cluster.addChart(
      name: "my-app",
      chart: helmDir,
    );
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

class Util {
  extern "./util.js" pub static toHelmChart(chart: k8s.Chart): str;
}