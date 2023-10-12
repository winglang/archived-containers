bring "cdk8s" as values_cdk8s;
bring util;

class Util {
  pub static all(): Map<str> {
    let all = MutMap<str>{};

    if let valuesFile = util.tryEnv("WING_VALUES_FILE") {
      if valuesFile != "undefined" { // bug
        if !Util.fileExists(valuesFile) {
          throw "Values file ${valuesFile} not found";
        }

        let yaml = values_cdk8s.Yaml.load(valuesFile);
        for x in yaml {
          let y: Json = x;
  
          for entry in Json.entries(y) {
            all.set(entry.key, entry.value.asStr());
          }
        }
      }
    }

    if let values = util.tryEnv("WING_VALUES") {
      if values != "undefined" {
        for v in values.split(",") {
          let kv = v.split("=");
          let key = kv.at(0);
          let value = kv.at(1);
          all.set(key, value);
        }
      }
    }

    return all.copy();
  }

  pub static tryGet(key: str): str? {
    return Util.all().get(key);
  }

  pub static has(key: str): bool {
    return Util.tryGet(key)?;
  }

  pub static get(key: str): str {
    if let value = Util.tryGet(key) {
      return value;
    } else {
      throw "Missing platform value '${key}' (use --values or -v)";
    }
  }

  extern "../util.js" static fileExists(path: str): bool;
}