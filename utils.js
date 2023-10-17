const child_process = require("child_process");
const fs = require('fs');
const crypto = require('crypto');
const wingsdk = require('@winglang/sdk');
const glob = require('glob');
const path = require('path');

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
  const entrypoint = wingsdk.core.App.of(scope).entrypointDir;
  if (!entrypoint) {
    throw new Error('Entrypoint directory not found');
  }

  return entrypoint;
};

exports.dirname = function() {
  return __dirname;
};

exports.contentHash = function(patterns, cwd) {
  const hash = crypto.createHash('md5');
  const files = glob.globSync(patterns, { nodir: true, cwd });
  for (const f of files) {
    const data = fs.readFileSync(path.join(cwd, f));
    hash.update(data);
  }
  return hash.digest('hex');
};