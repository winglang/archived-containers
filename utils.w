bring "./api.w" as utils_api;

class Util {
  extern "./utils.js" pub static inflight shell(command: str, args: Array<str>, cwd: str?): str;
  extern "./utils.js" pub static contentHash(files: Array<str>, cwd: str): str;
  extern "./utils.js" pub static entrypointDir(scope: std.IResource): str;
  extern "./utils.js" pub static dirname(): str;

  pub static isPath(s: str): bool {
    return s.startsWith("/") || s.startsWith("./");
  }

  pub static inflight isPathInflight(s: str): bool {
    return s.startsWith("/") || s.startsWith("./");
  }

  pub static resolveContentHash(scope: std.IResource, props: utils_api.WorkloadProps): str? {
    if !Util.isPath(props.image) {
      return nil;
    }
    
    let sources = props.sources ?? ["**/*"];
    let imageDir = props.image;
    return props.sourceHash ?? Util.contentHash(sources, imageDir);
  }
}