bring "cdk8s" as values_cdk8s;
bring util;

class Util {
  pub static get(key: str): str {
    if let valuesFile = util.tryEnv("WING_VALUES_FILE") {
      let yaml = values_cdk8s.Yaml.load(valuesFile);
      log("values file: ${yaml}");
    }

    if let values = util.tryEnv("WING_VALUES") {
      for v in values.split(",") {
        let kv = v.split("=");
        let key = kv.at(0);
        let value = kv.at(1);
        log("${key} is ${value}");

      }
    }
  }
}