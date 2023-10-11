bring "../tf-aws/values.w" as values;
bring util;

if let x = values.tryGet("foo") {
  log(x);
}