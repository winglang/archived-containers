bring "../workload.w" as containers;
bring http;

let app = new containers.Workload(
  name: "my-app",
  image: "./my-app",
  port: 3000,
  public: true,
);

test "can access container" {
  let response = http.get("${app.publicUrl}");
  if let body = response.body {
    log(body);
  }
  
  assert((response.body ?? "") == "Hello, Wingnuts!");
}