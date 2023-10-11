bring aws;
bring cloud;
bring "constructs" as c;
bring "cdktf" as cdktf;
bring "@cdktf/provider-aws" as tfaws;
bring "@cdktf/provider-helm" as helm4;
bring "@cdktf/provider-kubernetes" as kubernetes;
bring "./vpc.w" as v;
bring "./values.w" as values;

struct ClusterAttributes {
  name: str;
  certificate: str;
  endpoint: str;
}

interface ICluster extends std.IResource {
  attributes(): ClusterAttributes;
}

class ClusterRef impl ICluster {
  _attributes: ClusterAttributes;

  init(attributes: ClusterAttributes) {
    this._attributes = attributes;
  }

  pub attributes(): ClusterAttributes {
    return this._attributes;
  }
}

class HelmChart {
  init(cluster: ICluster, release: helm4.release.ReleaseConfig) {
    let stack = cdktf.TerraformStack.of(this);
    let singletonKey = "WingHelmProvider";
    let attributes = cluster.attributes();
    let existing = stack.node.tryFindChild(singletonKey);
    if !existing? {
      new helm4.provider.HelmProvider(kubernetes: {
        host: attributes.endpoint,
        clusterCaCertificate: cdktf.Fn.base64decode(attributes.certificate),
        exec: {
          apiVersion: "client.authentication.k8s.io/v1beta1",
          args: ["eks", "get-token", "--cluster-name", attributes.name],
          command: "aws",
        }
      }) as singletonKey in stack;
    }

    new helm4.release.Release(release) as release.name;
  }
}

class Cluster impl ICluster {

  /** singleton */
  pub static getOrCreate(scope: std.IResource): ICluster {
    let stack = cdktf.TerraformStack.of(scope);
    let uid = "WingEksCluster";
    let existing: ICluster? = unsafeCast(stack.node.tryFindChild(uid));

    let newCluster = (): ICluster => {
      if let attrs = Cluster.tryGetClusterAttributes() {
        return new ClusterRef(attrs) as uid in stack;
      } else {
        return new Cluster() as uid in stack;
      }
    };

    return existing ?? newCluster();
  }

  static tryGetClusterAttributes(): ClusterAttributes? {
    if !values.has("eks.cluster_name") {
      return nil;
    }

    return ClusterAttributes {
      name: values.get("eks.cluster_name"),
      certificate: values.get("eks.certificate"),
      endpoint: values.get("eks.endpoint"),
    };

  }

  _attributes: ClusterAttributes;
  _oidcProviderArn: str;

  vpc: v.Vpc;

  init() {
    let clusterName = "wing-eks-${this.node.addr.substring(0, 6)}";

    let privateSubnetTags = MutMap<str>{};
    privateSubnetTags.set("kubernetes.io/role/internal-elb", "1");
    privateSubnetTags.set("kubernetes.io/cluster/${clusterName}", "shared");

    let publicSubnetTags = MutMap<str>{};
    publicSubnetTags.set("kubernetes.io/role/elb", "1");
    publicSubnetTags.set("kubernetes.io/cluster/${clusterName}", "shared");

    this.vpc = new v.Vpc(
      privateSubnetTags: privateSubnetTags.copy(),
      publicSubnetTags: publicSubnetTags.copy(),
    );

    let cluster = new cdktf.TerraformHclModule(
      source: "terraform-aws-modules/eks/aws",
      version: "19.17.1",
      variables: {
        cluster_name: clusterName,

        vpc_id: this.vpc.id,
        subnet_ids: this.vpc.privateSubnets,
        cluster_endpoint_public_access: true,
        eks_managed_node_group_defaults: {
          ami_type: "AL2_x86_64"
        },
        eks_managed_node_groups: {
          system: {
            name: "system",
            instance_types: ["t3.small"],
            min_size: 1,
            max_size: 10,
            desired_size: 10
          },
        },
        fargate_profiles: {
          default: {
            name: "default",
            selectors: [
              { namespace: "default" }
            ]
          }
        },
        cluster_addons: {
          coredns: {
            most_recent: true,
          }
        }
      }
    ) as "eks";

    this._attributes = {
      name: clusterName,
      certificate:  cluster.get("cluster_certificate_authority_data"),
      endpoint: cluster.get("cluster_endpoint"),
    };

    this._oidcProviderArn = cluster.get("oidc_provider_arn");

    let ebsCsiPolicy = new tfaws.dataAwsIamPolicy.DataAwsIamPolicy(arn: "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy");

    let irsaEbsCsi = new cdktf.TerraformHclModule(
      source: "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc",
      version: "5.30.0",
      variables: {
        create_role: true,
        role_name: "AmazonEKSTFEBSCSIRole-${clusterName}",
        provider_url: cluster.get("oidc_provider"),
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

    // setup the "kubernetes" terraform provider
    new kubernetes.provider.KubernetesProvider(
      host: this._attributes.endpoint,
      clusterCaCertificate: cdktf.Fn.base64decode(this._attributes.certificate),
      exec: {
        apiVersion: "client.authentication.k8s.io/v1beta1",
        args: ["eks", "get-token", "--cluster-name", this._attributes.name],
        command: "aws",
      }
    );

    // output the cluster name
    new cdktf.TerraformOutput(value: this._attributes.name, description: "eks.cluster_name") as "eks.cluster_name";
    new cdktf.TerraformOutput(value: this._attributes.certificate, description: "eks.certificate") as "eks.certificate";
    new cdktf.TerraformOutput(value: this._attributes.endpoint, description: "eks.endpoint") as "eks.endpoint";

    // install the LB controller to support ingress
    this.addLoadBalancerController();
  }

  pub attributes(): ClusterAttributes { 
    return this._attributes;
  }

  addLoadBalancerController() {
    let region = new tfaws.dataAwsRegion.DataAwsRegion();
    let serviceAccountName = "aws-load-balancer-controller";
    let lbRole = new cdktf.TerraformHclModule(
      source: "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks",
      variables: {
        role_name: "eks-lb-role-${this.node.addr}",
        attach_load_balancer_controller_policy: true,
        oidc_providers: {
          main: {
            provider_arn: this._oidcProviderArn,
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

    new HelmChart(this, 
      name: "aws-load-balancer-controller",
      repository: "https://aws.github.io/eks-charts",
      chart: "aws-load-balancer-controller",
      namespace: "kube-system",
      dependsOn: [serviceAccount],
      set: [
        { name: "region", value: region.name },
        { name: "vpcId", value: this.vpc.id },
        { name: "serviceAccount.create", value: "false" },
        { name: "serviceAccount.name", value: serviceAccountName },
        { name: "clusterName", value: this._attributes.name },
      ]
    );
  }
}
