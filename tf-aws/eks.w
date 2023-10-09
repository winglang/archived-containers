bring aws;
bring cloud;
bring "cdktf" as cdktf;
bring "@cdktf/provider-aws" as tfaws;
bring "@cdktf/provider-helm" as helm4;
bring "@cdktf/provider-kubernetes" as kubernetes;
bring "./vpc.w" as v;

class EksCluster {
  pub endpoint: str;
  pub certificate: str;
  pub name: str;
  pub oidcProviderArn: str;

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
    this.oidcProviderArn = eks.get("oidc_provider_arn");

    let k8sconfig = {
      host: this.endpoint,
      clusterCaCertificate: cdktf.Fn.base64decode(this.certificate),
      exec: {
        apiVersion: "client.authentication.k8s.io/v1beta1",
        args: ["eks", "get-token", "--cluster-name", this.name],
        command: "aws",
      }
    };

    new helm4.provider.HelmProvider(kubernetes: k8sconfig);
    new kubernetes.provider.KubernetesProvider(k8sconfig);

    let serviceAccountName = "aws-load-balancer-controller";
    let lbRole = new cdktf.TerraformHclModule(
      source: "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks",
      variables: {
        role_name: "eks-lb-role-${this.node.addr}",
        attach_load_balancer_controller_policy: true,
        oidc_providers: {
          main: {
            provider_arn: this.oidcProviderArn,
            namespace_service_accounts: ["kube-system:${serviceAccountName}"],
          }
        }
      }
    ) as "lb_role";

    let serviceAccount = new kubernetes.serviceAccount.ServiceAccount(
      metadata: {
        name: serviceAccountName,
        namespace: "kube-system",
        labels: {
          "app.kubernetes.io/name" => serviceAccountName,
          "app.kubernetes.io/component"=> "controller"
        },
        annotations: {
          "eks.amazonaws.com/role-arn" => lbRole.get("iam_role_arn"),
          "eks.amazonaws.com/sts-regional-endpoints" => "true"
        },
      }
    );

    new cdktf.TerraformOutput(value: clusterName);

    this.addChart(
      name: "aws-load-balancer-controller",
      repository: "https://aws.github.io/eks-charts",
      chart: "aws-load-balancer-controller",
      namespace: "kube-system",
      dependsOn: [serviceAccount],
      set: [
        { name: "region", value: EksUtil.awsRegion(this) },
        { name: "vpcId", value: vpc.id },
        { name: "serviceAccount.create", value: "false" },
        { name: "serviceAccount.name", value: serviceAccountName },
        { name: "clusterName", value: this.name },
      ]
    );
  }

  /**
   * Deploys a Helm chart to the cluster.
   */
  pub addChart(release: helm4.release.ReleaseConfig) {
    new helm4.release.Release(release) as release.name;
  }
}

class EksUtil {
  extern "./util.js" pub static awsRegion(scope: std.IResource): str;
}