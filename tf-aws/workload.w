bring "../api.w" as api;
bring "./eks.w" as eks;
bring "cdk8s-plus-27" as cdk8s;
bring "cdk8s" as k8s;
bring "cdktf" as cdktf3;

class Workload impl api.IWorkload {
  init(props: api.WorkloadProps) {
    let name = "${this.node.id.replace(".", "-").substring(0, 40).lowercase()}-${this.node.addr.substring(0, 6)}";
    let cluster = eks.Cluster.getOrCreate(this);
    let chart = new _Chart(name, props);
    let helmDir = chart.toHelm();

    new eks.HelmChart(
      cluster,
      name: name,
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

class _Chart extends k8s.Chart {
  name: str;

  init(name: str, props: api.WorkloadProps) {
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
        throw "Cannot setup readiness probe without a `port`";
      }
    }

    let deployment = new cdk8s.Deployment(
      replicas: props.replicas,
      metadata: {
        name: name
      },
    );

    deployment.addContainer(
      image: props.image,
      envVariables: envVariables.copy(),
      ports: ports.copy(),
      readiness: readiness,
      args: props.args,
      securityContext: {
        ensureNonRoot: false,
      }
    );

    let isPublic = props.public ?? false;
    let var serviceType: cdk8s.ServiceType? = nil;

    if isPublic {
      serviceType = cdk8s.ServiceType.NODE_PORT;
    }

    let service = deployment.exposeViaService(
      name: name,
      serviceType: serviceType,
    );

    if isPublic {
      new cdk8s.Ingress(
        metadata: {
          name: name,
          annotations: {
            "kubernetes.io/ingress.class": "alb",
            "alb.ingress.kubernetes.io/scheme": "internet-facing",
            "alb.ingress.kubernetes.io/target-type": "ip",
            "alb.ingress.kubernetes.io/healthcheck-protocol": "HTTP",
            "alb.ingress.kubernetes.io/healthcheck-port": "traffic-port",
            "alb.ingress.kubernetes.io/healthcheck-path": "/",
          }
        },
        defaultBackend: cdk8s.IngressBackend.fromService(service),
      );
    }

    this.name = name;
  }

  pub toHelm(): str {
    return _Chart.toHelmChart(this);
  }

  extern "./util.js" pub static toHelmChart(chart: k8s.Chart): str;
}
