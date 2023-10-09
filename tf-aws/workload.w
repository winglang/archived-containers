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
        throw "Cannot setup readiness probe without a `port`";
      }
    }

    let deployment = new cdk8s.Deployment(
      metadata: {
        name: "deployment-${this.node.addr}"
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
      name: "service-${this.node.addr}",
      serviceType: cdk8s.ServiceType.NODE_PORT,
    );

    let ingress = new cdk8s.Ingress(
      metadata: {
        name: "ingress-${this.node.addr}",
        annotations: {
          "kubernetes.io/ingress.class": "alb",
          "alb.ingress.kubernetes.io/scheme": "internet-facing",
          // "alb.ingress.kubernetes.io/target-type": "instance",
          // "alb.ingress.kubernetes.io/load-balancer-name": "",
          // "alb.ingress.kubernetes.io/backend-protocol": "HTTP",
          // "alb.ingress.kubernetes.io/listen-ports": "[{\"HTTP\": 80}]",
        }
      },
      defaultBackend: cdk8s.IngressBackend.fromService(service),
    );

    // ingress.addRule("/", );
  }
}

class Workload impl api.IWorkload {
  init(props: api.WorkloadProps) {
    let cluster = new eks.EksCluster();

    let chart = new _Chart(props);
    let helmDir = Util.toHelmChart(chart);

    // log(helmDir);
    
    cluster.addChart(
      name: "app-${this.node.addr}",
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