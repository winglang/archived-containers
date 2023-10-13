bring cloud;
bring http;
bring "../containers.w" as containers;

let app = new containers.Workload(
  image: "hashicorp/http-echo",
  port: 5678,
  public: true,
  replicas: 2,
  args: ["-text=bang_bang"],
) as "http-echo";

test "http get" {
  if let url = app.url() {
    let response = http.get(url);
    log(response.body ?? "");
    if let body = response.body {
      assert(body.contains("bang_bang"));
    }
  }
}
