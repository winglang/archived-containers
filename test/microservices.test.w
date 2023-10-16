bring "../containers.w" as containers;
bring cloud;
bring http;

let producer = new containers.Workload(
  name: "producer",
  image: "./microservices-producer",
  port: 4000,
) as "producer";

let consumer = new containers.Workload(
  name: "consumer",
  image: "./microservices-consumer",
  port: 3000,
  public: true,
  env: {
    PRODUCER_URL: producer.internalUrl,
  }
);

