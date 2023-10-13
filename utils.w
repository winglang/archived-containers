bring "./api.w" as utils_api;

class Util {
  extern "./utils.js" pub static inflight shell(command: str, args: Array<str>, cwd: str?): str;
  extern "./utils.js" pub static contentHash(files: Array<str>, cwd: str): str;
  extern "./utils.js" pub static entrypointDir(scope: std.IResource): str;
  extern "./utils.js" pub static dirname(): str;

  pub static resolveContentHash(scope: std.IResource, props: utils_api.WorkloadProps): str {
    if !props.image.startsWith("./") {
      throw "image is not a local docker build: ${props.image}";
    }
    
    let sources = props.sources ?? ["**/*"];
    let imageDir = Util.entrypointDir(scope) + "/" + props.image;
    return props.sourceHash ?? Util.contentHash(sources, imageDir);
  }
}