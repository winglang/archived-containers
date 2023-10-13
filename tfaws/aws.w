bring "cdktf" as aws_cdktf;
bring "@cdktf/provider-aws" as aws_aws;

class Aws {
  pub static getOrCreate(scope: std.IResource): Aws {
    let stack = aws_cdktf.TerraformStack.of(scope);
    let id = "WingAwsUtil";
    let existing: Aws? = unsafeCast(stack.node.tryFindChild(id));
    return (existing ?? new Aws() as id in stack);
  }

  regionData: aws_aws.dataAwsRegion.DataAwsRegion;
  accountData: aws_aws.dataAwsCallerIdentity.DataAwsCallerIdentity;


  init() { 
    this.regionData = new aws_aws.dataAwsRegion.DataAwsRegion();
    this.accountData = new aws_aws.dataAwsCallerIdentity.DataAwsCallerIdentity();
  }

  pub region(): str {
    return this.regionData.name;
  }

  pub accountId(): str {
    return this.accountData.accountId;
  }
}