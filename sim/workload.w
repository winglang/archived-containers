bring "../api.w" as api;
bring http;
bring util;
bring cloud;

class Workload impl api.IWorkload {
  containerId: str;
  bucket: cloud.Bucket;
  urlKey: str;
  props: api.WorkloadProps;
  appDir: str;

  init(props: api.WorkloadProps) {
    this.appDir = Workload.entrypointDir(this);
    this.props = props;
    let hash = util.sha256(Json.stringify(props));
    this.containerId = "wing-${this.node.addr.substring(0, 6)}-${hash}";
    this.bucket = new cloud.Bucket();
    this.urlKey = "url";

    new cloud.Service(inflight () => {
      this.start();
      return () => {
        this.stop();
      };
    });
  }

  pub inflight start(): void {
    log("starting container");
    log("appdir=${this.appDir}");

    let opts = this.props;

    let image = opts.image;
    let var tag = image;

    // if this a reference to a local directory, build the image from a docker file
    log("image: ${image}");
    if image.startsWith("./") {
      tag = this.containerId;
      log("building locally from ${image} and tagging ${tag}...");
      Workload.shell("docker", ["build", "-t", tag, image], this.appDir);
    } else {
      Workload.shell("docker", ["pull", opts.image], this.appDir);
    }

    // remove old container
    Workload.shell("docker", ["rm", "-f", this.containerId]);
    
    // start the new container
    let args = MutArray<str>[];
    args.push("run");
    args.push("--detach");
    args.push("--name");
    args.push(this.containerId);

    if let port = opts.port {
      args.push("-p");
      args.push("${port}");
    }

    if let env = opts.env {
      if env.size() > 0 {
        args.push("-e");
        for k in env.keys() {
          args.push("${k}=${env.get(k)}");
        }
      }
    }

    args.push(tag);

    if let runArgs = this.props.args {
      for a in runArgs {
        args.push(a);
      }
    }

    Workload.shell("docker", args.copy());

    let out = Json.parse(Workload.shell("docker", ["inspect", this.containerId]));

    if let port = opts.port {
      let hostPort = out.tryGetAt(0)?.tryGet("NetworkSettings")?.tryGet("Ports")?.tryGet("${port}/tcp")?.tryGetAt(0)?.tryGet("HostPort")?.tryAsStr();
      if !hostPort? {
        throw "Container does not listen to port ${port}";
      }

      let url = "http://localhost:${hostPort}";
      this.bucket.put(this.urlKey, url);

      if let readiness = opts.readiness {
        let readinessUrl = "${url}${readiness}";
        log("waiting for container to be ready: ${readinessUrl}...");
        util.waitUntil(inflight () => {
          try {
            return http.get(readinessUrl).ok;
          } catch {
            return false;
          }
        }, interval: 0.1s);
      }
    }
  }

  pub inflight stop() {
    log("stopping container");
    Workload.shell("docker", ["rm", "-f", this.containerId]);
  }

  pub inflight url(): str? {
    return this.bucket.tryGet(this.urlKey);
  }  

  extern "./util.js" static inflight shell(command: str, args: Array<str>, cwd: str?): str;
  extern "./util.js" static entrypointDir(root: std.IResource): str;
}