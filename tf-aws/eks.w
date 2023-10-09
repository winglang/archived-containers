bring "cdktf" as cdktf;
bring "@cdktf/provider-aws" as tfaws;
bring aws;
bring cloud;
bring "./vpc.w" as v;
bring "@cdktf/provider-helm" as helm4;

class EksCluster {
  pub endpoint: str;
  pub certificate: str;
  pub name: str;

  init() {
    let clusterName = "wing-eks-${this.node.addr.substring(0, 6)}";

    let privateSubnetTags = MutMap<str>{};
    privateSubnetTags.set("kubernetes.io/role/internal-elb", "1");
    privateSubnetTags.set("kubernetes.io/cluster/${clusterName}", "shared");

    let publicSubnetTags = MutMap<str>{};
    publicSubnetTags.set("kubernetes.io/role/elb", "1");
    publicSubnetTags.set("kubernetes.io/cluster/${clusterName}", "shared");

    let vpc = new v.Vpc(
      privateSubnetTags: privateSubnetTags.copy(),
      publicSubnetTags: publicSubnetTags.copy(),
    );

    let eks = new cdktf.TerraformHclModule(
      source: "terraform-aws-modules/eks/aws",
      version: "19.17.1",
      variables: {
        cluster_name: clusterName,

        vpc_id: vpc.id,
        subnet_ids: vpc.privateSubnets,
        cluster_endpoint_public_access: true,
        // create_aws_auth_configmap: true,
        // manage_aws_auth_configmap: true,
        eks_managed_node_group_defaults: {
          ami_type: "AL2_x86_64"
        },
        eks_managed_node_groups: {
          one: {
            name: "node-group-1",
            instance_types: ["t3.small"],
            min_size: 1,
            max_size: 3,
            desired_size: 2
          },
          two: {
            name: "node-group-2",
            instance_types: ["t3.small"],
            min_size: 1,
            max_size: 2,
            desired_size: 1,
          },
        }
      }
    ) as "eks";

    let ebsCsiPolicy = new tfaws.dataAwsIamPolicy.DataAwsIamPolicy(arn: "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy");

    let irsaEbsCsi = new cdktf.TerraformHclModule(
      source: "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc",
      version: "5.30.0",
      variables: {
        create_role: true,
        role_name: "AmazonEKSTFEBSCSIRole-${clusterName}",
        provider_url: eks.get("oidc_provider"),
        role_policy_arns: [ebsCsiPolicy.arn],
        oidc_fully_qualified_subjects: ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
      }
    ) as "irsa-ebs-csi";

    new tfaws.eksAddon.EksAddon(
      clusterName: clusterName,
      addonName: "aws-ebs-csi-driver",
      addonVersion: "v1.20.0-eksbuild.1",
      serviceAccountRoleArn: irsaEbsCsi.get("iam_role_arn"),
      tags: {
        "eks_addon" => "ebs-csi",
        "terraform" => "true",
      },
    );

    this.name = clusterName;
    this.certificate = eks.get("cluster_certificate_authority_data");
    this.endpoint = eks.get("cluster_endpoint");

    new helm4.provider.HelmProvider(
      kubernetes: {
        host: this.endpoint,
        clusterCaCertificate: cdktf.Fn.base64decode(this.certificate),
        exec: {
          apiVersion: "client.authentication.k8s.io/v1beta1",
          args: ["eks", "get-token", "--cluster-name", this.name],
          command: "aws"
        }
      }
    );

    new cdktf.TerraformOutput(value: clusterName);
  }

  /**
   * Deploys a Helm chart to the cluster.
   */
  pub addChart(release: helm4.release.ReleaseConfig) {
    new helm4.release.Release(release);
  }
}
