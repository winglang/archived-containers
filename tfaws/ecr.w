bring "@cdktf/provider-aws" as ecr_aws;
bring "cdktf" as ecr_cdktf;
bring "@cdktf/provider-null" as ecr_null;
bring "./aws.w" as ecr_aws_info;

struct RepositoryProps {
  directory: str;
  name: str;
  tag: str;
}

class Repository {
  pub image: str;
  pub deps: Array<ecr_cdktf.ITerraformDependable>;

  init(props: RepositoryProps) {
    let deps = MutArray<ecr_cdktf.ITerraformDependable>[];

    let count = 5;

    let r = new ecr_aws.ecrRepository.EcrRepository(
      name: props.name,
      forceDelete: true,
      imageTagMutability: "IMMUTABLE",
      imageScanningConfiguration: {
        scanOnPush: true,
      }
    );

    deps.push(r);
    
    new ecr_aws.ecrLifecyclePolicy.EcrLifecyclePolicy(
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

    let awsInfo = ecr_aws_info.Aws.getOrCreate(this);
    let region = awsInfo.region();
    let accountId = awsInfo.accountId();
    let image = "${r.repositoryUrl}:${props.tag}";
    let arch = "linux/amd64";


    // null provider singleton
    let stack = ecr_cdktf.TerraformStack.of(this);
    let nullProviderId = "NullProvider";
    if !stack.node.tryFindChild(nullProviderId)? {
      new ecr_null.provider.NullProvider() as nullProviderId in stack;
    }    
    
    let publish = new ecr_null.resource.Resource(
      dependsOn: [r],
      triggers: {
        tag: image,
      },
      provisioners: [
        {
          type: "local-exec",
          command: [
            "aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${accountId}.dkr.ecr.${region}.amazonaws.com || exit 1",
            "docker buildx build --platform ${arch} -t ${image} ${props.directory} || exit 1",
            "docker push ${image} || exit 1",
          ].join("\n")
        }
      ],
    );

    deps.push(publish);

    this.image = image;
    this.deps = deps.copy();
  }
}
