const child_process = require("child_process");
const tfaws = require("@winglang/sdk/lib/target-tf-aws");

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

// exports.awsVpc = function(scope) {
//   return tfaws.App.of(scope).vpc;
// }

// exports.toSubnet = function(scope) {
//   return scope;
// }