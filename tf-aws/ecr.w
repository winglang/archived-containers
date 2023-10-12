bring "@cdktf/provider-aws" as tfaws2;
bring "cdktf" as cdktf22;
bring "@cdktf/provider-null" as null_provider;
bring "@cdktf/provider-random" as random;
bring "./aws.w" as aws999;

struct RepositoryProps {
  directory: str;
  tag: str;
}

class Repository {
  pub image: str;

  init(props: RepositoryProps) {
    new random.provider.RandomProvider();
    // let uid = new random.id.Id(byteLength: 4).id;
    let uid = new random.integer.Integer(min: 100, max: 999).id;
    let repositoryName = "wing-ecr-${this.node.addr.substring(0, 6)}-${uid}";
    let count = 5;

    let r = new tfaws2.ecrRepository.EcrRepository(
      name: repositoryName,
      imageScanningConfiguration: {
        scanOnPush: true,
      }
    );
    
    new tfaws2.ecrLifecyclePolicy.EcrLifecyclePolicy(
      repository: r.name,
      policy: Json.stringify({
        rules: [
	        {
	          rulePriority: 1,
	          description: "Keep only the last ${count} untagged images.",
	          selection: {
	            tagStatus: "untagged",
	            countType: "imageCountMoreThan",
	            countNumber: count
	          },
	          action: {
	            type: "expire"
	          }
	        }
	      ]
      })
    );

    let awsInfo = aws999.Aws.getOrCreate(this);
    let region = awsInfo.region();
    let accountId = awsInfo.accountId();
    let image = "${r.repositoryUrl}:${props.tag}";
    let arch = "linux/amd64";

    new null_provider.provider.NullProvider();
    new null_provider.resource.Resource(
      dependsOn: [r],
      triggers: {
        tag: props.tag,
      },
      provisioners: [
        {
          type: "local-exec",
          command: [
            "aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${accountId}.dkr.ecr.${region}.amazonaws.com",
            "docker buildx build --platform ${arch} -t ${image} ${props.directory}",
            "docker push ${image}",
          ].join("\n")
        }
      ],
    );

    this.image = image;
  }
}