bring "../tf-aws/ecr.w" as ecr;
bring "../utils.w" as utils;

new ecr.Repository(
  directory: utils.dirname() + "/test/my-app",
  tag: "t3"
);
