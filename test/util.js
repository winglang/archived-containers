const child_process = require("child_process");
const cdk8s = require('cdk8s');
const fs = require('fs');
const os = require('os');
const path = require('path');
const cdktf = require('cdktf');
const wingsdk = require('@winglang/sdk');
const crypto = require('crypto');

exports.shell = async function (command, args, cwd) {
  return new Promise((resolve, reject) => {
    child_process.execFile(command, args, { cwd }, (error, stdout, stderr) => {
      if (error) {
        console.error(stderr);
        return reject(error);
      }

      return resolve(stdout ? stdout : stderr);
    });
  });
};

exports.entrypointDir = function (scope) {
  return scope.node.root.entrypointDir;
};

exports.toHelmChart = function(chart) {
  const app = cdk8s.App.of(chart);
  const outdir = wingsdk.core.App.of(chart).workdir;
  console.log(outdir);


  app.resolvers = [new cdk8s.LazyResolver(), new cdk8s.ImplicitTokenResolver(), new cdk8s.NumberStringUnionResolver()];
  const docs = cdk8s.App._synthChart(chart);
  const yaml = cdk8s.Yaml.stringify(...docs);

  const hash = crypto.createHash("md5").update(yaml).digest("hex");
  const reldir = `helm/${chart.name}-${hash}`;

  const workdir = path.join(outdir, reldir);//fs.mkdtempSync(path.join(os.tmpdir(), "helm."));
  const templates = path.join(workdir, "templates");
  fs.mkdirSync(templates, { recursive: true });
  fs.writeFileSync(path.join(templates, "all.yaml"), yaml);

  const manifest = {
    apiVersion: "v2",
    name: chart.name,
    description: chart.node.path,
    type: "application",
    version: "0.1.0",
    appVersion: hash,
  };

  fs.writeFileSync(path.join(workdir, "Chart.yaml"), cdk8s.Yaml.stringify(manifest));

  return path.join("./", ".wing", reldir);
};

exports.toEksCluster = x => x;

