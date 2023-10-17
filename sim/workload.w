bring http;
bring util;
bring cloud;
bring sim;
bring "../api.w" as api;
bring "../utils.w" as utils;

class Workload impl api.IWorkload {
  containerId: str;
  publicUrlKey: str;
  internalUrlKey: str;

  props: api.WorkloadProps;
  appDir: str;
  imageTag: str;
  public: bool;
  state: sim.State;
  
  init(props: api.WorkloadProps) {
    this.appDir = utils.entrypointDir(this);
    this.props = props;
    this.state = new sim.State();

    let hash = utils.resolveContentHash(this, props);
    if hash? {
      this.imageTag = "${props.name}:${hash}";
      this.containerId = "${props.name}-${hash}";
    } else {
      this.imageTag = props.image;
      this.containerId = props.name;
    }

    this.public = props.public ?? false;
    this.publicUrlKey = "public_url";
    this.internalUrlKey = "internal_url";

    new cloud.Service(inflight () => {
      this.start();
      return () => { this.stop(); };
    });
  }

  pub getInternalUrl(): str? {
    if !this.props.port? {
      return nil;
    }

    return this.state.token(this.internalUrlKey);
  }

  pub inflight start(): void {
    log("starting workload...");

    let opts = this.props;

    // if this a reference to a local directory, build the image from a docker file
    if utils.isPathInflight(opts.image) {
      // check if the image is already built
      try {
        utils.shell("docker", ["inspect", this.imageTag]);
        log("image ${this.imageTag} already exists");
      } catch {
        log("building locally from ${opts.image} and tagging ${this.imageTag}...");
        utils.shell("docker", ["build", "-t", this.imageTag, opts.image], this.appDir);
      }
    } else {
      log("pulling ${opts.image}");
      utils.shell("docker", ["pull", opts.image], this.appDir);
    }

    // remove old container
    utils.shell("docker", ["rm", "-f", this.containerId]);
    
    // start the new container
    let dockerRun = MutArray<str>[];
    dockerRun.push("run");
    dockerRun.push("--detach");
    dockerRun.push("--name");
    dockerRun.push(this.containerId);

    if let port = opts.port {
      dockerRun.push("-p");
      dockerRun.push("${port}");
    }

    if let env = opts.env {
      if env.size() > 0 {
        dockerRun.push("-e");
        for k in env.keys() {
          dockerRun.push("${k}=${env.get(k)}");
        }
      }
    }

    dockerRun.push(this.imageTag);

    if let runArgs = this.props.args {
      for a in runArgs {
        dockerRun.push(a);
      }
    }

    log("starting container ${this.containerId}");
    log("docker ${dockerRun.join(" ")}");
    utils.shell("docker", dockerRun.copy());

    let out = Json.parse(utils.shell("docker", ["inspect", this.containerId]));

    if let port = opts.port {
      let hostPort = out.tryGetAt(0)?.tryGet("NetworkSettings")?.tryGet("Ports")?.tryGet("${port}/tcp")?.tryGetAt(0)?.tryGet("HostPort")?.tryAsStr();
      if !hostPort? {
        throw "Container does not listen to port ${port}";
      }

      let publicUrl = "http://localhost:${hostPort}";
      this.state.set(this.publicUrlKey, publicUrl);
      this.state.set(this.internalUrlKey, "http://host.docker.internal:${hostPort}");

      if let readiness = opts.readiness {
        let readinessUrl = "${publicUrl}${readiness}";
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
    utils.shell("docker", ["rm", "-f", this.containerId]);
  }

  pub inflight url(): str? {
    if !this.props.port? {
      return nil;
    }

    return this.state.get(this.publicUrlKey).asStr();
  }
}