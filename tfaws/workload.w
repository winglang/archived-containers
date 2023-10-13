bring "../api.w" as workload_api;
bring "./eks.w" as workload_eks;
bring "cdk8s-plus-27" as workload_plus;
bring "cdk8s" as workload_cdk8s;
bring "cdktf" as workload_cdktf;
bring "./ecr.w" as workload_ecr;
bring "../utils.w" as workload_utils;

class Workload impl workload_api.IWorkload {
  init(props: workload_api.WorkloadProps) {
    let cluster = workload_eks.Cluster.getOrCreate(this);

    let var image = props.image;
    let var deps = MutArray<workload_cdktf.ITerraformDependable>[];

    if props.image.startsWith("./") {
      let hash = workload_utils.resolveContentHash(this, props);
      let appDir = workload_utils.entrypointDir(this);
      let repository = new workload_ecr.Repository(
        name: props.name,
        directory: appDir + "/" + props.image,
        tag: hash
      );

      image = repository.image;
      for d in repository.deps {
        deps.push(d);
      }
    }

    let chart = new _Chart(props);
    let helmDir = chart.toHelm();

    let helm = new workload_eks.HelmChart(
      cluster,
      dependsOn: deps.copy(),
      name: props.name,
      chart: helmDir,
      values: ["image: ${image}"],
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

class _Chart extends workload_cdk8s.Chart {
  name: str;

  init(props: workload_api.WorkloadProps) {
    let env = props.env ?? {};
    let envVariables = MutMap<workload_plus.EnvValue>{};

    for k in env.keys() {
      envVariables.set(k, workload_plus.EnvValue.fromValue(env.get(k)));
    }

    let ports = MutArray<workload_plus.ContainerPort>[];
    if let port = props.port {
      ports.push({ number: port });
    }

    let var readiness: workload_plus.Probe? = nil;
    if let x = props.readiness {
      if let port = props.port {
        readiness = workload_plus.Probe.fromHttpGet(x, port: port);
      } else {
        throw "Cannot setup readiness probe without a `port`";
      }
    }

    let deployment = new workload_plus.Deployment(
      replicas: props.replicas,
      metadata: {
        name: props.name
      },
    );

    deployment.addContainer(
      image: "{{ .Values.image }}",
      envVariables: envVariables.copy(),
      ports: ports.copy(),
      readiness: readiness,
      args: props.args,
      securityContext: {
        ensureNonRoot: false,
      }
    );

    let isPublic = props.public ?? false;
    let var serviceType: workload_plus.ServiceType? = nil;

    if isPublic {
      serviceType = workload_plus.ServiceType.NODE_PORT;
    }

    let service = deployment.exposeViaService(
      name: props.name,
      serviceType: serviceType,
    );

    if isPublic {
      new workload_plus.Ingress(
        metadata: {
          name: props.name,
          annotations: {
            "kubernetes.io/ingress.class": "alb",
            "alb.ingress.kubernetes.io/scheme": "internet-facing",
            "alb.ingress.kubernetes.io/target-type": "ip",
            "alb.ingress.kubernetes.io/healthcheck-protocol": "HTTP",
            "alb.ingress.kubernetes.io/healthcheck-port": "traffic-port",
            "alb.ingress.kubernetes.io/healthcheck-path": "/",
          }
        },
        defaultBackend: workload_plus.IngressBackend.fromService(service),
      );
    }

    this.name = props.name;
  }

  pub toHelm(): str {
    return _Chart.toHelmChart(this);
  }

  extern "./util.js" pub static toHelmChart(chart: workload_cdk8s.Chart): str;
}
