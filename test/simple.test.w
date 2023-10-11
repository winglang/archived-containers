bring "../containers.w" as containers;

new containers.Workload(
  image: "hashicorp/http-echo",
  port: 5678,
  public: true,
  replicas: 2,
  args: ["-text=bang_bang"],
);
