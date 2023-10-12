bring "../containers.w" as containers;
bring http;

let app = new containers.Workload(
  image: "./my-app",
  port: 3000,
  public: true,
) as "my-app-4";

test "can access container" {
  let response = http.get("${app.url()}");
  assert((response.body ?? "") == "Hello, world!");
}