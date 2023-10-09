bring "../containers.w" as containers;
bring http;

let message = "hello, wing!";

let hello = new containers.Workload(
  image: "paulbouwer/hello-kubernetes:1",
  port: 8080,
  readiness: "/",
  env: {
    "MESSAGE" => message,
  }
);

test "workload started" {
  if let url = hello.url() {
    assert(http.get(url).body?.contains(message) ?? false);
  } else {
    assert(false);
  }
}