const child_process = require("child_process");
const fs = require('fs');
const wingsdk = require('@winglang/sdk');

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
  return wingsdk.core.App.of(scope).entrypointDir;
};

exports.fileExists = function(path) {
  return fs.existsSync(path);
};

exports.dirname = function() {
  return __dirname;
};