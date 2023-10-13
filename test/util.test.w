bring "../utils.w" as utils;

let hash = utils.contentHash(["*/**"], "test/my-app");
assert(hash == "c50686c1a1d3007bf0f21838dec40eb4");
