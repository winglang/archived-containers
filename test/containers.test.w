bring "../containers.w" as containers;
bring expect;
bring http;

let message = "hello, wing change!!";

let hello = new containers.Workload(
  name: "hello",
  image: "paulbouwer/hello-kubernetes:1",
  port: 8080,
  readiness: "/",
  replicas: 2,
  env: {
    "MESSAGE" => message,
  },
  public: true,
) as "hello";

new containers.Workload(
  name: "http-echo",
  image: "hashicorp/http-echo",
  port: 5678,
  public: true,
  replicas: 2,
  args: ["-text=hello1234"],
) as "http-echo";

let tryGetBody = inflight (): str? => {
};

test "ping" {
  if let url = hello.publicUrl {
    let body = http.get(url).body;
    assert(body?.contains(message) ?? false);
  } else {
    assert(false);
  }
}
